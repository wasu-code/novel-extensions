-- {"ver":"1.0.1","author":"Bigrand","dep":["utf8"]}

--[[
    This lib turns HTML into plain text.

    It converts tags like <p>, <br>, and <hr> to their string equivalent so the structure isn’t lost, 
    but pretty much everything else gets stripped out. It also turns HTML entities into actual characters
    and does its best to handle tables and image alt text.

    Notable:
        - Table and image alt text support.

    Caveats:
        - Unordered and ordered lists just come out as bullet lists without indentation
        - <pre> and anything with formatting gets flattened
        - No custom decorations (e.g., <h1> will look the same as a regular <p> tag)
        - No support for lots of HTML tags and edge cases. REGEX/Pattern matching gave me PTSD :D
        
    Available functions:
        - HTMLToString(s: string, config: table)
        - trim(s: string)
        - collapseWS(s: string)
        - ensureString(input: any, funcName: string)
        - ensureTable(input: any, funcName: string)
        - removeComments(s: string)
        - normalizeTags(s: string)
        - removeSpecialTags(s: string)
        - addTagBreaks(s: string)
        - fixDivPBreaks(s: string)
        - removeUnallowedTags(s: string, allowedTags: table)
        - formatHrTags(s: string, character: string, length: integer)
        - newlineToSpace(s: string)
        - formatLists(s: string, character: string)
        - brToNewlines(s: string)
        - cleanLines(s: string)
        - limitNewlines(s: string)
        - formatImages(s: string)
        - formatTables(s: string)
        - convertHTMLentities(s: string)
        - shouldExecute(s: string, pattern: string|table)
    
    If you want more details on what each function does, just check out the return {} (at the end of this file)
    and hover over the functions or find the function itself in the code and look above it. You'll find all the info you need there.
]]

-- Cache all functions used
local gsub     = string.gsub
local match    = string.match
local gmatch   = string.gmatch
local lower    = string.lower
local rep      = string.rep
local sub      = string.sub
local find     = string.find
local format   = string.format
local concat   = table.concat
local insert   = table.insert
local sort     = table.sort
local max      = math.max
local tonumber = tonumber
local type     = type
local ipairs   = ipairs
local pairs    = pairs
local error    = error
local pcall    = pcall
local tostring = tostring

local utf8 = Require("utf8")

local htmlComment       = "<!%-%-.-%-%->"
local anyTag            = "<%s*(/?)%s*([%w]+)(.-)(/?)%s*>"
local htmlAttr          = "([%a][%w-]*)%s*="
local scriptTag         = "<script[^>]*>.-</script>"
local styleTag          = "<style[^>]*>.-</style>"
local doctypeTag        = "<!doctype[^>]*>"
local divP              = "</div>(%s*)<p>"
local brTag             = "<%s*br%s*/?%s*>"
local closeTag          = "^</%s*([a-z0-9-]+)"
local openTag           = "^<%s*([a-z0-9-]+)"
local hrTag             = "<%s*/?%s*hr[^>]*%s*/?%s*>"
local htmlEntity        = "(&%a+;)"
local decimalEntity     = "&#(%d+);"
local hexadecimalEntity = "&#x(%x+);"
local newline           = "[\r\n]+"
local brWS              = "<br>%s*"
local brLi              = "(<br>%s*)<li%s*>"
local openLi            = "<li%s*>"
local closeLi           = "</li%s*>"
local multiNewline      = "%s*\n%s*\n%s*\n+%s*"
local tableBlock        = "<table.-</table>"
local trBlock           = "<tr.-</tr>"
local tableCell         = "<(t[dh])[^>]*>(.-)</%1>"
local simpleAnyTag      = "<[^>]+>"
local imgTag            = "(<img.-/?>)"
local imgAltAttrDouble  = [[alt%s*=%s*"([^"]*)"]]
local imgAltAttrSingle  = [[alt%s*=%s*'([^']*)']]
local anyThTag          = "<th"

-- Jsoup already decodes HTML entities but I'm using pattern matching
-- because I'm a dumbass, so enjoy it :)
local htmlEntities = {
	-- Basic Entities
	["&nbsp;"] = " ", ["&amp;"] = "&", ["&quot;"] = "\"", ["&apos;"] = "'", ["&lt;"] = "<", ["&gt;"] = ">",

	-- Copyright and Trademark
	["&copy;"] = "©", ["&reg;"] = "®", ["&trade;"] = "™",

	-- Currency
	["&cent;"] = "¢", ["&pound;"] = "£", ["&euro;"] = "€", ["&yen;"] = "¥", ["&curren;"] = "¤",

	-- Math Operators
	["&times;"] = "×", ["&divide;"] = "÷",

	-- ISO-8859-1 Symbols
	["&iexcl;"] = "¡", ["&brvbar;"] = "¦", ["&sect;"] = "§", ["&uml;"] = "¨", ["&ordf;"] = "ª", ["&laquo;"] = "«",
	["&not;"] = "¬", ["&macr;"] = "¯", ["&deg;"] = "°", ["&plusmn;"] = "±", ["&sup2;"] = "²", ["&sup3;"] = "³",
	["&acute;"] = "´", ["&micro;"] = "µ", ["&para;"] = "¶", ["&cedil;"] = "¸", ["&sup1;"] = "¹", ["&ordm;"] = "º",
	["&raquo;"] = "»", ["&frac14;"] = "¼", ["&frac12;"] = "½", ["&frac34;"] = "¾", ["&iquest;"] = "¿",

	-- Math Symbols
	["&forall;"] = "∀", ["&part;"] = "∂", ["&exist;"] = "∃", ["&empty;"] = "∅", ["&nabla;"] = "∇", ["&isin;"] = "∈",
	["&notin;"] = "∉", ["&ni;"] = "∋", ["&prod;"] = "∏", ["&sum;"] = "∑", ["&minus;"] = "−", ["&lowast;"] = "∗",
	["&radic;"] = "√", ["&prop;"] = "∝", ["&infin;"] = "∞", ["&ang;"] = "∠", ["&and;"] = "∧", ["&or;"] = "∨",
	["&cap;"] = "∩", ["&cup;"] = "∪", ["&int;"] = "∫", ["&there4;"] = "∴", ["&sim;"] = "∼", ["&cong;"] = "≅",
	["&asymp;"] = "≈", ["&ne;"] = "≠", ["&equiv;"] = "≡", ["&le;"] = "≤", ["&ge;"] = "≥", ["&sub;"] = "⊂",
	["&sup;"] = "⊃", ["&nsub;"] = "⊄", ["&sube;"] = "⊆", ["&supe;"] = "⊇", ["&oplus;"] = "⊕", ["&otimes;"] = "⊗",
	["&perp;"] = "⊥", ["&sdot;"] = "⋅",

	-- Greek Letters (Uppercase)
	["&Alpha;"] = "Α", ["&Beta;"] = "Β", ["&Gamma;"] = "Γ", ["&Delta;"] = "Δ", ["&Epsilon;"] = "Ε", ["&Zeta;"] = "Ζ",
	["&Eta;"] = "Η", ["&Theta;"] = "Θ", ["&Iota;"] = "Ι", ["&Kappa;"] = "Κ", ["&Lambda;"] = "Λ", ["&Mu;"] = "Μ",
	["&Nu;"] = "Ν", ["&Xi;"] = "Ξ", ["&Omicron;"] = "Ο", ["&Pi;"] = "Π", ["&Rho;"] = "Ρ", ["&Sigma;"] = "Σ",
	["&Tau;"] = "Τ", ["&Upsilon;"] = "Υ", ["&Phi;"] = "Φ", ["&Chi;"] = "Χ", ["&Psi;"] = "Ψ", ["&Omega;"] = "Ω",

	-- Greek Letters (Lowercase)
	["&alpha;"] = "α", ["&beta;"] = "β", ["&gamma;"] = "γ", ["&delta;"] = "δ", ["&epsilon;"] = "ε", ["&zeta;"] = "ζ",
	["&eta;"] = "η", ["&theta;"] = "θ", ["&iota;"] = "ι", ["&kappa;"] = "κ", ["&lambda;"] = "λ", ["&mu;"] = "μ",
	["&nu;"] = "ν", ["&xi;"] = "ξ", ["&omicron;"] = "ο", ["&pi;"] = "π", ["&rho;"] = "ρ", ["&sigmaf;"] = "ς",
	["&sigma;"] = "σ", ["&tau;"] = "τ", ["&upsilon;"] = "υ", ["&phi;"] = "φ", ["&chi;"] = "χ", ["&psi;"] = "ψ",
	["&omega;"] = "ω", ["&thetasym;"] = "ϑ", ["&upsih;"] = "ϒ", ["&piv;"] = "ϖ",

	-- Miscellaneous
	["&OElig;"] = "Œ", ["&oelig;"] = "œ", ["&Scaron;"] = "Š", ["&scaron;"] = "š", ["&Yuml;"] = "Ÿ", ["&fnof;"] = "ƒ",

	-- Arrows
	["&larr;"] = "←", ["&rarr;"] = "→", ["&uarr;"] = "↑", ["&darr;"] = "↓",
	["&lArr;"] = "⇐", ["&rArr;"] = "⇒", ["&uArr;"] = "⇑", ["&dArr;"] = "⇓",
	["&harr;"] = "↔", ["&hArr;"] = "⇔",

	-- Typographic Symbols
	["&ndash;"] = "–", ["&mdash;"] = "—", ["&tilde;"] = "˜",
	["&lsquo;"] = "‘",  ["&rsquo;"] = "’", ["&circ;"] = "ˆ",
	["&ldquo;"] = "“",   ["&rdquo;"] = "”",
	["&bdquo;"] = "„", ["&dagger;"] = "†",
	["&Dagger;"] = "‡", ["&bull;"] = "•", ["&hellip;"] = "…",

	-- Common Accented Latin Characters
	["&Agrave;"] = "À", ["&Aacute;"] = "Á", ["&Acirc;"] = "Â", ["&Atilde;"] = "Ã", ["&Auml;"] = "Ä", ["&Aring;"] = "Å",
	["&AElig;"] = "Æ", ["&Ccedil;"] = "Ç", ["&Egrave;"] = "È", ["&Eacute;"] = "É", ["&Ecirc;"] = "Ê", ["&Euml;"] = "Ë",
	["&Igrave;"] = "Ì", ["&Iacute;"] = "Í", ["&Icirc;"] = "Î", ["&Iuml;"] = "Ï", ["&ETH;"] = "Ð", ["&Ntilde;"] = "Ñ",
	["&Ograve;"] = "Ò", ["&Oacute;"] = "Ó", ["&Ocirc;"] = "Ô", ["&Otilde;"] = "Õ", ["&Ouml;"] = "Ö", ["&Oslash;"] = "Ø",
	["&Ugrave;"] = "Ù", ["&Uacute;"] = "Ú", ["&Ucirc;"] = "Û", ["&Uuml;"] = "Ü", ["&Yacute;"] = "Ý", ["&THORN;"] = "Þ",
	["&szlig;"] = "ß", ["&agrave;"] = "à", ["&aacute;"] = "á", ["&acirc;"] = "â", ["&atilde;"] = "ã", ["&auml;"] = "ä",
	["&aring;"] = "å", ["&aelig;"] = "æ", ["&ccedil;"] = "ç", ["&egrave;"] = "è", ["&eacute;"] = "é", ["&ecirc;"] = "ê",
	["&euml;"] = "ë", ["&igrave;"] = "ì", ["&iacute;"] = "í", ["&icirc;"] = "î", ["&iuml;"] = "ï", ["&eth;"] = "ð",
	["&ntilde;"] = "ñ", ["&ograve;"] = "ò", ["&oacute;"] = "ó", ["&ocirc;"] = "ô", ["&otilde;"] = "õ", ["&ouml;"] = "ö",
	["&oslash;"] = "ø", ["&ugrave;"] = "ù", ["&uacute;"] = "ú", ["&ucirc;"] = "û", ["&uuml;"] = "ü", ["&yacute;"] = "ý",
	["&thorn;"] = "þ", ["&yuml;"] = "ÿ",

	-- Card Suits and Symbols
	["&hearts;"] = "♥", ["&diams;"] = "♦", ["&clubs;"] = "♣", ["&spades;"] = "♠",
	["&star;"] = "★", ["&check;"] = "✓", ["&cross;"] = "✗",

	-- Additional Math and Technical Symbols
	["&prime;"] = "′", ["&Prime;"] = "″",
	["&frasl;"] = "⁄", ["&weierp;"] = "℘",
	["&image;"] = "ℑ", ["&real;"] = "ℜ",
	["&alefsym;"] = "ℵ",

	-- Extra Space Characters
	["&ensp;"] = " ", ["&emsp;"] = " ", ["&thinsp;"] = " ",

	-- Control Characters
	["&zwj;"] = "\u{200D}", ["&zwnj;"] = "\u{200C}",
	["&lrm;"] = "\u{200E}", ["&rlm;"] = "\u{200F}",
}

---Ensures the input is a string, converting it if possible or raising an error.
---
---@param input any 
---@param funcName string Used for error reporting. The name of the section calling this function.
---@return string validatedString The validated string or an error :)
local function ensureString(input, funcName)
    funcName = funcName or "ensureString"

    if type(input) == "string" then
        return input
    end

    local success, result = pcall(tostring, input)
    if success and type(result) == "string" then
        return result
    end

    error(format(
        "unhtml(%s): expected a string or a value convertible to string, but got a '%s'.",
        funcName,
        type(input)
    ), 2)
end


---Ensures the input is a table, converting it if possible or raising an error.
---
---@param input any
---@param funcName string Used for error reporting. The name of the section calling this function.
---@return table validatedTable The validated table or an error :)
local function ensureTable(input, funcName)
    funcName = funcName or "ensureTable"

    if type(input) ~= "table" then
        error(format(
            "unhtml(%s): expected a table, but got '%s'. Ensure the input is in the correct format.",
            funcName,
            type(input)
        ), 2)
    end

    -- If the input is a table, return it as is
    return input
end

local trimWS = "^%s*(.-)%s*$"

---Trims whitespace from both ends.
---
---@param s string
---@return string modifiedInput
local function trim(s)
    s = ensureString(s, "trim")
    if s == "" then return "" end

    return match(s, trimWS)
end


local whitespace = "%s+"

---Collapses all sequences of whitespace characters in the input string into a single space.
---
---@param s string
---@return string modifiedText
---@return integer nReplacements
local function collapseWS(s)
    s = ensureString(s, "collapseWS")
    if s == "" then return "", 0 end

    return gsub(s, whitespace, " ")
end

---Removes all HTML comment tags from the input string.
---
---@param s string
---@return string modifiedInput
---@return integer nReplacements
local function removeComments(s)
    s = ensureString(s, "removeComments")
    if s == "" then return "", 0 end

    return gsub(s, htmlComment, "")
end

---Normalizes HTML tags in the input string by ensuring lowercase tags and attributes,
---and correctly formatting self-closing and closing tags.
---
---@param s string
---@return string modifiedInput
---@return integer nReplacements
local function normalizeTags(s)
    s = ensureString(s, "normalizeTags")
    if s == "" then return "", 0 end

    return gsub(s, anyTag, function(closing, tag, attributes, selfClosing)
        tag = lower(tag)

        if closing ~= "" then
            return "</" .. tag .. ">"
        else
            local attrText = ""
            if attributes and match(attributes, "%S") then
                local normalizedAttrs = gsub(attributes, htmlAttr, function(attr)
                    return lower(attr) .. "="
                end)

                attrText = " " .. trim(normalizedAttrs)
            end

            if selfClosing ~= "" then
                return "<" .. tag .. attrText .. "/>"
            else
                return "<" .. tag .. attrText .. ">"
            end
        end
    end
    )
end

---Removes special HTML tags (script, style, doctype) from the input string.
---
---@param s string
---@return string modifiedInput
---@return integer nReplacements
local function removeSpecialTags(s)
    s = ensureString(s, "removeSpecialTags")
    if s == "" then return "", 0 end

    local nTotal = 0
    local n

    s, n = gsub(s, scriptTag, "")
    nTotal = nTotal + n

    s, n = gsub(s, styleTag, "")
    nTotal = nTotal + n

    s, n = gsub(s, doctypeTag, "")
    nTotal = nTotal + n

    return s, nTotal
end

---Adds `<br>` tags before and after specified block tags in the input string to preserve text structure.
---
---@param s string
---@param blockTags table A table of block tags with associated before and after <br> counts. Each entry should be a table in the form `{tagName, beforeCount, afterCount}`.
---@return string modifiedInput
local function addTagBreaks(s, blockTags)
    s = ensureString(s, "addTagBreaks")
    if s == "" then return "" end
    ensureTable(blockTags, "addTagBreaks")

    -- Create a lookup table for faster tag access and to handle duplicates
    local tagLookup = {}
    for _, tagInfo in ipairs(blockTags) do
        local tag, before, after = tagInfo[1], tagInfo[2], tagInfo[3]
        tagLookup[tag] = {
            before = rep("<br>", before),
            after = rep("<br>", after)
        }
    end

    -- Collect all tag positions to avoid processing the same section multiple times
    local modifications = {}

    -- Process closing tags first (add breaks after)
    for tag, config in pairs(tagLookup) do
        local pattern = "</" .. tag .. ">"
        local startPos = 1

        while true do
            local tagPos = find(s, pattern, startPos, true)
            if not tagPos then break end

            local endPos = tagPos + #pattern - 1
            insert(modifications, {
                position = endPos + 1,
                content = config.after,
                type = "after"
            })

            startPos = endPos + 1
        end
    end

    -- Process opening tags (add breaks before)
    for tag, config in pairs(tagLookup) do
        if #config.before > 0 then
            local startPos = 1

            while true do
                local tagStart = find(s, "<" .. tag .. "[^>]*>", startPos)
                if not tagStart then break end

                local tagEnd = find(s, ">", tagStart)
                if not tagEnd then break end

                insert(modifications, {
                    position = tagStart,
                    content = config.before,
                    type = "before"
                })

                startPos = tagEnd + 1
            end
        end
    end

    -- Sort modifications in reverse order to avoid position shifts
    sort(modifications, function(a, b)
        return a.position > b.position
    end)

    -- Apply modifications
    for _, mod in ipairs(modifications) do
        if mod.type == "after" then
            s = sub(s, 1, mod.position - 1) .. mod.content .. sub(s, mod.position)
        else -- "before"
            s = sub(s, 1, mod.position - 1) .. mod.content .. sub(s, mod.position)
        end
    end

    return s
end


---Inserts `<br><br>` between `</div>` and `<p>` if no `<br>` tags are found between them.
---
---@param s string
---@return string modifiedText
---@return integer nReplacements
local function fixDivPBreaks(s)
    s = ensureString(s, "fixDivPBreaks")
    if s == "" then return "", 0 end

    return gsub(s, divP, function (whitespace)
        -- If there's a <br> already, return the original string
        if find(whitespace, brTag) then
            return "</div>" .. whitespace .. "<p>"
        else
            return "</div>" .. whitespace .. "<br><br><p>"
        end
    end)
end

---Removes all HTML tags from the input string except for those specified in the `allowedTags` table.
---
---@param s string
---@param allowedTags table A table of tag names that are allowed to remain in the string. Each entry is a string: `{"hr", "br"}`.
---@return string modifiedInput
local function removeUnallowedTags(s, allowedTags)
    s = ensureString(s, "removeUnallowedTags")
    if s == "" then return "" end
    ensureTable(allowedTags, "removeUnallowedTags")

    local result = ""
    local position = 1

    while position <= #s do
        -- Find the next opening angle bracket
        local tagStart = find(s, "<", position)
        if not tagStart then
            -- No more tags, add the rest of the string
            result = result .. sub(s, position)
            break
        end

        -- Add string up to the tag
        result = result .. sub(s, position, tagStart - 1)

        -- Find the closing angle bracket
        local tagEnd = find(s, ">", tagStart)
        if not tagEnd then
            -- Unclosed tag, treat as string
            result = result .. sub(s, tagStart)
            break
        end

        -- Extract the tag
        local tag = sub(s, tagStart, tagEnd)

        -- Check if it's a closing or opening tag 
        local tagName
        if match(tag, closeTag) then
            tagName = match(tag, closeTag)
        else
            tagName = match(tag, openTag)
        end

        -- Only keep the tag if it's allowed
        local keepTag = false
        for _, allowed in ipairs(allowedTags) do
            if tagName == allowed then
                keepTag = true
                break
            end
        end

        if keepTag then
            result = result .. tag
        end

        position = tagEnd + 1
    end

    return result
end

---Replaces `<hr>` tags with a line seperator.
---
---@param s string
---@param character string The character to be used as a separator. Defaults to ─.
---@param length integer The number of times the character will be repeated. Must be positive. Defaults to 10.
---@return string modifiedInput
---@return integer nReplacements
local function formatHrTags(s, character, length)
    s = ensureString(s, "formatHrTags")
    if s == "" then return "", 0 end

    character = character or "─"
    length = max(1, tonumber(length) or 10)

    local separator = rep(character, length)

    return gsub(s, hrTag, "<br><br>" .. separator .. "<br><br>")
end

---Replaces all newline characters in the input string with spaces.
---
---@param s string
---@return string modifiedText
---@return integer nReplacements
local function newlineToSpace(s)
    s = ensureString(s, "newlineToSpace")
    if s == "" then return "", 0 end

    return gsub(s, newline, " ")
end

---Partial support for HTML lists. Converts `<li>` tags to bullet points and removes `</li>` tags.
---Doesn't preserve nested/indented lists or ordered lists.
---
---@param s string
---@param character string The character to be used as the bullet point. Defaults to •.
---@return string modifiedInput
---@return integer nReplacements
local function formatLists(s, character)
    s = ensureString(s, "formatLists")
    if s == "" then return "", 0 end

    character = character or "•"

    local nTotal = 0
    local n

    -- Remove any extra whitespace after <br>
    s, n = gsub(s, brWS, "<br>")
    nTotal = nTotal + n

    -- If `<li>` is preceded by a <br>, just add a bullet
    s, n = gsub(s, brLi, "%1" .. character .. " ")
    nTotal = nTotal + n

    -- For opening `<li>` tags, add a bullet and line break
    s, n = gsub(s, openLi, "<br>" .. character .. " ")
    nTotal = nTotal + n

    -- Remove closing `</li>` tags
    s, n = gsub(s, closeLi, "")
    nTotal = nTotal + n

    return s, nTotal
end

---Replaces all `<br>` tags in the input string with newline characters.
---
---@param s string
---@return string modifiedInput
---@return integer nReplacements
local function brToNewlines(s)
    s = ensureString(s, "brToNewlines")
    if s == "" then return "", 0 end

    return gsub(s, brTag, "\n")
end

---Cleans up line formatting by trimming and collapsing whitespace on each line.
---Preserves line breaks and ensures consistent spacing within the text.
---
---@param s string
---@return string modifiedInput
local function cleanLines(s)
    s = ensureString(s, "cleanLines")
    if s == "" then return "" end

    local processedLines = {}

    for line in gmatch(s .. "\n", "(.-)\n") do
        local cleaned = trim(collapseWS(line))
        insert(processedLines, cleaned)
    end

    s = concat(processedLines, "\n")

    return s
end

---Limits consecutive newlines in a string to "\n\n"
---
---@param s string
---@return string modifiedInput
---@return integer nReplacements
local function limitNewlines(s)
    s = ensureString(s, "limitNewlines")
    if s == "" then return "", 0 end

    return gsub(s, multiNewline, "\n\n")
end

---Replaces image tags with their alt text. If an image has alt text, the format will be `[Image: <alt-text>]`.
---if no alt text is found, it will be replaced with `[Image]`.
---
---@param s string
---@return string modifiedInput
local function formatImages(s)
    s = ensureString(s, "formatImages")
    if s == "" then return "" end

    local lastPos = 1
    local processedChunks = {}

    local imgPos = 1
    while true do
        local imgStart, imgEnd, imgTagText = find(s, imgTag, imgPos)

        -- If no more images found, exit the loop
        if not imgStart then
            break
        end

        -- Add text before the image as it was
        insert(processedChunks, sub(s, lastPos, imgStart - 1))

        -- Extract alt attribute
        local alt = imgTagText:match(imgAltAttrDouble) or imgTagText:match(imgAltAttrSingle) or ""

        -- Replace the image tag with its alt text
        if alt ~= "" then
            insert(processedChunks, "[Image: " .. alt .. "]")
        else
            insert(processedChunks, "[Image]")
        end

        -- Move on to look for the next image
        lastPos = imgEnd + 1
        imgPos = imgEnd + 1
    end

    -- Add remaining text after last image
    insert(processedChunks, sub(s, lastPos))
    s = concat(processedChunks)

    return s
end

---Converts HTML table tags into a string table format with padded columns.
---Header rows are separated by a line of dashes.
---
---@param s string
---@return string modifiedInput
local function formatTables(s)
    s = ensureString(s, "formatTables")
    if s == "" then return "" end

    local lastPos = 1
    local tableChunks = {}

    local pos = 1
    while true do
        -- Find the next table
        local tableStart, tableEnd = find(s, tableBlock, pos)

        -- Add text before the table as it was
        if not tableStart then
            break
        end

        insert(tableChunks, sub(s, lastPos, tableStart - 1))

        -- Extract the table HTML
        local tableHTML = sub(s, tableStart, tableEnd)

        local rows = {}
        local isHeader = false
        local maxColumns = {}

        -- Pull out all rows and calculate the widest cell in each column
        for row in gmatch(tableHTML, trBlock) do
            local columns = {}
            local isHeaderRow = find(row, anyThTag) ~= nil
            if isHeaderRow then isHeader = true end

            -- Grab each <td> or <th> in the row
            for tag, content in gmatch(row, tableCell) do
                local raw = gsub(content, simpleAnyTag, "") -- Remove HTML tags
                local text = trim(collapseWS(raw))
                insert(columns, text)

                -- Update the max width for this column if needed
                maxColumns[#columns] = max(maxColumns[#columns] or 0, #text)
            end

            -- Only add the row if it has content
            if #columns > 0 then
                insert(rows, { columns = columns, isHeader = isHeaderRow })
            end
        end

        local outputLines = {}

        -- Format everything with padding
        for i, row in ipairs(rows) do
            local formattedRow = {}
            for j, text in ipairs(row.columns) do
                insert(formattedRow, text .. rep(" ", maxColumns[j] - #text))
            end
            insert(outputLines, concat(formattedRow, " | "))

            -- If it's a header row, add in a separator line after it
            if i == 1 and isHeader then
                local separator = {}
                for j = 1, #row.columns do
                    insert(separator, rep("-", maxColumns[j]))
                end
                insert(outputLines, concat(separator, " | "))
            end
        end

        -- Insert the formatted table into the result string
        insert(tableChunks, concat(outputLines, "\n") .. "\n\n")

        -- Move on to look for the next table
        lastPos = tableEnd + 1
        pos = tableEnd + 1
    end

    -- Add remaining text after last table
    insert(tableChunks, sub(s, lastPos))
    s = concat(tableChunks)

    return s
end

---Converts HTML entities in a string to their corresponding characters.
---Supports named, decimal, and hexadecimal HTML entities.
---
---@param s string
---@return string modifiedInput
---@return integer nReplacements
local function convertHTMLentities(s)
    s = ensureString(s, "convertHTMLentities")
    if s == "" then return "", 0 end

    local nTotal = 0
    local r

    s, r = gsub(s, htmlEntity, htmlEntities)
    nTotal = nTotal + r

    s, r = gsub(s, decimalEntity, function(num)
        local n = tonumber(num) or 0
        return n and utf8.char(n) or ""
    end)
    nTotal = nTotal + r

    s, r = gsub(s, hexadecimalEntity, function(hex)
        local n = tonumber(hex, 16)
        return n and utf8.char(n) or ""
    end)
    nTotal = nTotal + r

    return s, nTotal
end

---Quickly checks if a string contains specific patterns to determine if a function should be executed
---
---@param s string
---@param pattern string|table
---@return boolean shouldExecute True if the pattern(s) were found
local function shouldExecute(s, pattern)
    -- If input is not a string or empty, don't execute
    if type(s) ~= "string" or s == "" then
        return false
    end

    -- If pattern is a table of patterns, check each one
    if type(pattern) == "table" then
        for _, p in ipairs(pattern) do
            if find(s, p, 1, true) then
                return true
            end
        end
        return false
    end

    -- Check for single pattern
    return find(s, pattern, 1, true) ~= nil
end

--- Converts a string containing HTML to a strings representation with formatting.
--- Some decorations can be customized using the `config` table.
---
--- @param s string The HTML input string to be converted. If it's not a string, it will be converted into one if possible.
--- @param config table Configuration options to customize output:
---   - `hrTagSeparator` (string): Character(s) used for horizontal rule replacement (default: `"─"`).
---   - `hrTagSeparatorLength` (number): Length of the horizontal rule (default: `10`).
---   - `listBulletPointCharacter` (string): Bullet character for list items (default: `"•"`).
--- 
--- @example
--- ```lua
--- local config = {
---     hrTagSeparator = "─",
---     hrTagSeparatorLength = 10,
---     listBulletPointCharacter = "•"
--- }
--- 
--- -- Can also be a plain string with HTML tags.
--- local html = info:selectFirst(".description .hidden-content")
---
--- local output = HTMLToString(html, config)
--- print(output)
--- ```
local function HTMLToString(s, config)
    s = ensureString(s, "HTMLToString")
    if s == "" then return "" end

    -- Config
    config = config or {}
    local hrTagSeparator = config.hrTagSeparator or "─"
    local hrTagSeparatorLength = config.hrTagSeparatorLength or 10
    local listBulletPointCharacter = config.listBulletPointCharacter or "•"

    if shouldExecute(s, "<!--") then
        s = removeComments(s)
    end

    s = normalizeTags(s)

    if shouldExecute(s, {"<script", "<style", "<!doctype"}) then
        s = removeSpecialTags(s)
    end

    local blockTags = {
        -- {tag, brBefore, brAfter}
        {"address",   2, 2},
        {"article",   2, 2},
        {"aside",     2, 2},
        {"blockquote",2, 2},
        {"details",   2, 2},
        {"div",       2, 2},
        {"fieldset",  2, 2},
        {"figure",    2, 2},
        {"h1",        2, 2},
        {"h2",        2, 2},
        {"h3",        1, 2},
        {"h4",        1, 2},
        {"h5",        1, 2},
        {"h6",        1, 2},
        {"header",    2, 2},
        {"main",      2, 2},
        {"nav",       2, 2},
        {"p",         1, 2},
        {"pre",       2, 2},
        {"section",   2, 2},
        {"title",     0, 2},
    }

    -- Create a pattern to detect block tags quickly
    local blockTagPatterns = {}
    for _, tagInfo in ipairs(blockTags) do
        insert(blockTagPatterns, "<" .. tagInfo[1])
        insert(blockTagPatterns, "</" .. tagInfo[1])
    end

    if shouldExecute(s, blockTagPatterns) then
        s = addTagBreaks(s, blockTags)
    end

    -- Edge-case check
    if shouldExecute(s, "</div") and shouldExecute(s, "<p") then
        s = fixDivPBreaks(s)
    end

    local allowedTags = {"br", "hr", "li", "img", "table","tr",
                        "td", "th", "thead", "tbody", "tfoot"}
    s = removeUnallowedTags(s, allowedTags)

    if shouldExecute(s, {"<hr", "</hr"}) then
        s = formatHrTags(s, hrTagSeparator, hrTagSeparatorLength)
    end

    if shouldExecute(s, {"\r", "\n"}) then
        s = newlineToSpace(s)
    end

    if shouldExecute(s, {"<li", "</li"}) then
        s = formatLists(s, listBulletPointCharacter)
    end

    if shouldExecute(s, "<br") then
        s = brToNewlines(s)
    end

    s = cleanLines(s)

    if shouldExecute(s, "<img") then
        s = formatImages(s)
    end

    if shouldExecute(s, "<table") then
        s = formatTables(s)
    end

    if shouldExecute(s, "&") then
        s = convertHTMLentities(s)
    end

    s = limitNewlines(s)

    return trim(s)
end

return {
    ensureString = ensureString,
    ensureTable = ensureTable,
    trim = trim,
    collapseWS = collapseWS,
    removeComments = removeComments,
    normalizeTags = normalizeTags,
    removeSpecialTags = removeSpecialTags,
    addTagBreaks = addTagBreaks,
    fixDivPBreaks = fixDivPBreaks,
    removeUnallowedTags = removeUnallowedTags,
    formatHrTags = formatHrTags,
    newlineToSpace = newlineToSpace,
    formatLists = formatLists,
    brToNewlines = brToNewlines,
    cleanLines = cleanLines,
    limitNewlines = limitNewlines,
    formatImages = formatImages,
    formatTables = formatTables,
    convertHTMLentities = convertHTMLentities,
    shouldExecute = shouldExecute,
    HTMLToString = HTMLToString
}
