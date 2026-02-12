-- {"ver":"1.0.2","author":"Bigrand","dep":["url>=1.0.0", "unhtml>=1.0.0"]}

local qs = Require("url").querystring
local unhtml = Require("unhtml")
local HTMLToString = unhtml.HTMLToString
local trim = unhtml.trim

local toText = function(v)
    return v:text()
end

-- BRIEF WARNING!!!
-- 
-- Certain defaults aren't actually defined by default. 
-- It may crash the entire app if you don't set them up. 
-- The exact ones are unknown, as it doesn't log a stack trace
-- but it's probably `listingConfigs`, `supportedFilters`, `genres`, and/or `statuses`.
-- Anyway, it shouldn't be a problem as long as you set up the extension correctly :D
local defaults = {
    hasCloudFlare = false,
    hasSearch = true,
    chapterType = ChapterType.HTML,
    isSearchIncrementing = true,

    -- Some sources don't have an exclusive path for novels
    --
    -- For example,
    -- - with special path: `.com/novel/i-kissed-your-mom`
    -- - with no special path: `.com/i-kissed-your-mom.html`
    --
    -- Used to expand or shrink the URLs accordingly
    novelParam = nil,

    authorParam = "author", -- Source's exclusive path for authors. Used to build the authors CSS selector
    genreParam = "genre", -- Source's exclusive path for genres. Used to build the genre CSS selector
    tagParam = "tag", -- Source's exclusive path for tags. Used to build the tags CSS Selector.
    searchParam = "search", -- Source's exclusive path for searches. Used to build the search URL

    genreSpace = "+", -- Used to generate genre params. Character that replaces spaces.

    -- If this is set to `""` (empty string), it will append just the number to the URL.
    -- Meaning that instead of `popular?page=X`, you will get `popular/X`.
    pageParam = "page", -- Used to build the search URL. Refers to this part: `?page=X`

    -- This lib doesn't support paginated chapters because I'm tired.
    -- I've been working on this for too much time, and I'm sick of it.
    -- Total known sources affected by this: 1 (novellive.app) :D
    --
    -- AJAX endpoint to get chapters. No fallback.
    -- Known endpoints are:
    -- `"ajax-chapter-option"`, `"ajax/chapter-archive"` and `"get_chapter_list"`.
    -- If chapters are obtained through the novel's page, you must set `ajaxChaptersURL` to `"noajax"`.
    ajaxChaptersURL = "ajax-chapter-option",
    novelIdParam = "novelId", -- This is the query used to fetch chapters via the AJAX endpoint.

    novelIdAttribute = "data-novel-id", -- This ID is used to fetch chapters
    novelIdPattern   = nil, -- Use pattern matching on the novel's URL instead if the novel ID isn't accessible by attribute.

    -- Listings builder.
    -- Just add the name, whether it's paginated or not and its path.
    -- Example:
    -- ```lua
    -- listingConfigs = {
    --      { name = "Hot Novel", incrementing = true, param = "sort/hot-novel"},
    --      -- add or remove rows here as needed
    -- }
    -- ```
    listingConfigs = {},

    -- Must be overridden to enable filters.
    -- Possible options:
    -- `"genre"`, `"author"`, `"tag"` and `"status"`
    supportedFilters = {},
    genres = {}, -- Only define if its filter is enabled in `supportedFilters`

    -- Statuses are technically listings, but they are also relevant as filters.
    -- So, add them as filters and listings. Why not? :D
    --
    -- Example:
    -- ```lua
    -- statuses = {
    --     { name = "Ongoing",  param = "sort/nov-love-ongoing" },
    --     { name = "Completed",param = "sort/nov-love-completed" },
    --     -- Add or remove entries as needed.
    -- }
    -- ```
    statuses = {}, -- Only define this if the status filter is enabled in `supportedFilters`.

    -- Some sources provide search results through POST requests instead of GET.
    isSearchPOST = false,

    -- Most sources use low-resolution images with weird aspect ratios for search results.
    -- Luckily, some have a predictable URL pattern that can be modified to get the full resolution image.
    -- If the extension defines `searchImgModFunc`, it will inject the function to modify the image URL. Otherwise, the original `imageURL` is returned.
    -- The injected functions receives and must return an expanded image URL string.
    --
    -- Note: Shosetsu may fetch different HTML than a regular browser, so image URLs can vary.
    -- Some sources do provide low-resolution images with the correct aspect ratio (even if they serve different ratios to regular browsers).
    searchImgModFunc = nil,

    customStyle = "", -- Inject custom CSS for passages. Useful for RTL support.

    -- Used to build the correct chapter URL when the AJAX chapter URLs redirect to a different domain.
    -- This is specifically made for mirrors where chapter links redirect to `novelbin.com`,
    -- even though the chapters are also hosted on the domain using an alternate path.
    -- If defined, use `novelParam` with `chapterNovelParam` for chapter URLs only.
    --
    -- For example:
    --   - `novelbin.me/novel-book/<novelid>/chapter-1` → redirects to `novelbin.com`'s chapter URL
    --   - `novelbin.me/b/<novelid>/chapter-1` → directly serves the chapter
    --
    -- If the source has this problem:
    -- Both `novelParam` and `chapterNovelParam` must be defined to correctly build the correct URL.
    chapterNovelParam = nil,

    -- Element Selectors:
    -- `selectWithFallback()` tries each function in order. Ideally, one function checks multiple 
    -- CSS selectors by combining them into a single multi-selector string. If necessary, multiple 
    -- functions can be used, and it will check each one until a valid result (not falsey or an empty string) is found.
    -- These functions can be customized per extension without needing to update the library.
    -- All processing should be done inside the functions, which must return the expected type and value for the field.

    -- Yeah, it's kinda messy, but I want to avoid constantly updating this lib or hardcoding fixes.
    -- So I added function injection support for all selectors to keep things flexible,
    -- even if it's not the most efficient or cleaniest solution.
    -- Multiple functions are supported because it's a remnant of an old refactor.
    -- Removing it would require another refactor (idk actually), and I really don't want to do that for less features :D
    -- And why do I keep commenting useless shit? Because I'm lonely, so suck it up :DDD

    listingSelector = {
        function(el)
            local listing = el:select(".archive .list .row, .ul-list1.ul-list1-2.ss-custom .li-row")
            return listing
        end
    },

    listingTitleSelector = {
        function(el)
            local title = el:selectFirst(".novel-title, .truyen-title, .tit")
            if not title then
                error("No results found...")
            end
            return title and title:text()
        end
    },

    listingLinkSelector = {
        function(el)
            local link = el:selectFirst(".novel-title a, .truyen-title a, .tit a")
            return link and link:attr("href")
        end
    },

    -- Used by `getImgURL()`, so it must fetch the listing covers or the novel's cover
    imageURLAttribute = {
        function(el)
            local img = el:selectFirst("img.cover, .pic img") or el:selectFirst("div.book img, .m-imgtxt img")
            if not img then return nil end

            local src = img:attr("src")
            if src and src ~= "" then return src end

            local dataSrc = img:attr("data-src")
            if dataSrc and dataSrc ~= "" then return dataSrc end

            local cfsrc = img:attr("data-cfsrc")
            if cfsrc and cfsrc ~= "" then return cfsrc end

            return "NO_IMAGE_AVAILABLE"
        end
    },

    titleSelector = ".title, .m-desc > .tit",

    descriptionSelector = ".desc-text, .txt > .inner",

    altNamesSelector = {
        function(el)
            local altNames = {}
            local altNamesElement = el:selectFirst(
                ".info > li:has(h3:containsOwn(lternative))," ..
                ".info > div:has(h3:containsOwn(lternative))," ..
                'div.txt span[title="Alternative names"] + div.right span.s1'
            )

            if altNamesElement then
                local h3 = altNamesElement:selectFirst("h3")

                if h3 then
                    h3:remove()
                end

                local text = altNamesElement:text()
                for name in string.gmatch(text, '([^,]+)') do
                    table.insert(altNames, trim(name))
                end
            end

            return altNames
        end
    },

    statusSelector = {
        function(el)
            local status = el:selectFirst(
                ".info .text-primary," ..
                ".info > div:has(h3:containsOwn(tatus)) > a," ..
                ".info > div:has(h3:contains(tatus)) > h3:nth-of-type(2)," ..
                'div.txt span[title="Status"] + div.right span.s1'
            )

            return status:text()
        end
    },

    tagsSelector = {
        function(self, el)
            local tags = el:select(
                '.info a[href*="/'.. self.tagParam .. '/"],' ..
                '.txt a[href*="/'.. self.tagParam .. '/"]'
            )
            return map(tags, toText)
        end
    },

    genresSelector = {
        function(self, el)
            local genres = el:select(
                '.info a[href*="/'.. self.genreParam .. '/"],' ..
                '.m-imgtxt > .txt a[href*="/' .. self.genreParam ..'/"]'
            )

            if genres:isEmpty() then
                genres = el:select(
                    ".info > div:has(h3:containsOwn(enre)) > a," ..
                    ".info > li:has(h3:containsOwn(enre)) > a"
                )
            end

            return map(genres, toText)
        end
    },

    authorSelector = {
        function(self, el)
            local authors = el:select(
                '.info a[href*="/' .. self.authorParam .. '/"],' ..
                '.m-imgtxt > .txt a[href*="/' .. self.authorParam .. '/"]'
            )

            if authors:isEmpty() then
                authors = el:select(
                    ".info > div:has(h3:containsOwn(uthor)) > a," ..
                    ".info > li:has(h3:containsOwn(uthor)) > a"
                )
            end

            return map(authors, toText)
        end
    },

    chapterTitleSelector = {
        function(el)
            local chapTitle = el:selectFirst(".chapter-text, .chr-title, .wp > .top > span")
            return chapTitle and chapTitle:text()
        end
    },

    chapterContentSelector = {
        function(el)
            local chapSelector = "#chr-content, #chapter-content, .wp > .txt"
            local chapContent = el:selectFirst(chapSelector)

            local usedSelector = nil
            if chapContent then
                if chapContent:id() == "chr-content" then
                    usedSelector = "#chr-content"
                elseif chapContent:id() == "chapter-content" then
                    usedSelector = "#chapter-content"
                else
                    usedSelector = ".wp > .txt"
                end
            end

            return chapContent, usedSelector -- Returns the CSS selector for passage processing
        end
    },

    chapterFetchSelector = {
        function(doc)
            local links = doc:select(".m-newest2 > .ul-list5 > li > a")
            if not links:isEmpty() then
                return links, "ul"
            end

            links = doc:select("select option")
            if not links:isEmpty() then
                return links, "select"
            end

            links = doc:select(".list-chapter li a")
            if not links:isEmpty() then
                return links, "list"
            end

            -- Specific to Light Novel Plus
            links = doc:select("pre"):text()
            links = Document(links)
            links = links:select("select option")
            if not links:isEmpty() then
                return links, "select"
            end

            error("Error: Couldn't fetch chapter links.")
        end
    }
}

-- Ideally, each extension would define the exact CSS selector,
-- but requiring that makes extensions annoying to add and test.
--
--- @param element Element          -- The element to match selectors against.
--- @param selectorFuncs function[] -- Array of functions that take an element and return element(s). For example, `el:selectFirst(".title"):text()`.          
local function selectWithFallback(element, selectorFuncs, context, msg)
    if type(context) == "string" and msg == nil then
        msg, context = context, nil
    end

    for _, fn in ipairs(selectorFuncs) do
        local results

        if context then
            results = { fn(context, element) }
        else
            results = { fn(element) }
        end

        if #results > 0 then
            local allValid = true

            for _, value in ipairs(results) do
                if not value or value == "" then
                    allValid = false
                    break
                end
            end

            if allValid then
                return table.unpack(results)
            end
        end
    end

    error("Error: All selectors failed. " .. (msg and ("type: " .. msg) or "") )
end

-- Automatically, generates the URL params used by the genre filter.
-- If it doesn't follow lowercase and hyphens for spaces format
-- then you must set it yourself inside `self.genres` using `param`
--
---@return table genreParams
function defaults:generateGenreParams()
    local out = { "" }
    for i, item in ipairs(self.genres) do
        local name, param

        if type(item) == "table" then
            name  = item.name or ""
            param = item.param or ""
            out[i+1] = param
        else
            name  = item
            param = name:lower():gsub(" ", self.genreSpace)
            out[i+1] = self.genreParam .. "/" .. param
        end
    end
    return out
end

-- gsub does pattern-based replacements, not literal substring replacements.
-- This function escapes all Lua pattern-matching characters in the `substring`,
-- so Lua doesn't interpret it as a pattern.
--
--- @param s string        The input string in which to perform replacements.
--- @param substring string The exact substring to be replaced (treated literally).
--- @param replacement string The string to replace each occurrence with.
--- @return string
--- @return integer nReplacements
local function replace(s, substring, replacement)
    local escaped = substring:gsub("(%p)", "%%%1")
    return s:gsub(escaped, replacement)
end

function defaults:expandURL(url)
    if self.novelParam then
        return self.baseURL .. "/" .. self.novelParam .. "/" .. url
    end

    return self.baseURL .. "/" .. url
end

function defaults:shrinkURL(url)
    if self.novelParam then
        return replace(url, self.baseURL .. "/" .. self.novelParam .. "/", "")
    end

    return replace(url, self.baseURL .. "/", "")
end


---@param imageURL string 
---@return string modifiedImageURL
function defaults:getFullSizeImage(imageURL)
    local finalImageURL = imageURL

    if self.searchImgModFunc then
        finalImageURL = self.searchImgModFunc(imageURL)
    end

    return finalImageURL
end

---@return string
function defaults:getImgURL(el)
    local imageURL = selectWithFallback(el, self.imageURLAttribute, "img")

    -- Basically, normalizes the URL so it's always an expanded one.
    -- Can't use `expandURL()` because it's used for novel URLs
    if not imageURL:match("^https?://") then
        imageURL = imageURL:match("^/(.*)") or imageURL
        imageURL = self.baseURL .. "/" .. imageURL
    end

    return imageURL
end

function defaults:searchPOST(query)
    local payload = "searchkey=" .. query
    local MTYPE = MediaType("application/x-www-form-urlencoded")
    local body = RequestBody(payload, MTYPE)

    -- Not sure if it's necessary, but whatever lol
    local HEADERS = HeadersBuilder()
        :add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        :add("Accept-Language", "en-US,en;q=0.5")
        :add("Content-Type", "application/x-www-form-urlencoded")
        :add("Origin", self.baseURL)
        :add("DNT", "1")
        :add("Sec-GPC", "1")
        :add("Connection", "keep-alive")
        :add("Referer", self.baseURL .. "/" .. self.searchParam)
        :build()

    local results = RequestDocument(POST(self.baseURL .. "/" .. self.searchParam, HEADERS, body))

    return results
end

-- Some sources repeat the last page's results when there are no more pages
-- causing duplicate entries. If `page` is passed, we compare the current results with the last ones.
-- If they're the same, we return empty results and stop Shosetsu from loading more pages.
local lastSeen = nil

function defaults:parseListing(listingURL, page, postQuery)
    local document

    -- `postQuery` is only provided if `isSearchPOST` is true
    if postQuery then
        document = self.searchPOST(postQuery)
    else
        document = GETDocument(listingURL)
    end

    local listing = selectWithFallback(document, self.listingSelector, "listing")

    local current = listing:text()
    if page then
        if page > 1 and lastSeen == current then
            return {}
        end

        lastSeen = current
    end

    return map(listing, function(v)
        local title = selectWithFallback(v, self.listingTitleSelector, "listingTitle")

        local imageURL = self.getImgURL(v)
        imageURL = self.getFullSizeImage(imageURL)

        local link = selectWithFallback(v, self.listingLinkSelector, "listingLink")
        link = self.shrinkURL(link)
        link = link:match("^/(.*)") or link
        link = link

        return Novel {
            title = title,
            imageURL = imageURL,
            link = link
        }
    end)
end

function defaults:search(data)
    local userQuery = data[QUERY]
    local currentPage = data[PAGE]
    local url = qs({ keyword = userQuery, [self.pageParam] = currentPage}, self.baseURL .. "/" .. self.searchParam)

    -- A bad way to to do it but the document is requested inside `parseListing()`
    if self.isSearchPOST then
        return self.parseListing(url, currentPage, userQuery)
    end

    return self.parseListing(url, currentPage)
end

function defaults:getPassage(chapterURL)
    local url = self.expandURL(chapterURL)

    if self.chapterNovelParam and self.novelParam then
        url = replace(url, self.novelParam, self.chapterNovelParam)
    end

    local document = GETDocument(url)

    local title = selectWithFallback(document, self.chapterTitleSelector, "title")
    local chapter, chapSelector = selectWithFallback(document, self.chapterContentSelector, "chapterContent")

    -- Maybe using the tail would be better but whatever
    local toRemove = {}
    chapter:traverse(NodeVisitor(function (v)
        local tag = v:tagName()
        if not v:hasText() then
            table.insert(toRemove, v)
        end

        if tag == "iframe" or tag == "script" then
            table.insert(toRemove, v)
        end
    end), function()end, true)

    for _, node in ipairs(toRemove) do
        node:remove()
    end

    toRemove = {}
    chapter:traverse(NodeVisitor(function (v)
        local tag = v:tagName()

        -- Remove that one annoying <br> between paragraphs - Specific to NovLove but others could benefit too
        -- This doesn't account for stray text nodes, which means it could potentially remove useful
        -- <br> tags and the like. BUT! I don't care, so won't fix :D
        if tag == "br" then
            local previous = v:previousElementSibling()
            local next = v:nextElementSibling()

            if previous and next and previous:tagName() == "p" and next:tagName() == "p" then
                table.insert(toRemove, v)
            end
        end
    end, function()end, true)) -- Enable elements only to avoid crashes

    for _, node in ipairs(toRemove) do
        node:remove()
    end

    if chapter:hasAttr("style") then
        chapter:removeAttr("style")
    end

    -- Remove duplicated titles
    -- The CSS selector (and others) could be simplified by using a simple `:is()`, 
    -- but for some reason, I can't get it working :DDDDD
    local headingTags = { "h1", "h2", "h3", "h4", "h5", "h6", "p" }
    local selectorParts = {}
    for _, tag in ipairs(headingTags) do
        table.insert(selectorParts, chapSelector .. " " .. tag)
    end

    local selector = table.concat(selectorParts, ", ")
    local dupEl = document:selectFirst(selector)
    local titleLower = trim(title):gsub("^\239\187\191", ""):gsub("%c+", ""):lower()
    local prefixLen = math.min(#titleLower, 9)
    local titlePrefix = titleLower:sub(1, prefixLen)

    -- This only checks the very first text of the chapter.
    -- Meaning that it doesn't detect double or more duplicated titles.
    -- It's probably an easy fix? Yes. Will I do it? No. I'm sick of all of this :D
    if dupEl and dupEl:text():lower():find(titlePrefix, 1, true) then
        local dupText = dupEl:text()
        dupEl:remove()

        local _, count = dupText:lower():gsub(titlePrefix, "")

        local ratioLimit = 1.8
        local okLength = #dupText <= ratioLimit * #title

        local isSuitableDup = count < 2 and (#dupText > #title and okLength)

        -- The reason we are keeping the duplicated title and removing the original one  
        -- is that sometimes the duplicated title is correctly ripped off and has more info  
        -- or correct formatting than the one in the index. So, that's why we check for length.
        if isSuitableDup then
            chapter:prepend("<h1>" .. dupText .. "</h1>")
        else
            chapter:prepend("<h1>" .. title .. "</h1>")
        end
    else
        chapter:prepend("<h1>" .. title .. "</h1>")
    end

    -- Remove watermark
    local watermarkElement = document:selectFirst(chapSelector .. " > p:last-child")
    if watermarkElement and string.find(watermarkElement:text():lower(), "source:", 1, true) then
        watermarkElement:remove()
    end

    -- Remove premium buttons - Specific to NovLove, NovelBin
    local premiumElement = document:selectFirst(".unlock-buttons")
    if premiumElement then
        premiumElement:remove()
    end

    -- Remove error report suggestion - Specific to NovelFull
    local suggestionElement = document:selectFirst(chapSelector .. " > div:last-of-type")
    if suggestionElement and string.find(suggestionElement:text():lower(), "report chapter", 1, true) then
        suggestionElement:remove()
    end

    return pageOfElem(chapter, false, self.customStyle)
end

local function parseSelectChapter(element)
    local chapTitle = element:text()
    local chapLink = element:attr("value")

    return { title = chapTitle, link = chapLink }
end

local function parseListChapter(element)
    local titleElement = element:selectFirst(".nchr-text")

    local isPremium = titleElement:selectFirst(".premium-label")
    local isPaid = titleElement:selectFirst(".paid-label")

    if isPremium or isPaid then
        return nil
    end

    local chapTitle = element:text()
    local chapLink = element:attr("href")

    return { title = chapTitle, link = chapLink }
end

local function parseUlChapter(element)
    local chapTitle = element:text()
    local chapLink = element:attr("href")

    return { title = chapTitle, link = chapLink }
end

function defaults:parseNovel(novelURL, loadChapters)
    local url = self.expandURL(novelURL)
    local document = GETDocument(url)

    local title = document:selectFirst(self.titleSelector)
    if not title then
        error("Error: Novel not found. Contact developers.")
    end
    title = title:text()

    local novelID = document:selectFirst("div[" .. self.novelIdAttribute .. "]")
    if self.ajaxChaptersURL ~= "noajax" then
        if self.novelIdPattern then
            novelID = string.match(url, self.novelIdPattern)
        elseif novelID then
            novelID = novelID:attr(self.novelIdAttribute)
        else
            error("Error: Couldn't get novel ID. Contact developers.")
        end
    end

    local imageURL = self.getImgURL(document)
    local description = HTMLToString(document:selectFirst(self.descriptionSelector))
    local altNames = selectWithFallback(document, self.altNamesSelector, "altNames")
    local status = selectWithFallback(document, self.statusSelector, "status")
    local tags = selectWithFallback(document, self.tagsSelector, self, "tags")
    local genres = selectWithFallback(document, self.genresSelector, self, "genres")
    local authors = selectWithFallback(document, self.authorSelector, self, "authors")

    local NovelInfo = NovelInfo {
        title = title,
        alternativeTitles = altNames,
        imageURL = imageURL,
        description = description,
        status = ({
            Ongoing = NovelStatus.PUBLISHING,
            OnGoing = NovelStatus.PUBLISHING,
            Completed = NovelStatus.COMPLETED,
        })[status] or NovelStatus.UNKNOWN,
        tags = tags,
        genres = genres,
        authors = authors,
    }

    if loadChapters then
        local chapterIndexURL
        chapterIndexURL = qs({[self.novelIdParam] = novelID}, self.baseURL .. "/" .. self.ajaxChaptersURL)

        local chapterIndexDoc
        if self.ajaxChaptersURL ~= "noajax" then
            chapterIndexDoc = GETDocument(chapterIndexURL)
        else
            chapterIndexDoc = document
        end
        local chapterLinks, method = selectWithFallback(chapterIndexDoc, self.chapterFetchSelector, "chapterFetch")

        local i = 0
        local chapters = AsList(mapNotNil(chapterLinks, function(v)
            local parsed

            if method == "select" then
                parsed = parseSelectChapter(v)
            elseif method == "list" then
                parsed = parseListChapter(v)
            else
                parsed = parseUlChapter(v)
            end

            if not parsed or not parsed.title or not parsed.link then
                return nil
            end

            local link = parsed.link
            link = link:match("^/(.*)") or self.shrinkURL(link)
            link = link

            i = i + 1 -- explicitly calculate order
            return NovelChapter {
                order = i,
                title = parsed.title,
                link = link
            }
        end))

        NovelInfo:setChapters(chapters)
    end

    return NovelInfo
end

local GENRE_FILTER_ID = 2
local AUTHOR_FILTER_ID = 3
local STATUS_FILTER_ID = 4
local TAG_FILTER_ID = 5
function defaults:getListing(name, inc, sortString)
    return Listing(name, inc, function(data)
        local page   = data[PAGE]
        local genre  = data[GENRE_FILTER_ID]
        local author = data[AUTHOR_FILTER_ID]
        local status = data[STATUS_FILTER_ID]
        local tag    = data[TAG_FILTER_ID]

        -- `getListing()` also handles filter URL building.
        -- We need to know if it's a normal listing or a filter listing.
        local isListing = true
        local url

        if genre and genre ~= 0 then
            -- `generateGenreParams()` should handle path building.
            local GENRE_PARAMS = self:generateGenreParams()
            local genreValue = GENRE_PARAMS[genre + 1]

            url = self.baseURL .. "/" .. genreValue
            isListing = false
        end

        if author and author ~= "" and isListing then
            url = self.baseURL .. "/" .. self.authorParam .. "/" .. author
            isListing = false
        end

        if status and status ~= 0 and isListing then
            local STATUS_PARAMS = self.statuses
            local statusValue = STATUS_PARAMS[status].param

            url = self.baseURL .. "/" .. statusValue
            isListing = false
        end

        if tag and tag ~= "" and isListing then
            url = self.baseURL .. "/" .. self.tagParam .. "/" .. tag:upper()
            isListing = false
        end

        if isListing then
            url = self.baseURL .. "/" .. sortString
        end

        if page > 1 and inc then
            local sep = url:find("?", 1, true) and "&" or "?"
            if self.pageParam and self.pageParam ~= "" then
                url = url .. sep .. self.pageParam .. "=" .. page
            else
                url = url .. "/" .. page
            end
        end

        return self.parseListing(url, page)
    end)
end

function defaults:getFilters()
    local filters = {}
    local priorityOrder = { "genre", "author", "status", "tag" }

    if #self.supportedFilters > 1 then
        local activeFilters = {}
        for _, f in ipairs(self.supportedFilters) do
            activeFilters[f] = true
        end

        local priorityList = {}
        for _, key in ipairs(priorityOrder) do
            if activeFilters[key] then
                table.insert(priorityList, key)
            end
        end

        local priorityNote = "Note: Filters can't be combined. Use one at the time. (Reset)\n" ..
                             "Priority: " .. table.concat(priorityList, " > ")

        table.insert(filters, RadioGroupFilter(1000, priorityNote, {}))
    end

    for _, v in ipairs(self.supportedFilters) do
        if v == "genre" then
            local genres = { "None" }
            for _, item in ipairs(self.genres) do
                if type(item) == "table" then
                    table.insert(genres, item.name)
                else
                    table.insert(genres, item)
                end
            end
            table.insert(filters, DropdownFilter(GENRE_FILTER_ID, "Genre", genres))
        elseif v == "author" then
            table.insert(filters, TextFilter(AUTHOR_FILTER_ID, "Author Name (Single)"))
        elseif v == "status" then
            local statuses = { "All" }
            for _, status in ipairs(self.statuses) do
                table.insert(statuses, status.name)
            end
            table.insert(filters, DropdownFilter(STATUS_FILTER_ID, "Status", statuses))
        else
            table.insert(filters, TextFilter(TAG_FILTER_ID, "Tag (Single)"))
        end
    end

    return filters
end

return function(baseURL, _self)
    -- An extension can't override a default with nil.
    _self = setmetatable(_self or {}, { __index = function(_, k)
        local d = defaults[k]
        return (type(d) == "function" and wrap(_self, d) or d)
    end })

    _self["baseURL"] = baseURL
    _self["searchFilters"] = _self.getFilters()

    local listings = {}
    for _, cfg in ipairs(_self.listingConfigs) do
        table.insert(listings, _self.getListing(cfg.name, cfg.incrementing, cfg.param))
    end
    _self["listings"] = listings

    return _self
end
