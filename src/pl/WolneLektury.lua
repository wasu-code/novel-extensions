-- {"id":23119218,"ver":"0.1.0","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["dkjson>=1.0.1", "class"]}

local qs = Require("url").querystring
local json = Require("dkjson")
local HTMLToString = Require("unhtml").HTMLToString
local FilterOptions = Require("FilterOptions")
local makeClass = Require("class")

local PAGE_SIZE = 20
local KEY_LISTING_URL = 3

local baseURL = "https://wolnelektury.pl"

local FID_SORT = 2
local sortFilter = FilterOptions({
  nil,
  { alpha = "Alfabetyczne" },
  { ["-alpha"] = "Alfabetyczne (odwrotne)" },
  { popularity = "Najpopularniejsze" },
  { ["-popularity"] = "Najmniej popularne" },
}, "Domyślne")

local function shrinkURL(url, type)
  return url
    :gsub(".-wolnelektury%.pl/?", "")
end

local function expandURL(url, type)
  -- if no type provided it's probably Novel WebView
  -- if not type then
    -- baseURL.."/katalog/lektura/"..slug,
  -- end
  -- KEY_NOVEL_URL: baseURL".."/api/2/books/"..slug.."/?format=json"
  -- KEY_CHAPTER_URL: baseURL.."/media/book/html/"..slug..".html
  -- KEY_LISTING_URL baseURL.."/api/2/"..slug
  return baseURL .. "/" .. url:gsub("^/", "")
end

--- Extracts slug from API URL
local function extractTitleFromURL(url)
  return url
    :match("/books/([^/?]+)") -- extract slug
    :gsub("-", " ") -- replace hyphens with spaces
    :gsub("(%w)(%w*)", function(first, rest) -- capitalize first letters
        return first:upper() .. rest:lower()
    end)
end

---@class Book
---@field slug string
---@field title string novel or chapter title
---@field full_sort_key string
---@field href string absolute API URL
---@field url string absolute URL to entry page (HTML)
---@field language string
---@field authors Author[]
---@field translators table
---@field epochs table
---@field genres table
---@field kinds table
---@field children table
---@field parent string|nil absolute API URL to parent entry/book
---@field preview boolean
---@field epub string absolute URL to file
---@field mobi string absolute URL to file
---@field pdf string absolute URL to file
---@field html string absolute URL to file
---@field txt string absolute URL to file
---@field fb2 string absolute URL to file
---@field xml string absolute URL to file
---@field cover_thumb string
---@field cover string
---@field isbn_pdf string|nil
---@field isbn_epub string|nil
---@field isbn_mobi string|nil
---@field abstract string|HTML
---@field has_mp3_file boolean
---@field has_sync_file boolean
---@field elevenreader_link string absolute URL to external reader
---@field content_warnings table
---@field audiences table
---@field changed_at string
---@field read_time number
---@field pages number
---@field redakcja string absolute URL (may lead to 404)
local Book = makeClass()

---@class Chapter
---@field slug string
---@field title string
local Chapter = makeClass()

function Chapter:toNovelChapter()
  return NovelChapter {
    title = self.title,
    link = self.slug,
  }
end

---Creates Novel object by using a subset of basic fields from Book
---@return Novel novel
function Book:toNovel()
  return Novel {
    -- for chapters use parent's slug in place of title
    title = self.parent and extractTitleFromURL(self.parent) or self.title,
    link = shrinkURL(self.parent or self.href),
    imageURL = self.cover_thumb
  }
end

---Creates NovelInfo object from Book fields
---@return NovelInfo novel
function Book:toNovelInfo()
  return NovelInfo {
    title = self.title,
    link = shrinkURL(self.parent or self.href),
    imageURL = self.cover,
    authors = map(self.authors, function(a) return a.name end),
    chapterCount = #self.children,
    chapters = ( #self.children > 0 )
      and map(self.children, function(v)
          return Chapter(v):toNovelChapter()
      end)
      or { NovelChapter {title = self.title, link = self.slug} },
    description = HTMLToString(self.abstract),
    genres = map(self.genres, function(g) return g.name end),
    tags = map(self.kinds, function(k) return k.name end),
    language = self.language,
    status = NovelStatus.COMPLETED
  }
end

---@class Author
---@field id number
---@field url string
---@field href string
---@field name string
---@field slug string
local Author = {}

local function getListing(data)
  local url = qs({
    offset = PAGE_SIZE * data[PAGE],
    sort = sortFilter:valueOfOrFirst(data[FID_SORT]),
    search = data[QUERY],
    format = "json",
    -- tag = 0
    -- translator = 0
  }, "/api/2/books")

  local jsonData = json.GET(expandURL(url, KEY_LISTING_URL))
  local books = jsonData.member

  if not books then return {} end

  -- that will get rid of duplicates only on THIS page
  -- some duplicates may still occur if spread through multiple pages
  local seen = {}
  local novels = {}
  for _, b in ipairs(books) do
    if not b.parent or not seen[b.parent] then
      table.insert(novels, Book(b):toNovel())
    end
    seen[b.parent or b.href] = true
  end

  return novels
end

local function parseNovel(url, loadChapters)
  local jsonData = json.GET(expandURL(url, KEY_NOVEL_URL))
  return Book(jsonData):toNovelInfo()
end

local function getPassage(slug)
  local documentURL = expandURL("/media/book/html/"..slug..".html", KEY_CHAPTER_URL)
  local doc = GETDocument(documentURL)
  return pageOfElem(doc, false, ".theme-begin {float:right;}")
end

return {
  id = 23119218,
  name = "Wolne Lektury",
  baseURL = baseURL,
  imageURL = "https://fundacja.wolnelektury.pl/wp-content/themes/koed_wl/images/wolnelektury-favicon.png",
  chapterType = ChapterType.HTML,
  -- hasCloudFlare = hasCloudFlare,

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  listings = {
    Listing("Default", true, getListing)
  },
  searchFilters = {
    DropdownFilter(FID_SORT, "Sortowanie", sortFilter:labels())
  },

  parseNovel = parseNovel,
  getPassage = getPassage,

  hasSearch = true,
  isSearchIncrementing = true,
  startIndex = 0,
  search = getListing,

  settings = {},
  updateSetting = function(id, value)
    -- settings[id] = value
  end,
}