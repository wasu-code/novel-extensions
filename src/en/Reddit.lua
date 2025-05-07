-- {"id": 345674, "ver": "1.0.0", "libVer": "1.0.0", "author": "wasu", "dep": ["url>=1.0.0", "CommonCSS>=1.0.0"]}
-- https://www.reddit.com/svc/shreddit/community-more-posts/best/?after=dDNfMWhxdXA5aQ%3D%3D&t=DAY&name=shortstory&navigationSessionId=f73b84eb-6db4-4226-8559-555e50cd9320&feedLength=28&distance=25
-- TODO pagination
-- TODO search (subreddit name) or add subs in settings
-- TODO fix covers

local baseURL = "https://www.reddit.com"
local IMAGE_HI = "https://www.redditstatic.com/shreddit/assets/snoo_wave.png"
local DEFAULT_COVER = "https://redditinc.com/hs-fs/hubfs/Reddit%20Inc/Graphics/Headers/Desktop/RedditInc_Header_Brand.png?width=300&height=300&name=RedditInc_Header_Brand.png"

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
      imageUrl = IMAGE_HI
    }
  end)
end

local function parseNovel(novelUrl, loadChapters)
  local doc = GETDocument(expandURL(novelUrl))
  local info = NovelInfo {
    title = doc:selectFirst('h1[slot="title"]'):text(),
    description = doc:selectFirst('div[slot="text-body"] p'):text(),
    authors = {doc:selectFirst(".author-name"):text()},
    imageUrl = DEFAULT_COVER
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
  imageURL = "https://redditinc.com/hubfs/Reddit_Favicon_FullColor_48x48.png",

	shrinkURL = shrinkURL,
	expandURL = expandURL,

	listings = {
    Listing("r/shortstory", false, function(data)
      return parseListing(GETDocument(baseURL .. "/svc/shreddit/community-more-posts/best/?name=shortstory"))
    end),
  },

	parseNovel = parseNovel,

	chapterType = ChapterType.HTML,
	getPassage = function (chapterUrl)
    local doc = GETDocument(expandURL(chapterUrl))
    local story = doc:selectFirst('div[slot="text-body"]')
    return pageOfElem(story)
  end,

	-- Optional values to change
	hasCloudFlare = true,
	hasSearch = false,
	-- settings = settingsModel,


	-- Required if [settings] is not empty
	-- updateSetting = updateSetting,
}
