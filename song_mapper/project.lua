-- REAPER adapter. All project writes are confined to apply().
local model = require('song_mapper.model')
local codec = require('song_mapper.codec')
local M = {}
M.namespace = 'ReaperSongMapper'
M.reference = 'P_EXT:ReaperSongMapperRevision'

local function near(a, b)
  return type(a) == 'number' and type(b) == 'number' and math.abs(a - b) <= 0.000001
end

function M.new(api, project)
  local self = { r = api, project = project }
  return setmetatable(self, { __index = M })
end

function M:alive()
  return self.r.ValidatePtr(self.project, 'ReaProject*')
end

function M:revision()
  if not self:alive() then return nil end
  local _, value = self.r.GetSetMediaTrackInfo_String(
    self.r.GetMasterTrack(self.project), M.reference, '', false)
  return value or ''
end

function M:load()
  local revision = self:revision()
  if revision == nil then return nil, 'The original project has been closed.' end
  if revision == '' then return nil end
  local found, raw = self.r.GetProjExtState(self.project, M.namespace, 'revision:' .. revision)
  if found == 0 then return nil, 'Saved Song Mapper revision is missing. Apply is disabled.' end
  local saved, err = codec.decode(raw)
  if not saved or type(saved) ~= 'table' or saved.version ~= 1 then
    return nil, 'Cannot read saved Song Mapper data: ' .. (err or 'unsupported format')
  end
  err = model.validate(saved.document)
  if err then return nil, 'Invalid saved map: ' .. err end
  if type(saved.generated) ~= 'table' or type(saved.generated.tempos) ~= 'table'
    or type(saved.generated.regions) ~= 'table' or type(saved.generated.tempo_points) ~= 'string' then
    return nil, 'Saved map bookkeeping is invalid. Apply is disabled.'
  end
  return saved
end

function M:markers()
  local rows, index = {}, 0
  while true do
    local ok, region, position, finish, name, id, color = self.r.EnumProjectMarkers3(self.project, index)
    if ok == 0 then break end
    rows[#rows + 1] = { region = region, position = position, finish = finish,
      name = name, id = id, color = color }
    index = index + 1
  end
  return rows
end

function M:tempos()
  local rows = {}
  for i = 0, self.r.CountTempoTimeSigMarkers(self.project) - 1 do
    local ok, time, measure, beat, bpm, num, den, linear = self.r.GetTempoTimeSigMarker(self.project, i)
    assert(ok, 'Could not read tempo marker')
    rows[#rows + 1] = { time = time, measure = measure, beat = beat, bpm = bpm,
      numerator = num, denominator = den, linear = linear }
  end
  return rows
end

function M:tempo_points()
  -- Include point metadata (metronome patterns, flags, etc.), excluding envelope UI state.
  local env = self.r.GetTrackEnvelopeByName(self.r.GetMasterTrack(self.project), 'Tempo map')
  assert(env, 'Cannot access the tempo map envelope')
  local ok, chunk = self.r.GetEnvelopeStateChunk(env, '', false)
  assert(ok, 'Cannot read the tempo map envelope')
  local points = {}
  for line in chunk:gmatch('[^\r\n]+') do
    if line:match('^PT ') then points[#points + 1] = line end
  end
  return table.concat(points, '\n')
end

local function same_marker(a, b)
  return type(a) == 'table' and type(b) == 'table' and a.region == b.region
    and a.id == b.id and a.name == b.name and a.color == b.color
    and near(a.position, b.position) and near(a.finish, b.finish)
end

local function same_tempos(a, b)
  if #a ~= #b then return false end
  for i, x in ipairs(a) do
    local y = b[i]
    if type(y) ~= 'table' or not near(x.time, y.time) or not near(x.bpm, y.bpm)
      or x.measure ~= y.measure or not near(x.beat, y.beat)
      or x.numerator ~= y.numerator or x.denominator ~= y.denominator
      or x.linear ~= y.linear then return false end
  end
  return true
end

function M:conflict(saved)
  local tempos = self:tempos()
  if not saved then
    if #tempos > 1 or (#tempos == 1 and not near(tempos[1].time, 0)) then
      return 'This project already has a tempo map. Use a new project for Song Mapper.'
    end
    return
  end
  if not same_tempos(tempos, saved.generated.tempos)
    or self:tempo_points() ~= saved.generated.tempo_points then
    return 'The tempo map was changed outside Song Mapper. Undo that change before applying.'
  end
  local regions = {}
  for _, marker in ipairs(self:markers()) do
    if marker.region then regions[marker.id] = marker end
  end
  for _, expected in ipairs(saved.generated.regions) do
    if not same_marker(expected, regions[expected.id]) then
      return 'A Song Mapper region was moved, renamed, recolored, or deleted. Undo that change before applying.'
    end
  end
end

function M:guard()
  if not self:alive() then return 'The original project has been closed.' end
  if self.r.EnumProjects(-1) ~= self.project then return 'Switch back to this window’s project to apply.' end
  if self.r.GetPlayStateEx(self.project) ~= 0 then return 'Stop playback or recording before applying.' end
  if self.r.CountMediaItems(self.project) > 0 then
    return 'This project contains media items. Song Mapper is read-only after recording or importing media.'
  end
  local saved, err = self:load()
  if err then return err end
  return self:conflict(saved)
end

function M:apply(document, expected_revision)
  local plan, err = model.plan(document)
  if not plan then return nil, err end
  local ok, reason = pcall(self.guard, self)
  if not ok then return nil, 'Could not inspect this project: ' .. tostring(reason) end
  if reason then return nil, reason end
  if expected_revision ~= nil and self:revision() ~= expected_revision then
    return nil, 'The applied map changed (Undo/Redo or another window). Reload the applied map first.'
  end
  local r, p = self.r, self.project
  local saved = self:load()
  local previous_revision = self:revision()
  local before_markers, before_tempos, before_points = self:markers(), self:tempos(), self:tempo_points()
  local owned = {}
  if saved then
    for _, region in ipairs(saved.generated.regions) do owned[region.id] = true end
  end
  local revision = r.genGuid()
  local undo_name = 'Song Mapper: Apply song map [' .. revision .. ']'
  local wrote_reference, result = false, nil
  r.Undo_BeginBlock2(p)
  r.PreventUIRefresh(1)
  local success, failure = xpcall(function()
    -- Master-track P_EXT participates in Undo; SetProjExtState does not.
    -- Immutable revision payloads remain available for both Undo and Redo.
    assert(r.GetSetMediaTrackInfo_String(r.GetMasterTrack(p), M.reference, revision, true),
      'Could not write the map revision')
    wrote_reference = true
    for _, marker in ipairs(before_markers) do
      if marker.region and owned[marker.id] then
        assert(r.DeleteProjectMarker(p, marker.id, true), 'Could not remove an old region')
      end
    end
    for i = r.CountTempoTimeSigMarkers(p) - 1, 0, -1 do
      assert(r.DeleteTempoTimeSigMarker(p, i), 'Could not remove an old tempo marker')
    end
    for _, entry in ipairs(plan.entries) do
      assert(r.SetTempoTimeSigMarker(p, -1, -1, entry.start_measure, 0,
        entry.bpm, entry.numerator, entry.denominator, false), 'Could not create a tempo marker')
    end
    -- Tempo edits can move existing markers with REAPER's timebase. Keep unrelated
    -- markers and regions exactly where they were in absolute project time.
    for _, marker in ipairs(before_markers) do
      if not (marker.region and owned[marker.id]) then
        assert(r.SetProjectMarker3(p, marker.id, marker.region, marker.position,
          marker.finish, marker.name, marker.color), 'Could not preserve an unrelated marker')
      end
    end
    local created = {}
    for _, entry in ipairs(plan.entries) do
      local start, start_qn, _, num, den, bpm = r.TimeMap_GetMeasureInfo(p, entry.start_measure)
      local finish, end_qn = r.TimeMap_GetMeasureInfo(p, entry.end_measure)
      assert(near(start_qn, entry.start_qn) and near(end_qn, entry.end_qn)
        and near(start, entry.start_seconds) and near(finish, entry.end_seconds)
        and num == entry.numerator and den == entry.denominator and near(bpm, entry.bpm),
        'REAPER returned an unexpected measure boundary or tempo')
      local rgb = model.colors[entry.type]
      local color = r.ColorToNative(table.unpack(rgb)) | 0x1000000
      local id = r.AddProjectMarker2(p, true, start, finish, entry.name, -1, color)
      assert(id >= 0, 'Could not create region ' .. entry.name)
      created[#created + 1] = {region = true, position = start, finish = finish,
        name = entry.name, id = id, color = color}
    end
    assert(r.CountTempoTimeSigMarkers(p) == #plan.entries, 'Unexpected number of tempo markers')
    result = { version = 1, document = model.copy(document),
      generated = { regions = created, tempos = self:tempos(), tempo_points = self:tempo_points() } }
    local raw = codec.encode(result)
    assert(#raw <= 4000000, 'Saved map exceeds the storage limit')
    assert(r.SetProjExtState(p, M.namespace, 'revision:' .. revision, raw) > 0,
      'Could not save the song map')
    assert(not self:conflict(result), 'Generated map did not pass verification')
  end, debug.traceback)
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(p, undo_name, -1)
  r.UpdateTimeline()
  r.UpdateArrange()
  if success then return result end

  -- Undo only our own block, never an earlier user action. Restore metadata
  -- separately because extension state is deliberately outside REAPER Undo.
  if wrote_reference and r.Undo_CanUndo2(p) == undo_name then
    r.Undo_DoUndo2(p)
    -- A no-op undo checkpoint is optimized away by REAPER. Change a private
    -- recovery stamp so ordinary Redo cannot replay the partial failed map.
    r.Undo_BeginBlock2(p)
    r.GetSetMediaTrackInfo_String(r.GetMasterTrack(p),
      'P_EXT:ReaperSongMapperRecovery', revision, true)
    r.Undo_EndBlock2(p, 'Song Mapper: Recovered failed apply', -1)
  end
  r.SetProjExtState(p, M.namespace, 'revision:' .. revision, '')
  local restored_ok, restored = pcall(function()
    if self:revision() ~= previous_revision or not same_tempos(self:tempos(), before_tempos)
      or self:tempo_points() ~= before_points then return false end
    local now = self:markers()
    if #now ~= #before_markers then return false end
    for i, marker in ipairs(now) do if not same_marker(marker, before_markers[i]) then return false end end
    return true
  end)
  if restored_ok and restored then
    return nil, 'Apply failed; the previous map was restored.\n' .. tostring(failure)
  end
  return nil, 'Apply failed and automatic recovery could not be verified. Stop editing and reopen your last saved project.\n' .. tostring(failure)
end

return M
