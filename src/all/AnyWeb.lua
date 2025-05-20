-- {"id": 23119214, "ver": "1.0.1", "libVer": "1.0.0", "author": "wasu-code", "dep": ["Readability>=1.0.0", "url", "unhtml"]}

local parseArticle = Require("Readability").parse
local qs = Require("url").querystring
local HTMLToString = Require("unhtml").HTMLToString

local novelUpdatesURL = "https://www.novelupdates.com"

-- Filters IDs
local FID_SORT = 2
local FID_ORDER = 3
local FID_STATUS = 4

local text = function(v)
    return v:text()
end

local function parseNovelUpdatesChapters(doc)
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

  local chapters = filter(
    map(
      doc2:select("a[href]"),
      function(card)
        if card:hasAttr("data-id") then
          local span = card:selectFirst("span")
          if span then
            return NovelChapter {
              title = span:attr("title"),
              link = "https:" .. card:attr("href"),
            }
          end
        end
        return nil  -- will be filtered out
      end
    ),
    function(chapter)
      return chapter ~= nil
    end
  )

  Reverse(chapters)
  return chapters
end

--- Parses novel and chapters from NovelUpdates metadata
--- @param novelUrl string full novel url.
--- @return NovelInfo
local function parseNUNovel(novelUrl, loadChapters)
  local doc = GETDocument(novelUrl)

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
    info:setChapters(parseNovelUpdatesChapters(doc))
  end

  return info
end

--- Parses any website as single-chapter novel
--- @param novelUrl string full novel url.
--- @return NovelInfo
local function parseWebsiteNovel(novelUrl, loadChapters)
  local doc = GETDocument(novelUrl)

  -- Attempt to extract metadata using OpenGraph tags
  local title = doc:selectFirst("meta[property='og:title']") and doc:selectFirst("meta[property='og:title']"):attr("content") 
                or doc:selectFirst("title"):text()
  local description = doc:selectFirst("meta[property='og:description']") and doc:selectFirst("meta[property='og:description']"):attr("content") or nil
  local imageURL = doc:selectFirst("meta[property='og:image']") and doc:selectFirst("meta[property='og:image']"):attr("content") 
                   or (doc:selectFirst("img[src]") and doc:selectFirst("img[src]"):attr("src"))
                   or nil
  local author = doc:selectFirst("meta[name='author']") and doc:selectFirst("meta[name='author']"):attr("content") or nil

  local info = NovelInfo {
    title = title and title:gsub("%s*[%-%|—]%s*.*$", "") or title,
    description = description,
    imageURL = imageURL,
    authors = author and { author } or nil
  }

  if loadChapters then
    info:setChapters({
      NovelChapter {
        title = title,
        link = novelUrl,
      }
    })
  end

  return info
end

local function parseNovel(novelUrl, loadChapters)
  if novelUrl:find(novelUpdatesURL, 1, true) then
    return parseNUNovel(novelUrl, loadChapters)
  else
    return parseWebsiteNovel(novelUrl, loadChapters)
  end
end

local function getPassage(chapterUrl)
  local doc = GETDocument(chapterUrl)
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

  if query:match("^https?://") then
    if data[PAGE] > 1 then return {} end
    return {
      Novel {
        title = "Click to load",
        link = query,
      }
    }
  else
    return searchNovelUpdates(data)
  end
end

local function parseListing(data)
  local doc = GETDocument(qs({
    sort = data[FID_SORT] + 1,
    order = data[FID_ORDER] and 2 or 1,
    status = data[FID_STATUS] + 1,
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

return {
	id = 23119214,
	name = "AnyWeb (+NovelUpdates)",
	baseURL = "",
	imageURL = "https://novelupdates.com/appicon.png",
  chapterType = ChapterType.HTML,
	hasCloudFlare = true,

	shrinkURL = function(url) return url end,
	expandURL = function(url) return url end,

  listings = {
    Listing("Series", true, parseListing),
  },
	parseNovel = parseNovel,
	getPassage = getPassage,

	hasSearch = true,
	isSearchIncrementing = true,
	search = search,

  searchFilters = {
    DropdownFilter(FID_SORT, "Sort by", {
      "Frequency", -- 1
      "Rank", -- 2
      "Rating", -- 3
      "Readers", -- 4
      "Chapters", -- 5
      "Reviews", -- 6
      "Title", -- 7
      "Last Updated" -- 8
    }),
	  SwitchFilter(FID_ORDER, "Descending"), -- 1: "Ascending", 2: "Descending"
    DropdownFilter(FID_STATUS, "Status", {
      "All", -- 1
      "Completed", -- 2
      "Ongoing", -- 3
      "Hiatus" -- 4
    }),
	},
}
