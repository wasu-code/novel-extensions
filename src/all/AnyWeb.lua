-- {"id": 23119214, "ver": "0.0.1", "libVer": "1.0.0", "author": "wasu-code", "dep": []}

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
  doc:select("script"):remove()
  doc:select("style"):remove()
  doc:select("head"):remove()

  local body = doc:selectFirst("body")
  body:attr("id", "shosetsu-content")

  local script = [[
    var styleBackup = []; /*backup shosetsu stylesheets*/
    document.querySelectorAll("style").forEach(function(style) {
      styleBackup.push(style.outerHTML);
    });

    var article = new Readability(document, {
      keepClasses: true
    }).parse();
    document.getElementById("shosetsu-content").innerHTML = article.content;

    styleBackup.forEach(function(style) {
      document.head.insertAdjacentHTML("beforeend", style);
    });
  ]]
  body:append('<script src="https://cdnjs.cloudflare.com/ajax/libs/readability/0.6.0/Readability.min.js" integrity="sha512-gUyZHlv5aSSuW4HZmQxiuWLagqsiddDmftdPnfgjzjfGlbYnK+Ukam3TAAqKnZ3JXdsaFEwx8o9HGRaj6++ZnA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>')
  body:append('<script>' .. script .. '</script>')

  return pageOfElem(body, true, "", true)
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
