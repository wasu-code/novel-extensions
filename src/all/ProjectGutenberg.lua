-- {"id":231192101,"ver":"1.0.0","libVer":"1.0.0","author":"wasu-code","repo":"","dep":["FilterOptions", "url"]}

local FilterOptions = Require("FilterOptions")
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

local languages = FilterOptions({
  nil,
  {af = "Afrikaans"},
  {ale = "Aleut"},
  {ar = "Arabic"},
  {arp = "Arapaho"},
  {brx = "Bodo"},
  {br = "Breton"},
  {bg = "Bulgarian"},
  {rmq = "Caló"},
  {ca = "Catalan"},
  {ceb = "Cebuano"},
  {zh = "Chinese"},
  {cs = "Czech"},
  {da = "Danish"},
  {nl = "Dutch"},
  {en = "English"},
  {eo = "Esperanto"},
  {et = "Estonian"},
  {fa = "Farsi"},
  {fi = "Finnish"},
  {fr = "French"},
  {fy = "Frisian"},
  {fur = "Friulian"},
  {gla = "Gaelic, Scottish"},
  {gl = "Galician"},
  {kld = "Gamilaraay"},
  {de = "German"},
  {el = "Greek"},
  {grc = "Greek, Ancient"},
  {he = "Hebrew"},
  {hu = "Hungarian"},
  {is = "Icelandic"},
  {ilo = "Iloko"},
  {ia = "Interlingua"},
  {iu = "Inuktitut"},
  {ga = "Irish"},
  {it = "Italian"},
  {ja = "Japanese"},
  {csb = "Kashubian"},
  {kha = "Khasi"},
  {ko = "Korean"},
  {la = "Latin"},
  {lt = "Lithuanian"},
  {mi = "Maori"},
  {myn = "Mayan Languages"},
  {enm = "Middle English"},
  {nah = "Nahuatl"},
  {nap = "Napoletano-Calabrese"},
  {nav = "Navajo"},
  {nai = "North American Indian"},
  {no = "Norwegian"},
  {oc = "Occitan"},
  {oji = "Ojibwa"},
  {ang = "Old English"},
  {pl = "Polish"},
  {pt = "Portuguese"},
  {ro = "Romanian"},
  {ru = "Russian"},
  {sa = "Sanskrit"},
  {sr = "Serbian"},
  {sl = "Slovenian"},
  {es = "Spanish"},
  {sv = "Swedish"},
  {bgs = "Tagabawa"},
  {tl = "Tagalog"},
  {te = "Telugu"},
  {cy = "Welsh"},
  {yi = "Yiddish"}
}, "Any")

local sortOrder = FilterOptions{
  {downloads = "Most Popular"},
  {release_date = "New Releases"}
}

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
      local language = languages:valueOf(data[FID_LANG])
      local order = sortOrder:valueOf(data[FID_SORT])

      local params = {
        sort_order = order,
        start_index = offset
      }
      if language then params["query"] = "l." .. language end

      return getListing(qs(params, "ebooks/search/"))
    end),
    Listing("Random Suggestions", false, function()
      return getListing("ebooks/search/?sort_order=random")
    end)
  },
  searchFilters = {
    DropdownFilter(FID_SORT, "Sort order", sortOrder:labels()),
    DropdownFilter(FID_LANG, "Language", languages:labels())
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