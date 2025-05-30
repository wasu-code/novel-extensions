-- {"id": 23119213, "ver": "0.0.1", "libVer": "1.0.0", "author": "wasu-code", "dep": []}

local settings = {
  [1] = false,
}

local baseURL = "https://megatranslations5.wordpress.com"

local function shrinkURL(url)
  return url:gsub("^https://megatranslations5.wordpress.com/?", "")
end

local function expandURL(url)
    return baseURL .. "/" .. url
end

local function flatten(tables)
  local result = {}
  for _, sub in ipairs(tables) do
    for _, v in ipairs(sub) do
      table.insert(result, v)
    end
  end
  return result
end

local function gatherParagraphsBetween(doc, selectorA, selectorB)
  local paragraphs = {}
  local startElem = doc:selectFirst(selectorA)
  if not startElem then return paragraphs end

  local node = startElem:nextElementSibling()
  while node and not node:is(selectorB) do
    if node:tagName() == "p" then
      table.insert(paragraphs, node:text())
    end
    node = node:nextElementSibling()
  end
  return paragraphs
end

local function parseListing(doc)
  return map(doc:select("ul.wp-block-navigation__container li:nth-of-type(2) ul li a"), function(card)
    return Novel {
      title = card:text(),
      link = shrinkURL(card:attr("href")),
    }
  end)
end

local function parseNovel(url, loadChapters)
  local doc = GETDocument(expandURL(url))

  local alternativeTitles = gatherParagraphsBetween(doc, "h2:contains(Other Names), h3:contains(Other Names)", "h2, h3")

  local descriptionParagraphs = flatten({
    gatherParagraphsBetween(doc, "h2:contains(Synopsis), h3:contains(Synopsis)", "h2, h3"),
    gatherParagraphsBetween(doc, "h2:contains(Related Series), h3:contains(Related Series)", "h2, h3")
  })
  local description = table.concat(descriptionParagraphs, "\n\n")

  local info = NovelInfo {
    title = doc:selectFirst(".wp-block-post-title"):text(),
    imageURL = doc:selectFirst('.entry-content img'):attr("src"),
    description = description,
    authors = {(doc:selectFirst(".is-nowrap p:first-of-type"):text():gsub("^Author:%s*", ""))},
    artists = {(doc:selectFirst(".is-nowrap p:last-of-type"):text():gsub("^Illustrator:%s*", ""))},
    alternativeTitles = alternativeTitles,
  }

  if loadChapters then
    local chapters = {}
    local sections = doc:select(".wp-block-heading + .wp-block-media-text")
    for i = 0, sections:size() - 1 do
      local section = sections:get(i)
      local header = section:previousElementSibling()
      if header and header:hasClass("wp-block-heading") then
        local links = section:select("p.has-text-align-center a")
        for j = 0, links:size() - 1 do
          local ch = links:get(j)
          table.insert(chapters, NovelChapter {
            title = header:text():gsub("Volume%s*(%d+)", "Vol.%1") .. " " .. ch:text():gsub("Chapter%s*(%d+)", "Ch.%1"),
            link = shrinkURL(ch:attr("href")),
          })
        end
      end
    end
    info:setChapters(chapters)
  end

  return info
end

local function getPassage(url)
  local doc = GETDocument(expandURL(url))
    local story = doc:selectFirst(".entry-content")

    local wpComments = story:selectFirst(".wp-block-comments")
    local prev = wpComments:previousElementSibling()
    if prev and prev:tagName() == "p" and prev:selectFirst("a") then
      prev:remove() -- remove ToC/Navigation links
    end
    if not settings[1] then wpComments:remove() end

  return pageOfElem(story, false)
end

return {
  id = 23119213,
  name = "MegaTranslations",
  baseURL = baseURL,
  imageURL = "https://1.gravatar.com/avatar/74b24baa6e6a4a71642701f4ed57cc47eb2d86fba6284c575ee32628affa9fba?size=128",
  chapterType = ChapterType.HTML,

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  listings = {
    Listing("Projects", false, function(data)
      return parseListing(GETDocument(baseURL))
    end),
  },

  searchFilters = {},

  parseNovel = parseNovel,
  getPassage = getPassage,

  hasSearch = false,

  settings = {
    SwitchFilter(1, "Show comments")
  },
  updateSetting = function(id, value)
    settings[id] = value
  end,
}