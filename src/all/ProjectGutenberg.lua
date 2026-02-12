-- {"id":231192101,"ver":"1.0.0","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["IndexedMap", "url"]}

local IndexedMap = Require("IndexedMap")
local qs = Require("url").querystring

local baseURL = "https://www.gutenberg.org"

local PAGE_SIZE = 25

-- Filters IDs
local FID_LANG = 2
local FID_SORT = 3

-- Settings IDs
local SID_PRESERVE_STYLES = 1
local settings = {
  [SID_PRESERVE_STYLES] = false
}

local function shrinkURL(url, type)
  return url:gsub(".-gutenberg%.org/?", "")
end

local function expandURL(url, type)
  return baseURL .. "/" .. url:gsub("^/*", "")
end

local function getListing(url)
  local doc = GETDocument(expandURL(url))
  return map(doc:select("li.booklink"), function(card)
    return Novel {
      title = card:selectFirst(".title"):text(),
      link = card:selectFirst(".link"):attr("href"),
      imageURL = expandURL(card:selectFirst(".cover-thumb"):attr("src"))
    }
  end)
end

local function parseNovel(url, loadChapters)
  local doc = GETDocument(expandURL(url))

  local info = NovelInfo {
    title = doc:selectFirst("[itemprop=headline]"):text(),
    imageURL = doc:selectFirst(".cover-art"):attr("src"),
    description = doc:selectFirst(".readmore-container"):ownText() 
      .. doc:selectFirst(".readmore-container .toggle-content"):text(),
    authors = map(doc:select("[itemprop='creator']"), function(c)
      return c:text()
    end),
    genres = map(doc:select("[property='dcterms:subject']"), function(s)
      return s:text()
    end),
    status = NovelStatus.COMPLETED,
    language = doc:selectFirst("[itemprop=inLanguage]"):attr("content")
  }

  if loadChapters then
    local chapters = {}
    chapters = {
      NovelChapter {
        title = doc:selectFirst("[itemprop=headline]"):text(),
        link = doc:selectFirst(".link.read_html"):attr("href"),
        release = doc:selectFirst("[itemprop=dateModified]"):text()
      }
    }
    info:setChapters(AsList(chapters))
  end

  return info
end

local function getPassage(url)
  local doc = GETDocument(expandURL(url))

  -- add base URL so image URLs can resolve
  local og = doc:selectFirst("meta[property='og:url']")
  if og then
    local ogUrl = og:attr("content")
    if ogUrl ~= "" then
      doc:head():prependElement("base"):attr("href", ogUrl)
    end
  end

  return pageOfElem(doc, not settings[SID_PRESERVE_STYLES])
end

local languages = IndexedMap({
  {"Any", ""},
  {"Afrikaans", "af"},
  {"Aleut", "ale"},
  {"Arabic", "ar"},
  {"Arapaho", "arp"},
  {"Bodo", "brx"},
  {"Breton", "br"},
  {"Bulgarian", "bg"},
  {"Caló", "rmq"},
  {"Catalan", "ca"},
  {"Cebuano", "ceb"},
  {"Chinese", "zh"},
  {"Czech", "cs"},
  {"Danish", "da"},
  {"Dutch", "nl"},
  {"English", "en"},
  {"Esperanto", "eo"},
  {"Estonian", "et"},
  {"Farsi", "fa"},
  {"Finnish", "fi"},
  {"French", "fr"},
  {"Frisian", "fy"},
  {"Friulian", "fur"},
  {"Gaelic, Scottish", "gla"},
  {"Galician", "gl"},
  {"Gamilaraay", "kld"},
  {"German", "de"},
  {"Greek", "el"},
  {"Greek, Ancient", "grc"},
  {"Hebrew", "he"},
  {"Hungarian", "hu"},
  {"Icelandic", "is"},
  {"Iloko", "ilo"},
  {"Interlingua", "ia"},
  {"Inuktitut", "iu"},
  {"Irish", "ga"},
  {"Italian", "it"},
  {"Japanese", "ja"},
  {"Kashubian", "csb"},
  {"Khasi", "kha"},
  {"Korean", "ko"},
  {"Latin", "la"},
  {"Lithuanian", "lt"},
  {"Maori", "mi"},
  {"Mayan Languages", "myn"},
  {"Middle English", "enm"},
  {"Nahuatl", "nah"},
  {"Napoletano-Calabrese", "nap"},
  {"Navajo", "nav"},
  {"North American Indian", "nai"},
  {"Norwegian", "no"},
  {"Occitan", "oc"},
  {"Ojibwa", "oji"},
  {"Old English", "ang"},
  {"Polish", "pl"},
  {"Portuguese", "pt"},
  {"Romanian", "ro"},
  {"Russian", "ru"},
  {"Sanskrit", "sa"},
  {"Serbian", "sr"},
  {"Slovenian", "sl"},
  {"Spanish", "es"},
  {"Swedish", "sv"},
  {"Tagabawa", "bgs"},
  {"Tagalog", "tl"},
  {"Telugu", "te"},
  {"Welsh", "cy"},
  {"Yiddish", "yi"}
}, 0)

local sortOrder = IndexedMap({
  {"Most Popular", "downloads"},
  {"New Releases", "release_date"}
}, 0)

return {
  id = 231192101,
  name = "Project Gutenberg",
  baseURL = baseURL,
  imageURL = "https://www.gutenberg.org/gutenberg/pg-logo-144x144.png",
  chapterType = ChapterType.HTML,

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  startIndex = 0,
  listings = {
    Listing("Browse", true, function(data)
      local offset = data[PAGE] * PAGE_SIZE + 1
      local language = languages:valueAt(data[FID_LANG])
      local order = sortOrder:valueAt(data[FID_SORT])

      local params = {
        sort_order = order,
        start_index = offset
      }
      if language ~= "" then params["query"] = "l." .. language end

      return getListing(qs(params, "ebooks/search/"))
    end),
    Listing("Random Suggestions", false, function()
      return getListing("ebooks/search/?sort_order=random")
    end)
  },
  searchFilters = {
    DropdownFilter(FID_SORT, "Sort order", sortOrder.keys),
    DropdownFilter(FID_LANG, "Language", languages.keys)
  },

  parseNovel = parseNovel,
  getPassage = getPassage,

  hasSearch = true,
  isSearchIncrementing = true,
  search = function(data)
    local offset = data[PAGE] * PAGE_SIZE + 1
    local query = data[QUERY]
    return getListing("ebooks/search/?query=" .. query .. "&start_index=" .. offset)
  end,

  settings = {
    SwitchFilter(SID_PRESERVE_STYLES, "Preserve formatting")
  },
  updateSetting = function(id, value)
    settings[id] = value
  end,
}