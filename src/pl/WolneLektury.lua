-- {"id":23119218,"ver":"0.0.0","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["dkjson>=1.0.1"]}

local qs = Require("url").querystring
local json = Require("dkjson")
local HTMLToString = Require("unhtml").HTMLToString
local FilterOptions = Require("FilterOptions")

local PAGE_SIZE = 20

local baseURL = "https://wolnelektury.pl"

local FID_SORT = 2
 -- alpha OR -alpha OR popularity OR -popularity
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
  return baseURL .. "/" .. url:gsub("^/", "")
end

--- Generic function to create class tables  
--- Creates a Lua "class" table with methods and callable constructor
--- @param methods table? Table containing initial methods (optional)
--- @return table A class-like table with `__index` and `__call`
local function makeClass(methods)
    local cls = methods or {}
    cls.__index = cls

    -- Make cls callable: cls(table) sets metatable
    setmetatable(cls, {
        __call = function(self, entry)
            setmetatable(entry, self)
            return entry
        end
    })

    return cls
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
---@field parent string|nil
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
    title = self.title,
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
    sort = sortFilter:valueOf(data[FID_SORT]),
    search = data[QUERY],
    format = "json",
    -- tag = 0
    -- translator = 0
  }, "/api/2/books")

  local jsonData = json.GET(expandURL(url))
  local books = jsonData.member

  if not books then return {} end

  return map(books, function(b) return Book(b):toNovel() end)
end

local function parseNovel(url, loadChapters)
  local jsonData = json.GET(expandURL(url))
  return Book(jsonData):toNovelInfo()
end

local function getPassage(url)
  local documentURL = expandURL("/media/book/html/"..url..".html")
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