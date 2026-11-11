local model = require('song_mapper.model')
local codec = require('song_mapper.codec')
local Session = require('song_mapper.session')
local compat = require('song_mapper.compat')
local count = 0
local function test(name, fn)
  fn(); count = count + 1; print('PASS ' .. name)
end
local function near(a, b) assert(math.abs(a - b) < 1e-9, tostring(a) .. ' ~= ' .. tostring(b)) end
local function example() return model.example() end

test('supports 7.82 through 7.85 and later versions without an upper limit', function()
  for _, version in ipairs({'7.82', '7.83/macOS-arm64', '7.84.0', '7.85',
    '7.82.0_3385784u', '7.100', '8.0', '10.0', '7.85+dev1111'}) do
    assert(compat.supports(version), version)
  end
  for _, version in ipairs({'7.81', '7.9', '6.99', '', 'unknown'}) do
    assert(not compat.supports(version), version)
  end
end)
test('startup detects missing capabilities on newer REAPER versions', function()
  local api = {}
  for _, name in ipairs(compat.required) do api[name] = function() end end
  api.GetAppVersion = function() return '8.0' end
  assert(not compat.check(api))
  api.SetTempoTimeSigMarker = nil
  assert(compat.check(api):find('SetTempoTimeSigMarker'))
end)

test('example names and ranges without count-in', function()
  local doc = example(); doc.count_in = 0
  local p = assert(model.plan(doc))
  assert(p.measures == 16 and #p.entries == 5)
  local starts, ends = {0,4,6,10,12}, {4,6,10,12,16}
  local names = {'Verse 1','Chorus 1','Verse 2','Chorus 2','Bridge'}
  for i,e in ipairs(p.entries) do
    assert(e.start_measure == starts[i] and e.end_measure == ends[i] and e.name == names[i])
  end
  near(p.seconds, 32 * 60 / 110 + 32 * 60 / 120)
end)
test('count-in follows first section tempo and meter', function()
  local d = example(); d.sections[1].numerator = 6; d.sections[1].denominator = 8
  local p = assert(model.plan(d))
  assert(p.entries[1].name == 'Count-in' and p.entries[2].start_measure == 2)
  near(p.entries[1].end_seconds, 6 * 60 / 110)
end)
test('mixed 4/4, 6/8, 7/8 at quarter-note BPM', function()
  local d = model.new(); d.count_in = 0
  for _, s in ipairs({{4,4}, {6,8}, {7,8}}) do
    model.add(d, {type='Verse', measures=1, bpm=120, numerator=s[1], denominator=s[2]})
  end
  local p = assert(model.plan(d))
  near(p.entries[1].end_seconds, 2)
  near(p.entries[2].end_seconds, 3.5)
  near(p.entries[3].end_seconds, 5.25)
  near(p.quarter_notes, 10.5)
end)
test('fractional BPM preserves precision', function()
  local d = model.new(); model.add(d, {bpm=110.125}); d.count_in=0
  near(assert(model.plan(d)).seconds, 16 * 60 / 110.125)
end)
test('new sections inherit settings without reusing IDs', function()
  local d = model.new(); local a = model.add(d, {type='Bridge', measures=7, bpm=113.5, numerator=7, denominator=8})
  local b = model.add(d)
  assert(b.id ~= a.id and b.type == 'Bridge' and b.bpm == 113.5 and b.denominator == 8)
end)
test('duplicate inserts immediately after original', function()
  local d = example(); local old=d.sections[2].id
  local copy = model.duplicate(d, 1)
  assert(d.sections[2] == copy and d.sections[3].id == old and copy.id ~= d.sections[1].id)
end)
test('move preserves stable identity and renumbers by order', function()
  local d = example(); local id=d.sections[3].id
  model.move(d,3,-1); model.move(d,2,-1)
  assert(d.sections[1].id==id and assert(model.plan(d)).entries[2].name=='Verse 1')
  assert(model.move(d,1,-1)==1)
end)
test('deleting repeated section removes redundant numbering', function()
  local d = example(); table.remove(d.sections,3)
  assert(assert(model.plan(d)).entries[2].name=='Verse')
end)
test('custom names are trimmed and numbered', function()
  local d = model.new(); model.add(d,{type='Custom',label='  Riff A  '}); model.add(d)
  local p = assert(model.plan(d)); assert(p.entries[2].name=='Riff A 1' and p.entries[3].name=='Riff A 2')
end)

for _, case in ipairs({{'zero measures','measures',0}, {'fractional measures','measures',1.5},
  {'negative BPM','bpm',-1}, {'NaN BPM','bpm',0/0}, {'infinite BPM','bpm',math.huge},
  {'excessive BPM','bpm',961}, {'zero numerator','numerator',0}, {'invalid denominator','denominator',3},
  {'unknown type','type','Nope'}}) do
  test('rejects '..case[1],function() local d=example(); d.sections[1][case[2]]=case[3]; assert(model.validate(d)) end)
end
test('rejects empty map, invalid count-in, duplicate IDs and unsupported versions', function()
  assert(model.validate(model.new()))
  local d=example(); d.count_in=-1; assert(model.validate(d)); d.count_in=2
  d.sections[2].id=d.sections[1].id; assert(model.validate(d))
  d=example(); d.version=2; assert(model.validate(d))
end)
test('rejects blank and control-character custom labels',function()
  local d=example(); d.sections[1].type='Custom'; d.sections[1].label=' '; assert(model.validate(d))
  d.sections[1].label='bad\nlabel'; assert(model.validate(d))
end)
test('codec round-trips Unicode, quotes, fractions, nested tables, booleans', function()
  local value={document=example(),name='Écho "橋" :\\',flags={true,false},fraction=110.125}
  local encoded=codec.encode(value); local decoded=assert(codec.decode(encoded))
  assert(codec.encode(decoded)==encoded)
end)
test('codec never evaluates untrusted project content',function()
  for _, text in ipairs({'return os.execute("oops")','s99:short','t1:s1:xb2','n3:nan','t2:s1:xn1:1s1:xn1:2'}) do
    assert(not codec.decode(text))
  end
  assert(not codec.decode(codec.encode({})..'junk'))
end)

local function fake_project()
  local p = {rev='',saved=nil}
  function p:load() return self.saved end
  function p:revision() return self.rev end
  function p:apply(doc, expected)
    if expected ~= self.rev then return nil,'stale' end
    self.rev=self.rev..'x'; self.saved={document=model.copy(doc)}; return self.saved
  end
  return p
end
test('clean draft follows Undo/Redo revision changes', function()
  local p=fake_project(); local s=Session.new(p)
  s.document=example(); assert(s:dirty()); assert(s:apply()); assert(not s:dirty())
  p.rev=''; p.saved=nil; s:poll(); assert(#s.document.sections==0 and not s:dirty())
  p.rev='x'; p.saved={document=example()}; s:poll(); assert(#s.document.sections==5 and not s:dirty())
end)
test('dirty draft is retained and blocked after external revision change',function()
  local p=fake_project(); local s=Session.new(p); s.document=example()
  p.rev='external'; s:poll(); assert(s.stale and #s.document.sections==5)
  assert(not s:apply()); assert(s:reload()); assert(not s.stale)
end)
test('non-finite draft input stays editable for validation',function()
  local s=Session.new(fake_project()); s.document=example()
  s.document.sections[1].bpm=math.huge
  assert(s:dirty() and model.validate(s.document))
  s.document.sections[1].bpm=0/0
  assert(s:dirty() and model.validate(s.document))
end)
print(string.format('\n%d unit tests passed', count))
return count
