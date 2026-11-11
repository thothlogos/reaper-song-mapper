-- Pure song data and musical-time calculations. No REAPER dependency.
local M = {}
M.VERSION = 1
M.types = { 'Intro', 'Verse', 'Pre-Chorus', 'Chorus', 'Bridge', 'Breakdown',
  'Solo', 'Interlude', 'Outro', 'Custom' }
M.denominators = { 1, 2, 4, 8, 16, 32, 64 }
M.colors = {
  Intro = {105, 175, 166}, Verse = {93, 156, 213}, ['Pre-Chorus'] = {153, 134, 213},
  Chorus = {232, 165, 77}, Bridge = {185, 124, 196}, Breakdown = {213, 111, 111},
  Solo = {205, 185, 94}, Interlude = {121, 181, 136}, Outro = {119, 151, 170},
  Custom = {156, 162, 174}, ['Count-in'] = {112, 119, 132},
}

function M.copy(value)
  if type(value) ~= 'table' then return value end
  local result = {}
  for k, v in pairs(value) do result[k] = M.copy(v) end
  return result
end

function M.new()
  return { version = M.VERSION, count_in = 2, next_id = 1, sections = {} }
end

function M.add(doc, source)
  source = source or doc.sections[#doc.sections] or {}
  local section = { id = doc.next_id, type = source.type or 'Verse',
    label = source.label or '', measures = source.measures or 4,
    bpm = source.bpm or 120, numerator = source.numerator or 4,
    denominator = source.denominator or 4 }
  doc.next_id = doc.next_id + 1
  doc.sections[#doc.sections + 1] = section
  return section
end

function M.duplicate(doc, index)
  local section = M.add(doc, assert(doc.sections[index]))
  table.remove(doc.sections)
  table.insert(doc.sections, index + 1, section)
  return section
end

function M.move(doc, index, delta)
  local dest = index + delta
  if dest < 1 or dest > #doc.sections then return index end
  doc.sections[index], doc.sections[dest] = doc.sections[dest], doc.sections[index]
  return dest
end

function M.label(section)
  if section.type == 'Custom' then return (section.label or ''):match('^%s*(.-)%s*$') end
  return section.type
end

local function integer(n, min, max)
  return type(n) == 'number' and n == math.floor(n) and n >= min and n <= max
end
local function contains(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

function M.validate(doc)
  if type(doc) ~= 'table' or doc.version ~= M.VERSION then return 'Unsupported song document version.' end
  if not integer(doc.count_in, 0, 10000) then return 'Count-in must be a whole number from 0 to 10,000.' end
  if type(doc.sections) ~= 'table' or #doc.sections == 0 then return 'Add at least one section.' end
  if #doc.sections > 1000 then return 'A map can contain at most 1,000 sections.' end
  local seen, largest, total = {}, 0, doc.count_in
  for i, s in ipairs(doc.sections) do
    local prefix = 'Section ' .. i .. ': '
    if type(s) ~= 'table' then return prefix .. 'invalid section.' end
    if not integer(s.id, 1, 1000000000) or seen[s.id] then return prefix .. 'invalid or duplicate section ID.' end
    seen[s.id], largest = true, math.max(largest, s.id)
    if not contains(M.types, s.type) then return prefix .. 'choose a section type.' end
    if type(s.label) ~= 'string' then return prefix .. 'invalid label.' end
    local label = M.label(s)
    if #label == 0 or #label > 120 or label:find('%c') then
      return prefix .. 'enter a label of 1–120 bytes without control characters.'
    end
    if not integer(s.measures, 1, 10000) then return prefix .. 'measures must be a whole number from 1 to 10,000.' end
    if type(s.bpm) ~= 'number' or s.bpm ~= s.bpm or s.bpm < 1 or s.bpm > 960 then
      return prefix .. 'BPM must be a number from 1 to 960.'
    end
    if not integer(s.numerator, 1, 64) or not contains(M.denominators, s.denominator) then
      return prefix .. 'use a numerator from 1 to 64 and a denominator of 1, 2, 4, 8, 16, 32, or 64.'
    end
    total = total + s.measures
  end
  if total > 1000000 then return 'A map can contain at most 1,000,000 measures.' end
  if not integer(doc.next_id, largest + 1, 1000000001) then return 'Invalid next section ID.' end
end

function M.plan(doc)
  local err = M.validate(doc)
  if err then return nil, err end
  local totals, counts, entries = {}, {}, {}
  for _, s in ipairs(doc.sections) do
    local label = M.label(s)
    totals[label] = (totals[label] or 0) + 1
  end
  local measure, qn, seconds = 0, 0, 0
  local function append(s, label, kind, bars)
    local length_qn = bars * s.numerator * 4 / s.denominator
    local duration = length_qn * 60 / s.bpm
    entries[#entries + 1] = { id = s.id, name = label, type = kind, measures = bars,
      start_measure = measure, end_measure = measure + bars,
      start_qn = qn, end_qn = qn + length_qn,
      start_seconds = seconds, end_seconds = seconds + duration,
      bpm = s.bpm, numerator = s.numerator, denominator = s.denominator }
    measure, qn, seconds = measure + bars, qn + length_qn, seconds + duration
  end
  if doc.count_in > 0 then append(doc.sections[1], 'Count-in', 'Count-in', doc.count_in) end
  for _, s in ipairs(doc.sections) do
    local label = M.label(s)
    counts[label] = (counts[label] or 0) + 1
    local name = totals[label] > 1 and (label .. ' ' .. counts[label]) or label
    append(s, name, s.type, s.measures)
  end
  return { entries = entries, measures = measure, quarter_notes = qn, seconds = seconds }
end

function M.example()
  local doc = M.new()
  for _, row in ipairs({{'Verse', 4, 110}, {'Chorus', 2, 120}, {'Verse', 4, 110},
    {'Chorus', 2, 120}, {'Bridge', 4, 120}}) do
    M.add(doc, {type = row[1], measures = row[2], bpm = row[3]})
  end
  return doc
end

return M
