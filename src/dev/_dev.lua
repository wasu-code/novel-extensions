-- {"id": 23119210, "ver": "0.0.0", "libVer": "1.0.0", "author": "wasu-code"}

-- Source URL of the external Lua file you're working on to load dynamically  
-- ! **Change accordingly** (eg. "http://ipv4:port/src/dev/extension-template.lua")
local URL = "http://192.168.1.23:5533/src/all/AnyWeb.lua"

-- NOTE: This development extension uses the same ID as the target script.
--       This means the following:
--     → Downloaded chapters will be saved in the same directory 
--       as the original extension's chapters.
--     → To take effect settings must be changed on the original extension,
--       not in !dev extension

-- Fetch and load the remote script as a Lua chunk
local extensionScript = GETDocument(URL):wholeText()
local extension = load(extensionScript, "devExt")()

-- Override some fields (optional) so that they appear differently
local originalName = extension.name
extension.name = "!dev: " .. originalName

-- Return extension's (modified) table
return extension