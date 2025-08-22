-- {"id": 23119210, "ver": "0.0.0", "libVer": "1.0.0", "author": "wasu-code"}

-- Source URL of the external Lua file you're working on to load dynamically  
-- ! **Change accordingly** (eg. "http://ipv4:port/src/dev/extension-template.lua")
local URL = "https://raw.githubusercontent.com/wasu-code/shosetsu-extensions/refs/heads/dev/src/dev/extension-template.lua"

-- Fetch and load the remote script as a Lua chunk
local extensionScript = Request(GET(URL)):body():string()
local extension = load(extensionScript, "devExt")()

-- Override some fields (optional)
extension.id = 23119210 -- needed for downloading and settings to work properly

local originalName = extension.name
extension.name = "!dev: " .. originalName

-- Return extension's (modified) table
return extension