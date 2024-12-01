-- midi import // convert midi to reflection patterns

local midim = {}

local ml = include 'lib/midilib'

local STEP_RES = 64 -- nishos reflection runs at 64ppqn
local tick_res = 0

local t = {} -- temp storage for pattern data
t.count = 0
t.step = 0
t.event = {}
t.endpoint = 0

local midi_files = {}
local midi_dir = ""
local active_bank = 0
local active_pattern = 0

local meter_values = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}


--------- utilities ----------
local function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
end

function copy_to_slot(ptn, bank, beats)
  local i = math.floor(ptn) -- some wonky stuff going on here... callback messes with first arg. why?
  p[i].count[bank] = t.count
  p[i].event[bank] = deep_copy(t.event)
  p[ptn].endpoint[bank] = beats * STEP_RES
  p[i].endpoint_init[bank] = beats * STEP_RES
  -- get bar and meter values
  if ((p[i].endpoint[bank] % STEP_RES == 0) and (p[i].endpoint[bank] >= (STEP_RES * 2))) then
    p[i].manual_length[bank] = false
    -- calc values
    local num_beats = (p[i].endpoint[bank] / STEP_RES)
    local current_meter = p[i].meter[bank]
    local bar_count = num_beats / (current_meter * 4)
    -- check bar-size
    if bar_count % 1 == 0 then
      p[i].barnum[bank] = bar_count
    else
      -- get closest fit
      local n = p[i].endpoint[bank] > (STEP_RES * 2) and 2 or 1
      for i = n, #meter_values do
        local new_meter = meter_values[i]
        local new_count = num_beats / (new_meter * 4)
        if new_count % 1 == 0 then
          p[i].barnum[bank] = new_count
          p[i].meter[bank] = new_meter
          break
        end
      end
    end
  else
    p[i].manual_length[bank] = true
  end
  print("copied to pattern "..i.." bank "..bank, "num beats: "..beats)
end

-- set directory and populate table with filenames
function get_files(filename)
  local dir = filename:match("(.*/)")
  local files = util.scandir(dir)
  local list = {}
  for i = 1, #files do
    if files[i]:match("^.+(%..+)$") == ".mid" then
      table.insert(list, files[i])
    end
  end
  return dir, list
end

-- extract specs from name. expected format: name_B4P3_16.mid
function get_specs(name)
  local bank = tonumber(name:match("[B%d+](%d+)"))
  local pattern = tonumber(name:match("[P%d+](%d+)"))
  local num_beats = tonumber(name:match("[_%d+](%d+)"))
  if name and pattern and num_beats then
    print(type(bank), type(pattern), type(num_beats))
    return bank, pattern, num_beats
  end
end

-- format event
function format_event(msg, note, vel)
  local msg = msg == "noteOn" and "note_on" or "note_off" -- transform string
  local e = {t = eKEYS, i = active_pattern, note = note, vel = vel, action = msg}
  return e
end

-- handler for note on/off messages
function parse_notes(msg, channel, note, velocity)
  local vel = math.floor(util.linlin(0, 1, 0, 127, velocity))
  local e = format_event(msg, note, vel)
  if not t.event[t.step] then
    t.event[t.step] = {}
  end
  table.insert(t.event[t.step], e)
  t.count = t.count + 1
end

-- handler for deltatime increments
function get_position(ticks)
  t.step = t.step + math.floor((ticks / tick_res) * STEP_RES)
end

-- callback function to grab tick resolution from header
function get_ticks(string, format, tracks, division)
  tick_res = division
end

-- callback to for conversion
function to_pattern(msg, ...)
  if msg == "deltatime" then
    get_position(...)
  elseif msg == "noteOn" or msg == "noteOff" then
    parse_notes(msg, ...)
  elseif msg == "endOfTrack" then
    copy_to_slot(active_pattern, active_bank, active_length)
  end
end

-- convert data
function midim.convert_all(filename)
  --local filename = filename or norns.state.data.."midi_files/testr/testr_P11_8B.mid"
  local dir, files = get_files(filename)
  for i = 1, #files do
    local ptn = tonumber(files[i]:match("[P%d+](%d+)"))
    local bank = tonumber(files[i]:match("[B%d+](%d+)"))
    local beats = tonumber(files[i]:match("[_%d+](%d+)"))
    if ptn and bank and beats then
      -- clear temp file
      t.count = 0
      t.step = 0
      t.event = {}
      t.endpoint = 0
      -- set current bank and pattern
      active_bank = bank
      active_pattern = ptn
      active_length = beats
      -- read midi and convert
      local file = assert(io.open(dir..files[i], "rb"))
      ml.processHeader(file, get_ticks)
      assert(file:seek("set"))
      ml.processTrack(file, to_pattern, 1)
      file:close()
    end
  end
  for i = 1, 8 do
    load_pattern_bank(i, 1)
  end
end

return midim