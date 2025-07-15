-- {"id": 23119212, "ver": "1.0.3", "libVer": "1.0.0", "author": "wasu-code", "dep": ["url>=1.0.0"]}

local qs = Require("url").querystring

local baseURL = "https://www.reddit.com"
local css = [[
pre {
  white-space: pre-wrap;
  word-wrap: break-word;
}
]]

local SNOO_HI = "https://www.redditstatic.com/shreddit/assets/snoo_wave.png"
local DEFAULT_COVER = "https://redditinc.com/hubfs/Reddit%20Inc/Blog/Imported_Blog_Media/BlogHeader_PortalSnoo_002.png"
local DEFAULT_COVER2 = "https://redditinc.com/hubfs/Reddit%20Inc/Blog/Imported_Blog_Media/BlogHeader_PortalSnoo_003.jpg"

local NEXT_PAGE_URL -- will hold next page url (shrunken) with token param
local LAST_SUBREDDIT -- will hold last used listing (to be used in search)

-- Filters
local FID_SORT = 2
local SORT_VALUES = {"new", "best", "hot", "top", "rising"}
local FID_FLAIR = 3

-- Settings (holds custom subreddits/listings)
local settings = {
  [1] = "",
  [2] = "",
  [3] = "",
  [4] = "",
  [5] = "",
}

local function shrinkURL(url)
  return url:gsub("^https://www.reddit.com/?", "")
end

local function expandURL(url)
  return baseURL .. "/" .. url
end

local function parseListing(doc)
  return map(doc:select("article:has(a[slot=full-post-link])"), function(card)
    local a = card:selectFirst("a[slot=full-post-link]")
    local img = card:selectFirst("[slot=post-media-container] img")
    return Novel {
      title = a:text(),
      link = shrinkURL(a:attr("href")),
      imageURL = img and img:attr("src") or DEFAULT_COVER
    }
  end)
end

local function parseSearch(doc)
  return map(doc:select("[data-testid=search-post-unit]"), function(card)
    local a = card:selectFirst("a[data-testid=post-title-text]")
    local img = card:selectFirst("faceplate-img")
    return Novel {
      title = card:text(),
      link = shrinkURL(card:attr("href")),
      imageURL = img and img:attr("src") or DEFAULT_COVER
    }
  end)
end

local function listing(data, subreddit)
  if not subreddit or subreddit == "" then
    error("Subreddit not provided (set subreddit name in extension's settings)")
  end

  LAST_SUBREDDIT = subreddit

  local page = data[PAGE]
  local sort = SORT_VALUES[data[FID_SORT] + 1]
  local flair = data[FID_FLAIR]

  local params = {
    name = subreddit
  }
  if flair ~= "" then
    params.f = '"' .. flair .. '"'
  end

  local url

  if page > 1 then
    url = NEXT_PAGE_URL
  else
    url = qs(params, "/svc/shreddit/community-more-posts/".. sort .. "/")
  end

  local doc = GETDocument(expandURL(url))
  local nextPageElement = doc:selectFirst('faceplate-partial[slot="load-after"]')
  NEXT_PAGE_URL = nextPageElement:attr("src")

  return parseListing(doc)
end

local function parseNovel(novelUrl, loadChapters)
  local doc = GETDocument(expandURL(novelUrl))

  local descElem = doc:selectFirst('div[slot="text-body"] p')
  local genreElem = doc:selectFirst('[slot="post-flair"] .flair-content')

  local function getSrc(selector)
    local el = doc:selectFirst(selector)
    return el and el:attr("src")
  end

  local info = NovelInfo {
    title = doc:selectFirst('h1[slot="title"]'):text(),
    description = descElem and descElem:text() or "THIS POST DOES NOT CONTAIN TEXT",
    authors = {doc:selectFirst(".author-name"):text()},
    imageURL = getSrc("img#post-image") -- post image
            or getSrc("img.media-lightbox-img") -- first image in gallery
            or getSrc('div[slot="text-body"] img') -- first image inside text post
            or DEFAULT_COVER2,
    genres = genreElem and {genreElem:text()} or {}
  }

  if loadChapters then
    info:setChapters({
      NovelChapter {
        title = doc:selectFirst('h1[slot="title"]'):text(),
        link = novelUrl,
      }
    })
  end
  return info
end

local function gatherCustomListings()
  return map(settings, function(value, index)
    return Listing("Custom subreddit " .. index, true, function(data) return listing(data, settings[index]) end)
  end)
end

local function gatherCustomSettings()
  return map(settings, function(value, index)
    return TextFilter(index, "Custom subreddit " .. index .. " (without /r prefix)")
  end)
end

local function search(data)
  local query = data[QUERY]

  if query:match("^r/") then
    -- If the query starts with "r/", treat it as a subreddit name
    return listing(data, query:sub(3)) -- Remove the "r/" prefix
  elseif query:match("^https?://[w.]*reddit.com/") then
    -- If the query is a Reddit URL, extract the path and use it
    local subredditPath = query:match("^https?://[w.]*reddit.com/(.+)")
    if data[PAGE] > 1 then return {} end -- Don't double the result
    return {
      Novel {
      title = "Click to load",
      link = subredditPath,
      imageURL = DEFAULT_COVER
    }
    }
  else
    -- search in last used subreddit

    -- will appear in global search if extension/any subreddit wasn't yet opened in app
    if not LAST_SUBREDDIT then error("Invalid query format. Expected: 'r/subreddit' or a valid Reddit URL.") end

    local page = data[PAGE]
    local sort = SORT_VALUES[data[FID_SORT] + 1]
    local flair = data[FID_FLAIR]

    local url

    if page > 1 then
      url = NEXT_PAGE_URL
    else
      url = "/svc/shreddit/search?q=subreddit:" .. LAST_SUBREDDIT .. "+" .. query
      url = url .. (flair ~= "" and '+flair:%22"'..flair..'"' or "")
      url = url .. (sort ~= "" and "&sort="..sort or "")
      url = url .. "&type=posts"
    end

    local doc = GETDocument(expandURL(url))
    local nextPageElement = doc:selectFirst('faceplate-partial')
    NEXT_PAGE_URL = nextPageElement:attr("src")

    return parseSearch(doc)
  end
end

return {
	-- Required
	id = 23119212,
	name = "Reddit",
	baseURL = baseURL,
  imageURL = SNOO_HI,
	hasCloudFlare = true,

	shrinkURL = shrinkURL,
	expandURL = expandURL,

	listings = {
    Listing("r/shortstories", true, function(data) return listing(data, "shortstories") end),
    Listing("r/shortstory", true, function(data) return listing(data, "shortstory") end),
    table.unpack(gatherCustomListings())
  },

	parseNovel = parseNovel,

	chapterType = ChapterType.HTML,
	getPassage = function (chapterUrl)
    local doc = GETDocument(expandURL(chapterUrl))
    local story = doc:selectFirst('div[slot="text-body"]')
    return pageOfElem(story, false, css)
  end,

	hasSearch = true,
  isSearchIncrementing = true,
  search = search,
  searchFilters = {
    DropdownFilter(FID_SORT, "Sorting", SORT_VALUES),
    TextFilter(FID_FLAIR, "Flair")
	},

  settings = gatherCustomSettings(),
	updateSetting = function(id, value)
    settings[id] = value
  end,
}
