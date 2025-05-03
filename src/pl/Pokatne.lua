-- {"id": 90001, "ver": "1.0.0", "libVer": "1.0.0", "author": "ChatGPT", "dep": ["url>=1.0.0", "CommonCSS>=1.0.0"]}

local baseURL = "https://www.pokatne.pl"
local qs = Require("url").querystring
local css = Require("CommonCSS").table

local PAGE_SIZE = 30

local function shrinkURL(url)
  return url:gsub("^https://www.pokatne.pl/?", "")
end

local function expandURL(url)
  return baseURL .. "/" .. url
end

local function parseListing(doc)
  return map(doc:select("article"), function(card)
    local a = card:selectFirst(".snippet-title-small a")
    return Novel {
      title = a:text(),
      link = shrinkURL(a:attr("href")),
      imageURL = card:selectFirst("img"):attr("data-src")
    }
  end)
end

local function parseSearch(doc)
  return map(doc:select("a"), function(card)
    return Novel {
      title = card:selectFirst("h4"):text(),
      link = shrinkURL(card:selectFirst("a"):attr("href")),
      imageURL = card:selectFirst("img"):attr("src")
    }
  end)
end

local function parseInbox(doc)
  local loginRequired = doc:selectFirst('link[rel="canonical"]'):attr("href"):find("/secure/login") ~= nil
  if loginRequired then
    return {
      Novel {
        title = "Zaloguj się w WebView",
        link = "/secure/login",
        description = "Musisz się zalogować by wyświetlić opowiadania od obserwowanych autorów."
      }
    }
  else
    return map(doc:select(".media-body"), function(card)
      local a = card:selectFirst('a[href*="/opowiadanie/"]')
      return Novel {
        title = a:text():gsub('^"(.-)"$', '%1'),
        link = shrinkURL(a:attr("href")),
        imageURL = "https://www.pokatne.pl/images/800x500.png"
      }
    end)
  end
end

local function parseNovel(url, loadChapters)
  local doc = GETDocument(expandURL(url))
  local isSeries = doc:selectFirst(".series") ~= nil

  local title = isSeries and doc:selectFirst(".series a"):text() or doc:selectFirst("header h1"):text()

  local descElement = doc:selectFirst(".disclaimer")
  local description = descElement ~= nil and descElement:text() or "No description available"

  local status
  if isSeries then
      local seriesCompleted = doc:selectFirst('[data-original-title="Seria zakończona"]') ~= nil
      status = seriesCompleted and NovelStatus.COMPLETED or NovelStatus.PUBLISHING
  else
      status = NovelStatus.COMPLETED
  end

  local info = NovelInfo {
    title = title,
    imageURL = doc:selectFirst('meta[property="og:image"]'):attr("content"),
    description = description,
    authors = { doc:selectFirst("a[itemprop=author]"):text() },
    tags = map(doc:select(".tags li a"), function(v) return v:text() end),
    status = status
  }

  if loadChapters then
    local chapters = {}

    if isSeries then
      local seriesUrl = doc:selectFirst(".series a"):attr("href")
      local seriesDoc = GETDocument(seriesUrl)
      chapters = map(seriesDoc:select(".articles .col-sm-6.col-md-4"), function(e)
        local a = e:selectFirst(".snippet-title-small a")
        return NovelChapter {
          title = a:text(),
          link = shrinkURL(a:attr("href")),
          release = e:selectFirst(".sn-date"):text()
        }
      end)
    else
      chapters = {
        NovelChapter {
          title = title,
          link = url,
          release = doc:selectFirst(".publish_date"):text()
        }
      }
    end

    info:setChapters(AsList(chapters))
  end

  return info
end

return {
  id = 90001,
  name = "Pokatne",
  baseURL = baseURL,
  imageURL = "https://www.pokatne.pl/favicon.ico",
  chapterType = ChapterType.HTML,

  listings = {
    Listing("Popularne", true, function(data)
      local offset = data[PAGE] * PAGE_SIZE
      return parseListing(GETDocument(baseURL .. "/opowiadania/najulubiensze/" .. offset))
    end),
    Listing("Najnowsze", true, function(data)
      local offset = data[PAGE] * PAGE_SIZE
      return parseListing(GETDocument(baseURL .. "/opowiadania/" .. offset))
    end),
    Listing("Inbox", false, function(data)
      return parseInbox(GETDocument(baseURL .. "/inbox/administracja"))
    end)
  },

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  parseNovel = parseNovel,

  getPassage = function(url)
    local doc = GETDocument(expandURL(url))
    local story = doc:selectFirst("div.story article")
    return pageOfElem(story, false, css)
  end,

  search = function(data)
    local query = data[QUERY]

    local document = RequestDocument(
        POST("https://www.pokatne.pl/ajax/auto_search", nil,
            FormBodyBuilder()
                :add("s", query)
                :build()
        )
    )

    return parseSearch(document)
  end,

  isSearchIncrementing = false
}
