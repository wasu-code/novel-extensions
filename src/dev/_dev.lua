-- {"id": 23119210, "ver": "0.0.0", "libVer": "1.0.0", "author": "wasu-code"}

-- Source URL of the external Lua file you're working on to load dynamically  
-- ! **Change accordingly** (eg. "http://ipv4:port/src/dev/extension-template.lua")
local URL = "https://raw.githubusercontent.com/wasu-code/novel-extensions/refs/heads/dev/src/dev/extension-template.lua"

-- NOTE: This development extension uses the same ID as the target script.
--       Implications:
--     ! Downloaded chapters will be stored in the same location 
--       as the original extension’s chapters.
--     ! Extension will use settings from the original extension, 
--       not this dev version.
--     → Overriding extension ID with 23119210 will fix the above, 
--       but will break hot reload (will require app restart).

-- Fetch and load the remote script as a Lua chunk
local extensionScript = Request(GET(URL)):body():string()
local chunkName = "devExt_" .. os.time() .. "_" .. math.random(1000)
local extension = load(extensionScript, chunkName)()

-- Override some fields (optional)
-- extension.id = 23119210 -- needed for downloading and settings to work properly, will break hot reload
local originalName = extension.name
extension.name = "!dev: " .. originalName

-- Return extension's (modified) table
return extension