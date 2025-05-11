-- {"id": 23119214, "ver": "0.0.2", "libVer": "1.0.0", "author": "wasu-code", "dep": ["Readability>=1.0.0"]}

local parseArticle = Require("Readability").parse

local function parseNovel(novelUrl, loadChapters)
  local doc = GETDocument(novelUrl)

  local info = NovelInfo {
    title = doc:selectFirst('title'):text(),
  }

  if loadChapters then
    info:setChapters({
      NovelChapter {
        title = doc:selectFirst('title'):text(),
        link = novelUrl,
      }
    })
  end
  return info
end

local function getPassage(chapterUrl)
  local doc = GETDocument(chapterUrl)
  return pageOfElem(parseArticle(doc), true, "", true)
end

local function search(data)
  local query = data[QUERY]

  return {
    Novel {
      title = "Click to load",
      link = query,
    }
  }
end

return {
	-- Required
	id = 23119214,
	name = "AnyWeb",
	baseURL = "",
  chapterType = ChapterType.HTML,

	shrinkURL = function(url) return url end,
	expandURL = function(url) return url end,

  listings = {
    Listing("Example", false, function(data) return {} end),
  },
	parseNovel = parseNovel,
	getPassage = getPassage,

	-- Optional values to change
	-- imageURL = imageURL,
	-- hasCloudFlare = hasCloudFlare,
	hasSearch = true,
	isSearchIncrementing = true,
	search = search,
}
