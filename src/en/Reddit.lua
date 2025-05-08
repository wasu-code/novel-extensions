-- {"id": 345674, "ver": "1.0.0", "libVer": "1.0.0", "author": "wasu", "dep": []}

-- TODO fix covers

local baseURL = "https://www.reddit.com"

local SNOO_HI = "https://www.redditstatic.com/shreddit/assets/snoo_wave.png"
local DEFAULT_COVER = "https://redditinc.com/hubfs/Reddit%20Inc/Blog/Imported_Blog_Media/BlogHeader_PortalSnoo_002.png"
local DEFAULT_COVER2 = "https://redditinc.com/hubfs/Reddit%20Inc/Blog/Imported_Blog_Media/BlogHeader_PortalSnoo_003.jpg"

local NEXT_PAGE_URL -- will hold next page url (shrunken) with token param

-- Filters
local FID_SORT = 2
local SORT_VALUES = {"new", "best", "hot", "top", "rising"}

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
  return map(doc:select('a[slot="full-post-link"]'), function(card)
    return Novel {
      title = card:text(),
      link = shrinkURL(card:attr("href")),
      imageURL = DEFAULT_COVER
    }
  end)
end

local function listing(data, query)
  if not query or query == "" then
    error("Subreddit not provided (set subreddit name in extension's settings)")
  end

  local page = data[PAGE]
  local sort = SORT_VALUES[data[FID_SORT] + 1]

  local url = "/svc/shreddit/community-more-posts/".. sort .."/?name=" .. query
  if page > 1 then
    url = NEXT_PAGE_URL
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

  local info = NovelInfo {
    title = doc:selectFirst('h1[slot="title"]'):text(),
    description = descElem and descElem:text() or "THIS POST DOES NOT CONTAIN TEXT",
    authors = {doc:selectFirst(".author-name"):text()},
    imageURL = DEFAULT_COVER2,
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

return {
	-- Required
	id = 345674,
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
    return pageOfElem(story)
  end,

	hasSearch = true,
  isSearchIncrementing = true,
  search = function(data) return listing(data, data[QUERY]) end,
  searchFilters = {
    DropdownFilter(FID_SORT, "Sorting", SORT_VALUES),
	},

  settings = gatherCustomSettings(),
	updateSetting = function(id, value)
    settings[id] = value
  end,
}
