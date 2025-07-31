-- {"id": 23119210, "ver": "0.0.0", "libVer": "1.0.0", "author": "wasu-code"}

-- Source URL of the external Lua file you're working on to load dynamically  
-- ! **Change accordingly**
local URL = "http://192.168.1.23:5500/src/all/Reddit.lua"

-- NOTE: This development extension uses the same ID as the target script.
--       This means downloaded chapters will be saved in the same directory 
--       as the original plugin's chapters.

-- Fetch and load the remote script as a Lua chunk
local extensionScript = GETDocument(URL):wholeText()
local extension = load(extensionScript, "devExt")()

-- Override some fields (optional) so that they appear differently
local originalName = extension.name
extension.name = "!dev: " .. originalName

-- Return extension's (modified) table
return extension