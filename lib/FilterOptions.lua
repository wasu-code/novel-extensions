-- {"ver":"0.0.1","author":"wasu-code","dep":[]}

--- FilterOptions aims to make managing Shosetsu filter values/labels easier.  
--- Each entry can be:
---   1. An empty table `{}` or `nil` → treated as explicit nil value
---   2. A map-style table `{ key = value }`  
---   3. Simple types like sting or number
---
--- Example: 
--- ```lua
--- local sort = FilterOptions({
---   nil,                     -- value: nil         label: "Default"
---   "newest",                -- value: "newest"    label: "newest"
---   "oldest",                -- value: "oldest"    label: "oldest"
---   { top_rated = "best" },  -- value: "top_rated" label: "best"
--- }, "Default")
--- ```
--- @param entries (string|number|boolean|table)[] List of entries (strings, numbers, booleans, tables(value=label))
--- @param nilLabel string|nil Optional label for nil / empty entries (default "Default")
local function FilterOptions(entries, nilLabel)
  nilLabel = nilLabel or "Default"

  local labels = {}
  local values = {}

  -- sentinel to represent explicit nil
  local NIL = {}

  local function addOption(value, label)
    values[#values + 1] = value
    labels[#labels + 1] = label
  end

  for i = 1, #entries do
    local entry = entries[i]

    if type(entry) ~= "table" and entry ~= nil then
      -- simple string, number, etc.
      addOption(entry, tostring(entry))  -- use tostring for label

    elseif entry == nil or next(entry) == nil then
      -- nil or empty table: {}, { nil }, { Anything = nil }
      addOption(NIL, nilLabel)

    else
      -- map-style table: { key = value }
      local value, label = next(entry)
      addOption(value, label)
    end
  end

  local map = {}

  --- Get label at zero-based index
  function map:labelOf(index)
    local l = labels[index+1]
    return l
  end

  --- Get value at zero-based index  
  --- For safe access, use `valueOfOrFirst`.
  --- @param index number Zero-based index (must be a valid number)
  --- @return any|nil value The value at the given index (can be nil if stored value is NIL)
  function map:valueOf(index)
    local v = values[index + 1]
    return v ~= NIL and v or nil
  end

  --- Safely get value at zero-based index.  
  --- Falls back to the first element if index is nil or invalid.
  --- @param index number|nil
  --- @return any|nil value The value at the given index (can be nil if stored value is NIL)
  function map:valueOfOrFirst(index)
    if type(index) ~= "number" then
      return self:valueOf(0)
    end
    return self:valueOf(index)
  end

  --- Get all labels as one-based table
  function map:labels()
    return labels
  end

  --- Get all values as one-based table
  function map:values()
    local out = {}
    for i = 1, #values do
      local v = values[i]
      out[i] = (v ~= NIL) and v or nil
    end
    return out
  end

  -- Metatable for [] operator (1-based indexing)
  setmetatable(map, {
    __index = function(t, k)
      if type(k) == "number" then
        -- normal Lua 1-based index
        local v = values[k]
        return v ~= NIL and v or nil
      else
        return rawget(map, k)
      end
    end
  })

  return map
end

return FilterOptions