-- @description Song Mapper - build song regions and tempo maps before recording
-- @version 1.0.0
-- @author Reaper Song Mapper
-- @about Requires REAPER 7.82+ and ReaImGui 0.10+ (available through ReaPack).

local root = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
package.path = root .. '?.lua;' .. package.path

local function message(text)
  reaper.ShowMessageBox(text, 'Song Mapper', 0)
end

local compatibility_error = require('song_mapper.compat').check(reaper)
if compatibility_error then
  message(compatibility_error)
  reaper.defer(function() end)
  return
end

if not reaper.APIExists('ImGui_GetBuiltinPath') then
  message('Song Mapper needs ReaImGui 0.10 or newer.\n\nIn Extensions > ReaPack > Browse packages, search for "ReaImGui", install "ReaImGui: ReaScript binding for Dear ImGui", then restart REAPER.\n\nSee the README next to this script for toolbar setup.')
  reaper.defer(function() end)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ok, ImGui = pcall(function() return require('imgui')('0.10') end)
if not ok then
  message('Song Mapper could not load ReaImGui 0.10. Update ReaImGui through ReaPack and restart REAPER.\n\n' .. tostring(ImGui))
  reaper.defer(function() end)
  return
end

local started, err = xpcall(function()
  local project = require('song_mapper.project').new(reaper, reaper.EnumProjects(-1))
  require('song_mapper.ui').run(reaper, ImGui, project)
end, debug.traceback)
if not started then
  message('Could not open Song Mapper:\n' .. tostring(err))
  reaper.defer(function() end)
end
