-- Draft/applied-state coordination, independent of the UI toolkit.
local model = require('song_mapper.model')
local M = {}

local function equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= 'table' then return a == b end
  for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end

function M.new(project)
  local self = setmetatable({ project = project }, {__index = M})
  self:reload()
  return self
end

function M:reload()
  local saved, err = self.project:load()
  if err then self.load_error = err; return nil, err end
  self.document = saved and model.copy(saved.document) or model.new()
  self.baseline = model.copy(self.document)
  self.revision = self.project:revision()
  self.load_error, self.stale = nil, false
  return true
end

function M:dirty()
  -- Invalid numeric input is still an editable draft; serialization rejects it
  -- only after validation, never while deciding whether the window is dirty.
  return self.document and not equal(self.document, self.baseline)
end

function M:poll()
  local revision = self.project:revision()
  if revision == nil then return end
  if revision ~= self.revision then
    if self:dirty() then self.stale = true else self:reload() end
  else self.stale = false end
end

function M:apply()
  if self.load_error then return nil, self.load_error end
  if self.stale then return nil, 'Reload the applied map before applying this draft.' end
  local saved, err = self.project:apply(self.document, self.revision)
  if not saved then return nil, err end
  self.document = model.copy(saved.document)
  self.baseline = model.copy(self.document)
  self.revision = self.project:revision()
  return true
end

return M
