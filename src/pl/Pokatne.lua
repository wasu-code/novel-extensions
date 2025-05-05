-- {"id": 90001, "ver": "1.0.0", "libVer": "1.0.0", "author": "ChatGPT", "dep": ["url>=1.0.0", "CommonCSS>=1.0.0"]}

local baseURL = "https://www.pokatne.pl"
local qs = Require("url").querystring
local css = Require("CommonCSS").table

local PAGE_SIZE = 30

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
    return Novel {
      title = a:text(),
      link = shrinkURL(a:attr("href")),
      imageURL = card:selectFirst("img"):attr("data-src")
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
      }
    end)
  end
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
    Listing("Najulubiensze", true, function(data)
      local offset = data[PAGE] * PAGE_SIZE
      return parseListing(GETDocument(baseURL .. "/opowiadania/najulubiensze/" .. offset))
    end),
    -- Listing("Artykuły", true, function(data)
    --   local offset = data[PAGE] * PAGE_SIZE
    --   return parseListing(GETDocument(baseURL .. "/artykuly/" .. offset))
    -- end),
    -- Listing("Wyznania", true, function(data)
    --   local offset = data[PAGE] * PAGE_SIZE
    --   return parseListing(GETDocument(baseURL .. "/wyznania/" .. offset))
    -- end),
    Listing("Inbox", false, function(data)
      return parseInbox(GETDocument(baseURL .. "/inbox/administracja"))
    end)
  },

  searchFilters = {
    DropdownFilter(FID_CAT, "Zbiór", {"Zbiór główny", "Poczekalnia", "Wszystko"}), -- all, 1, 4
    TriStateFilter(FID_WARNING, "Kontrowersyjna treść"), -- all, 0, 1
    TriStateFilter(FID_SERIES, "Część serii"), -- all, 0, 1
    TextFilter(FID_TAG, "Tagi (łączone znakiem +)"), -- tag1+tag%20more
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
    return pageOfElem(story, false, css)
  end,

  isSearchIncrementing = false,
  search = function(data)
    if data[PAGE] ~= 1 then return {} end -- search doesn't increment

    local document = RequestDocument(
        POST("https://www.pokatne.pl/ajax/auto_search", nil,
            FormBodyBuilder()
                :add("s", data[QUERY])
                :build()
        )
    )

    return parseSearch(document)
  end
}
