-- {"id": 23119214, "ver": "1.0.12", "libVer": "1.0.0", "author": "wasu-code", "dep": ["Readability>=1.1.0", "url", "unhtml", "FilterOptions"]}

local parseArticle = Require("Readability").parse
local qs = Require("url").querystring
local HTMLToString = Require("unhtml").HTMLToString
local FilterOptions = Require("FilterOptions")

math.randomseed(os.time())

local novelUpdatesURL = "https://www.novelupdates.com"

--- @deprecated Use filters to search and [ANYWEB_URL_PATTERN] to save URL
local INDEX_PREFIX = "index:"
--- Lua Pattern for URL format used with chapter indexes.  
--- Has two capturing groups: `index depth` and `url`.
local ANYWEB_URL_PATTERN = "^http://(%d+%.)anyweb%.invalid/(.*)$"

local USER_MANUAL = [[
  How to use this extension?
  In the search bar type/paste:

  🔍 keywords / search phrase
  → Search for novels on NovelUpdates

  🔍 url
  → Parse website as single-chapter novel

  🔍 url and change strategy in Filters
  → Parse website with multiple links as multi-chapter novel
  → Parse website with multiple links as listing of separate single-chapter novels
]]

local ANYWEB_MASCOT = [[
(\_/)   
( •,•)  
(")_(")
]]

-- Filters IDs
local FID_NU_SORT = 2
local FID_NU_ORDER = 3
local FID_NU_STATUS = 4
local FID_AW_APPROACH = 5
local FID_AW_INDEX_DEPTH = 6

-- Settings IDs
local SID_INDEX_DEPTH = 1
local SID_INDEX_EXCLUDE_SELECTOR = 2
local SID_USER_MANUAL = 3
local SID_CUSTOM_LISTINGS = 4
local settings = {
  [SID_INDEX_DEPTH] = 3,
  [SID_INDEX_EXCLUDE_SELECTOR] = "footer, header, nav, .nav, .footer, .header",
  [SID_CUSTOM_LISTINGS] = ""
}

local approachFilter = FilterOptions {
  { novel = "Single-chapter novel" },
  { index = "Multi-chapter novel (index)" },
  { listing = "Listing of novels" }
}

local text = function(v)
    return v:text()
end

--- Resolves a possibly relative URL to an absolute URL based on the current URL.
--- Handles absolute URLs, protocol-relative URLs, root-relative URLs, and relative paths.
--- @param url string The URL to resolve (can be absolute or relative).
--- @param currentURL string The base URL to resolve against.
--- @return string The resolved absolute URL.
local function resolveURL(url, currentURL)
  if url:match("^https?://") then
    return url
  elseif url:sub(1, 2) == "//" then
    -- Protocol-relative URL
    local scheme = currentURL:match("^(https?)://")
    return scheme and (scheme .. ":" .. url) or ("https:" .. url)
  elseif url:sub(1, 1) == "/" then
    -- Root-relative URL
    local base = currentURL:match("^(https?://[^/]+)")
    return base and (base .. url) or url
  else
    -- Relative to current path
    local base = currentURL:match("^(https?://.*/)")
    return base and (base .. url) or url
  end
end

--- Parses chapters from NovelUpdates by sending an AJAX request using extracted hidden form fields.
--- This function requires the user to be logged in and will throw an error if not authenticated.
---
--- @param doc Document The HTML document of the NovelUpdates novel page.
--- @return NovelChapter[] chapters A list of NovelChapter objects, in ascending order.
local function parseChapters_fromNU(doc)
  if not doc:selectFirst("#logged_avatar") then
    error("Login in WebView to show chapters")
  end

  local doc2 = RequestDocument(
    POST(novelUpdatesURL .. "/wp-admin/admin-ajax.php", nil,
        FormBodyBuilder()
            :add("action", "nd_getchapters")
            :add("mygrr", doc:selectFirst("#grr_groups"):attr("value"))
            :add("mygroupfilter", "")
            :add("mypostid", doc:selectFirst("#mypostid"):attr("value"))
            :build()
    )
  )

  local chapters = map(doc2:select("a[href][data-id]"),
    function(card)
      return NovelChapter {
        title = card:selectFirst("span"):attr("title"),
        link = "https:" .. card:attr("href"),
      }
    end
  )

  -- Reverse the chapters list
  local n = #chapters
  for i = 1, math.floor(n / 2) do
    chapters[i], chapters[n - i + 1] = chapters[n - i + 1], chapters[i]
  end

  for index, chapter in ipairs(chapters) do
    chapter:setOrder(index)
  end

  return chapters
end

--- Parses novel and chapters from NovelUpdates metadata
--- @param novelURL string full novel url.
--- @return NovelInfo
local function parseNovel_fromNU(novelURL, loadChapters)
  local doc = GETDocument(novelURL)

  local info = NovelInfo {
    title = doc:selectFirst(".seriestitlenu"):text(),
    imageURL = doc:selectFirst(".seriesimg img[src], .serieseditimg img"):attr("src"),
    description = HTMLToString(doc:selectFirst("#editdescription")),
    alternativeTitles = map(
      (function()
        local titles = {}
        for title in doc:select("#editassociated"):text():gmatch("[^\n]+") do
          table.insert(titles, title)
        end
        return titles
      end)(),
      function(title) return title:match("^%s*(.-)%s*$") end
    ),
    tags = map(doc:select("#showtags a"), text),
    genres = map(doc:select("#seriesgenre a"), text),
    authors = map(doc:select("#showauthors a"), text),
    artists = map(doc:select("#showartists a"), text)
  }

  if loadChapters then
    info:setChapters(parseChapters_fromNU(doc))
  end

  return info
end

--- Parses a website's chapter index by analyzing HTML structure and selecting the most likely container of chapter links.
--- This function is intended for INDEX mode where chapters are listed on a single page (not paginated).
---
--- @param doc Document The parsed HTML document object representing the novel index page.
--- @param indexURL string Base URL used for resolving relative paths.
--- @param entryType NovelChapter | Novel Type of entries in result array.
--- @param maxDepth number Maximum depth of index searching strategy
--- @return NovelChapter[]|Novel[] A list of NovelChapter or Novel objects.
local function parseChapters_fromIndex(doc, indexURL, entryType, maxDepth)
  local excludeSelector = settings[SID_INDEX_EXCLUDE_SELECTOR]

  -- Remove excluded elements
  if excludeSelector and excludeSelector ~= "" then
    map(doc:select(excludeSelector), function (el)
      el:remove()
    end)
  end

  local selectors, weights = {}, {}
  for d = 1, maxDepth do
    local path = string.rep("> * ", d)
    local selector = (path .. "> a"):gsub("> %* > a", "> a") -- fix for depth=1
    table.insert(selectors, selector)
    table.insert(weights, math.max(1, maxDepth - (d - 1))) -- e.g. depth 1 = 3, depth 2 = 2, etc.
  end

  local candidates = {}
  map(doc:select("*"), function(el)
    for _, sel in ipairs(selectors) do
      if el:select(sel):size() > 0 then
        table.insert(candidates, el)
        break
      end
    end
  end)

  local bestScore, bestContainer = 0, nil
  for _, container in ipairs(candidates) do
    local score = 0
    for i, sel in ipairs(selectors) do
      score = score + container:select(sel):size() * weights[i]
    end
    if score > bestScore then
      bestScore = score
      bestContainer = container
    end
  end

  local chapters = {}
  if bestContainer then
    map(bestContainer:select("a"), function(a)
      local entry = entryType {
        title = a:text():match("^%s*(.-)%s*$") ~= "" and a:text() or "Untitled",
        link = resolveURL(a:attr("href"), indexURL),
      }
      if entryType == Novel and a:selectFirst("img") then
        entry:setImageURL(resolveURL(a:selectFirst("img"):attr("src"), indexURL))
      end
      table.insert(chapters, entry)
    end)
  end

  for index, chapter in ipairs(chapters) do
    chapter:setOrder(index)
  end

  return chapters
end

--- Parses any website as single- or multi-chapter (when prefixed with index prefix) novel
--- @param novelURL string full novel url.
--- @param loadChapters boolean indicates whether chapters should be parsed (or only novel metadata).
--- @param isIndex boolean indicates wether website should be parsed as index of chapters.
--- @param depth number? max depth of index (required when `isIndex` is `true`).
--- @return NovelInfo
local function parseNovel_fromWebsite(novelURL, loadChapters, isIndex, depth)
  if isIndex then assert(depth ~= nil, "Index depth should not be nil") end

  local doc = GETDocument(novelURL)

  -- Attempt to extract metadata using OpenGraph tags
  local title = doc:selectFirst("meta[property='og:title']") and doc:selectFirst("meta[property='og:title']"):attr("content") 
                or doc:selectFirst("title"):text()
  local description = doc:selectFirst("meta[property='og:description']") and doc:selectFirst("meta[property='og:description']"):attr("content") or nil
  local imageURL = doc:selectFirst("meta[property='og:image']") and doc:selectFirst("meta[property='og:image']"):attr("content") 
                   or (doc:selectFirst("img[src]") and resolveURL((doc:selectFirst("img[src]"):attr("src")), novelURL))
                   or nil
  local author = doc:selectFirst("meta[name='author']") and doc:selectFirst("meta[name='author']"):attr("content") or nil

  local info = NovelInfo {
    title = title and title:gsub("%s*[%-%|—]%s*.*$", "") or title,
    description = description,
    imageURL = imageURL,
    authors = author and { author } or nil
  }

  if loadChapters then
    if isIndex then
      info:setChapters(parseChapters_fromIndex(doc, novelURL, NovelChapter, depth))
    else
      info:setChapters({
        NovelChapter {
          title = title,
          link = novelURL,
        }
      })
    end
  end

  return info
end

local function parseNovel(novelURL, loadChapters)
  if novelURL:find(novelUpdatesURL, 1, true) then
    return parseNovel_fromNU(novelURL, loadChapters)
  else
    local isIndex = false

    local depth, indexURL = string.match(novelURL, ANYWEB_URL_PATTERN)
    if indexURL ~= nil then
      isIndex = true
      depth = tonumber(depth)
      novelURL = indexURL
    end

    -- backward compatibility
    if novelURL:sub(1, INDEX_PREFIX:len()) == INDEX_PREFIX then
      isIndex = true
      depth = tonumber(settings[SID_INDEX_DEPTH]) or 3
      novelURL = novelURL:sub(INDEX_PREFIX:len() + 1)  -- remove the index prefix
    end

    return parseNovel_fromWebsite(novelURL, loadChapters, isIndex, depth)
  end
end

local function getPassage(chapterURL)
  local doc = GETDocument(chapterURL)
  return pageOfElem(parseArticle(doc), true, "", true)
end

local function searchNovelUpdates(data)
  local query = data[QUERY]
  local page = data[PAGE]

  local doc = GETDocument(qs({
    sf = 1,
    sh = query,
    sort = "sdate",
    order ="desc",
    pg = page
  }, novelUpdatesURL .. "/series-finder"))

  return map(doc:select(".search_main_box_nu"), function(card)
    local a = card:selectFirst(".search_title > a[href]")
    return Novel {
      title = a:text(),
      link = a:attr("href"),
      imageURL = card:selectFirst(".search_img_nu > img[src]"):attr("src")
    }
  end)
end

local function search(data)
  local query = data[QUERY]

  -- delegate text-based searches to Novel Updates
  if not query:match("^https?://") then
    return searchNovelUpdates(data)
  end

  -- AnyWeb doesn't support pagination
  if data[PAGE] > 1 then return {} end

  local approach = approachFilter:valueOfOrFirst(data[FID_AW_APPROACH])
  local url = query
  local depth = tonumber(data[FID_AW_INDEX_DEPTH]) or tonumber(settings[SID_INDEX_DEPTH]) or 3

  if approach == "listing" then
    local doc = GETDocument(url)
    return parseChapters_fromIndex(doc, url, Novel, depth)
  end

  if approach == "index" then
    url = string.format("http://%d.anyweb.invalid/%s", depth, url)
  end

  return {
    Novel {
      title = "Click to load",
      link = url,
    }
  }
end

local function parseListing(data)
  local doc = GETDocument(qs({
    sort = (data[FID_NU_SORT] or 0) + 1,
    order = data[FID_NU_ORDER] and 2 or 1,
    status = (data[FID_NU_STATUS] or 0) + 1,
    pg = data[PAGE]
  }, novelUpdatesURL .. "/novelslisting/"))

  return map(doc:select(".search_main_box_nu"), function(card)
    local a = card:selectFirst(".search_title > a[href]")
    return Novel {
      title = a:text(),
      link = a:attr("href"),
      imageURL = card:selectFirst(".search_img_nu > img[src]"):attr("src")
    }
  end)
end

local function splitLines(long_text)
    -- trim leading and trailing whitespace
    long_text = long_text:match("^%s*(.-)%s*$")

    local lines = {}
    for line in long_text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    return lines
end

return {
  id = 23119214,
  name = "AnyWeb (+NovelUpdates)",
  baseURL = novelUpdatesURL,
  imageURL = "https://novelupdates.com/appicon.png",
  chapterType = ChapterType.HTML,
  hasCloudFlare = true,

  shrinkURL = function(url) return url end,
  expandURL = function(url)
    -- remove legacy the index prefix so novel can be opened in webview
    if url:sub(1, INDEX_PREFIX:len()) == INDEX_PREFIX then
      return url:sub(INDEX_PREFIX:len() + 1)
    end

    -- remove AnyWeb URL pattern so novel can be opened in webview
    local _, indexURL = string.match(url, ANYWEB_URL_PATTERN)
    if indexURL ~= nil then
      return indexURL
    end

    return url
  end,

  listings = {
    Listing("NovelUpdates", true, parseListing),
    Listing("AnyWeb", false, function() error(
      "\n\n" .. ANYWEB_MASCOT .. "\n\n" .. USER_MANUAL)
    end),
    Listing("Custom", false, function (data)
      local links = splitLines(settings[SID_CUSTOM_LISTINGS])
      if #links < 1 then
        error("Add listing URL(s) in extension settings")
      end

      local listingURL = links[math.random(1, #links)]
      local doc = GETDocument(listingURL)
      local depth = tonumber(data[FID_AW_INDEX_DEPTH]) or tonumber(settings[SID_INDEX_DEPTH]) or 3
      return parseChapters_fromIndex(doc, listingURL, Novel, depth)
    end)
  },
  parseNovel = parseNovel,
  getPassage = getPassage,

  hasSearch = true,
  isSearchIncrementing = true,
  search = search,

  searchFilters = {
    FilterGroup("AnyWeb", {
      DropdownFilter(FID_AW_APPROACH, "Parse as", approachFilter:labels()),
      TextFilter(FID_AW_INDEX_DEPTH, "Index depth")
    }),
    FilterGroup("NovelUpdates", {
      DropdownFilter(FID_NU_SORT, "Sort by", {
        "Frequency", -- 1
        "Rank", -- 2
        "Rating", -- 3
        "Readers", -- 4
        "Chapters", -- 5
        "Reviews", -- 6
        "Title", -- 7
        "Last Updated" -- 8
    }),
    SwitchFilter(FID_NU_ORDER, "Descending"), -- 1: "Ascending", 2: "Descending"
    DropdownFilter(FID_NU_STATUS, "Status", {
      "All", -- 1
      "Completed", -- 2
      "Ongoing", -- 3
      "Hiatus" -- 4
    }),
    }),
  },

  settings = {
    TextFilter(SID_INDEX_EXCLUDE_SELECTOR, "Index Exclude Selector (default: footer, header, nav, .nav, .footer, .header)"),
    TextFilter(SID_INDEX_DEPTH, "Index Depth (default: 3)"),
    TextFilter(SID_CUSTOM_LISTINGS, "URL(s) for Custom Listing (one per line)"),
    TriStateFilter(SID_USER_MANUAL, USER_MANUAL),
  },
  updateSetting = function(id, value)
    settings[id] = value
  end,
}
