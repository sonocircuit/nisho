-- nisha
--
-- two track
-- interval player
-- and sequencer
--
-- 0.0.4 @sonocircuit
-- llllllll.co/t/nisha
--
--
-- for docs go to:
-- >> github.com/sonocircuits
--    /nisha
--
-- or smb into:
-- >> code/nisha/docs
--
--

engine.name = "Thebangs"
-- ;install https://github.com/catfact/thebangs

thebangs = include('lib/thebangs_engine')
halfsync = include('lib/halfsync')

mu = require 'musicutil'
pattern_time = require 'pattern_time'

g = grid.connect()

-------- variables --------

local int_focus = 1
local key_focus = 1
local alt = false
local shift = false
local key_link = true
local mute_int = false
local mute_key = false
local overdub = false
local quantize = false
local flash_bar = false
local flash_beat = false
local ledview = 1
local q_rate = 16

local v8_std_1 = 12
local v8_std_2 = 12
local env1_amp = 8
local env1_a = 0
local env1_d = 0.4
local env2_a = 0
local env2_d = 0.4
local env2_amp = 8

-------- tables --------

options = {}
options.output = {"engine", "midi", "crow 1+2", "crow 3+4", "crow ii jf"}
options.div_view = {"1/4", "1/6", "1/8", "1/16", "1/32"}
options.div_value = {1/4, 1/6, 1/8, 1/16, 1/32}

notes = {}
notes.oct_int = 0
notes.oct_key = 0
notes.last = 1
notes.home = 1
notes.played = 60

track = {}
for i = 1, 2 do -- 2 tracks
  track[i] = {}
  track[i].note_num = 60
  track[i].output = 1
end

set_midi = {}
for i = 1, 2 do -- 2 tracks
  set_midi[i] = {}
  set_midi[i].ch = 1
  set_midi[i].velocity = 100
  set_midi[i].active_notes = {}
end

set_crow = {}
for i = 1, 2 do -- 2 tracks
  set_crow[i] = {}
  set_crow[i].jf_ch = i
  set_crow[i].jf_amp = 5
end

m = {}
for i = 1, 2 do
  m[i] = midi.connect()
end

-------- scales --------

scale_notes = {}

function build_scale()
  local root = params:get("root_note") % 12 + 24
  scale_notes = mu.generate_scale(root, params:get("scale"), 6) -- generate 6 octave scale
end

function lookup(note) -- check if note is in the selected scale
   for i = 1, 8 do
     for j = 0, 1 do
        if scale_notes[i] == note + j * 12 then
           return true
        end
      end
   end
   return false
end

-------- track settings --------

function set_track_output()
  local count = 0
  for i = 1, 2 do
    track[i].output = params:get("track_out"..i)
    if params:get("track_out"..i) == 5 then
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

function midi.add() -- MIDI register callback
  build_midi_device_list()
end

function midi.remove() -- MIDI remove callback
  clock.run(
    function()
      clock.sleep(0.2)
      build_midi_device_list()
    end
  )
end

function clock.transport.start()
  --
end

function clock.transport.stop()
  --
end

function notes_off(i) -- per track
  for _, a in pairs(set_midi[i].active_notes) do
    m[i]:note_off(a, nil, set_midi[i].ch)
  end
  set_midi[i].active_notes = {}
end

function all_notes_off() -- both tracks
  for i = 1, 2 do
    for _, a in pairs(set_midi[i].active_notes) do
      m[i]:note_off(a, nil, set_midi[i].ch)
    end
    set_midi[i].active_notes = {}
  end
end

-------- pattern recording --------

local eNOTE = 1
local ePATTERN = 2

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
end

function event(e)
  if quantize then
    event_q(e)
  else
    if e.t ~= ePATTERN then
      event_record(e)
    end
    event_exec(e)
  end
end

local quantize_events = {}
function event_q(e)
  table.insert(quantize_events, e)
end

function update_q_clock()
  while true do
    clock.sync(q_rate)
    event_q_clock()
  end
end

function event_q_clock()
  if #quantize_events > 0 then
    for k, e in pairs(quantize_events) do
      if e.t ~= ePATTERN then event_record(e) end
      event_exec(e)
    end
    quantize_events = {}
  end
end

-- exec function
function event_exec(e)
  if e.t == eNOTE then
    play_voice(e.i, e.note)
    notes.played = e.note
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
end

pattern = {}
for i = 1, 8 do
  pattern[i] = pattern_time.new()
  pattern[i].process = event_exec
end

-------- clock coroutines --------

function ledpulse()
  ledview = (ledview % 8) + 4
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
  params:set_action("scale", function() build_scale() end)

  params:add_number("root_note", "root note", 24, 84, 60, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("root_note", function() build_scale() notes.home = tab.key(scale_notes, params:get("root_note")) end)

  params:add_option("quant_div", "pattern quantization", options.div_view, 4)
  params:set_action("quant_div", function(idx) q_rate = options.div_value[idx] * 4 end)

  -- track params
  params:add_separator("tracks", "tracks")
  for i = 1, 2 do
    params:add_group("track_"..i, "track "..i, 7)

    -- output
    params:add_option("track_out"..i, "output", options.output, 1)
    params:set_action("track_out"..i, function() set_track_output() build_menu() end)

    -- midi params
    params:add_option("track_midi_device"..i, "midi device", midi_devices, 1)
    params:set_action("track_midi_device"..i, function(val) m[i] = midi.connect(val) end)

    params:add_number("track_midi_channel"..i, "midi channel", 1, 16, 1)
    params:set_action("track_midi_channel"..i, function(val) notes_off(i) set_midi[i].ch = val end)

    params:add_number("midi_velocity"..i, "velocity", 1, 127, 100)
    params:set_action("midi_velocity"..i, function(val) set_midi[i].velocity = val end)

    -- jf params
    params:add_option("jf_mode"..i, "jf_mode", {"vox", "note"}, 1)
    params:set_action("jf_mode"..i, function() build_menu() end)

    params:add_number("jf_voice"..i, "jf voice", 1, 6, i)
    params:set_action("jf_voice"..i, function(vox) set_crow[i].jf_ch = vox end)

    params:add_control("jf_amp"..i, "jf level", controlspec.new(0.1, 10, "lin", 0.1, 8.0, "vpp"))
    params:set_action("jf_amp"..i, function(level) set_crow[i].jf_amp = level end)

  end

  params:add_separator("sound", "sound")
  -- delay params
  params:add_group("delay", "delay", 8)
  halfsync.init()

  -- engine params
  params:add_group("thebangs", "thebangs", 8)
  thebangs.synth_params()

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

  params:bang()

  -- set defaults
  notes.last = notes.home
  for i = 1, 2 do
    track[i].note_num = scale_notes[notes.home]
  end
  -- metros
  hardwareredrawtimer = metro.init(hardware_redraw, 1/30, -1)
  hardwareredrawtimer:start()
  dirtygrid = true

  screenredrawtimer = metro.init(screen_redraw, 1/15, -1)
  screenredrawtimer:start()
  dirtyscreen = true

  ledcounter = metro.init(ledpulse, 0.1, -1)
  ledcounter:start()

  -- hardware callbacks
  grid.add = drawgrid_connect

end

-------- playback --------

function play_voice(i, note_num)
  -- engine output
  if track[i].output == 1 then
    local freq = mu.note_num_to_freq(note_num)
    engine.hz(freq)
  -- midi output
  elseif track[i].output == 2 then
    m[i]:note_on(note_num, set_midi[i].velocity, set_midi[i].ch)
    table.insert(set_midi[i].active_notes, note_num)
  -- crow output 1+2
  elseif track[i].output == 3 then
    crow.output[1].volts = ((note_num - 60) / v8_std_1)
    crow.output[2].action = "{ to(0, 0), to("..env1_amp..", "..env1_a.."), to(0, "..env1_d..", 'log') }"
    crow.output[2]()
  -- crow output 3+4
  elseif track[i].output == 4 then
    crow.output[3].volts = ((note_num - 60) / v8_std_2)
    crow.output[4].action = "{ to(0, 0), to("..env2_amp..", "..env2_a.."), to(0, "..env2_d..", 'log') }"
    crow.output[4]()
  -- crow ii jf
  elseif track[i].output == 5 then
    if params:get("jf_mode"..i) == 1 then
      crow.ii.jf.play_voice(set_crow[i].jf_ch, ((note_num - 60) / 12), set_crow[i].jf_amp)
    else
      crow.ii.jf.play_note(((note_num - 60) / 12), set_crow[i].jf_amp)
    end
  end
  dirtyscreen = true
end

-------- norns interface --------

function enc(n, d)
  if n == 1 then
    --
  elseif n == 2 then
    if shift then
      params:delta("scale", d)
    else
      --
    end
  elseif n == 3 then
    if shift then
      params:delta("root_note", d)
    else
      --
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if n == 2 and z == 1 then
    --
  elseif n == 3 and z == 1 then
    --
  end
  dirtyscreen = true
  dirtygrid = true
end

function redraw()
  screen.clear()
  local note_count = #scale_intervals[params:get("scale")] - 1
  for i = 1, note_count do
    screen.level((notes.played - scale_notes[i]) % 12 == 0 and 15 or 2)
    screen.move(i * 14 + (-7 * note_count + 56), 36)
    screen.text_center(mu.note_num_to_name(scale_notes[i], false))
  end
  if shift then
    screen.level(8)
    screen.move(8, 58)
    screen.text(params:string("scale"))
    screen.move(110, 58)
    screen.text(params:string("root_note"))
  end
  screen.update()
end

-------- grid interface --------

function g.key(x, y, z)
  if y == 1 and x == 3 then
    overdub = z == 1 and true or false
  end
  if y == 1 and x == 14 then
    alt = z == 1 and true or false
  end
  if y == 4 and x > 7 and x < 10 then -- mute interval
    mute_int = z == 1 and true or false
  end
  -- when key is pressed do
  if z == 1 then
    if y == 1 then
      -- set int_focus
      if x == 1 or x == 16 then
        local i = 1/15 * x + 14/15
        int_focus = math.floor(i)
      end
      -- patterns
      if x > 4 and x < 13 then
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
    elseif y == 2 then
      if x == 1 or x == 16 then
        local i = 1/15 * x + 14/15
        key_focus = math.floor(i)
      end
    elseif y == 3 and x > 7 and x < 10 then -- home
      track[int_focus].note_num = scale_notes[notes.home]
      notes.last = notes.home
      if not mute_int then
        local e = {t = eNOTE, i = int_focus, note = track[int_focus].note_num} event(e)
      end
    elseif y == 4 and x == 1 then
      notes.oct_int = util.clamp(notes.oct_int + 1, -3, 3)
    elseif y == 4 and x > 3 and x < 8 then  -- intervals dec
      local interval = x - 8
      local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
      track[int_focus].note_num = scale_notes[new_note]
      notes.last = new_note
      if not mute_int then
        local e = {t = eNOTE, i = int_focus, note = track[int_focus].note_num} event(e)
      end
    elseif y == 4 and x > 9 and x < 14 then -- intervals inc
      local interval = x - 9
      local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
      track[int_focus].note_num = scale_notes[new_note]
      notes.last = new_note
      if not mute_int then
        local e = {t = eNOTE, i = int_focus, note = track[int_focus].note_num} event(e)
      end
    elseif y == 4 and x == 16 then
      quantize = not quantize
      if quantize then
        quantizer = clock.run(update_q_clock)
        downbeat = clock.run(barpulse)
        quater = clock.run(beatpulse)
      else
        clock.cancel(quantizer)
        clock.cancel(downbeat)
        clock.cancel(quater)
      end
    elseif y == 5 and x == 1 then
      notes.oct_int = util.clamp(notes.oct_int - 1, -3, 3)
    elseif y == 5 and x > 7 and x < 10 then -- no interval
      track[int_focus].note_num = scale_notes[notes.last]
      if not mute_int then
        local e = {t = eNOTE, i = int_focus, note = track[int_focus].note_num} event(e)
      end
    elseif y == 7 then
      if x > 3 and x < 14 then -- keyboard black keys
        if x == 4 then
          track[key_focus].note_num = 61 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 6 then
          track[key_focus].note_num = 63 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 9 then
          track[key_focus].note_num = 66 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 11 then
          track[key_focus].note_num = 68 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 13 then
          track[key_focus].note_num = 70 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        end
        if key_link and tab.key(scale_notes, track[key_focus].note_num) ~= nil then
          local octave = #scale_intervals[params:get("scale")] - 1
          notes.last = tab.key(scale_notes, track[key_focus].note_num) + octave * notes.oct_int
        end
      elseif x == 1 then -- octave up
        notes.oct_key = util.clamp(notes.oct_key + 1, -3, 3)
      elseif x == 16 then
        key_link = not key_link
      end
    elseif y == 8 then
      if x > 2 and x < 15 then -- keyboard white keys
        if x == 3 then
          track[key_focus].note_num = 60 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 5 then
          track[key_focus].note_num = 62 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 7 then
          track[key_focus].note_num = 64 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 8 then
          track[key_focus].note_num = 65 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 10 then
          track[key_focus].note_num = 67 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 12 then
          track[key_focus].note_num = 69 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        elseif x == 14 then
          track[key_focus].note_num = 71 + notes.oct_key * 12
          if not mute_key then
            local e = {t = eNOTE, i = key_focus, note = track[key_focus].note_num} event(e)
          end
        end
        if key_link and tab.key(scale_notes, track[key_focus].note_num) ~= nil then
          local octave = #scale_intervals[params:get("scale")] - 1
          notes.last = tab.key(scale_notes, track[key_focus].note_num) + octave * notes.oct_int
        end
      elseif x == 1 then -- octave down
        notes.oct_key = util.clamp(notes.oct_key - 1, -3, 3)
      elseif x == 16 then
        mute_key = not mute_key
      end
    end
  -- when key is released do
  elseif z == 0 then
    if y == 4 and track[int_focus].output == 2 then
      if x > 3 and x < 8 then
        notes_off(int_focus)
      elseif x > 9 and x < 14 then
        notes_off(int_focus)
      end
    elseif (y == 7 or y == 8) and track[key_focus].output == 2 then
      if x > 2 and x < 15 then
        notes_off(key_focus)
      end
    end
  end
  dirtygrid = true
  dirtyscreen = true
end

function gridredraw()
  g:all(0)
  -- patterns
  g:led(3, 1, overdub == true and 15 or 8)
  g:led(14, 1, alt == true and 15 or 8) -- alt
  g:led(16, 4, quantize == true and (flash_bar and 15 or (flash_beat and 10 or 7)) or 3) -- Q flash
  for i = 1, 8 do
    if pattern[i].rec == 1 then
      g:led(i + 4, 1, 15)
    elseif pattern[i].overdub == 1 then
      g:led(i + 4, 1, ledview)
    elseif pattern[i].play == 1 then
      g:led(i + 4, 1, 12)
    elseif pattern[i].count > 0 then
      g:led(i + 4, 1, 8)
    else
      g:led(i + 4, 1, 4)
    end
  end
  -- focus
  g:led(1, 1, int_focus == 1 and 10 or 4)
  g:led(16, 1, int_focus == 2 and 10 or 4)
  g:led(1, 2, key_focus == 1 and 10 or 4)
  g:led(16, 2, key_focus == 2 and 10 or 4)
  -- mute interval
  for i = 8, 9 do
    g:led(i, 4, mute_int == true and 15 or 2)
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
  -- int octave
  g:led(1, 4, 8 + notes.oct_int * 2)
  g:led(1, 5, 8 - notes.oct_int * 2)
  -- key octave
  g:led(1, 7, 8 + notes.oct_key * 2)
  g:led(1, 8, 8 - notes.oct_key * 2)
  -- keyboard
  local root = params:get("root_note") % 12 + 24
  g:led(3, 8, root == 24 and 15 or (lookup(24) == true and 10 or 2))  -- C
  g:led(4, 7, root == 25 and 15 or (lookup(25) == true and 10 or 2)) -- C#
  g:led(5, 8, root == 26 and 15 or (lookup(26) == true and 10 or 2)) -- D
  g:led(6, 7, root == 27 and 15 or (lookup(27) == true and 10 or 2)) -- D#
  g:led(7, 8, root == 28 and 15 or (lookup(28) == true and 10 or 2)) -- E
  g:led(8, 8, root == 29 and 15 or (lookup(29) == true and 10 or 2)) -- F
  g:led(9, 7, root == 30 and 15 or (lookup(30) == true and 10 or 2)) -- F#
  g:led(10, 8, root == 31 and 15 or (lookup(31) == true and 10 or 2)) -- G
  g:led(11, 7, root == 32 and 15 or (lookup(32) == true and 10 or 2)) -- G#
  g:led(12, 8, root == 33 and 15 or (lookup(33) == true and 10 or 2)) -- A
  g:led(13, 7, root == 34 and 15 or (lookup(34) == true and 10 or 2)) -- A#
  g:led(14, 8, root == 35 and 15 or (lookup(35) == true and 10 or 2)) -- B
  -- key link
  g:led(16, 7, key_link == true and 10 or 4)
  -- mute key
  g:led(16, 8, mute_key == true and 4 or 10)
  g:refresh()
end


-------- utilities --------

function hardware_redraw()
  if dirtygrid == true then
    gridredraw()
    dirtygrid = false
  end
end

function screen_redraw()
  if dirtyscreen == true then
    redraw()
    dirtyscreen = false
  end
end

function build_menu()
  for i = 1, 2 do
    if track[i].output == 2 then
      params:show("track_midi_device"..i)
      params:show("track_midi_channel"..i)
      params:show("midi_velocity"..i)
    else
      params:hide("track_midi_device"..i)
      params:hide("track_midi_channel"..i)
      params:hide("midi_velocity"..i)
    end
    if track[i].output == 3 then
      if (params:get("clock_crow_out") == 2 or params:get("clock_crow_out") == 3) then
        params:set("clock_crow_out", 1)
      end
    end
    if track[i].output == 4 then
      if (params:get("clock_crow_out") == 4 or params:get("clock_crow_out") == 5) then
        params:set("clock_crow_out", 1)
      end
    end
    if track[i].output == 5 then
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

function drawgrid_connect()
  dirtygrid = true
  gridredraw()
end

function cleanup()
  grid.add = function() end
  crow.ii.jf.mode(0)
  for i = 1, 8 do
    pattern[i]:stop()
    pattern[i] = nil
  end
end
