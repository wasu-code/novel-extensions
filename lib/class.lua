-- {"ver":"1.0.0","author":"wasu-code"}

--- Generic function to create class tables  
--- Creates a Lua "class" table with methods and callable constructor
--- @param methods table? Table containing initial methods (optional)
--- @return table A class-like table with `__index` and `__call`
local function makeClass(methods)
    local cls = methods or {}
    cls.__index = cls

    -- Make cls callable: cls(table) sets metatable
    setmetatable(cls, {
        __call = function(self, entry)
            setmetatable(entry, self)
            return entry
        end
    })

    return cls
end

return makeClass