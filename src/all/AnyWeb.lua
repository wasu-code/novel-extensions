-- {"id": 23119214, "ver": "0.0.2", "libVer": "1.0.0", "author": "wasu-code", "dep": ["Readability>=1.0.0", "url"]}

local parseArticle = Require("Readability").parse
local qs = Require("url").querystring

local novelUpdatesURL = "https://www.novelupdates.com"

local function parseNovel(novelUrl, loadChapters)
  local doc = GETDocument(novelUrl)

  -- TODO more accurate metadata
  local info = NovelInfo {
    title = doc:selectFirst('title'):text(),
  }

  if loadChapters then
    if not novelUrl:find(novelUpdatesURL, 1, true) then
      info:setChapters({
        NovelChapter {
          title = doc:selectFirst('title'):text(),
          link = novelUrl,
        }
      })
    else
      -- Handle chapters for novelUpdatesURL

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

      info:setChapters(
        filter(
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
      )

    end
  end

  return info
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

local function parseListing(url, data)
  return {}
end

return {
	id = 23119214,
	name = "AnyWeb",
	baseURL = "",
  chapterType = ChapterType.HTML,
	hasCloudFlare = true,

	shrinkURL = function(url) return url end,
	expandURL = function(url) return url end,

  listings = {
    Listing("Example", true, function(data) return parseListing("https://www.novelupdates.com/novelslisting/?sort=7&order=1&status=1", data) end),
  },
	parseNovel = parseNovel,
	getPassage = getPassage,

	-- Optional values to change
	-- imageURL = imageURL,
	hasSearch = true,
	isSearchIncrementing = true,
	search = search,
}
