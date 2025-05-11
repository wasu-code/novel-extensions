-- {"id": 23119214, "ver": "0.0.2", "libVer": "1.0.0", "author": "wasu-code", "dep": ["Readability>=1.0.0", "url"]}

local parseArticle = Require("Readability").parse
local qs = Require("url").querystring

local text = function(v)
    return v:text()
end

local novelUpdatesURL = "https://www.novelupdates.com"

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

  return filter(
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
end

--- Parses novel and chapters from NovelUpdates metadata
--- @param novelUrl string full novel url.
--- @return NovelInfo
local function parseNUNovel(novelUrl, loadChapters)
  local doc = GETDocument(novelUrl)

  local info = NovelInfo {
    title = doc:selectFirst(".seriestitlenu"):text(),
    imageURL = doc:selectFirst("div.seriesimg img[src]") and doc:selectFirst("div.seriesimg img[src]"):attr("src") or nil, -- TODO why not working
    description = doc:selectFirst("#editdescription"):text(),
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
    title = title,
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

local function parseListing(url, data)
  return {}
end

return {
	id = 23119214,
	name = "AnyWeb",
	baseURL = "",
	imageURL = "https://novelupdates.com/appicon.png",
  chapterType = ChapterType.HTML,
	hasCloudFlare = true,

	shrinkURL = function(url) return url end,
	expandURL = function(url) return url end,

  listings = {
    Listing("Example", true, function(data) return parseListing("https://www.novelupdates.com/novelslisting/?sort=7&order=1&status=1", data) end),
  },
	parseNovel = parseNovel,
	getPassage = getPassage,

	hasSearch = true,
	isSearchIncrementing = true,
	search = search,
}
