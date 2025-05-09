-- {"id": 23119211, "ver": "1.0.0", "libVer": "1.0.0", "author": "wasu", "dep": ["url>=1.0.0"]}

local qs = Require("url").querystring

local baseURL = "https://www.pokatne.pl"

local PAGE_SIZE = 30
local DEFAULT_COVER = "https://www.pokatne.pl/images/noav.png"

-- Filter IDs
local FID_CAT = 2
local FID_WARNING = 3
local FID_TAG = 4
local FID_SERIES = 5
local FID_LECTURE_TIME = 6
local FID_MIN_RATING = 7
local FID_YEAR = 8

local function shrinkURL(url)
  return url:gsub("^https://www.pokatne.pl/?", "")
end

local function expandURL(url)
  return baseURL .. "/" .. url
end

local function parseListing(doc)
  return map(doc:select("article"), function(card)
    local a = card:selectFirst(".snippet-title-small a")
    local imageUrl = card:selectFirst("img"):attr("data-src") ~= "" and card:selectFirst("img"):attr("data-src") or DEFAULT_COVER
    return Novel {
      title = a:text(),
      link = shrinkURL(a:attr("href")),
      imageURL = imageUrl
    }
  end)
end

local function parseConfessions(doc)
  return map(doc:select(".caption"), function(card)
    local a = card:selectFirst("h3 a")
    return Novel {
      title = a:text(),
      link = shrinkURL(a:attr("href")),
      imageURL = DEFAULT_COVER
    }
  end)
end

local function parseAudiobooks(doc)
  return map(doc:select(".thumbnail"), function(card)
    local a = card:selectFirst("h3 a")
    return Novel {
      title = a:text(),
      link = shrinkURL(a:attr("href")),
      imageURL = card:selectFirst("img"):attr("src"),
      authors = {card:selectFirst(".caption > a")}
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
        description = "Musisz się zalogować (używając WebView) by wyświetlić opowiadania od obserwowanych autorów.",
        imageURL = DEFAULT_COVER
      }
    }
  else
    return map(doc:select(".media-body"), function(card)
      local a = card:selectFirst('a[href*="/opowiadanie/"]')
      return Novel {
        title = a:text():gsub('^"(.-)"$', '%1'),
        link = shrinkURL(a:attr("href")),
        imageURL = DEFAULT_COVER
      }
    end)
  end
end

local function parseSearch(doc)
  return map(doc:select('a[data-type="Opowiadanie"]'), function(card)
    return Novel {
      title = card:selectFirst("h4"):text(),
      link = shrinkURL(card:selectFirst("a"):attr("href")),
      imageURL = card:selectFirst("img"):attr("src")
    }
  end)
end

local function parseNovel(url, loadChapters)
  local doc = GETDocument(expandURL(url))
  local isSeries = doc:selectFirst(".series") ~= nil

  local title = isSeries and doc:selectFirst(".series a"):text() or doc:selectFirst("header h1"):text()

  local status
  if isSeries then
      local seriesCompleted = doc:selectFirst('[data-original-title="Seria zakończona"]') ~= nil
      status = seriesCompleted and NovelStatus.COMPLETED or NovelStatus.PUBLISHING
  else
      status = NovelStatus.COMPLETED
  end

  local authorElem = doc:selectFirst("a[itemprop=author]")
  local descElement = doc:selectFirst(".disclaimer")

  local info = NovelInfo {
    title = title,
    imageURL = doc:selectFirst('meta[property="og:image"]'):attr("content"),
    tags = map(doc:select(".tags li a"), function(v) return v:text() end),
    status = status
  }
  if authorElem then info:setAuthors({authorElem:text()}) end
  if descElement then info:setDescription(descElement:text()) end

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
          release = (doc:selectFirst(".publish_date") and doc:selectFirst(".publish_date"):text()) or nil
        }
      }
    end

    info:setChapters(AsList(chapters))
  end

  return info
end

return {
  id = 23119211,
  name = "Pokatne",
  baseURL = baseURL,
  imageURL = "https://www.pokatne.pl/images/apple-touch-icon.png",
  chapterType = ChapterType.HTML,

  listings = {
    Listing("Najnowsze (obsługuje filtry)", true, function(data)
      local offset = (data[PAGE] - 1) * PAGE_SIZE

      -- Create a table of non-nil filters
      local filters = {}
      if data[FID_CAT] > 0 then
        if data[FID_CAT] == 1 then
          filters["cat"] = 4 -- Poczekalnia
        elseif data[FID_CAT] == 2 then
          filters["cat"] = "all" -- Wszystko
        end
      end
      if data[FID_WARNING] > 0 then filters["warning"] = data[FID_WARNING] == 1 and 1 or 0 end
      if data[FID_SERIES] > 0 then filters["series"] = data[FID_SERIES] == 1 and 1 or 0 end
      if data[FID_TAG] ~= "" then filters["tag"] = data[FID_TAG] end
      if data[FID_LECTURE_TIME] ~= "" then filters["lecture_time"] = data[FID_LECTURE_TIME] end
      if data[FID_MIN_RATING] ~= "" then filters["min_rating"] = data[FID_MIN_RATING] end
      if data[FID_YEAR] ~= "" then filters["year"] = data[FID_YEAR] end

      -- if filters are present listing doesn't increment
      if next(filters) and data[PAGE] ~= 1 then return {} end

      local filterUrl = qs(filters, baseURL .. "/opowiadania")
      local paginationUrl = baseURL .. "/opowiadania/" .. offset
      -- either uses filters or pagination
      local urlToUse = next(filters) and filterUrl or paginationUrl

      return parseListing(GETDocument(urlToUse))
    end),
    Listing("Najulubiensze (najczęściej w ulubionych)", true, function(data)
      local offset = (data[PAGE] - 1) * PAGE_SIZE
      return parseListing(GETDocument(baseURL .. "/opowiadania/najulubiensze/" .. offset))
    end),
    Listing("Najlepsze (najwyżej oceniane)", true, function(data)
      local offset = (data[PAGE] - 1) * PAGE_SIZE
      return parseListing(GETDocument(baseURL .. "/opowiadania/najulubiensze/" .. offset))
    end),
    Listing("Poczekalnia", true, function(data)
      local offset = (data[PAGE] - 1) * PAGE_SIZE
      return parseListing(GETDocument(baseURL .. "/poczekalnia/" .. offset))
    end),
    Listing("Audiobooki", true, function(data)
      local offset = (data[PAGE] - 1) * PAGE_SIZE
      return parseAudiobooks(GETDocument(baseURL .. "/audiobooki/" .. offset))
    end),
    Listing("Artykuły", true, function(data)
      local offset = (data[PAGE] - 1) * PAGE_SIZE
      return parseListing(GETDocument(baseURL .. "/artykuly/" .. offset))
    end),
    Listing("Wyznania", true, function(data)
      local offset = (data[PAGE] - 1) * PAGE_SIZE
      return parseConfessions(GETDocument(baseURL .. "/wyznania/" .. offset))
    end),
    Listing("Inbox", false, function(data)
      return parseInbox(GETDocument(baseURL .. "/inbox/administracja"))
    end),
  },

  searchFilters = {
    DropdownFilter(FID_CAT, "Zbiór", {"Zbiór główny", "Poczekalnia", "Wszystko"}),
    TriStateFilter(FID_WARNING, "Kontrowersyjna treść"), 
    TriStateFilter(FID_SERIES, "Część serii"),
    TextFilter(FID_TAG, "Tagi (łączone znakiem +)"),
    TextFilter(FID_LECTURE_TIME, "Czas lektury (w minutach, format: ?-?)"),
    TextFilter(FID_MIN_RATING, "Minimalna ocena ?/10"),
    TextFilter(FID_YEAR, "Rok publikacji"),
	},

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  parseNovel = parseNovel,
  getPassage = function(url)
    local doc = GETDocument(expandURL(url))
    local story = doc:selectFirst("div.story article .content")
    return pageOfElem(story, false)
  end,

  isSearchIncrementing = false,
  search = function(data)
    if data[PAGE] ~= 1 then return {} end -- search doesn't increment

    local query = data[QUERY]

    -- if query prefixed with "author:" or "autor:" display all works from given author
    if query:sub(1, 7) == "author:" or query:sub(1, 7) == "autor:" then
      local authorName = query:sub(8)
      local authorUrl = baseURL .. "/autorzy/" .. authorName
      return parseListing(GETDocument(authorUrl))
    end

    local document = RequestDocument(
        POST("https://www.pokatne.pl/ajax/auto_search", nil,
            FormBodyBuilder()
                :add("s", query)
                :build()
        )
    )

    return parseSearch(document)
  end
}
