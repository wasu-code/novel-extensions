-- {"id": 345674, "ver": "1.0.0", "libVer": "1.0.0", "author": "wasu", "dep": ["url>=1.0.0", "CommonCSS>=1.0.0"]}
-- https://www.reddit.com/svc/shreddit/community-more-posts/best/?after=dDNfMWhxdXA5aQ%3D%3D&t=DAY&name=shortstory&navigationSessionId=f73b84eb-6db4-4226-8559-555e50cd9320&feedLength=28&distance=25

-- TODO fix covers

local baseURL = "https://www.reddit.com"

local SNOO_HI = "https://www.redditstatic.com/shreddit/assets/snoo_wave.png"
local DEFAULT_COVER = "https://redditinc.com/hs-fs/hubfs/Reddit%20Inc/Graphics/Headers/Desktop/RedditInc_Header_Brand.png?width=300&height=300"

local NEXT_PAGE_URL -- will hold next page url (shrunken) with token param
local FID_SORT = 2
local SORT_VALUES = {"new", "best", "hot", "top", "rising"}

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
      imageUrl = DEFAULT_COVER
    }
  end)
end

local function listing(data, query)
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
  local info = NovelInfo {
    title = doc:selectFirst('h1[slot="title"]'):text(),
    description = descElem and descElem:text() or "THIS POST DOES NOT CONTAIN TEXT",
    authors = {doc:selectFirst(".author-name"):text()},
    imageUrl = SNOO_HI
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

	-- settings = settingsModel,
	-- Required if [settings] is not empty
	-- updateSetting = updateSetting,
}
