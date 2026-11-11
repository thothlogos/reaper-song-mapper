-- Runs inside REAPER after the macOS installer copies the runtime.
-- Verify the actual resource path and dependency API before registering anything.
local r = reaper
local root = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local function stop(message)
  r.ShowMessageBox(message, 'Song Mapper installation', 0)
  r.defer(function() end)
end
local compatibility_error = dofile(root .. 'song_mapper/compat.lua').check(r)
if compatibility_error then stop(compatibility_error); return end
local expected = r.GetResourcePath() .. '/Scripts/Song Mapper/'
if root ~= expected then
  stop('This REAPER instance uses a different resource folder. Run the installer with --resource-path pointing to the folder shown by Options > Show REAPER resource path.\n\nNo action was registered.')
  return
end
if not r.APIExists('ImGui_GetBuiltinPath') then
  stop('ReaImGui did not load. Restart REAPER, then run Finish Installation.lua again. If the problem remains, check the selected architecture and use the manual installation guide. No existing dependency was overwritten.')
  return
end
package.path = r.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ok, err = pcall(function() return require('imgui')('0.10') end)
if not ok then
  stop('ReaImGui 0.10 or newer is required. Update it through ReaPack (if managed there) or follow the manual installation guide, restart REAPER, then rerun Finish Installation.lua.\n\n' .. tostring(err))
  return
end
-- AddRemoveReaScript reuses the action for the same path, including repeated runs.
local id = r.AddRemoveReaScript(true, 0, root .. 'Song Mapper.lua', true)
if id == 0 then stop('Could not register Song Mapper. Load Song Mapper.lua from the Actions window manually.'); return end
r.ShowMessageBox('Song Mapper is installed and registered.\n\nTo add its optional toolbar button: right-click the main toolbar > Customize toolbar > Add > Script: Song Mapper.lua > Select/close > OK.\n\nThe editor will open when you dismiss this message.', 'Song Mapper installation complete', 0)
dofile(root .. 'Song Mapper.lua')
