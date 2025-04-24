-- {"id":95566,"ver":"1.0.0","libVer":"1.0.0","author":"Confident-hate"}

local baseURL = "https://novelbuddy.com"

---@param v Element
local text = function(v)
    return v:text():gsub(" ,", "")
end

---@param url string
---@param type int
local function shrinkURL(url)
    return url:gsub("https://novelbuddy.com", "")
end

---@param url string
---@param type int
local function expandURL(url)
    return baseURL .. url
end

local GENRE_FILTER = 2
local GENRE_VALUES = { 
    "All",
    "Action",
    "Action Adventure",
    "Adult",
    "Adventure",
    "Bender",
    "Chinese",
    "Comedy",
    "Cultivation",
    "Drama",
    "Eastern",
    "Ecchi",
    "Fan-Fiction",
    "Fanfiction",
    "Fantasy",
    "Game",
    "Gender",
    "Gender Bender",
    "Harem",
    "Historica",
    "Historical",
    "History",
    "Horror",
    "Isekai",
    "Josei",
    "Lolicon",
    "Magic",
    "Martial",
    "Martial Arts",
    "Mature",
    "Mecha",
    "Military",
    "Modern Life",
    "Mystery",
    "Psychologic",
    "Psychological",
    "Reincarnation",
    "Romance",
    "School Life",
    "Sci-fi",
    "Seinen",
    "Shoujo",
    "Shoujo Ai",
    "Shounen",
    "Shounen Ai",
    "Slice Of Life",
    "Smut",
    "Sports",
    "Supernatural",
    "System",
    "Tragedy",
    "Urban",
    "Urban Life",
    "Wuxia",
    "Xianxia",
    "Xuanhuan",
    "Yaoi",
    "Yuri"
}

local GENRE_PARAMS = {
    "",
    "/genres/action",
    "/genres/action-adventure",
    "/genres/adult",
    "/genres/adventure",
    "/genres/bender",
    "/genres/chinese",
    "/genres/comedy",
    "/genres/cultivation",
    "/genres/drama",
    "/genres/eastern",
    "/genres/ecchi",
    "/genres/fan-fiction",
    "/genres/fanfiction",
    "/genres/fantasy",
    "/genres/game",
    "/genres/gender",
    "/genres/gender-bender",
    "/genres/harem",
    "/genres/historica",
    "/genres/historical",
    "/genres/history",
    "/genres/horror",
    "/genres/isekai",
    "/genres/josei",
    "/genres/lolicon",
    "/genres/magic",
    "/genres/martial",
    "/genres/martial-arts",
    "/genres/mature",
    "/genres/mecha",
    "/genres/military",
    "/genres/modern-life",
    "/genres/mystery",
    "/genres/psychologic",
    "/genres/psychological",
    "/genres/reincarnation",
    "/genres/romance",
    "/genres/school-life",
    "/genres/sci-fi",
    "/genres/seinen",
    "/genres/shoujo",
    "/genres/shoujo-ai",
    "/genres/shounen",
    "/genres/shounen-ai",
    "/genres/slice-of-life",
    "/genres/smut",
    "/genres/sports",
    "/genres/supernatural",
    "/genres/system",
    "/genres/tragedy",
    "/genres/urban",
    "/genres/urban-life",
    "/genres/wuxia",
    "/genres/xianxia",
    "/genres/xuanhuan",
    "/genres/yaoi",
    "/genres/yuri"
}

local SORT_BY_FILTER = 3
local SORT_BY_VALUES = {"Views", "Top Day", "Top Week", "Top Month", "Updated", "Created"}
local SORT_BY_PARAMS = {"?sort=views", "?sort=top-day", "?sort=top-week", "?sort=top-month", "?sort=updated_date", "?sort=created_date"}

local STATUS_FILTER = 4
local STATUS_VALUES = {"All", "Ongoing", "Completed"}
local STATUS_PARAMS = {"&status=all", "&status=ongoing", "&status=completed"}

local searchFilters = {
    DropdownFilter(GENRE_FILTER, "Genre", GENRE_VALUES),
    DropdownFilter(SORT_BY_FILTER, "Sort By", SORT_BY_VALUES),
    DropdownFilter(STATUS_FILTER, "Status", STATUS_VALUES)
}

--- @param chapterURL string @url of the chapter
--- @return string @of chapter
local function getPassage(chapterURL)
    local htmlElement = GETDocument(chapterURL)
    local chapter = htmlElement:selectFirst(".content-inner")
    local title = htmlElement:selectFirst("h1"):text()
    chapter:prepend("<h1>" .. title .. "</h1>")

    return pageOfElem(chapter, false)
end

--- @param data table
local function search(data)
    local queryContent = data[QUERY]
    local page = "&page=" .. data[PAGE]
    local document = GETDocument(baseURL .. "/search?q=" .. queryContent .. page)
    return map(document:select(".section-body .book-item"), function(v)
        return Novel {
            title = v:selectFirst(".book-detailed-item .title h3 a"):text(),
            imageURL = "http:" .. v:selectFirst(".book-detailed-item .thumb img"):attr("data-src"),
            link = v:selectFirst(".book-detailed-item .title h3 a"):attr("href")
        }
    end)
end

--- @param novelURL string @URL of novel
--- @return NovelInfo
local function parseNovel(novelURL)
    local url = baseURL .. novelURL
    local document = GETDocument(url)
    local novelID = string.match(document:selectFirst(".layout > script"):html(), ".*bookId = (%d*);")
    local chapterURL = "https://novelbuddy.com/api/manga/" .. novelID .. "/chapters?source=detail"
    local chaperDoc = GETDocument(chapterURL)
    local chapterOrder = chaperDoc:select(".chapter-list li a"):size()
    return NovelInfo {
        title = document:selectFirst(".detail .name.box h1"):text(),
        description = document:selectFirst(".section-body.summary .content"):text(),
        imageURL = "http:" .. document:selectFirst(".img-cover img"):attr("data-src"),
        status = ({
            Ongoing = NovelStatus.PUBLISHING,
            Completed = NovelStatus.COMPLETED,
        })[document:selectFirst("div.meta:nth-child(2) > p:nth-child(2) > a:nth-child(2) > span:nth-child(1)"):text()],
        authors = map(document:selectFirst("div.meta:nth-child(2) > p:nth-child(1)"):select("a span"), text ),
        genres = map(document:selectFirst("div.meta:nth-child(2) > p:nth-child(3)"):select("a"), text ),
        tags = map(document:select(".tags a"), text ),
        chapters = AsList(
            map(chaperDoc:select(".chapter-list li a"), function(v)
                chapterOrder = chapterOrder - 1
                return NovelChapter {
                    order = chapterOrder,
                    title = v:selectFirst(".chapter-title"):text(),
                    link = baseURL .. v:attr("href")
                }
            end)
        )
    }
end

local function parseListing(listingURL)
    local document = GETDocument(listingURL)
    return map(document:select(".section-body .book-item"), function(v)
        return Novel {
            title = v:selectFirst(".book-detailed-item .title h3 a"):text(),
            imageURL = "http:" .. v:selectFirst(".book-detailed-item .thumb img"):attr("data-src"),
            link = v:selectFirst(".book-detailed-item .title h3 a"):attr("href")
        }
    end)
end

local function getListing(name, inc, listingString)
    return Listing(name, inc, function(data)
        local page = "&page=" .. data[PAGE]
        local genre = data[GENRE_FILTER]
        local genreValue = ""
        local sortby = data[SORT_BY_FILTER]
        local sortByValue = ""
        local status = data[STATUS_FILTER]
        local statusValue = ""
        if status ~= nil then
            statusValue = STATUS_PARAMS[status+1]
        end
        if genre ~= nil then
            genreValue = GENRE_PARAMS[genre+1]
        end
        if sortby ~= nil then
            sortByValue = SORT_BY_PARAMS[sortby+1]
        end
        local url = baseURL .. genreValue .. sortByValue .. statusValue .. page
        if genreValue == "" then
            url = baseURL .. listingString .. sortByValue .. statusValue .. page
        end
        return parseListing(url)
    end)
end

return {
    id = 95566,
    name = "NovelBuddy",
    baseURL = baseURL,
    imageURL = "https://novelbuddy.com/static/sites/novelbuddy/icons/apple-touch-icon.png",
    hasSearch = true,
    listings = {
        getListing("Popular", true, "/popular"),
        getListing("Newest", true, "/newest"),
        getListing("Chinese", true, "/types/chinese"),
        getListing("Korean", true, "/types/korean"),
        getListing("Japanese", true, "/types/japanese")
    },
    parseNovel = parseNovel,
    getPassage = getPassage,
    chapterType = ChapterType.HTML,
    search = search,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    searchFilters = searchFilters
}