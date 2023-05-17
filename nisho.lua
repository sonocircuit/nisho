-- nisho
--
-- 1.1.1 @sonocircuit
-- llllllll.co/t/nisho
--
-- a four voice interval player,
-- keyboard and pattern recorder
-- 
--
--
-- for docs go to:
-- >> github.com/sonocircuit
--    /nisho
--
-- or smb into:
-- >> code/nisho/docs
--

---------------------------------------------------------------------------
-- TODO:
-- test the shit out of this thing!
-- 
---------------------------------------------------------------------------

engine.name = "Moonshine"

local softsync = include "lib/nishos_softsync"
local mirror = include "lib/nishos_reflection"
local moons = include "lib/nishos_moonshine"
  
local mu = require "musicutil"

local g = grid.connect()


-------- variables --------
local load_pset = false
local midi_thru = false
local main_pageNum = 1
local pattern_pageNum = 1 
local pattern_view = false
local int_focus = 1
local key_focus = 1
local pattern_focus = 1
local viewinfo = 0
local mod_a = false
local mod_b = false
local shift = false
local key_link = true
local mute_int = false
local mute_key = false
local transpose = false
local transpose_value = 0
local key_quantize = false
local flash_bar = false
local flash_beat = false
local ledfast = 8
local ledslow = 4
local q_rate = 16
local voice_count_1 = 0
local voice_count_2 = 0
local NUM_VOICES = 4

local v8_std_1 = 12
local v8_std_2 = 12
local env1_amp = 8
local env1_a = 0
local env1_r = 0.4
local env2_amp = 8
local env2_a = 0
local env2_r = 0.4
local wsyn_amp = 5

local midi_in_device = 5
local midi_out_device = 6
local midi_in_dest = 0

local arp_notes = {}
local collected_notes = {}
local arp_active = false
local collecting_notes = false
local arp_step = 0
local arp_rate = 1/4

local eINT = 1
local eKEY = 2
local eTRANSPOSE = 3
local eMIDI = 4
local quant_event = {}
local root_oct = 3

local copying = false
local pasting = false
local copy_src = {state = false, pattern = nil, bank = nil}

local held = 0
local heldmax = 0
local first = 0
local second = 0

local view_message = ""


-------- tables --------
local options = {}
options.key_quant = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
options.quant_value = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
options.pattern_mode = {"manual", "synced"}
options.pattern_play = {"loop", "oneshot"}
options.pattern_countin = {"none", "beat", "bar"}
options.pattern_quantize = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/24", "1/32", "3/128", "1/48", "1/64"}
options.pattern_quantize_value = {1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}
options.pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
options.meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}

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
for i = 1, NUM_VOICES do -- 4 voices
  voice[i] = {}
  voice[i].output = 1
  voice[i].mute = false
end

local set_midi = {}
for i = 1, 6 do -- 4 voices + 2 global
  set_midi[i] = {}
  set_midi[i].ch = 1
  set_midi[i].velocity = 100
  set_midi[i].length = 0.2
end

local set_crow = {}
for i = 1, NUM_VOICES do -- 4 voices
  set_crow[i] = {}
  set_crow[i].jf_ch = i
  set_crow[i].jf_amp = 5
end

local m = {}
for i = 1, 6 do -- 4 voices + 2 global
  m[i] = midi.connect()
end


-------- scales --------
local scale_notes = {}
local note_map = {}

function build_scale()
  local root = params:get("root_note") % 12 + 24
  root_oct = math.floor((params:get("root_note") - root) / 12)
  scale_notes = mu.generate_scale_of_length(root, params:get("scale"), 50)
  local num_to_add = 50 - #scale_notes
  for i = 1, num_to_add do
    table.insert(scale_notes, scale_notes[50 - num_to_add])
  end
end

function build_scale_map()
  note_map = mu.generate_scale_of_length(0, params:get("midi_in_scale"), 100)
  local num_to_add = 100 - #scale_notes
  for i = 1, num_to_add do
    table.insert(scale_notes, scale_notes[100 - num_to_add])
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
  for i = 1, NUM_VOICES do
    voice[i].output = params:get("voice_out"..i)
    if voice[i].output == 6 then
      count = count + 1
    end
    if voice[i].output == 7 then
      crow.ii.wsyn.voices(4)
    end
  end
  if count > 0 then
    crow.ii.jf.mode(1)
  else
    crow.ii.jf.mode(0)
  end
end

function set_defaults()
  params:set("voice_out1", 1)
  params:set("voice_out2", 2)
  params:set("voice_out3", 3)
  params:set("voice_out4", 3)
end


-------- pattern recording --------

-- exec function
function event_exec(e)
  if e.t == eINT then
    local octave = (root_oct - e.root) * (#scale_intervals[params:get("scale")] - 1)
    local idx = util.clamp(e.note + transpose_value + octave, 1, #scale_notes)
    local note_num = scale_notes[idx]
    play_voice(e.i, note_num)
    notes.played = note_num
  elseif e.t == eKEY then
    local octave = (root_oct - e.root) * (#scale_intervals[params:get("scale")] - 1)
    local idx = util.clamp(e.note + transpose_value + octave, 1, #scale_notes)
    local note_num = scale_notes[idx]
    play_voice(e.i, note_num)
    notes.played = note_num
  elseif e.t == eTRANSPOSE then
    local home_note = tab.key(scale_notes, params:get("root_note"))
    transpose_value = util.clamp(transpose_value + e.interval, -home_note + 1, #scale_notes - home_note)
    if e.interval == 0 then
      transpose_value = 0
    end
  elseif e.t == eMIDI then
    if e.dest == 0 then
      if e.action == "note_on" then
        if params:get("glb_midi_in_quantization") == 2 then
          e.note = mu.snap_note_to_array(e.note, note_map)
        end
        m[midi_out_device]:note_on(e.note, e.vel, e.ch)
      elseif e.action == "note_off" then
        if params:get("glb_midi_in_quantization") == 2 then
          e.note = mu.snap_note_to_array(e.note, note_map)
        end
        m[midi_out_device]:note_on(e.note, 0, e.ch)
      end
    elseif e.dest > 0 and e.action == "note_on" then
      if params:get("glb_midi_in_quantization") == 2 then
        e.note = mu.snap_note_to_array(e.note, note_map)
      end
      play_voice(e.dest, e.note, e.vel)
    end
  end
  dirtyscreen = true
end

local pattern = {}
for i = 1, 8 do
  pattern[i] = mirror.new("pattern "..i)
  pattern[i].process = event_exec
  pattern[i].start_callback = function() step_one_indicator(i) set_pattern_length(i) end
  pattern[i].end_of_loop_callback = function() set_pattern_bank(i) end
  pattern[i].end_callback = function() dirtygrid = true end
  pattern[i].step_callback = function() if pattern_view then dirtygrid = true end end
end

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
end

function event(e)
  if key_quantize then
    table.insert(quant_event, e)
  else
    event_record(e)
    event_exec(e)
  end
end

function event_q_clock()
  while true do
    clock.sync(q_rate)
    if #quant_event > 0 then
      for k, e in pairs(quant_event) do
        event_record(e)
        event_exec(e)
      end
      quant_event = {}
    end
  end
end

local p = {}
for i = 1, 8 do
  p[i] = {}
  p[i].key_flash = false
  p[i].bank = 1
  p[i].load = nil
  p[i].looping = false
  p[i].loop = {}
  p[i].quantize = {}
  p[i].count = {}
  p[i].event = {}
  p[i].endpoint = {}
  p[i].endpoint_init = {}
  p[i].step_min = {}
  p[i].step_max = {}
  p[i].beatnum = {}
  p[i].meter = {}
  p[i].length = {}
  p[i].manual_length = {}
  p[i].auto_len = {}
  for j = 1, 4 do
    p[i].loop[j] = 1
    p[i].quantize[j] = 1/4
    p[i].count[j] = 0
    p[i].event[j] = {}
    p[i].endpoint[j] = 0
    p[i].endpoint_init[j] = 0
    p[i].step_min[j] = 0
    p[i].step_max[j] = 0
    p[i].beatnum[j] = 16
    p[i].meter[j] = 4/4
    p[i].length[j] = 16
    p[i].manual_length[j] = false
    p[i].auto_len[j] = true
  end
end

local function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
end

function step_one_indicator(i)
  p[i].key_flash = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(0.1)
    p[i].key_flash = false
    dirtygrid = true
  end) 
end

function set_pattern_length(i)
  local prev_length = pattern[i].length
  pattern[i].length = pattern[i].meter * pattern[i].beatnum
  if prev_length ~= pattern[i].length then
    pattern[i]:set_length(pattern[i].length)
  end
end

function update_pattern_length(i)
  if pattern[i].play == 0 then
    pattern[i].length = pattern[i].meter * pattern[i].beatnum
    pattern[i]:set_length(pattern[i].length)
  end
end

function set_pattern_bank(i)
  if p[i].load then
    p[i].bank = p[i].load
    load_pattern_bank(i, p[i].bank)
    if p[i].count[p[i].bank] == 0 then
      pattern[i]:end_playback()
    end
    p[i].load = nil
    if pattern_view then dirtyscreen = true end
  end
end

function paste_arp_pattern(i)
  if #arp_notes > 0 then
    for n = 1, #arp_notes do
      local s = math.floor((n - 1) * (arp_rate * 64) + 1)
      if arp_notes[n] > 0 then
        if not pattern[i].event[s] then
          pattern[i].event[s] = {}
        end
        local e = {t = eKEY, i = key_focus, root = root_oct, note = arp_notes[n]}
        table.insert(pattern[i].event[s], e)
        pattern[i].count = pattern[i].count + 1
      end
    end
    pattern[i].endpoint = #arp_notes * (arp_rate * 64)
    pattern[i].endpoint_init = pattern[i].endpoint
    pattern[i].step_max = pattern[i].endpoint
    pattern[i].manual_length = true
  else
    show_message("arp pattern empty")
  end
end

function set_pattern_params(i)
  params:set("patterns_playback"..i, pattern[i].loop == 1 and 1 or 2)
  params:set("patterns_quantize"..i, tab.key(options.pattern_quantize_value, pattern[i].quantize))
  params:set("patterns_beatnum"..i, math.floor(pattern[i].beatnum / 4))
  params:set("patterns_meter"..i, tab.key(options.meter_val, pattern[i].meter))
end

function copy_pattern(src, src_bank, dst, dst_bank)
  p[dst].loop[dst_bank] = p[src].loop[src_bank]
  p[dst].quantize[dst_bank] = p[src].quantize[src_bank]
  p[dst].count[dst_bank] = p[src].count[src_bank]
  p[dst].event[dst_bank] = deep_copy(p[src].event[src_bank])
  p[dst].endpoint[dst_bank] = p[src].endpoint[src_bank]
  p[dst].beatnum[dst_bank] = p[src].beatnum[src_bank]
  p[dst].meter[dst_bank] = p[src].meter[src_bank]
  p[dst].length[dst_bank] = p[src].length[src_bank]
end

function save_pattern_bank(i, bank)
  p[i].loop[bank] = pattern[i].loop
  p[i].quantize[bank] = pattern[i].quantize
  p[i].count[bank] = pattern[i].count
  p[i].event[bank] = deep_copy(pattern[i].event)
  p[i].endpoint[bank] = pattern[i].endpoint
  p[i].beatnum[bank] = pattern[i].beatnum
  p[i].meter[bank] = pattern[i].meter
  p[i].length[bank] = pattern[i].length
end

function load_pattern_bank(i, bank)
  pattern[i].count = p[i].count[bank]
  pattern[i].loop = p[i].loop[bank]
  pattern[i].quantize = p[i].quantize[bank]
  pattern[i].event = deep_copy(p[i].event[bank])
  pattern[i].endpoint = p[i].endpoint[bank]
  pattern[i].step_min = 0
  pattern[i].step_max = pattern[i].endpoint
  pattern[i].beatnum = p[i].beatnum[bank]
  pattern[i].meter = p[i].meter[bank]
  pattern[i].length = p[i].length[bank]
  p[i].looping = false
  set_pattern_params(i)
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
  if arp_clock then
     clock.cancel(arp_clock)
     arp_step = 0
  end
  arp_clock = clock.run(make_arp)
end

function clock.transport.stop()
  for i = 1, 8 do
    pattern[i]:end_playback()
  end
  if arp_clock then
    clock.cancel(arp_clock)
    arp_step = 0
  end
  dirtygrid = true
  all_notes_off()
end

function set_midi_in_dest(dest)
  if dest == 1 then
    midi_in_dest = 0
  elseif dest > 1 then
    local i = dest - 1
    midi_in_dest = params:get("voice_out"..i)
  end
end

function notes_off(i) -- per voice
  for j = 0, 127 do
    m[i]:note_off(j, 0, set_midi[i].ch)
  end
end

function all_notes_off() -- all voices
  for i = 1, NUM_VOICES do
    for j = 0, 127 do
      m[i]:note_off(j, 0, set_midi[i].ch)
    end
  end
end

function midi_events(data)
  local msg = midi.to_msg(data)
  if msg.ch == set_midi[midi_in_device].ch then
    if msg.type == "note_on" or msg.type == "note_off" then
      local e = {t = eMIDI, action = msg.type, note = msg.note, vel = msg.vel, ch = set_midi[midi_out_device].ch, dest = midi_in_dest} event(e)
    end
  end
end

function set_midi_event_callback()
  midi.cleanup()
  m[midi_in_device].event = midi_events
end


-------- clock coroutines --------

function ledpulse_fast()
  while true do
    clock.sync(1/4)
    ledfast = ledfast == 8 and 12 or 8
    for i = 1, 8 do
      if pattern[i].rec == 1 then
        dirtygrid = true
      end
    end
  end
end

function ledpulse_slow()
  ledslow = util.wrap(ledslow + 1, 4, 12)
  for i = 1, 8 do
    if (p[i].load or copy_src) then
      dirtygrid = true
    end
  end
end

function barpulse()
  while true do
    clock.sync(4)
    flash_bar = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(0.1)
      flash_bar = false
      dirtygrid = true
    end)
  end
end

function beatpulse()
  while true do
    clock.sync(1)
    flash_beat = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(0.1)
      flash_beat = false
      dirtygrid = true
    end)
  end
end

function set_metronome(mode)
  if mode == 1 then
    clock.cancel(barviz)
    clock.cancel(beatviz)
  else
    barviz = clock.run(barpulse)
    beatviz = clock.run(beatpulse)
  end
end

function make_arp()
  while true do
    clock.sync(arp_rate)
    arp_step = arp_step + 1
    if #arp_notes > 0 and arp_active then
      if arp_notes[arp_step] > 0 then
        local e = {t = eKEY, i = key_focus, root = root_oct, note = arp_notes[arp_step]} event(e)
      end
    end
    if arp_step >= #arp_notes then
      arp_step = 0
    end
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

  params:add_option("metronome_viz", "metronome", {"hide", "show"}, 2)
  params:set_action("metronome_viz", function(mode) set_metronome(mode) end)

  params:add_option("keyboard_type", "keyboard type", {"intervals", "semitones"}, 1)
  params:set_action("keyboard_type", function() dirtygrid = true end)

  params:add_option("key_quant_value", "key quantization", options.key_quant, 7)
  params:set_action("key_quant_value", function(idx) q_rate = options.quant_value[idx] * 4 end)
  params:hide("key_quant_value")

  params:add_option("arp_rate", "arp rate", options.key_quant, 7)
  params:set_action("arp_rate", function(idx) arp_rate = options.quant_value[idx] * 4 end)
  params:hide("arp_rate")

  params:add_group("global_midi_group", "midi settings", 11)

  params:add_separator("glb_midi_in_params", "midi in")

  params:add_option("glb_midi_in_device", "midi in device", midi_devices, 1)
  params:set_action("glb_midi_in_device", function(val) m[midi_in_device] = midi.connect(val) set_midi_event_callback() end)

  params:add_number("glb_midi_in_channel", "midi in channel", 1, 16, 14)
  params:set_action("glb_midi_in_channel", function(val) notes_off(midi_in_device) set_midi[midi_in_device].ch = val end)

  params:add_option("glb_midi_in_quantization", "map to scale", {"no", "yes"}, 1)
  params:set_action("glb_midi_in_quantization", function() build_menu() end)

  params:add_option("midi_in_scale", "scale", scale_names, 1)
  params:set_action("midi_in_scale", function() build_scale_map() end)

  params:add_option("glb_midi_in_destination", "send midi to..", {"midi out", "voice 1", "voice 2", "voice 3", "voice 4"})
  params:set_action("glb_midi_in_destination", function(dest) set_midi_in_dest(dest) end)

  params:add_separator("glb_midi_out_params", "midi out")

  params:add_option("glb_midi_out_device", "midi out device", midi_devices, 1)
  params:set_action("glb_midi_out_device", function(val) m[midi_out_device] = midi.connect(val) end)

  params:add_number("glb_midi_out_channel", "midi out channel", 1, 16, 1)
  params:set_action("glb_midi_out_channel", function(val) notes_off(midi_out_device) set_midi[midi_out_device].ch = val end)

  params:add_option("glb_midi_thru", "mirror voices", {"no", "yes"}, 1)
  params:set_action("glb_midi_thru", function(val) midi_thru = val == 2 and true or false end)

  params:add_binary("glb_midi_panic", "don't panic", "trigger", 0)
  params:set_action("glb_midi_panic", function() all_notes_off() end)

  -- patterns params
  params:add_group("patterns", "patterns", 48)
  params:hide("patterns")
  for i = 1, 8 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("patterns_playback"..i, "playback", options.pattern_play, 1)
    params:set_action("patterns_playback"..i, function(mode) pattern[i].loop = mode == 1 and 1 or 0 end)

    params:add_option("patterns_quantize"..i, "quantize", options.pattern_quantize, 7)
    params:set_action("patterns_quantize"..i, function(idx) pattern[i].quantize = options.pattern_quantize_value[idx] end)

    params:add_option("patterns_countin"..i, "count in", options.pattern_countin, 3)

    params:add_option("patterns_meter"..i, "meter", options.pattern_meter, 3)
    params:set_action("patterns_meter"..i, function(idx) pattern[i].meter = options.meter_val[idx] update_pattern_length(i) end)

    params:add_number("patterns_beatnum"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("patterns_beatnum"..i, function(num) pattern[i].beatnum = num * 4 update_pattern_length(i) dirtygrid = true end)
  end

  -- voice params
  params:add_separator("voices", "voices")
  for i = 1, NUM_VOICES do
    params:add_group("voice_"..i, "voice "..i, 10)
    -- output
    params:add_option("voice_out"..i, "output", {"synth[one]", "synth[two]", "midi", "crow 1+2", "crow 3+4", "crow ii jf", "crow ii wsyn"}, 1)
    params:set_action("voice_out"..i, function() set_voice_output() build_menu() end)
    -- mute
    params:add_option("voice_mute"..i, "mute", {"off", "on"}, 1)
    params:set_action("voice_mute"..i, function(val) voice[i].mute = val == 2 and true or false dirtygrid = true end)

    -- midi params
    params:add_option("midi_device"..i, "midi device", midi_devices, 1)
    params:set_action("midi_device"..i, function(val) m[i] = midi.connect(val) end)

    params:add_number("midi_channel"..i, "midi channel", 1, 16, i)
    params:set_action("midi_channel"..i, function(val) notes_off(i) set_midi[i].ch = val end)

    params:add_number("midi_velocity"..i, "velocity", 1, 127, 100)
    params:set_action("midi_velocity"..i, function(val) set_midi[i].velocity = val end)

    params:add_control("midi_length"..i, "note length", controlspec.new(0.01, 2, "lin", 0.01, 0.2, "s"))
    params:set_action("midi_length"..i, function(val) set_midi[i].length = val end)

    params:add_binary("midi_panic"..i, "don't panic", "trigger", 0)
    params:set_action("midi_panic"..i, function() notes_off(i) end)

    -- jf params
    params:add_option("jf_mode"..i, "jf mode", {"vox", "note"}, 1)
    params:set_action("jf_mode"..i, function() build_menu() end)

    params:add_number("jf_voice"..i, "jf voice", 1, 6, i)
    params:set_action("jf_voice"..i, function(vox) set_crow[i].jf_ch = vox end)

    params:add_control("jf_amp"..i, "jf level", controlspec.new(0.1, 10, "lin", 0.1, 8.0, "vpp"))
    params:set_action("jf_amp"..i, function(level) set_crow[i].jf_amp = level end)
  end

  params:add_separator("sound_params", "sound")
  -- engine params
  moons.add_params()
  -- delay params
  softsync.init()

  -- crow params
  params:add_separator("crow", "crow")

  params:add_group("out 1+2", 4)
  params:add_option("v8_type_1", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_1", function(x) if x == 1 then v8_std_1 = 12 else v8_std_1 = 10 end end)

  params:add_control("env1_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env1_amplitude", function(value) env1_amp = value end)

  params:add_control("env1_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env1_attack", function(value) env1_a = value end)

  params:add_control("env1_decay", "release", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env1_decay", function(value) env1_r = value end)

  params:add_group("out 3+4", 4)
  params:add_option("v8_type_2", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_2", function(x) if x == 1 then v8_std_2 = 12 else v8_std_2 = 10 end end)

  params:add_control("env2_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env2_amplitude", function(value) env2_amp = value end)

  params:add_control("env2_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env2_attack", function(value) env2_a = value end)

  params:add_control("env2_decay", "release", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env2_decay", function(value) env2_r = value end)

  -- wsyn
  params:add_group("wsyn_params", "wsyn", 10)
  -- wsyn params
  params:add_option("wysn_mode", "wsyn mode", {"hold", "lpg"}, 2)
  params:set_action("wysn_mode", function(mode) crow.ii.wsyn.ar_mode(mode - 1) end)

  params:add_control("wsyn_amp", "wsyn level", controlspec.new(0, 10, "lin", 0, 5, "vpp"))
  params:set_action("wsyn_amp", function(level) wsyn_amp = level end)
  
  params:add_control("wsyn_curve", "curve",  controlspec.new(-5, 5, "lin", 0, 5, "v"))
  params:set_action("wsyn_curve", function(v) crow.ii.wsyn.curve(v) end)
  
  params:add_control("wsyn_ramp", "ramp", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_ramp", function(v) crow.ii.wsyn.ramp(v) end)
  
  params:add_control("wsyn_lpg_time", "lpg time", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_lpg_time", function(v) crow.ii.wsyn.lpg_time(v) end)
  
  params:add_control("wsyn_lpg_sym", "lpg symmetry", controlspec.new(-5, 5, "lin", 0, -5, "v"))
  params:set_action("wsyn_lpg_sym", function(v) crow.ii.wsyn.lpg_symmetry(v) end)
  
  params:add_control("wsyn_fm_index", "fm index", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_fm_index", function(v) crow.ii.wsyn.fm_index(v) end)
  
  params:add_control("wsyn_fm_env", "fm envelope", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_fm_env", function(v) crow.ii.wsyn.fm_env(v) end)
  
  params:add_number("wsyn_fm_num", "fm ratio num", 1, 16, 1)
  params:set_action("wsyn_fm_num", function(num) crow.ii.wsyn.fm_ratio(num, params:get("wsyn_fm_den")) end)
  
  params:add_number("wsyn_fm_den", "fm ratio denom", 1, 16, 2)
  params:set_action("wsyn_fm_den", function(denom) crow.ii.wsyn.fm_ratio(params:get("wsyn_fm_num"), denom) end)

  -- pset callbacks
  params.action_write = function(filename, name, number)
    -- make directory
    os.execute("mkdir -p "..norns.state.data.."patterns/"..number.."/")
    -- save pattern data
    for i = 1, 8 do
      save_pattern_bank(i, p[i].bank)
    end
    -- make table
    local pattern_data = {}
    clock.run(function() 
      clock.sleep(0.5)
      for i = 1, 8 do
        -- paste data
        pattern_data[i] = {}
        pattern_data[i].bank = p[i].bank
        pattern_data[i].loop = {}
        pattern_data[i].quantize = {}
        pattern_data[i].count = {}
        pattern_data[i].event = {}
        pattern_data[i].endpoint = {}
        pattern_data[i].beatnum = {}
        pattern_data[i].meter = {}
        pattern_data[i].length = {}
        for j = 1, 4 do
          pattern_data[i].loop[j] = p[i].loop[j]
          pattern_data[i].quantize[j] = p[i].quantize[j]
          pattern_data[i].count[j] = p[i].count[j]
          pattern_data[i].event[j] = deep_copy(p[i].event[j])
          pattern_data[i].endpoint[j] = p[i].endpoint[j]
          pattern_data[i].beatnum[j] = p[i].beatnum[j]
          pattern_data[i].meter[j] = p[i].meter[j]
          pattern_data[i].length[j] = p[i].length[j]
        end
      end
      -- save table
      tab.save(pattern_data, norns.state.data.."patterns/"..number.."/"..name.."_pattern.data")
      print("finished writing pset:'"..name.."'")
    end)
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      -- load sesh data
      local pattern_data = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
      for i = 1, 8 do
        p[i].bank = pattern_data[i].bank
        for j = 1, 4 do
          p[i].loop[j] = pattern_data[i].loop[j]
          p[i].quantize[j] = pattern_data[i].quantize[j]
          p[i].count[j] = pattern_data[i].count[j]
          p[i].event[j] = deep_copy(pattern_data[i].event[j])
          p[i].endpoint[j] = pattern_data[i].endpoint[j]
          p[i].beatnum[j] = pattern_data[i].beatnum[j]
          p[i].meter[j] = pattern_data[i].meter[j]
          p[i].length[j] = pattern_data[i].length[j]
        end
        load_pattern_bank(i, p[i].bank)
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
  set_defaults()

  -- metros
  hardwareredrawtimer = metro.init(hardware_redraw, 1/30, -1)
  hardwareredrawtimer:start()
  dirtygrid = true

  screenredrawtimer = metro.init(screen_redraw, 1/15, -1)
  screenredrawtimer:start()
  dirtyscreen = true

  slowpulse = metro.init(ledpulse_slow, 0.2, -1)
  slowpulse:start()

  -- clocks
  clock.run(event_q_clock)
  clock.run(ledpulse_fast)
  
  -- hardware callbacks
  grid.add = drawgrid_connect
  midi.add = midi_connect
  midi.remove = midi_disconnect
  m[midi_in_device].event = midi_events

end


-------- playback --------
function play_voice(i, note_num, vel)
  local velocity = vel or set_midi[i].velocity
  -- engine output
  if not voice[i].mute then
    -- midi output
    if (voice[i].output == 3 or midi_thru) then
      m[i]:note_on(note_num, velocity, set_midi[i].ch)
      clock.run(
        function()
          clock.sleep(set_midi[i].length)
          m[i]:note_off(note_num, 0, set_midi[i].ch)
        end
      )
    end
    -- moonshine group 1
    if voice[i].output == 1 then
      voice_count_1 = voice_count_1 % 4 + 1
      local freq = mu.note_num_to_freq(note_num)
      engine.trig(voice_count_1, freq)
    -- moonshine group 2
    elseif voice[i].output == 2 then
      voice_count_2 = voice_count_2 % 4 + 5
      local freq = mu.note_num_to_freq(note_num)
      engine.trig(voice_count_2, freq)
    -- crow output 1+2
    elseif voice[i].output == 4 then
      crow.output[1].volts = ((note_num - 60) / v8_std_1)
      crow.output[2].action = "{ to(0, 0), to("..env1_amp..", "..env1_a.."), to(0, "..env1_r..", 'log') }"
      crow.output[2]()
    -- crow output 3+4
    elseif voice[i].output == 5 then
      crow.output[3].volts = ((note_num - 60) / v8_std_2)
      crow.output[4].action = "{ to(0, 0), to("..env2_amp..", "..env2_a.."), to(0, "..env2_r..", 'log') }"
      crow.output[4]()
    -- crow ii jf
    elseif voice[i].output == 6 then
      if params:get("jf_mode"..i) == 1 then
        crow.ii.jf.play_voice(set_crow[i].jf_ch, ((note_num - 60) / 12), set_crow[i].jf_amp)
      else
        crow.ii.jf.play_note(((note_num - 60) / 12), set_crow[i].jf_amp)
      end
    elseif voice[i].output == 7 then
      crow.ii.wsyn.play_note(((note_num - 60) / 12), wsyn_amp)
    end
  end
end


-------- norns interface --------
function enc(n, d)
  if n == 1 then
    if pattern_view then
      pattern_pageNum = util.clamp(pattern_pageNum + d, 1, 2)
    end
  elseif n == 2 then
    if pattern_view then
      if pattern_pageNum == 1 then
        if not pattern[pattern_focus].manual_length then
          if viewinfo == 0 then
            params:delta("patterns_meter"..pattern_focus, d)
          else
            params:delta("patterns_beatnum"..pattern_focus, d)
          end
        end
      else
        params:delta("arp_rate", d)
      end
    else
      if shift then
        params:delta("scale", d)
      end
    end
  elseif n == 3 then
    if pattern_view then
      if pattern_pageNum == 1 then
        if viewinfo == 0 then
          params:delta("patterns_quantize"..pattern_focus, d) 
        else
          params:delta("patterns_countin"..pattern_focus, d)
        end
      else
        params:delta("key_quant_value", d)
      end
    else
      if shift then
        params:delta("root_note", d)
      end
    end
  end
  dirtygrid = true
  dirtyscreen = true
end

function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if n == 2 and z == 1 then
    if pattern_view then
      if not shift then
        viewinfo = 1 - viewinfo
      end
    else
      transpose = not transpose
    end
  elseif n == 3 and z == 1 then
    if pattern_view then
      pattern_focus = util.wrap(pattern_focus + 1, 1, 8)
    else
      if not transpose then
        transpose_value = 0
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function redraw()
  screen.clear()
  local sel = viewinfo == 0
  if pattern_view then
    screen.font_size(8)
    screen.level(15)
    screen.move(10, 16)
    screen.text("PATTERN "..pattern_focus.." > BANK "..p[pattern_focus].bank)
    screen.level(10)
    screen.move(86, 16)

    for i = 1, 2 do
      screen.rect(i * 8 + 100, 11, 5, 5)
      if i == pattern_pageNum then
        screen.level(15)
      else
        screen.level(2)
      end
      screen.fill()
    end

    if pattern_pageNum == 1 then
      screen.level(sel and 15 or 4)
      screen.move(10, 32)
      local idx = tab.key(options.meter_val, pattern[pattern_focus].meter)
      screen.text(pattern[pattern_focus].manual_length and "-" or options.pattern_meter[idx])
      screen.move(70, 32)
      screen.text(params:string("patterns_quantize"..pattern_focus))
      screen.level(mod_a and 15 or 3)
      screen.move(10, 40)
      screen.text("meter")
      screen.level(3)
      screen.move(70, 40)
      screen.text("quantization")

      screen.level(not sel and 15 or 4)
      screen.move(10, 52)
      screen.text(pattern[pattern_focus].manual_length and "-" or params:string("patterns_beatnum"..pattern_focus))
      screen.move(70, 52)
      screen.text(params:string("patterns_countin"..pattern_focus))
      screen.level(mod_b and 15 or 3)
      screen.move(10, 60)
      screen.text("length")
      screen.level(3)
      screen.move(70, 60)
      screen.text("count in")
    else
      screen.level(15)
      screen.move(36, 38)
      screen.text_center(params:string("arp_rate"))
      screen.level(3)
      screen.move(36, 48)
      screen.text_center("arp rate")

      screen.level(15)
      screen.move(90, 38)
      screen.text_center(params:string("key_quant_value"))
      screen.level(3)
      screen.move(90, 48)
      screen.text_center("key quant")
    end
  else
    local note_count = #scale_intervals[params:get("scale")] - 1
    for i = 1, note_count do
      screen.font_size(8)
      screen.level((notes.played - scale_notes[i]) % 12 == 0 and 15 or 2)
      screen.move(i * 14 + (-7 * note_count + 56), 36)
      screen.text_center(mu.note_num_to_name(scale_notes[i], false))
    end
    if shift and not collecting_notes then
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
      --screen.text_center("trsp "..intlookup(semitone))
      if semitone > 0 then
        screen.text_center("trsp +"..semitone)
      else
        screen.text_center("trsp "..semitone)
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
  if collecting_notes and #collected_notes > 0 then
    screen.level(8)
    screen.font_size(16)
    screen.move(64, 54)
    screen.text_center(#collected_notes)
  end
  -- display messages
  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end
  screen.update()
end


-------- grid interface -------- 
function pattern_keys(i)
  if pasting and not copying then
    if pattern[i].count > 0 then
      pattern[i]:double()
      show_message("doubled pattern")
    end
  elseif not pasting and not copying then
    -- stop and clear
    if mod_a and mod_b then
      if pattern[i].count > 0 then
        pattern[i]:clear()
      end
    else
      -- if pattern is not playing
      if pattern[i].play == 0 then
        local count_in = params:get("patterns_countin"..i) == 2 and 1 or (params:get("patterns_countin"..i) == 3 and 4 or nil)
        -- if pattern is empty
        if pattern[i].count == 0 then
          -- if rec not enabled press key to enable recording
          if arp_active and not (mod_a or mod_b) then
            paste_arp_pattern(i)
          else
            if pattern[i].rec_enabled == 0 then
              local mode = mod_b and 1 or 2
              local dur = not mod_a and pattern[i].length or nil
              pattern[i]:set_rec(mode, dur, 4)
            -- if recording and no data then press key to abort
            else
              pattern[i]:set_rec(0)
              pattern[i]:stop()
            end
          end
        -- if a pattern contains data then
        else
          pattern[i]:start(count_in)
        end
      -- if pattern is playing
      else
        -- if holding modifier key a
        if mod_a then
          -- if recording then discard the recording and replace with prev event table
          if pattern[i].rec == 1 then
            pattern[i]:set_rec(0)
            pattern[i]:undo()
          -- if not recording start recording
          else
            pattern[i]:set_rec(1)               
          end
        elseif mod_b then
          local dur = pattern[i].length
          if pattern[i].rec == 0 then
            pattern[i]:set_rec(2, dur)
          end
        else
          if pattern[i].rec == 1 then
            pattern[i]:set_rec(0)
          else
            pattern[i]:stop()
          end
        end
      end
    end
  end
end

function func_keys(x, y, z)
  if y == 2 and x == 4 then -- pattern mod_a
    mod_a = z == 1 and true or false
    if mod_a and collecting_notes then
      table.insert(collected_notes, 0)
    end
    dirtyscreen = true
  end
  if y == 2 and x == 13 then -- pattern mod_b
    mod_b = z == 1 and true or false
    if mod_b and collecting_notes then
      table.insert(collected_notes, 0)
    end
    dirtyscreen = true
  end
  if y == 5 and x == 16 and z == 1 then
    pattern_view = not pattern_view
    if pattern_view then
      for i = 1, 8 do
        save_pattern_bank(i, p[i].bank)
      end
    else
      copying = false
      pasting = false
    end
    dirtyscreen = true
  end
  if y == 7 and x == 16 and not pattern_view then
    collecting_notes = z == 1 and true or false
    if z == 0 and #collected_notes > 0 then
      arp_step = 0
      arp_notes = {table.unpack(collected_notes)}
    else
      collected_notes = {}
    end
    dirtyscreen = true
  end
  if y == 8 and pattern_view then
    if z == 1 and held then heldmax = 0 end
    held = held + (z * 2 - 1)
    if held > heldmax then heldmax = held end
    if z == 1 then
      if held == 1 then
        first = x
      elseif held == 2 then
        second = x
      end
      if p[pattern_focus].looping then
        p[pattern_focus].looping = false
        clock.run(function()
          local sync = params:get("patterns_countin"..pattern_focus) == 2 and 1 or (params:get("patterns_countin"..pattern_focus) == 3 and 4 or pattern[pattern_focus].quantize)
          clock.sync(sync)
          if not p[pattern_focus].looping then
            pattern[pattern_focus].step = 0
            pattern[pattern_focus].step_min = 0
            pattern[pattern_focus].step_max = pattern[pattern_focus].endpoint
          end
        end)
      end
    else
      if held == 1 and heldmax == 2 then
        local segment = util.round(pattern[pattern_focus].endpoint / 16, 1)
        pattern[pattern_focus].step_min = segment * (math.min(first, second) - 1)
        pattern[pattern_focus].step_max = segment * math.max(first, second)
        p[pattern_focus].looping = true
      end
    end
  end
end

function g.key(x, y, z)
  func_keys(x, y, z)
  if y == 1 and x > 4 and x < 13 and z == 1 then
    local i = x - 4
    pattern_keys(i)
  end
  -- pattern view
  if pattern_view then
    if z == 1 then
      if y == 1 and (x < 3 or x > 14) then
        local bank = x < 3 and x or x - 12
        if pasting and copy_src.state then
          copy_pattern(copy_src.pattern, copy_src.bank, pattern_focus, bank)
          show_message("pasted to pattern "..pattern_focus.." bank "..bank)
          copying = false
          copy_src = {state = false, pattern = nil, bank = nil}
        elseif pasting and not copy_src.state then
          pasting = false
          show_message("clipboard empty")
        elseif copying and not copy_src.state then
          copy_src.pattern = pattern_focus
          copy_src.bank = bank
          copy_src.state = true
          show_message("pattern "..copy_src.pattern.." bank "..copy_src.bank.." selected")
        else
          if mod_a or mod_b then
            for i = 1, 8 do
              save_pattern_bank(i, p[i].bank)
            end
          else
            save_pattern_bank(pattern_focus, p[pattern_focus].bank)
          end
        end
      elseif y == 4 and x == 1 then
        copying = not copying
        if not copying then
          copy_src = {state = false, pattern = nil, bank = nil}
        end
        if copying and pasting then pasting = false end
      elseif y == 5 and x == 1 then
        pasting = not pasting
      elseif x > 4 and x < 13 then
        local i = x - 4
        -- set focus
        if (mod_a or mod_b) then
          if y > 4 and y < 7 then
            if pattern_focus ~= i then
              pattern_focus = i
            end
              pattern[pattern_focus].endpoint = pattern[pattern_focus].endpoint_init
              pattern[pattern_focus].step_max = pattern[pattern_focus].endpoint_init
            if (pattern[pattern_focus].endpoint_init % 64 ~= 0 or pattern[pattern_focus].endpoint_init < 128) then
              pattern[pattern_focus].manual_length = true
            end
          end
        else
          if y < 7 then
            if pattern_focus ~= i then
              pattern_focus = i
            end
          end
        end
        -- set params
        if y == 3 then
          if mod_b and not mod_a then
            params:set("patterns_beatnum"..pattern_focus, i)
            if pattern[pattern_focus].manual_length then
              pattern[pattern_focus].manual_length = false
              pattern[pattern_focus].length = pattern[pattern_focus].meter * pattern[pattern_focus].beatnum
              pattern[pattern_focus]:set_length(pattern[pattern_focus].length)
            end
          elseif mod_a and not mod_b then
            params:set("patterns_meter"..pattern_focus, i)
            if pattern[pattern_focus].manual_length then
              pattern[pattern_focus].manual_length = false
              pattern[pattern_focus].length = pattern[pattern_focus].meter * pattern[pattern_focus].beatnum
              pattern[pattern_focus]:set_length(pattern[pattern_focus].length)
            end
          elseif not mod_a and not mod_b then
            local val = params:get("patterns_countin"..i)
            val = util.wrap(val + 1, 1, 3)
            params:set("patterns_countin"..i, val)
          end
        elseif y == 4 then
          if mod_b and not mod_a then
            params:set("patterns_beatnum"..pattern_focus, i + 8)
            if pattern[pattern_focus].manual_length then
              pattern[pattern_focus].manual_length = false
              pattern[pattern_focus].length = pattern[pattern_focus].meter * pattern[pattern_focus].beatnum
              pattern[pattern_focus]:set_length(pattern[pattern_focus].length)
            end
          elseif not mod_a and not mod_b then
            params:set("patterns_playback"..i, pattern[i].loop == 0 and 1 or 2)
          end
        end
        dirtyscreen = true
      end
    elseif z == 0 then
      if y == 1 and (x < 3 or x > 14) then
        local bank = x < 3 and x or x - 12
        if pasting and not copying then
          pasting = false
        elseif not copying and not pasting then
          if mod_a or mod_b then
            for i = 1, 8 do
              if p[i].bank ~= bank then
                p[i].load = bank
                if pattern[i].play == 0 then
                  set_pattern_bank(i)
                end
              end
            end
          else
            if p[pattern_focus].bank ~= bank then
              p[pattern_focus].load = bank
              if pattern[pattern_focus].play == 0 then
                set_pattern_bank(pattern_focus)
              end
            elseif p[pattern_focus].load then
              p[pattern_focus].load = nil
            end
          end
        end
      end
    end
  else
    if z == 1 then
      if y == 1 then
        -- set interval_focus
        if (x == 1 or x == 2 or x == 15 or x == 16) then
          local i = x < 3 and x or x - 12
          if (mod_a or mod_b) then
            params:set("voice_mute"..i, voice[i].mute and 1 or 2)
          elseif not voice[i].mute then
            int_focus = i
          end
        end
      elseif y == 2 then
        -- set key focus
        if (x == 1 or x == 2 or x == 15 or x == 16) then
          local i = x < 3 and x or x - 12
          if (mod_a or mod_b) then
            params:set("voice_mute"..i, voice[i].mute and 1 or 2)
          elseif not voice[i].mute then
            key_focus = i
          end
        end
      elseif y == 3 then
        -- play home note
        if x > 7 and x < 10 then
          local home_note = tab.key(scale_notes, params:get("root_note"))
          if not transpose then
            if not mute_int then
              local e = {t = eINT, i = int_focus, root = root_oct, note = home_note} event(e)
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
        elseif x > 3 and x < 8 then
          local interval = x - 8
          local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
          if not transpose then
            if not mute_int then
              local e = {t = eINT, i = int_focus, root = root_oct, note = new_note} event(e)
            end
          else
            local e = {t = eTRANSPOSE, interval = interval} event(e)
          end
          notes.last = new_note
        -- interval increase
        elseif x > 9 and x < 14 then
          local interval = x - 9
          local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
          if not transpose then
            if not mute_int then
              local e = {t = eINT, i = int_focus, root = root_oct, note = new_note} event(e)
            end
          else
            local e = {t = eTRANSPOSE, interval = interval} event(e)
          end
          notes.last = new_note
        -- toggle quantization
        elseif x > 7 and x < 10 then
          link_clock = clock.run(
            function()
              clock.sleep(1)
              key_link = not key_link
            end
          )
        elseif x == 16 then
          key_quantize = not key_quantize
        end
      elseif y == 5 then
        -- interval octave down
        if x == 1 then
          notes.oct_int = util.clamp(notes.oct_int - 1, -3, 3)
        -- play last note
        elseif x > 7 and x < 10 then
          if not transpose then
            if not mute_int then
              local e = {t = eINT, i = int_focus, root = root_oct, note = notes.last} event(e)
            end
          else
            local octave = (#scale_intervals[params:get("scale")] - 1) * (x - 8 == 0 and -1 or 1)
            local e = {t = eTRANSPOSE, interval = octave} event(e)
          end
        end
      -- key octave up
      elseif y == 7 and x == 1 then
        notes.oct_key = util.clamp(notes.oct_key + 1, -3, 3)
      -- key octave down
      elseif y == 8 and x == 1 then
        notes.oct_key = util.clamp(notes.oct_key - 1, -3, 3)
      -- toggle arp state
      elseif y == 8 and x == 16 then
          arp_active = not arp_active
          if arp_active then
            if arp_clock then
              clock.cancel(arp_clock)
              arp_step = 0
            end
            arp_clock = clock.run(make_arp)
          else
            if arp_clock then
              clock.cancel(arp_clock)
              arp_step = 0
            end
            arp_notes = {}
          end
      -- play keys
      elseif (y == 7 or y == 8) and x > 2 and x < 15 then
        local octave = #scale_intervals[params:get("scale")] - 1
        if params:get("keyboard_type") == 1 then
          local note = (x - 2) + ((8 - y) * 3) + (notes.oct_key + 3) * octave
          if collecting_notes then
            table.insert(collected_notes, note)
          elseif arp_active then
            table.insert(arp_notes, note)
          end
          if not (mute_key or arp_active) then
            local e = {t = eKEY, i = key_focus, root = root_oct, note = note} event(e)
          end
          if key_link and not transpose then
            notes.last = note + octave * notes.oct_int
          end
        else
          local note = (60 + x - 3) + (notes.oct_key + 8 - y) * 12
          if tab.key(scale_notes, note) ~= nil then
            if collecting_notes then
              table.insert(collected_notes, tab.key(scale_notes, note))
            elseif arp_active then
              table.insert(arp_notes, tab.key(scale_notes, note))
            end
            if not (mute_key or arp_active) then
              local e = {t = eKEY, i = key_focus, root = root_oct, note = tab.key(scale_notes, note)} event(e)
            end
            if key_link and not transpose then
              notes.last = tab.key(scale_notes, note) + octave * notes.oct_int
            end
          end
        end
      end
    elseif z == 0 then
      if y == 4 and x > 7 and x < 10 then
        if link_clock ~= nil then
         clock.cancel(link_clock)
        end
      end
    end
  end
  dirtygrid = true
end

function gridredraw()
  g:all(0)
  -- patterns
  for i = 1, 8 do
    if pattern[i].rec == 1 and pattern[i].play == 1 then
      g:led(i + 4, 1, ledfast)
    elseif pattern[i].rec_enabled == 1 then
      g:led(i + 4, 1, 15)
    elseif pattern[i].play == 1 then
      g:led(i + 4, 1, p[i].key_flash and 15 or 12)
    elseif pattern[i].count > 0 then
      g:led(i + 4, 1, 6)
    else
      g:led(i + 4, 1, 2)
    end
  end
  g:led(4, 2, mod_a and 15 or 8) 
  g:led(13, 2, mod_b and 15 or 8)
  g:led(16, 5, pattern_view and 10 or 4) -- pattern view
  if params:get("metronome_viz") == 2 then
    g:led(16, 4, flash_bar and 15 or (flash_beat and 8 or (key_quantize and 3 or 6))) -- Q flash
  else
    g:led(16, 4, key_quantize and 6 or 3) -- Q flash
  end

  if pattern_view then
    g:led(1, 4, (copying and not copy_src.state) and ledslow or (copy_src.state and 10 or 4))
    g:led(1, 5, pasting and ledslow or 4)
    for i = 1, 2 do
      g:led(i, 1, p[pattern_focus].load == i and ledslow or (p[pattern_focus].bank == i and (p[pattern_focus].count[i] > 0 and 15 or 8) or 4))
      g:led(i + 14, 1, p[pattern_focus].load == i + 2 and ledslow or (p[pattern_focus].bank == i + 2 and (p[pattern_focus].count[i + 2] > 0 and 15 or 8) or 4))
    end
    for i = 1, 8 do
      if mod_b and not mod_a then
        g:led(i + 4, 3, params:get("patterns_beatnum"..pattern_focus) == i and 15 or 4)
        g:led(i + 4, 4, params:get("patterns_beatnum"..pattern_focus) == i + 8 and 15 or 4)
      elseif mod_a and not mod_b then
        g:led(i + 4, 3, params:get("patterns_meter"..pattern_focus) == i and 15 or 4)
        g:led(i + 4, 4, 1)
      else
        g:led(i + 4, 3, params:get("patterns_countin"..i) == 1 and 2 or (params:get("patterns_countin"..i) == 2 and 6 or 12))
        g:led(i + 4, 4, pattern[i].loop == 0 and 1 or 4)
      end
      g:led(i + 4, 5, pattern_focus == i and 10 or 1)
      g:led(i + 4, 6, pattern_focus == i and 10 or 1)
    end
    if p[pattern_focus].looping then
      local min = math.min(first, second)
      local max = math.max(first, second)
      for i = min, max do
        g:led(i, 8, 4)
      end
    end
    g:led(pattern[pattern_focus].position, 8, pattern[pattern_focus].play == 1 and 10 or 0)
  else
    -- focus
    g:led(1, 1, voice[1].mute and 2 or (int_focus == 1 and 10 or 4))
    g:led(2, 1, voice[2].mute and 2 or (int_focus == 2 and 10 or 4))
    g:led(15, 1, voice[3].mute and 2 or (int_focus == 3 and 10 or 4))
    g:led(16, 1, voice[4].mute and 2 or (int_focus == 4 and 10 or 4))
    g:led(1, 2, voice[1].mute and 2 or (key_focus == 1 and 10 or 4))
    g:led(2, 2, voice[2].mute and 2 or (key_focus == 2 and 10 or 4))
    g:led(15, 2, voice[3].mute and 2 or (key_focus == 3 and 10 or 4))
    g:led(16, 2, voice[4].mute and 2 or (key_focus == 4 and 10 or 4))
    -- interval
    for i = 8, 9 do
      g:led(i, 4, key_link and 2 or 0) -- key link
      g:led(i, 3, 6) -- home
      g:led(i, 5, 10) -- interval 0
    end
    for i = 1, 4 do
      g:led(i + 3, 4, 12 - i * 2) -- intervals dec
      g:led(i + 9, 4, 2 + i * 2) -- intervals inc
    end
    -- int octave
    g:led(1, 4, 8 + notes.oct_int * 2)
    g:led(1, 5, 8 - notes.oct_int * 2)
    -- key octave
    g:led(1, 7, 8 + notes.oct_key * 2)
    g:led(1, 8, 8 - notes.oct_key * 2)
    -- arpeggiator
    g:led(16, 7, collecting_notes and 12 or 4)
    g:led(16, 8, arp_active and 10 or 2)
    -- keyboard
    if params:get("keyboard_type") == 1 then
      for i = 1, 12 do
        local octave = #scale_intervals[params:get("scale")] - 1
        g:led(i + 2, 7, ((i + 3) % octave) == 1 and 12 or 3)
        g:led(i + 2, 8, (i % octave) == 1 and 12 or 3)
      end
    else
      for i = 1, 12 do
        for j = 1, 2 do
          g:led(i + 2, j + 6, notes.root[i] and 12 or (notes.key[i] and 8 or 0)) -- keyboard
        end
      end
    end
  end
  g:refresh()
end


-------- utilities --------
function r()
  norns.script.load(norns.state.script)
end

function show_message(message)
  clock.run(
    function()
      view_message = message
      dirtyscreen = true
      if string.len(message) > 20 then
        clock.sleep(1.6) -- long display time
        view_message = ""
        dirtyscreen = true
      else
        clock.sleep(0.8) -- short display time
        view_message = ""
        dirtyscreen = true
      end
    end
  )
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
  for i = 1, NUM_VOICES do
    if voice[i].output == 3 then
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
    if voice[i].output == 4 then
      if (params:get("clock_crow_out") == 2 or params:get("clock_crow_out") == 3) then
        params:set("clock_crow_out", 1)
      end
    end
    if voice[i].output == 5 then
      if (params:get("clock_crow_out") == 4 or params:get("clock_crow_out") == 5) then
        params:set("clock_crow_out", 1)
      end
    end
    if voice[i].output == 6 then
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
  if params:get("glb_midi_in_quantization") == 1 then
    params:hide("midi_in_scale")
  else
    params:show("midi_in_scale")
  end
  _menu.rebuild_params()
  dirtyscreen = true
end

function page_redraw(page)
  if main_pageNum == page then
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
end
