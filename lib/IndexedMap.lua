-- {"ver":"0.0.4","author":"wasu-code"}

--- A generic indexed map structure (supports 0-based or 1-based indexing)
---@param tbl table A table of key-value pairs
---@param startIndex number Number to start indexing from. Default is 1, but do use 0 for Shosetsu filters
local function IndexedMap(tbl, startIndex)
  startIndex = startIndex or 1 -- default is 1-based

  local self = {
    keys = {},
    values = {},
    map = {},
    startIndex = startIndex
  }

  for i, pair in ipairs(tbl) do
    local key, value = pair[1], pair[2]

    table.insert(self.keys, key)
    table.insert(self.values, value)
    self.map[key] = value
  end

  -- Methods
  function self:keyAt(i) return self.keys[i - self.startIndex + 1] end
  function self:valueAt(i) return self.values[i - self.startIndex + 1] end

  function self:getValue(key) return self.map[key] end

  function self:getIndexByKey(key)
    for i, k in ipairs(self.keys) do
      if k == key then
        return i + self.startIndex - 1
      end
    end
    return nil
  end

  function self:getIndexByValue(value)
    for i, v in ipairs(self.values) do
      if v == value then
        return i + self.startIndex - 1
      end
    end
    return nil
  end

  function self:getKeys() return self.keys end
  function self:getValues() return self.values end

  return self
end

return IndexedMap
