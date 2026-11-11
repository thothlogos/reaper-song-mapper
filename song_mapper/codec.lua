-- Deterministic, length-prefixed data encoding. Never executes project content.
local M = {}

function M.encode(value)
  local kind = type(value)
  if kind == 'string' then return 's' .. #value .. ':' .. value end
  if kind == 'number' then
    assert(value == value and math.abs(value) < math.huge, 'Non-finite number')
    local text = string.format('%.17g', value)
    return 'n' .. #text .. ':' .. text
  end
  if kind == 'boolean' then return value and 'b1' or 'b0' end
  assert(kind == 'table', 'Unsupported value: ' .. kind)
  local keys = {}
  for key in pairs(value) do
    assert(type(key) == 'string' or type(key) == 'number', 'Invalid key')
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    if type(a) ~= type(b) then return type(a) < type(b) end
    return a < b
  end)
  local parts = {'t' .. #keys .. ':'}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = M.encode(key)
    parts[#parts + 1] = M.encode(value[key])
  end
  return table.concat(parts)
end

function M.decode(text)
  if type(text) ~= 'string' or #text > 4000000 then return nil, 'Saved map is too large or invalid.' end
  local pos, nodes = 1, 0
  local function parse(depth)
    nodes = nodes + 1
    assert(depth <= 20 and nodes <= 200000, 'Saved map exceeds complexity limit')
    local kind = text:sub(pos, pos)
    pos = pos + 1
    if kind == 'b' then
      local b = text:sub(pos, pos)
      pos = pos + 1
      assert(b == '0' or b == '1', 'Invalid boolean')
      return b == '1'
    end
    assert(kind == 't' or kind == 's' or kind == 'n', 'Invalid value tag')
    local finish = assert(text:find(':', pos, true), 'Missing length')
    local digits = text:sub(pos, finish - 1)
    assert(digits:match('^%d+$') and #digits <= 8, 'Invalid length')
    local size = tonumber(digits)
    pos = finish + 1
    if kind == 't' then
      assert(size <= 50000, 'Table too large')
      local result = {}
      for _ = 1, size do
        local key = parse(depth + 1)
        assert(type(key) == 'string' or type(key) == 'number', 'Invalid table key')
        assert(result[key] == nil, 'Duplicate table key')
        result[key] = parse(depth + 1)
      end
      return result
    end
    assert(pos + size - 1 <= #text, 'Truncated value')
    local value = text:sub(pos, pos + size - 1)
    pos = pos + size
    if kind == 's' then return value end
    value = assert(tonumber(value), 'Invalid number')
    assert(value == value and math.abs(value) < math.huge, 'Non-finite number')
    return value
  end
  local ok, result = pcall(parse, 0)
  if not ok then return nil, tostring(result) end
  if pos ~= #text + 1 then return nil, 'Trailing saved data.' end
  return result
end

return M
