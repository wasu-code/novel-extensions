-- {"id":23119216,"ver":"0.0.0","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["dkjson>=1.0.1", "url"]}

local json = Require("dkjson")
local qs = Require("url").querystring
local encode = Require("url").encode

local PAGE_SIZE = 30

local baseURL = "https://www.pixiv.net/novel"
local apiURL = "https://www.pixiv.net/ajax/novel"
local apiURL_search = "https://www.pixiv.net/ajax/search/novels"

local function shrinkURL(url, type)
  return url:gsub(".-pixiv%.net/(ajax/)?novel/?", "")
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

local function toNovel(n)
  return Novel {
      title = n.seriesTitle or n.title,
      link = tostring(n.seriesId and "series/" .. n.seriesId or n.id),
      imageURL = n.url:gsub("i%.pximg%.net", "i.pixiv.re"),
      -- additional info
      -- alternativeTitles = n.titleCaptionTranslation
      genres = n.tags,
      authors = {n.userName},
      description = n.description,
      wordCount = n.wordCount,
      favoriteCount = n.bookmarkCount,
      language = n.language
    }
end

local function parseListing(url)
  local jsonData = json.GET(url)
  local novels = jsonData.body.thumbnails.novel

  return map(novels, function (novel)
    return toNovel(novel)
  end)
end

local function parseNovel(url, loadChapters)
  local isSeries = url:match("series/")
  local data = json.GET(expandURL(url))
  local novel = data.body

  local info = NovelInfo {
    title = novel.title,
    -- alternativeTitles
    link = tostring((isSeries and "series/" or "") .. novel.id),
    status = (not isSeries and NovelStatus.COMPLETED) -- One-shot
      or (novel.isConcluded and NovelStatus.COMPLETED or NovelStatus.PUBLISHING), -- Series
    genres = isSeries and novel.tags or map(novel.tags.tags, function (tag)
      return tag.tag
    end),
    authors = {novel.userName},
    description = isSeries and novel.caption or novel.description,
    language = novel.language,
    chapterCount = novel.publishedContentCount, -- or .displaySeriesContentCount or .total
    wordCount = novel.publishedTotalWordCount,
  }

  local imageURL = (isSeries and novel.cover and novel.cover.urls and novel.cover.urls["240mw"]) or novel.coverUrl or nil
  if imageURL then info:setImageURL(imageURL:gsub("i%.pximg%.net", "i.pixiv.re")) end

  if not loadChapters then
    return info
  end

  if isSeries then
    local seriesData = json.GET(qs({
      limit = PAGE_SIZE,
      last_order = 0,
      order_by = "asc",
      lang = "en" -- TODO
    }, expandURL("series_content/14226723")))

    local chapters = map(seriesData.body.page.seriesContents, function (n)
      return NovelChapter {
        title = n.title,
        link = n.id,
        release = os.date("%Y-%m-%d %H:%M:%S", n.reuploadTimestamp or n.uploadTimestamp),
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

  local searchUrl = qs({
    word = query,
    order = "date_d",
    mode = "all", -- TODO from filters
    p = page,
    csw = 0,
    s_mode = "s_tag_full",
    gs = 0,
    lang = "en" -- TODO
  }, apiURL_search .. "/" .. encode(query))

  local jsonData = json.GET(searchUrl)
  local novels = jsonData.body.novel.data

  return map(novels, function (novel)
    return toNovel(novel)
  end)
end

return {
  id = 23119216,
  name = "Pixiv",
  baseURL = baseURL,
  imageURL = "https://s.pximg.net/common/images/apple-touch-icon.png?20250206",
  chapterType = ChapterType.HTML,
  -- hasCloudFlare = true,

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  listings = {
  -- https://www.pixiv.net/ajax/top/novel?mode=all&lang=en
    Listing("Editor's picks", true, function (data, inc)
      return parseListing(qs({
        limit = PAGE_SIZE,
        lang = "en" -- TODO from settings
      }, expandURL("/editors_picks")))
    end),
    -- Listing("Popular original novels", true, function ()
    --   return parseListing("https://www.pixiv.net/ajax/genre/novel/all?mode=safe&lang=en")
    -- end)
  },
  -- searchFilters = searchFilters,

  parseNovel = parseNovel,
  getPassage = getPassage,

  hasSearch = true,
  isSearchIncrementing = true,
  -- startIndex = startIndex,
  search = search,

  settings = {},
  updateSetting = function(id, value)
    -- settings[id] = value
  end,
}