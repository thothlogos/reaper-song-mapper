local model = require('song_mapper.model')
local Session = require('song_mapper.session')
local M = {}

local function duration(seconds)
  return string.format('%d:%05.2f', math.floor(seconds / 60), seconds % 60)
end

function M.run(r, I, project)
  local session = Session.new(project)
  session.document = session.document or model.new()
  local ctx = I.CreateContext('Song Mapper', I.ConfigFlags_NavEnableKeyboard)
  local running, close_requested, confirm_action = true, false, nil
  local status, guard, next_poll = '', nil, 0
  local project_name = r.GetProjectName(project.project)
  project_name = project_name ~= '' and project_name or 'Unsaved project'

  local function apply()
    local ok, err = session:apply()
    status = ok and 'Song map applied. Save your REAPER project to keep it.' or err
    next_poll = 0
    return ok
  end
  local function request(action)
    if session:dirty() then confirm_action = action
    elseif action == 'close' then running = false
    elseif action == 'reload' then session:reload(); status = ''
    elseif action == 'example' then session.document = model.example() end
  end
  local function combo(label, current, values)
    local result = current
    if I.BeginCombo(ctx, label, tostring(current)) then
      for _, value in ipairs(values) do
        if I.Selectable(ctx, tostring(value), value == current) then result = value end
        if value == current then I.SetItemDefaultFocus(ctx) end
      end
      I.EndCombo(ctx)
    end
    return result
  end
  local function field_int(label, value, width)
    I.SetNextItemWidth(ctx, width)
    local _, next_value = I.InputInt(ctx, label, value, 1, 4)
    return next_value
  end
  local function button(label, disabled, action)
    I.BeginDisabled(ctx, disabled)
    if I.Button(ctx, label) then action() end
    I.EndDisabled(ctx)
  end

  local function draw()
    if r.time_precise() >= next_poll then
      session:poll()
      local ok, result = pcall(project.guard, project)
      if ok then guard = result else guard = 'Cannot inspect project: ' .. tostring(result) end
      next_poll = r.time_precise() + 0.25
    end
    local alive = project:alive()
    local read_only = not alive or session.load_error ~= nil
      or (alive and r.CountMediaItems(project.project) > 0)
    local doc = session.document
    local preview, validation = model.plan(doc)
    local blocked = session.load_error or (session.stale and 'The applied map changed. Reload it before applying your draft.')
      or guard or validation
    I.SetNextWindowSize(ctx, 1040, 640, I.Cond_FirstUseEver)
    I.SetNextWindowSizeConstraints(ctx, 860, 420, 1800, 1400)
    local visible, open = I.Begin(ctx, 'Song Mapper', true,
      session:dirty() and I.WindowFlags_UnsavedDocument or I.WindowFlags_None)
    if not open then close_requested = true end
    if visible then
      I.Text(ctx, 'SONG MAPPER')
      I.SameLine(ctx)
      I.TextDisabled(ctx, project_name)
      I.TextWrapped(ctx, 'Build the song, then apply its regions and tempo changes together. BPM = quarter notes per minute.')
      I.Separator(ctx)
      I.BeginDisabled(ctx, read_only)
      doc.count_in = field_int('Count-in measures (0 = off)', doc.count_in, 120)
      I.SameLine(ctx)
      if I.Button(ctx, 'Add section') then model.add(doc) end
      I.SameLine(ctx)
      if I.Button(ctx, 'Load example') then request('example') end
      I.EndDisabled(ctx)
      I.SameLine(ctx)
      button('Reload applied map', not alive, function() request('reload') end)

      if preview then
        I.Text(ctx, string.format('%d song measures + %d count-in = %d total   |   Estimated duration %s',
          preview.measures - doc.count_in, doc.count_in, preview.measures, duration(preview.seconds)))
        if doc.count_in > 0 then
          local first = preview.entries[1]
          I.TextDisabled(ctx, string.format('Count-in: measures 1–%d, %g BPM, %d/%d',
            doc.count_in, first.bpm, first.numerator, first.denominator))
        end
      else I.TextDisabled(ctx, 'Add valid sections to preview measure ranges and duration.') end

      local entries = {}
      if preview then
        for _, entry in ipairs(preview.entries) do
          if entry.type ~= 'Count-in' then entries[entry.id] = entry end
        end
      end
      local available_w, available_h = I.GetContentRegionAvail(ctx)
      local table_h = math.max(130, available_h - 130)
      local flags = I.TableFlags_Borders | I.TableFlags_RowBg | I.TableFlags_ScrollY
        | I.TableFlags_Resizable | I.TableFlags_SizingStretchProp
      local operation
      if I.BeginTable(ctx, 'sections', 6, flags, available_w, table_h) then
        I.TableSetupColumn(ctx, 'Section', I.TableColumnFlags_WidthStretch, 2.0)
        I.TableSetupColumn(ctx, 'Measures', I.TableColumnFlags_WidthStretch, 1.15)
        I.TableSetupColumn(ctx, 'BPM (quarter notes)', I.TableColumnFlags_WidthStretch, 1.35)
        I.TableSetupColumn(ctx, 'Time signature', I.TableColumnFlags_WidthStretch, 1.1)
        I.TableSetupColumn(ctx, 'Measure range', I.TableColumnFlags_WidthStretch, 1.1)
        I.TableSetupColumn(ctx, 'Arrange', I.TableColumnFlags_WidthFixed, 166)
        I.TableSetupScrollFreeze(ctx, 0, 1)
        I.TableHeadersRow(ctx)
        for index, s in ipairs(doc.sections) do
          I.PushID(ctx, s.id)
          I.TableNextRow(ctx)
          I.TableSetColumnIndex(ctx, 0)
          I.BeginDisabled(ctx, read_only)
          I.SetNextItemWidth(ctx, -1)
          s.type = combo('##type', s.type, model.types)
          if s.type == 'Custom' then
            I.SetNextItemWidth(ctx, -1)
            local _, label = I.InputText(ctx, '##custom', s.label)
            s.label = label
          end
          local entry = entries[s.id]
          local rgb = model.colors[s.type]
          local color = (rgb[1] << 24) | (rgb[2] << 16) | (rgb[3] << 8) | 255
          I.TextColored(ctx, color, entry and entry.name or model.label(s))
          I.TableSetColumnIndex(ctx, 1)
          s.measures = field_int('##measures', s.measures, -1)
          I.TableSetColumnIndex(ctx, 2)
          I.SetNextItemWidth(ctx, -1)
          local _, bpm = I.InputDouble(ctx, '##bpm', s.bpm, 1, 5, '%.3f')
          s.bpm = bpm
          I.TableSetColumnIndex(ctx, 3)
          I.SetNextItemWidth(ctx, 42)
          local _, num = I.InputInt(ctx, '##numerator', s.numerator, 0)
          s.numerator = num
          I.SameLine(ctx, 0, 3); I.Text(ctx, '/'); I.SameLine(ctx, 0, 3)
          I.SetNextItemWidth(ctx, 53)
          s.denominator = combo('##denominator', s.denominator, model.denominators)
          I.TableSetColumnIndex(ctx, 4)
          I.Text(ctx, entry and string.format('%d–%d', entry.start_measure + 1, entry.end_measure) or '—')
          I.TableSetColumnIndex(ctx, 5)
          button('Up', index == 1, function() operation = {'move', index, -1} end)
          I.SameLine(ctx, 0, 4)
          button('Down', index == #doc.sections, function() operation = {'move', index, 1} end)
          if I.Button(ctx, 'Duplicate') then operation = {'duplicate', index} end
          I.SameLine(ctx, 0, 4)
          if I.Button(ctx, 'Delete') then operation = {'delete', index} end
          I.EndDisabled(ctx)
          I.PopID(ctx)
        end
        I.EndTable(ctx)
      end
      if operation then
        if operation[1] == 'move' then model.move(doc, operation[2], operation[3])
        elseif operation[1] == 'duplicate' then model.duplicate(doc, operation[2])
        else table.remove(doc.sections, operation[2]) end
      end
      -- Revalidate after edits in this frame, before enabling Apply.
      blocked = session.load_error or (session.stale and 'The applied map changed. Reload it before applying your draft.')
        or guard or model.validate(doc)
      I.Separator(ctx)
      button('Apply Song Map', blocked ~= nil, apply)
      I.SameLine(ctx)
      if I.Button(ctx, 'Close') then close_requested = true end
      if blocked then I.TextWrapped(ctx, blocked)
      elseif session:dirty() then I.TextDisabled(ctx, 'Unapplied changes — the REAPER timeline has not changed.')
      else I.TextDisabled(ctx, 'Ready. Enable REAPER’s metronome when you want to hear the click.') end
      if status ~= '' then I.TextWrapped(ctx, status) end

      if close_requested then request('close'); close_requested = false end
      if confirm_action then I.OpenPopup(ctx, 'Unapplied changes') end
      if I.BeginPopupModal(ctx, 'Unapplied changes', nil, I.WindowFlags_AlwaysAutoResize) then
        if confirm_action == 'close' then
          I.Text(ctx, 'Apply your draft before closing Song Mapper?')
          button('Apply', blocked ~= nil, function()
            if apply() then running = false; confirm_action = nil; I.CloseCurrentPopup(ctx) end
          end)
          I.SameLine(ctx)
          if I.Button(ctx, 'Discard') then running = false; confirm_action = nil; I.CloseCurrentPopup(ctx) end
        else
          I.Text(ctx, 'Discard this draft and ' .. (confirm_action == 'reload' and 'reload the applied map?' or 'load the example?'))
          if I.Button(ctx, 'Discard draft') then
            if confirm_action == 'reload' then session:reload() else session.document = model.example() end
            confirm_action = nil; status = ''; I.CloseCurrentPopup(ctx)
          end
        end
        I.SameLine(ctx)
        if I.Button(ctx, 'Cancel') then confirm_action = nil; I.CloseCurrentPopup(ctx) end
        if blocked and confirm_action == 'close' then I.TextWrapped(ctx, blocked) end
        I.EndPopup(ctx)
      end
      I.End(ctx)
    elseif close_requested then request('close'); close_requested = false end
  end

  local function loop()
    local ok, err = xpcall(draw, debug.traceback)
    if not ok then
      r.ShowMessageBox('Song Mapper stopped:\n' .. tostring(err), 'Song Mapper', 0)
      return
    end
    if running then r.defer(loop) end
  end
  r.defer(loop)
end

return M
