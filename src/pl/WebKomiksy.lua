-- {"id":23119215,"ver":"1.0.3","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["url>=1.0.0", "dkjson"]}

local qs = Require("url").querystring
local dkjson = Require("dkjson")

local baseURL = "https://www.webkomiksy.pl"

-- Filter IDs
local FID_VERIFIED = 2
local FID_STATUS = 3
local FID_CATEGORY = 4
local FID_SORT = 5

local SID_UPCOMING = 1
local settings = {
  [SID_UPCOMING] = false,
}

local STATUSES = {
  { value = nil, label = "Wszystkie" },
  { value = "completed", label = "Ukończone" },
  { value = "in_progress", label = "W trakcie" },
  { value = "abandoned", label = "Porzucone" }
}

local CATEGORIES = {
  {value = nil, label = "Wszystko"},
  {value = "adventure", label = "Przygoda"},
  {value = "comedy", label = "Komedia"},
  {value = "criminal", label = "Kryminał"},
  {value = "drama", label = "Dramat"},
  {value = "fanfiction", label = "Fanfiction"},
  {value = "fantasy", label = "Fantasy"},
  {value = "historical", label = "Historyczne"},
  {value = "horror", label = "Horror"},
  {value = "poetic_prose", label="Proza poetycka"},
  {value = "religion", label = "Religia i duchowość"},
  {value = "romance_and_erotica", label = "Romans i Erotyka"},
  {value = "science_fiction", label = "Sci-Fi"},
  {value = "social_and_fine", label = "Literatura obyczajowa i piękna"},
  {value = "young_adult", label = "Dla młodzieży"},
}

local SORT = {
  {value = "latest", label = "Najnowsze"},
  {value = "popular", label = "Najpopularniejsze"},
  {value = "score", label = "Najwyżej oceniane"}
}

local function shrinkURL(url)
  return url:gsub("^https://www%.webkomiksy%.pl/?", "")
end

local function expandURL(url)
  return baseURL .. "/" .. url:gsub("^/*", "")
end

local function parseListing(doc)
    return map(doc:select(".flex-1 a:has(img)"), function(card)
        return Novel {
            title = card:selectFirst("h3"):text(),
            imageURL = expandURL(card:selectFirst("img"):attr("src")),
            link = card:attr("href")
        }
    end)
end

local function parseChapterList(document)
    local script = document:selectFirst("script#__NUXT_DATA__")
    local parsed = dkjson.decode(script:data())

    local function a(index)
      return parsed[index+1]
    end

    local chapters = {}

    local episodes = a(a(4).episodes)

    local function processEpisode(ep)
        local chapter = a(ep)
        local published = a(chapter.planned)

        local date = string.sub(a(chapter.date), 1, 10) -- show only YYYY-MM-DD

        local novelChapter = NovelChapter {
            title = a(chapter.name),
            order = a(chapter.index),
            link = a(a(1).path) .. "/czytnik/" .. a(chapter.index),
            release = date .. (published and " (nadchodzący)" or "")
        }

        table.insert(chapters, novelChapter)
    end

    local publishedEpisodes = a(episodes.current)
    for _, ep in ipairs(publishedEpisodes) do
        processEpisode(ep)
    end

    -- optionally load upcoming episodes
    if settings[SID_UPCOMING] then
      local upcomingEpisodes = a(episodes.planned)
      for _, ep in ipairs(upcomingEpisodes) do
          processEpisode(ep)
      end
    end

  return chapters
end

local function parseNovel(url, loadChapters)
  local doc = GETDocument(expandURL(url))
  local info = NovelInfo {
    title = doc:selectFirst("h1"):text(),
    imageURL = expandURL(doc:selectFirst('img[fetchpriority="high"]'):attr("src")),
    authors = {doc:selectFirst("img+span"):text()},
    description = doc:selectFirst("h2+div"):wholeText(),
    genres = map(doc:select("div:nth-child(2) > div.flex.flex-wrap.gap-2 span"), function(v) return v:text() end),
  }

  if loadChapters then
    info:setChapters(parseChapterList(doc))
  end

  return info
end

local function getPassage(url)
  local doc = GETDocument(expandURL(url))
  local story = doc:selectFirst("article") or error("\n\nTen rozdział nie jest jeszcze dostępny")
  return pageOfElem(story, false)
end

return {
	id = 23119215,
	name = "WebKomiksy",
  baseURL = baseURL,
  imageURL = "https://www.webkomiksy.pl/favicon.ico",
  chapterType = ChapterType.HTML,

	shrinkURL = shrinkURL,
	expandURL = expandURL,

	listings = {
    Listing("Książki", true, function(data)
      local filters = {
        page = data[PAGE],
        sort = SORT[data[FID_SORT]+1].value
      }
      local statusValue = STATUSES[data[FID_STATUS]+1].value
      if statusValue then filters["status"] = statusValue end

      local categoryValue = CATEGORIES[data[FID_CATEGORY]+1].value
      if categoryValue then filters["category"] = categoryValue end

      local verifiedValue = data[FID_VERIFIED]
      if verifiedValue then filters["verified"] = verifiedValue end

      return parseListing(GETDocument(expandURL(qs(filters, "/ksiazki"))))
    end)
  },
  searchFilters = {
    SwitchFilter(FID_VERIFIED, "Tylko polecane"),
    DropdownFilter(FID_STATUS, "Status", map(STATUSES, function(v) return v.label end)),
    DropdownFilter(FID_CATEGORY, "Kategoria", map(CATEGORIES, function(v) return v.label end)),
    DropdownFilter(FID_SORT, "Sortowanie", map(SORT, function(v) return v.label end))
  },

	parseNovel = parseNovel,
  getPassage = getPassage,

	-- Optional values to change
	hasSearch = false,
	isSearchIncrementing = false,
	search = function() end,

  settings = {
    SwitchFilter(SID_UPCOMING, "Pokaż nadchodzące rozdziały")
  },
  updateSetting = function(id, value)
    settings[id] = value
  end,
}