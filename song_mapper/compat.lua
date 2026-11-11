-- Minimum version and capability checks; deliberately no maximum REAPER version.
local M = {}
M.minimum = '7.82'
M.required = {
  'APIExists', 'GetAppVersion', 'EnumProjects', 'ValidatePtr', 'GetMasterTrack',
  'GetSetMediaTrackInfo_String', 'GetProjExtState', 'SetProjExtState',
  'EnumProjectMarkers3', 'CountTempoTimeSigMarkers', 'GetTempoTimeSigMarker',
  'GetTrackEnvelopeByName', 'GetEnvelopeStateChunk', 'GetPlayStateEx', 'CountMediaItems',
  'genGuid', 'Undo_BeginBlock2', 'Undo_EndBlock2', 'Undo_CanUndo2', 'Undo_DoUndo2',
  'PreventUIRefresh', 'DeleteProjectMarker', 'DeleteTempoTimeSigMarker',
  'SetTempoTimeSigMarker', 'SetProjectMarker3', 'TimeMap_GetMeasureInfo',
  'ColorToNative', 'AddProjectMarker2', 'UpdateTimeline', 'UpdateArrange',
  'GetProjectName', 'GetResourcePath', 'AddRemoveReaScript', 'ShowMessageBox',
  'defer', 'time_precise',
}

function M.supports(version)
  if type(version) ~= 'string' then return false end
  local major, minor = version:match('^(%d+)%.(%d+)')
  major, minor = tonumber(major), tonumber(minor)
  return major ~= nil and (major > 7 or (major == 7 and minor >= 82))
end

function M.check(api)
  if not M.supports(api.GetAppVersion()) then
    return 'Song Mapper requires REAPER 7.82 or newer. Installed version: ' .. tostring(api.GetAppVersion())
  end
  local missing = {}
  for _, name in ipairs(M.required) do
    -- Lua-only helpers such as defer are not extension API registrations.
    if type(api[name]) ~= 'function' then missing[#missing + 1] = name end
  end
  if #missing > 0 then
    return 'This REAPER installation is missing required scripting APIs: ' .. table.concat(missing, ', ')
  end
end

return M
