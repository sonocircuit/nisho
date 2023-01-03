-- nisho
--
-- a two voice
-- interval player,
-- keyboard and
-- pattern recorder
--
-- 1.0.1 @sonocircuit
-- llllllll.co/t/nisho
--
--
-- for docs go to:
-- >> github.com/sonocircuits
--    /nisho
--
-- or smb into:
-- >> code/nisho/docs
--
--

--engine.name = "Thebangs"
-- ;install https://github.com/catfact/thebangs

--local extensions = "/home/we/.local/share/SuperCollider/Extensions"
--engine.name = util.file_exists(extensions .. "/FormantTriPTR/FormantTriPTR.sc") and "FormantPerc" or nil

engine.name = "Moonshine"

halfsync = include "lib/halfsync"
pattern_time = include "lib/nisho_patterns"

--thebangs = include "lib/thebangs_engine"
moons = include "lib/moonshine"
--fperc = include "../lamination/lib/formantperc_engine"


mu = require "musicutil"

g = grid.connect()


-------- variables --------

-- locals
local load_pset = false
local pageNum = 1
local int_focus = 1
local key_focus = 1
local alt = false
local shift = false
local key_link = true
local mute_int = false
local mute_key = false
local transpose = false
local transpose_value = 0
local set_pattern = false
local overdub = false
local quantize = false
local flash_bar = false
local flash_beat = false
local ledfast = 1
local q_rate = 16

local v8_std_1 = 12
local v8_std_2 = 12
local env1_amp = 8
local env1_a = 0
local env1_d = 0.4
local env2_a = 0
local env2_d = 0.4
local env2_amp = 8

-- globals
pattern_len = 1


-------- tables --------

options = {} -- make this local?
options.output = {"thebangs", "midi", "crow 1+2", "crow 3+4", "crow ii jf"}
options.pattern_quant = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "1/32"}
options.quant_value = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
options.pattern_length = {"manual", "1bar", "2bars", "4bars", "8bars", "16bars", "32bars", "64bars"}
options.length_value = {0, 1, 2, 4, 8, 16, 32, 64}

local notes = {}
notes.oct_int = 0
notes.oct_key = 0
notes.last = 1
notes.home = 1
notes.played = 60
notes.root = {}
notes.key = {}
notes.ref = {}
for i = 1, 12 do
  notes.root[i] = nil
  notes.key[i] = nil
end

local voice = {}
for i = 1, 2 do -- 2 voices
  voice[i] = {}
  voice[i].output = 1
  voice[i].mute = false
end

local set_midi = {}
for i = 1, 2 do -- 2 voices
  set_midi[i] = {}
  set_midi[i].ch = 1
  set_midi[i].velocity = 100
  set_midi[i].length = 0.2
end

local set_crow = {}
for i = 1, 2 do -- 2 voices
  set_crow[i] = {}
  set_crow[i].jf_ch = i
  set_crow[i].jf_amp = 5
end

local m = {}
for i = 0, 2 do -- one global and 2 voices
  m[i] = midi.connect()
end


-------- scales --------

local scale_notes = {}

function build_scale()
  local root = params:get("root_note") % 12 + 24
  scale_notes = mu.generate_scale_of_length(root, params:get("scale"), 50)
  local num_to_add = 50 - #scale_notes
  for i = 1, num_to_add do
    table.insert(scale_notes, scale_notes[50 - num_to_add])
  end
end

function set_root()
  notes.home = tab.key(scale_notes, params:get("root_note"))
  for i = 1, 12 do
    if i == params:get("root_note") % 12 + 1 then
      notes.root[i] = true
    else
      notes.root[i] = false
    end
  end
end

function set_keys() -- set which keys to display
  for i = 1, 12 do
    if notelookup(i + 23) then
      notes.key[i] = true
    else
      notes.key[i] = false
    end
  end
end

function notelookup(note) -- check if note is in the selected scale
   for i = 1, 12 do
     for j = 0, 1 do -- iterate over two octaves
        if scale_notes[i] == note + j * 12 then
           return true
        end
      end
   end
   return false
end

function set_scale()
  build_scale()
  set_root()
  set_keys()
end


-------- voice settings --------

function set_voice_output()
  local count = 0
  for i = 1, 2 do
    voice[i].output = params:get("voice_out"..i)
    if voice[i].output == 5 then
      count = count + 1
    end
  end
  if count > 0 then
    crow.ii.jf.mode(1)
  else
    crow.ii.jf.mode(0)
  end
end


-------- midi --------

function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, i..": "..short_name)
  end
end

function midi_connect()
  build_midi_device_list()
end

function midi_disconnect()
  clock.run(
    function()
      clock.sleep(0.2)
      build_midi_device_list()
    end
  )
end

function clock.transport.start()
  -- do nothing for now
end

function clock.transport.stop()
  for i = 1, 8 do
    pattern[i]:stop()
  end
  dirtygrid = true
  all_notes_off()
end

function notes_off(i) -- per voice
  for j = 0, 127 do
    m[i]:note_off(j, 0, set_midi[i].ch)
  end
end

function all_notes_off() -- both voices
  for i = 1, 2 do
    for j = 0, 127 do
      m[i]:note_off(j, 0, set_midi[i].ch)
    end
  end
end


-------- pattern recording --------

local eINT = 1
local eKEY = 2
local eTRANSPOSE = 3
local ePATTERN = 4
local quant_event = {}

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
end

function event(e)
  if quantize then
    table.insert(quant_event, e)
  else
    if e.t ~= ePATTERN then
      event_record(e)
    end
    event_exec(e)
  end
end

function event_q_clock()
  while true do
    clock.sync(q_rate)
    if #quant_event > 0 then
      for k, e in pairs(quant_event) do
        if e.t ~= ePATTERN then event_record(e) end
        event_exec(e)
      end
      quant_event = {}
    end
  end
end

function set_pattern_len()
  pattern_len = options.length_value[params:get("pattern_length")] * clock.get_beat_sec() * 4
  --print("params set: "..pattern_len)
end

function clock.tempo_change_handler(tempo)
  -- can't use clock.get_beat_sec() here, otherwise offset by 1 (bug?)
  pattern_len = options.length_value[params:get("pattern_length")] * (60 / tempo) * 4
  -- if pattern of specified length has been recorded then adjust playback speed
  for i = 1, 8 do
    if pattern[i].bpm ~= nil then
      pattern[i].time_factor = pattern[i].bpm / tempo
    end
  end
end

-- exec function
function event_exec(e)
  if e.t == eINT then
    local idx = util.clamp(e.note + transpose_value, 1, #scale_notes)
    local note_num = scale_notes[idx]
    play_voice(e.i, note_num)
    notes.played = note_num
  elseif e.t == eKEY then
    local idx = util.clamp(e.note + transpose_value, 1, #scale_notes)
    local note_num = scale_notes[idx]
    play_voice(e.i, note_num)
    notes.played = note_num
  elseif e.t == eTRANSPOSE then
    local home_note = tab.key(scale_notes, params:get("root_note"))
    transpose_value = util.clamp(transpose_value + e.interval, -home_note + 1, #scale_notes - home_note)
    if e.interval == 0 then
      transpose_value = 0
    end
  elseif e.t == ePATTERN then
    if e.action == "stop" then
      pattern[e.i]:stop()
    elseif e.action == "start" then
      pattern[e.i]:start()
    elseif e.action == "rec_stop" then
      pattern[e.i]:rec_stop()
    elseif e.action == "rec_start" then
      pattern[e.i]:rec_start()
    elseif e.action == "clear" then
      pattern[e.i]:clear()
    elseif e.action == "overdub_on" then
      pattern[e.i]:set_overdub(1)
    elseif e.action == "overdub_off" then
      pattern[e.i]:set_overdub(0)
    end
  end
  dirtyscreen = true
end

pattern = {}
for i = 1, 8 do
  pattern[i] = pattern_time.new("pattern "..i)
  pattern[i].process = event_exec
end


-------- clock coroutines --------

function ledpulse_fast()
  ledfast = (ledfast % 8) + 4
  for i = 1, 8 do
    if pattern[i].overdub == 1 then
      dirtygrid = true
    end
  end
end

function barpulse()
  while true do
    clock.sync(4)
    flash_bar = true
    dirtygrid = true
    clock.run(
      function()
        clock.sleep(0.1)
        flash_bar = false
        dirtygrid = true
      end
    )
  end
end

function beatpulse()
  while true do
    clock.sync(1)
    flash_beat = true
    dirtygrid = true
    clock.run(
      function()
        clock.sleep(0.1)
        flash_beat = false
        dirtygrid = true
      end
    )
  end
end


-------- init funtion --------
function init()

  -- populate scale_names table
  scale_names = {}
  for i = 1, #mu.SCALES - 1 do
    table.insert(scale_names, string.lower(mu.SCALES[i].name))
  end

  -- populate scale intervals
  scale_intervals = {}
  for i = 1, #mu.SCALES - 1 do
    scale_intervals[i] = {table.unpack(mu.SCALES[i].intervals)}
  end

  build_midi_device_list()

  -- global params
  params:add_separator("global_settings", "global")
  params:add_option("scale", "scale", scale_names, 2)
  params:set_action("scale", function() set_scale() dirtygrid = true end)

  params:add_number("root_note", "root note", 24, 84, 60, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("root_note", function() set_scale() dirtygrid = true end)

  params:add_option("pattern_length", "pattern length", options.pattern_length , 2)
  params:set_action("pattern_length", function(idx) set_pattern_len() end)

  params:add_option("pattern_quant", "quantization", options.pattern_quant, 8)
  params:set_action("pattern_quant", function(idx) q_rate = options.quant_value[idx] * 4 end)

  -- voice params
  params:add_separator("voices", "voices")
  for i = 1, 2 do
    params:add_group("voice_"..i, "voice "..i, 10)

    -- output
    params:add_option("voice_out"..i, "output", options.output, 1)
    params:set_action("voice_out"..i, function() set_voice_output() build_menu() end)
    -- mute
    params:add_option("voice_mute"..i, "mute", {"off", "on"}, 1)
    params:set_action("voice_mute"..i, function(val) voice[i].mute = val == 2 and true or false dirtygrid = true end)

    -- midi params
    params:add_option("midi_device"..i, "midi device", midi_devices, 1)
    params:set_action("midi_device"..i, function(val) m[i] = midi.connect(val) end)

    params:add_number("midi_channel"..i, "midi channel", 1, 16, 1)
    params:set_action("midi_channel"..i, function(val) notes_off(i) set_midi[i].ch = val end)

    params:add_number("midi_velocity"..i, "velocity", 1, 127, 100)
    params:set_action("midi_velocity"..i, function(val) set_midi[i].velocity = val end)

    params:add_control("midi_length"..i, "note length", controlspec.new(0.01, 2, "lin", 0.01, 0.2, "s"))
    params:set_action("midi_length"..i, function(val) set_midi[i].length = val end)

    params:add_binary("midi_panic"..i, "don't panic", "trigger", 0)
    params:set_action("midi_panic"..i, function() notes_off(i) end)

    -- jf params
    params:add_option("jf_mode"..i, "jf_mode", {"vox", "note"}, 1)
    params:set_action("jf_mode"..i, function() build_menu() end)

    params:add_number("jf_voice"..i, "jf voice", 1, 6, i)
    params:set_action("jf_voice"..i, function(vox) set_crow[i].jf_ch = vox end)

    params:add_control("jf_amp"..i, "jf level", controlspec.new(0.1, 10, "lin", 0.1, 8.0, "vpp"))
    params:set_action("jf_amp"..i, function(level) set_crow[i].jf_amp = level end)

  end

  --params:add_separator("sound", "sound")

  -- engine params
  --params:add_group("thebangs", "thebangs", 9)
  --thebangs.synth_params()
  --thebangs.voice_params()
  --params:add_group("formant_params", "formantsub", 10)
  --fperc.params()
  moons.add_params()

  -- delay params
  params:add_group("delay", "delay", 8)
  halfsync.init()

  -- crow params
  params:add_separator("crow", "crow")

  params:add_group("out 1+2", 4)
  params:add_option("v8_type_1", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_1", function(x) if x == 1 then v8_std_1 = 12 else v8_std_1 = 10 end end)

  params:add_control("env1_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env1_amplitude", function(value) env1_amp = value end)

  params:add_control("env1_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env1_attack", function(value) env1_a = value end)

  params:add_control("env1_decay", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env1_decay", function(value) env1_d = value end)

  params:add_group("out 3+4", 4)
  params:add_option("v8_type_2", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_2", function(x) if x == 1 then v8_std_2 = 12 else v8_std_2 = 10 end end)

  params:add_control("env2_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env2_amplitude", function(value) env2_amp = value end)

  params:add_control("env2_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env2_attack", function(value) env2_a = value end)

  params:add_control("env2_decay", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env2_decay", function(value) env2_d = value end)

  -- pset callbacks
  params.action_write = function(filename, name, number)
    -- make directory
    os.execute("mkdir -p "..norns.state.data.."patterns/"..number.."/")
    -- make table
    local sesh_data = {}
    for i = 1, 8 do
      -- patterns
      sesh_data[i] = {}
      sesh_data[i].pattern_count = pattern[i].count
      sesh_data[i].pattern_time = pattern[i].time
      sesh_data[i].pattern_event = pattern[i].event
      sesh_data[i].pattern_time_factor = pattern[i].time_factor
      sesh_data[i].pattern_synced = pattern[i].synced
      sesh_data[i].pattern_sync_rate = pattern[i].sync_rate
      sesh_data[i].pattern_loop = pattern[i].loop
      sesh_data[i].pattern_count_in = pattern[i].count_in
      sesh_data[i].pattern_count_in_num = pattern[i].count_in_num
      sesh_data[i].pattern_bpm = pattern[i].bpm
    end
    -- save table
    tab.save(sesh_data, norns.state.data.."patterns/"..number.."/"..name.."_pattern.data")
    print("finished writing pset:'"..name.."'")
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      -- load sesh data
      sesh_data = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
      for i = 1, 8 do
        -- load patterns
        pattern[i].count = sesh_data[i].pattern_count
        pattern[i].time = {table.unpack(sesh_data[i].pattern_time)}
        pattern[i].event = {table.unpack(sesh_data[i].pattern_event)}
        pattern[i].time_factor = sesh_data[i].pattern_time_factor
        pattern[i].synced = sesh_data[i].pattern_synced
        pattern[i].sync_rate = sesh_data[i].pattern_sync_rate
        pattern[i].loop = sesh_data[i].pattern_loop
        pattern[i].count_in = sesh_data[i].pattern_count_in
        pattern[i].count_in_num = sesh_data[i].pattern_count_in_num
        pattern[i].bpm = sesh_data[i].pattern_bpm
        if pattern[i].bpm ~= nil then
          local newfactor = pattern[i].bpm / clock.get_tempo()
          pattern[i].time_factor = newfactor
        end
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
        if pattern[i].rec == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        end
      end
      dirtyscreen = true
      dirtygrid = true
      print("finished reading pset:'"..pset_id.."'")
    end
  end

  params.action_delete = function(filename, name, number)
    norns.system_cmd("rm -r "..norns.state.data.."patterns/"..number.."/")
    print("finished deleting pset:'"..name.."'")
  end

  -- bang params
  if load_pset then
    params:default()
  else
    params:bang()
  end

  -- set defaults
  notes.last = notes.home

  -- metros
  hardwareredrawtimer = metro.init(hardware_redraw, 1/30, -1)
  hardwareredrawtimer:start()
  dirtygrid = true

  screenredrawtimer = metro.init(screen_redraw, 1/15, -1)
  screenredrawtimer:start()
  dirtyscreen = true

  fastpulse = metro.init(ledpulse_fast, 0.1, -1)
  fastpulse:start()

  -- pattern clocks
  for i = 1, 8 do
    pattern[i]:init_clock()
  end

  -- hardware callbacks
  grid.add = drawgrid_connect
  midi.add = midi_connect
  midi.remove = midi_disconnect

end


-------- playback --------
local voice_num = 0
function play_voice(i, note_num)
  voice_num = voice_num % 4 + 1 + (i - 1) * 4
  -- engine output
  if not voice[i].mute then
    if voice[i].output == 1 then
      local freq = mu.note_num_to_freq(note_num)
      --engine.hz(freq)
      engine.trig(voice_num, freq)
    -- midi output
    elseif voice[i].output == 2 then
      m[i]:note_on(note_num, set_midi[i].velocity, set_midi[i].ch)
      clock.run(
        function()
          clock.sleep(set_midi[i].length)
          m[i]:note_off(note_num, 0, set_midi[i].ch)
        end
      )
    -- crow output 1+2
    elseif voice[i].output == 3 then
      crow.output[1].volts = ((note_num - 60) / v8_std_1)
      crow.output[2].action = "{ to(0, 0), to("..env1_amp..", "..env1_a.."), to(0, "..env1_d..", 'log') }"
      crow.output[2]()
    -- crow output 3+4
    elseif voice[i].output == 4 then
      crow.output[3].volts = ((note_num - 60) / v8_std_2)
      crow.output[4].action = "{ to(0, 0), to("..env2_amp..", "..env2_a.."), to(0, "..env2_d..", 'log') }"
      crow.output[4]()
    -- crow ii jf
    elseif voice[i].output == 5 then
      if params:get("jf_mode"..i) == 1 then
        crow.ii.jf.play_voice(set_crow[i].jf_ch, ((note_num - 60) / 12), set_crow[i].jf_amp)
      else
        crow.ii.jf.play_note(((note_num - 60) / 12), set_crow[i].jf_amp)
      end
    end
  end
end


-------- norns interface --------

function enc(n, d)
  if n == 1 then
    --
  elseif n == 2 then
    if shift then
      params:delta("scale", d)
    elseif set_pattern then
      params:delta("pattern_length", d)
      dirtygrid = true
    else
      --
    end
  elseif n == 3 then
    if shift then
      params:delta("root_note", d)
    elseif set_pattern then
      params:delta("pattern_quant", d)
      dirtygrid = true
    else
      --
    end
  end
  dirtyscreen = true
end

function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if n == 2 and z == 1 then
    transpose = not transpose
  elseif n == 3 and z == 1 then
    if not transpose then
      transpose_value = 0
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function redraw()
  screen.clear()
  if set_pattern then
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 18)
    screen.text_center("pattern length")
    screen.move(64, 44)
    screen.text_center("quantization")
    screen.level(4)
    screen.move(64, 30)
    screen.text_center(params:string("pattern_length"))
    screen.move(64, 56)
    screen.text_center(params:string("pattern_quant"))
  else
    local note_count = #scale_intervals[params:get("scale")] - 1
    for i = 1, note_count do
      screen.font_size(8)
      screen.level((notes.played - scale_notes[i]) % 12 == 0 and 15 or 2)
      screen.move(i * 14 + (-7 * note_count + 56), 36)
      screen.text_center(mu.note_num_to_name(scale_notes[i], false))
    end
    if shift then
      screen.level(8)
      screen.font_size(8)
      screen.move(8, 58)
      screen.text(params:string("scale"))
      screen.move(110, 58)
      screen.text(params:string("root_note"))
    end
    local semitone = scale_notes[tab.key(scale_notes, params:get("root_note")) + transpose_value] - params:get("root_note")
    if transpose then
      screen.level(4)
      screen.font_size(16)
      screen.move(64, 18)
      if semitone > 0 then
        screen.text_center("transpose +"..semitone)
      else
        screen.text_center("transpose "..semitone)
      end
    end
    if semitone ~= 0 and not transpose then
      screen.level(8)
      screen.font_size(16)
      screen.move(64, 18)
      if semitone > 0 then
        screen.text_center("+"..semitone)
      else
        screen.text_center(semitone)
      end
    end
  end
  screen.update()
end


-------- grid interface --------

function g.key(x, y, z)
  -- momentary key presses
  if y == 2 and x == 4 and not set_pattern then -- pattern overdub
    overdub = z == 1 and true or false
  end
  if y == 2 and x == 13 and not set_pattern then -- pattern alt
    alt = z == 1 and true or false
  end
  if y == 4 and x > 7 and x < 10 and not set_pattern then -- mute interval
    mute_int = z == 1 and true or false
  end
  --if y == 5 and x == 16 then -- set patterns
    --set_pattern = z == 1 and true or false
    --dirtyscreen = true
  --end
  -- when key is pressed do
  if z == 1 then
    if y == 1 then
      -- set interval_focus
      if x == 1 or x == 16 then
        local i = 1/15 * x + 14/15
        int_focus = math.floor(i)
      -- voice mute
      elseif x == 2 then
        local i = x - 1
        params:set("voice_mute"..i, voice[i].mute and 1 or 2)
      elseif x == 15 then
        local i = x - 13
        params:set("voice_mute"..i, voice[i].mute and 1 or 2)
      -- patterns
      elseif x > 4 and x < 13 then
        if set_pattern then
          local i = x - 4
          if pattern[i].sync_rate > 1 or pattern[i].count == 0 then
            pattern[i].synced = not pattern[i].synced
          end
        else
          local i = x - 4
          if alt then
            local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
            local e = {t = ePATTERN, i = i, action = "stop"} event(e)
            local e = {t = ePATTERN, i = i, action = "clear"} event(e)
          elseif overdub then
            if pattern[i].count == 0 then
              local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
            elseif pattern[i].rec == 1 then
              local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
              local e = {t = ePATTERN, i = i, action = "start"} event(e)
            elseif pattern[i].overdub == 1 then
              local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
            else
              local e = {t = ePATTERN, i = i, action = "overdub_on"} event(e)
            end
          elseif pattern[i].overdub == 1 then
            local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
          elseif pattern[i].rec == 1 then
            local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
            local e = {t = ePATTERN, i = i, action = "start"} event(e)
          elseif pattern[i].count == 0 then
            local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
          elseif pattern[i].play == 1 and pattern[i].overdub == 0 then
            local e = {t = ePATTERN, i = i, action = "stop"} event(e)
          else
            local e = {t = ePATTERN, i = i, action = "start"} event(e)
          end
        end
      end
    elseif y == 2 then
      -- set key focus
      if x == 1 or x == 16 then
        local i = 1/15 * x + 14/15
        key_focus = math.floor(i)
      elseif x > 4 and x < 13 and set_pattern then
        local i = x - 4
        if pattern[i].count_in_num == 1 then
          pattern[i].count_in_num = 4
        else
          pattern[i].count_in_num = 1
        end
      end
    elseif y == 3 then
      -- set pattern loop
      if x > 4 and x < 13 and set_pattern then
        local i = x - 4
        pattern[i].loop = not pattern[i].loop
      -- play home note
      elseif x > 7 and x < 10 and not set_pattern then
        local home_note = tab.key(scale_notes, params:get("root_note"))
        if not transpose then
          if not mute_int then
            local e = {t = eINT, i = int_focus, note = home_note} event(e)
          end
        else
          local e = {t = eTRANSPOSE, interval = 0} event(e)
        end
        notes.last = home_note
      end
    elseif y == 4 then
      -- interval octave up
      if x == 1 then
        notes.oct_int = util.clamp(notes.oct_int + 1, -3, 3)
      -- interval decrease
      elseif x > 3 and x < 8 and not set_pattern then
        local interval = x - 8
        local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
        if not transpose then
          if not mute_int then
            local e = {t = eINT, i = int_focus, note = new_note} event(e)
          end
        else
          local e = {t = eTRANSPOSE, interval = interval} event(e)
        end
        notes.last = new_note
      -- interval increase
      elseif x > 9 and x < 14 and not set_pattern then
        local interval = x - 9
        local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
        if not transpose then
          if not mute_int then
            local e = {t = eINT, i = int_focus, note = new_note} event(e)
          end
        else
          local e = {t = eTRANSPOSE, interval = interval} event(e)
        end
        notes.last = new_note
      -- toggle quantization
      elseif x == 16 then
        quantize = not quantize
        if quantize then
          quantizer = clock.run(event_q_clock)
          downbeat = clock.run(barpulse)
          beat = clock.run(beatpulse)
        else
          clock.cancel(quantizer)
          clock.cancel(downbeat)
          clock.cancel(beat)
        end
      end
    elseif y == 5 then
      -- interval octave down
      if x == 1 then
        notes.oct_int = util.clamp(notes.oct_int - 1, -3, 3)
      -- set pattern length
      elseif x > 4 and x < 13 and set_pattern then
          local val = x - 4
          params:set("pattern_length", val)
          dirtyscreen = true
      -- play last note
      elseif x > 7 and x < 10 and not set_pattern then
        if not transpose then
          if not mute_int then
            local e = {t = eINT, i = int_focus, note = notes.last} event(e)
          end
        else
          local octave = (#scale_intervals[params:get("scale")] - 1) * (x - 8 == 0 and -1 or 1)
          local e = {t = eTRANSPOSE, interval = octave} event(e)
        end
      elseif x == 16 then
        set_pattern = not set_pattern
        dirtyscreen = true
      end
    elseif y == 6 then
      -- set pattern quantization
      if x > 4 and x < 13 and set_pattern then
        local val = x - 4
        params:set("pattern_quant", val)
        dirtyscreen = true
      end
    -- key octave up
    elseif y == 7 and x == 1 then
      notes.oct_key = util.clamp(notes.oct_key + 1, -3, 3)
    -- toggle key link
    elseif y == 7 and x == 16 then
      key_link = not key_link
    -- play keys
    elseif (y == 7 or y == 8) and x > 2 and x < 15 then
      local new_note = (60 + x - 3) + (notes.oct_key + 8 - y) * 12
      if tab.key(scale_notes, new_note) ~= nil and not set_pattern then
        if not mute_key then
          local e = {t = eKEY, i = key_focus, note = tab.key(scale_notes, new_note)} event(e)
        end
        if key_link and not transpose then
          local octave = #scale_intervals[params:get("scale")] - 1
          notes.last = tab.key(scale_notes, new_note) + octave * notes.oct_int
        end
      end
    elseif y == 8 then
      -- key octave down
      if x == 1 then
        notes.oct_key = util.clamp(notes.oct_key - 1, -3, 3)
      -- toggle key mute
      elseif x == 16 then
        mute_key = not mute_key
      end
    end
  -- when key is released do
  elseif z == 0 then
    -- nothing for now
  end
  dirtygrid = true
end

function gridredraw()
  g:all(0)
  -- patterns
  g:led(4, 2, set_pattern and 0 or (overdub and 15 or 8))
  g:led(13, 2, set_pattern and 0 or (alt and 15 or 8)) -- alt
  g:led(16, 4, quantize and (flash_bar and 15 or (flash_beat and 10 or 7)) or 3) -- Q flash
  for i = 1, 8 do
    if set_pattern then
      g:led(i + 4, 1, pattern[i].synced and 10 or 4)
      g:led(i + 4, 2, pattern[i].count_in_num == 4 and 6 or 2)
      g:led(i + 4, 3, pattern[i].loop and 0 or 4)
      g:led(i + 4, 5, params:get("pattern_length") == i and 15 or 8)
      g:led(i + 4, 6, params:get("pattern_quant") == i and 15 or 4)
      --g:led(i + 4, 8, 2) -- TODO: pset load slots
    else
      if pattern[i].rec == 1 then
        g:led(i + 4, 1, 15)
      elseif pattern[i].overdub == 1 then
        g:led(i + 4, 1, ledfast)
      elseif pattern[i].play == 1 then
        g:led(i + 4, 1, pattern[i].flash and 15 or 12)
      elseif pattern[i].count > 0 then
        g:led(i + 4, 1, 7)
      else
        g:led(i + 4, 1, 3)
      end
      -- mute interval
      for i = 8, 9 do
        g:led(i, 4, mute_int and 15 or 2)
      end
      -- home
      for i = 8, 9 do
        g:led(i, 3, 6)
      end
      -- intervals dec
      for i = 1, 4 do
        local x = i + 3
        g:led(x, 4, 12 - i * 2)
      end
      -- intervals inc
      for i = 1, 4 do
        local x = i + 9
        g:led(x, 4, 2 + i * 2)
      end
      -- interval 0
      for i = 8, 9 do
        g:led(i, 5, 10)
      end
    end
  end
  -- focus
  g:led(1, 1, int_focus == 1 and 10 or 4)
  g:led(16, 1, int_focus == 2 and 10 or 4)
  g:led(1, 2, key_focus == 1 and 10 or 4)
  g:led(16, 2, key_focus == 2 and 10 or 4)
  --mute voice
  g:led(2, 1, voice[1].mute and 10 or 2)
  g:led(15, 1, voice[2].mute and 10 or 2)
  -- int octave
  g:led(1, 4, 8 + notes.oct_int * 2)
  g:led(1, 5, 8 - notes.oct_int * 2)
  -- key octave
  g:led(1, 7, 8 + notes.oct_key * 2)
  g:led(1, 8, 8 - notes.oct_key * 2)
  -- keyboard
  for i = 1, 12 do
    for j = 1, 2 do
      if not set_pattern then
        g:led(i + 2, j + 6, notes.root[i] and 15 or (notes.key[i] and 10 or 0))
      end
    end
  end
  -- key link
  g:led(16, 7, key_link and 10 or 4)
  -- mute keys
  g:led(16, 8, mute_key and 4 or 10)
  -- set pattern
  g:led(16, 5, set_pattern and 10 or 4)
  g:refresh()
end


-------- utilities --------

function r()
  norns.script.load(norns.state.script)
end

function hardware_redraw()
  if dirtygrid then
    gridredraw()
    dirtygrid = false
  end
end

function screen_redraw()
  if dirtyscreen then
    redraw()
    dirtyscreen = false
  end
end

function build_menu()
  for i = 1, 2 do
    if voice[i].output == 2 then
      params:show("midi_device"..i)
      params:show("midi_channel"..i)
      params:show("midi_velocity"..i)
      params:show("midi_length"..i)
      params:show("midi_panic"..i)

    else
      params:hide("midi_device"..i)
      params:hide("midi_channel"..i)
      params:hide("midi_velocity"..i)
      params:hide("midi_length"..i)
      params:hide("midi_panic"..i)
    end
    if voice[i].output == 3 then
      if (params:get("clock_crow_out") == 2 or params:get("clock_crow_out") == 3) then
        params:set("clock_crow_out", 1)
      end
    end
    if voice[i].output == 4 then
      if (params:get("clock_crow_out") == 4 or params:get("clock_crow_out") == 5) then
        params:set("clock_crow_out", 1)
      end
    end
    if voice[i].output == 5 then
      if params:get("jf_mode"..i) == 1 then
        params:show("jf_voice"..i)
      else
        params:hide("jf_voice"..i)
      end
      params:show("jf_amp"..i)
      params:show("jf_mode"..i)
    else
      params:hide("jf_mode"..i)
      params:hide("jf_voice"..i)
      params:hide("jf_amp"..i)
    end
  end
  _menu.rebuild_params()
  dirtyscreen = true
end

function page_redraw(page)
  if pageNum == page then
    dirtyscreen = true
  end
end

function drawgrid_connect()
  dirtygrid = true
  gridredraw()
end

function cleanup()
  grid.add = function() end
  midi.add = function() end
  midi.remove = function() end
  crow.ii.jf.mode(0)
  clock.cancel(quantizer)
  clock.cancel(downbeat)
  clock.cancel(beat)
  for i = 1, 8 do
    pattern[i]:stop()
    clock.cancel(pattern[i].sync_clock)
    pattern[i] = nil
  end
end
