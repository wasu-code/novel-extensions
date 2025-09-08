-- {"id":23119216,"ver":"0.0.0","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["dkjson>=1.0.1", "url"]}

local json = Require("dkjson")
local qs = Require("url").querystring

local baseURL = "https://www.pixiv.net/novel"
local apiURL = "https://www.pixiv.net/ajax/novel"

local function shrinkURL(url, type)
  return url:gsub(".-pixiv%.net/(ajax/)?novel/?", "")
end

local function expandURL(url, type)
  -- type is provided -> function is executed by Shosetsu -> use baseURL
  if (type) then
    -- TODO novel url: https://www.pixiv.net/novel/show.php?id=25767227
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
      tags = n.tags,
      authors = {n.userName},
      description = n.description,
      wordCount = n.wordCount,
      favoriteCount = n.bookmarkCount,
      language = n.language
    }
end

local function getListing(url)
  local data = json.GET(url)
  local novels = data.body.thumbnails.novel

  return map(novels, function (novel)
    return toNovel(novel)
  end)
end

local function parseNovel(url, loadChapters)
  local isSeries = url:match("series/")
  local data = json.GET(url)
  local novel = data.body

  --info for one-shot
  local info = NovelInfo {
    title = novel.title,
    -- alternativeTitles
    link = tostring((isSeries and "series/" or "") .. novel.id),
    status = novel.isConcluded and NovelStatus.COMPLETED or NovelStatus.PUBLISHING,
    tags = isSeries and novel.tags or map(novel.tags.tags, function (tag)
      return tag.tag
    end),
    authors = {novel.userName},
    imageURL = (isSeries and novel.cover.urls[1] or novel.coverUrl):gsub("i%.pximg%.net", "i.pixiv.re"),
    description = isSeries and novel.caption or novel.description,
    language = novel.language,
    chapterCount = novel.publishedContentCount, -- .displaySeriesContentCount ot .total
    wordCount = novel.publishedTotalWordCount,
  }

  if (isSeries) then
    -- TODO
  else
    info:setChapters({
      NovelChapter {
        title = novel.title,
        link = novel.id,
        release = novel.uploadDate
      }
    })
  end

  return info
end

local function getPassage(url)
  local data = json.GET(url)
  return data.body.content
end

-- https://www.pixiv.net/ajax/search/novels/girl?word=girl&order=date_d&mode=all&p=1&csw=0&s_mode=s_tag_full&gs=0&lang=en
-- https://www.pixiv.net/ajax/search/novels/happy%20girl?word=happy%20girl&order=date_d&mode=all&p=1&csw=0
-- &s_mode=s_tag_full&gs=0&lang=en
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
  }, "https://www.pixiv.net/ajax/search/novels/" .. query)

  local jsonData = json.GET(searchUrl)

  return map(jsonData.body.novel.data, function (novel)
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
    Listing("Editor's picks", false, function (data, inc)
      return getListing("https://www.pixiv.net/ajax/novel/editors_picks?limit=30&lang=en")
    end),
    
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