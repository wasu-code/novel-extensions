-- {"id":23119217,"ver":"1.0.1","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["dkjson>=1.0.1", "url>=0.0.4"]}

---@alias Novel NovelInfo

local json = Require("dkjson")
local FilterOptions = Require("FilterOptions")
local urlLib = Require("url")
local qs = urlLib.querystring
local encode = urlLib.encode

local PAGE_SIZE = 30

local baseURL = "https://www.pixiv.net/novel"
local apiURL = "https://www.pixiv.net/ajax/novel"
local apiURL_search = "https://www.pixiv.net/ajax/search/novels"

-- Settings
local SID_USE_SERIES_NAME = 1

local settings = {
  [SID_USE_SERIES_NAME] = false
}

-- Filters
local FID_ORDER = 2
local FID_MODE = 3
local FID_PERIOD = 4
local FID_BOOKMARKS = 5
local FID_LANGUAGE = 6
local FID_CHARACTER_COUNT = 7
local FID_WORD_COUNT = 8
local FID_READING_TIME = 9
local FID_ORIGINAL_ONLY = 10
local FID_SEARCH_MODE = 11
local FID_GROUP_SERIES = 12
local FID_GENRE = 13

local orderFilter = FilterOptions {
  { date_d = "Newest" },
  { date = "Oldest" }
}

local modeFilter = FilterOptions {
  { all = "Show all" },
  { safe = "Safe" },
  { r18 = "R-18 🔒" }
}

local modeFilter_popular = FilterOptions {
  { safe = "Safe" },
  { r18 = "R-18 🔒" }
}

local modeFilter_followed = FilterOptions {
  { all = "Show all" },
  { r18 = "R-18 🔒" }
}

local searchModeFilter = FilterOptions {
  { s_tag = "Tags, Titles, Captions" },
  { s_tag_full = "Tags (exact match)" },
  { s_tag_only = "Tags (partial match)" },
  { s_tc = "Text" }
}

local languageFilter = FilterOptions {
  { all = "All languages" },
  { en = "English" },
  { ja = "日本語" },
  { ko = "한국어" },
  { ["zh-cn"] = "简体中文" },
  { ["zh-cw"] = "繁體中文" },
  { id = "Bahasa Indonesia" },
  { da = "Dansk" },
  { de = "Deutsch" },
  { es = "Español" },
  { ["es-419"] = "Español (Latinoamérica)" },
  { tl = "Filipino" },
  { fr = "Français" },
  { hr = "Hrvatski" },
  { it = "Italiano" },
  { nl = "Nederlands" },
  { pl = "Polski" },
  { ["pt-br"] = "Português (Brasil)" },
  { ["pt-pt"] = "Português (Portugal)" },
  { vi = "Tiếng Việt" },
  { tr = "Türkçe" },
  { ru = "Русский" },
  { ar = "العربية" },
  { th = "ไทย" },
  { other = "Other" }
}

local genreFilter = FilterOptions {
  { all = "All Genres 👶" },
  { male = "Popular with male 🔞" },
  { female = "popular with female 🔞" },
  { romance = "Romance" },
  { isekai_fantasy = "Isekai fantasy" },
  { contemporary_fantasy = "Contemporary fantasy" },
  { mystery = "Mystery" },
  { horror = "Horror" },
  { ["sci-fi"] = "Sci-fi" },
  { literature = "Literature" },
  { drama = "Drama" },
  { historical_pieces = "Historical pieces" },
  { bl = "BL (yaoi)" },
  { yuri = "Yuri" },
  { for_kids = "For kids 👶" },
  { poetry = "Poetry" },
  { ["non-fiction"] = "Essays/non-fiction" },
  { screenplays = "Screenplays/scripts" },
  { reviews = "Reviews/opinion pieces" },
  { other = "Other" }
}

--- Retrieves URL of cover image from provided Pixiv Novel
local function getCover(n)
  local url = nil
  -- when entry represents a single novel
  if n.url then url = n.url end
  -- when entry represents a novel series
  if n.cover then url = n.cover.urls["240mw"] end

  if n.coverUrl then url = n.coverUrl end

  return url and url:gsub("i%.pximg%.net", "i.pixiv.re", 1)
end

---@class PixivListingEntry
---@field id string novel or series ID
---@field title string novel or series title
local PixivListingEntry = {}

---@class PixivListingNovel : PixivListingEntry
---@field url string cover URL
---@field seriesId string|nil
---@field seriesTitle string|nil
local PixivListingNovel = {}

---@class PixivListingSeries : PixivListingEntry
---@field cover table
---@field isOneshot boolean
---@field isConcluded boolean|nil
---@field novelId string|nil
local PixivListingSeries = {}

--- Converts a PixivListingEntry object to a Shosetsu Novel object
---@param n PixivListingNovel The PixivListingNovel object to convert
---@return Novel ShosetsuNovel Shosetsu Novel object
function PixivListingNovel:toNovel(n)
  return Novel {
    -- Use series title if available (and enabled in settings), otherwise use novel title
    title = (settings[SID_USE_SERIES_NAME] and n.seriesTitle) and n.seriesTitle or n.title,
    -- If part of series link to whole series
    link = n.seriesId and ("series/" .. n.seriesId) or n.id,
    imageURL = n.url:gsub("i%.pximg%.net", "i.pixiv.re"),
  }
end

--- Converts a PixivListingEntry object to a Shosetsu Novel object
---@param n PixivListingSeries The PixivListingSeries object to convert
---@return Novel ShosetsuNovel Shosetsu Novel object
function PixivListingSeries:toNovel(n)
  return Novel {
    title = n.title,
    -- if oneshot link directly to novel
    link = n.novelId and n.novelId or ("series/" .. n.id),
    imageURL = n.cover.urls["240mw"]:gsub("i%.pximg%.net", "i.pixiv.re"),
  }
end

--- Converts a PixivListingEntry object to a Shosetsu Novel object
---@param n {} Object with PixivListingEntry data
---@return Novel Novel Shosetsu Novel object
function PixivListingEntry:toNovel(n)
  -- isOneshot property is returned only when grouped as series
  local isSeries = n.isOneshot ~= nil

  return isSeries and PixivListingSeries:toNovel(n) or PixivListingNovel:toNovel(n)
end

local function shrinkURL(url, type)
  return url:gsub(".-pixiv%.net/(ajax/)?novel/(show%.php%?id=)?", "")
end

local function expandURL(url, type)
  -- type is provided -> function is executed by Shosetsu -> use baseURL
  if type then
    -- url consist of digits only -> it's novel id
    if url:match("^%d+$") then
      -- format for opening in WebView
      url = "show.php?id=" .. url
    end

    return baseURL .. "/" .. url:gsub("^/*", "")
  end

  -- no type -> function executed by extension -> use apiURL
  return apiURL .. "/" .. url:gsub("^/*", "")
end

---@param url string
---@param ... string strings representing path in json structure
---@return table Novels converted entries (empty table if path does not exist)
--- local novels = parseListing(url, "body", "thumbnails", "novel")
local function parseListing(url, ...)
  local jsonData = json.GET(url)
  local novels = jsonData

  for i = 1, select("#", ...) do
      novels = novels[select(i, ...)]
      if not novels then return {} end
  end

  return map(novels, function (novel)
    return PixivListingEntry:toNovel(novel)
  end)
end

local function parseNovel(url, loadChapters)
  local isSeries = url:match("series/")
  local data = json.GET(expandURL(url))
  local novel = data.body

  local info = NovelInfo {
    title = novel.title,
    link = tostring((isSeries and "series/" or "") .. novel.id),
    status = (not isSeries and NovelStatus.COMPLETED) -- One-shot
      or (novel.isConcluded and NovelStatus.COMPLETED or NovelStatus.PUBLISHING), -- Series
    genres = isSeries and novel.tags or map(novel.tags.tags, function (tag)
      return tag.tag
    end),
    authors = {novel.userName},
    description = isSeries and novel.caption or novel.description,
    language = novel.language,
    wordCount = novel.publishedTotalWordCount,
  }

  local imageURL = getCover(novel)
  if imageURL then info:setImageURL(imageURL) end

  if not loadChapters then
    return info
  end

  if isSeries then
    local seriesData = json.GET(qs({
      limit = PAGE_SIZE,
      last_order = 0,
      order_by = "asc",
      lang = "en"
    }, expandURL("series_content/" .. novel.id)))

    local chapters = map(seriesData.body.page.seriesContents, function (n)
      return NovelChapter {
        title = n.title,
        link = n.id,
        release = os.date("%Y-%m-%d", n.reuploadTimestamp or n.uploadTimestamp),
        order = n.series.contentOrder
      }
    end)

    info:setChapters(chapters)
  else
    info:setChapters({
      NovelChapter {
        title = novel.title,
        link = novel.id,
        release = novel.uploadDate:sub(1, 10)
      }
    })
  end

  return info
end

local function getPassage(url)
  local data = json.GET(expandURL(url))
  return data.body.content:gsub("\n", "<br/>")
end

local function search(data)
  local query = data[QUERY]
  local page = data[PAGE]

  local params = {
    word = query,
    order = orderFilter:valueOf(data[FID_ORDER]),
    mode = modeFilter:valueOf(data[FID_MODE]),
    p = page,
    csw = 0,
    s_mode = searchModeFilter:valueOf(data[FID_SEARCH_MODE]),
    gs = data[FID_GROUP_SERIES] and 1 or 0, -- group into series
    lang = "en"
  }
  local selectedLang = languageFilter:valueOf(data[FID_LANGUAGE])
  if not (selectedLang == "all") then params["work_lang"] = selectedLang end

  local searchUrl = qs(params, apiURL_search .. "/" .. encode(query))

  local jsonData = json.GET(searchUrl)
  local novels = jsonData.body.novel.data

  return map(novels, function (novel)
    return PixivListingEntry:toNovel(novel)
  end)
end

--- Returns user ID or nil if not logged in
local function getUserID()
    if not CookieJar then error("No cookie jar") end

    -- Load cookies
    local cookies = CookieJar():loadForRequest(HttpUrl(baseURL))

    for i = 0, cookies:size() - 1 do
        local cookie = cookies:get(i)
        if cookie:name() == "PHPSESSID" then
            local value = cookie:value()
            -- take part before first "_"
            local beforeUnderscore = value:match("^(.-)_(.+)$")
            return beforeUnderscore
        end
    end

    return nil
end

local function isLoggedIn()
  if not CookieJar then return true end -- fix for stable™ release

  return getUserID() ~= nil
end

return {
  id = 23119217,
  name = "Pixiv",
  baseURL = baseURL,
  imageURL = "https://s.pximg.net/common/images/apple-touch-icon.png?20250206",
  chapterType = ChapterType.HTML,
  -- hasCloudFlare = true,

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  listings = {
    Listing("Editor's picks", false, function ()
      return parseListing(qs({
        limit = PAGE_SIZE,
        lang = "en"
      }, "https://www.pixiv.net/ajax/novel/editors_picks"),
      "body", "thumbnails", "novel")
    end),
    Listing("Popular original novels", false, function (data)
      local genre = genreFilter:valueOf(data[FID_GENRE])
      local mode = ((genre == "all" or genre == "for_kids") and "safe")
                or ((genre == "male" or genre == "female") and "r18")
                or modeFilter_popular:valueOf(data[FID_MODE])

      return parseListing(qs({
        mode = mode,
        lang = "en"
      }, "https://www.pixiv.net/ajax/genre/novel/" .. genre),
      "body", "thumbnails", "novelSeries")
    end),
    Listing("Followed users 🔒", true, function (data)
      if not isLoggedIn() then error("Login in WebView") end

      return parseListing(qs({
        p = data[PAGE],
        mode = modeFilter_followed:valueOf(data[FID_MODE]),
        lang = "en"
      }, "https://www.pixiv.net/ajax/follow_latest/novel"),
      "body", "thumbnails", "novel")
    end),
    Listing("Your watchlist 🔒", true, function (data)
      if not isLoggedIn() then error("Login in WebView") end

      return parseListing(qs({
        p = data[PAGE],
        new = 1,
        lang = "en"
      }, "https://www.pixiv.net/ajax/watch_list/novel"),
      "body", "thumbnails", "novelSeries")
    end),
    Listing("Recommended 🔒", false, function (data)
      if not isLoggedIn() then error("Login in WebView") end

      return parseListing(qs({
        mode = modeFilter:valueOf(data[FID_MODE]),
        limit = 100,
        lang = "en"
      }, "https://www.pixiv.net/ajax/discovery/novels"),
      "body", "thumbnails", "novel")
    end),
    Listing("Bookmarks 🔒", true, function (data)
      local userID = getUserID()
      if not userID then error("Login in WebView") end

      return parseListing(qs({
        tag = "",
        offset = PAGE_SIZE * (data[PAGE] - 1),
        limit = PAGE_SIZE,
        rest = "show",
        lang = "en"
      }, "https://www.pixiv.net/ajax/user/" .. userID .. "/novels/bookmarks"),
      "body", "works")
    end)
  },
  searchFilters = {
    FilterGroup("Search filters", {
      DropdownFilter(FID_SEARCH_MODE, "Search target", searchModeFilter:labels()),
      DropdownFilter(FID_MODE, "Browsing mode", modeFilter:labels()),
      DropdownFilter(FID_ORDER, "Order", orderFilter:labels()),
      DropdownFilter(FID_LANGUAGE, "Work language", languageFilter:labels()),
      --Period
      --Bookmarks
      --Text length
      CheckboxFilter(FID_ORIGINAL_ONLY, "Only original works"),
      CheckboxFilter(FID_GROUP_SERIES, "Group into series")
    }),
    FilterGroup("Listing: Popular original novels", {
      DropdownFilter(FID_MODE, "Browsing mode", modeFilter_popular:labels()),
      DropdownFilter(FID_GENRE, "Genre", genreFilter:labels())
    }),
    FilterGroup("Listing: Followed users", {
      DropdownFilter(FID_MODE, "Browsing mode", modeFilter_followed:labels()),
    })
  },

  parseNovel = parseNovel,
  getPassage = getPassage,

  hasSearch = true,
  isSearchIncrementing = true,
  -- startIndex = startIndex,
  search = search,

  settings = {
    CheckboxFilter(SID_USE_SERIES_NAME, "Use series title in listings \n\n (May require \"More » Settings » Advanced » Remove Novel Cache\" to apply to already loaded novels)"),
    HeaderFilter and HeaderFilter([[
    Legend:
    🔒 - Login required
    👶 - Available only in "Safe" mode 
    🔞 - Available only in "R-18" mode
    ]])
  },
  updateSetting = function(id, value)
    settings[id] = value
  end,
}