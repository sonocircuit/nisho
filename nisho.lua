-- nisho v1.3.0 @sonocircuit
-- llllllll.co/t/nisho
--
-- six voices and
-- many other things
--
-- for docs go to:
-- >> github.com/sonocircuit
--    /nisho
--
-- or smb into:s
-- >> code/nisho/doc
--

---------------------------------------------------------------------------
-- BUG: patterns not catching more than 1 note at step_one -- with chords, no notes at all
-- BUG: occasional stuck midi notes. need to reproduce scenarios to debug.
---------------------------------------------------------------------------

engine.name = "Moonunit" 

mu = require ("musicutil")

softsync = include ("lib/nishos_softsync")
mirror = include ("lib/nishos_reflection")
moonunit = include ("lib/nishos_moonunit")
smpls = include ("lib/nishos_samples")
grd_zero = include ("lib/grid_zero")
grd_one = include ("lib/grid_one")
nb = include ("nb/lib/nb")

g = grid.connect()

-------- variables --------
load_pset = false
GRIDSIZE = 0
NUM_VOICES = 6

pageNum = 1
pattern_view = false
sample_view = false
sampl_param = 1
int_focus = 1
key_focus = 1
pattern_focus = 1
voice_focus = 1
viewinfo = 0
shift = false

mod_a = false
mod_b = false
mod_c = false
mod_d = false

key_link = true
transposing = false
transpose_value = 0

flash_bar = false
flash_beat = false
ledfast = 8
ledslow = 4

key_quantize = false
quant_rate = 16
quant_event = {}

v8_std_1 = 12
v8_std_2 = 12
env1_amp = 8
env1_a = 0
env1_r = 0.4
env2_amp = 8
env2_a = 0
env2_r = 0.4
wsyn_amp = 5

pool_count_1 = 0
pool_count_2 = 0

midi_in_dev = 8
midi_in_ch = 1
midi_in_dest = 0
midi_out_dev = 7
midi_out_ch = 1
midi_thru = false

seq_notes = {}
collected_notes = {}
seq_active = false
collecting_notes = false
appending_notes = false
seq_step = 0
seq_rate = 1/4
see_hold = false
retrig_mode = false
key_repeat = false
last_velocity = 100
rep_rate = 1/4
heldkey = 0

chord_play = true
chord_strum = false
chord_harp = false
strum_direction = 1
strum_rate = 0.1
strum_step = 0
strum_num = 6
strum_options = false

pattern_rec_mode = "queued"
pattern_overdub = false
copying_pattern = false
copy_src = {state = false, pattern = nil, bank = nil}
pasting_pattern = false
duplicating_pattern = false
appending_pattern = false
pattern_meter_config = false
pattern_length_config = false
pattern_options_config = false
pattern_reset = false
pattern_clear = false

key_reset = false --?? not assigned to anything, right?

eSCALE = 1
eKEYS = 2
eDRUMS = 3
eMIDI = 4
eTRSP_SCALE = 5
eSMPL = 6

view_message = ""
waveform_samples = {}


-------- tables --------
options = {}
options.key_quant = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
options.quant_value = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
options.pattern_mode = {"manual", "synced"}
options.pattern_play = {"loop", "oneshot"}
options.pattern_countin = {"none", "beat", "bar"}
options.pattern_quantize = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/24", "1/32", "3/128", "1/48", "1/64"}
options.pattern_quantize_value = {1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}
options.pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
options.meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}
options.output = {"moonunit [one]", "moonunit [two]", "midi", "crow 1+2", "crow 3+4", "crow ii jf", "crow ii wsyn", "nb [one]", "nb [two]"}

voice = {}
for i = 1, NUM_VOICES + 1 do -- 6 voices
  voice[i] = {}
  voice[i].output = 1
  voice[i].mute = false
  voice[i].length = 0.2
  voice[i].velocity = 100
  voice[i].midi_ch = i
  voice[i].jf_ch = i
  voice[i].jf_amp = 5
end

notes = {}
notes.oct_int = 0
notes.oct_key = 0
notes.last = 1
notes.home = 1
notes.viz = 60
notes.chord = {}
notes.held = {}
notes.root = {}
notes.key = {}
for i = 1, 12 do
  notes.root[i] = nil
  notes.key[i] = nil
end

chord_arp = {}
chord = {}
for i = 1, 12 do
  chord[i] = {}
end

m = {}
for i = 1, 8 do -- 6 voices + in/out
  m[i] = midi.connect()
end

gkey = {}
for x = 1, 16 do
  gkey[x] = {}
  for y = 1, 16 do
    gkey[x][y] = {}
    gkey[x][y].note = 0
    gkey[x][y].active = false
    gkey[x][y].chord = false
  end
end

held = {}
for i = 1, 8 do
  held[i] = {}
  held[i].num = 0
  held[i].max = 0
  held[i].first = 0
  held[i].second = 0
end

held_sample = {}
for i = 1, 5 do
  held_sample[i] = 0
end

voice_params = {
  {"main_amp1", "sine_amp1", "saw_amp1", "pulse_amp1", "noise_amp1", "supersaw1", "pulse_width1", "pwm_rate1", "pwm_depth1", "lpf_cutoff1", "lpf_resonance1", "env_lpf_depth1", "attack1", "release1"}, --moonunit [one]
  {"main_amp2", "sine_amp2", "saw_amp2", "pulse_amp2", "noise_amp2", "supersaw2", "pulse_width2", "pwm_rate2", "pwm_depth2", "lpf_cutoff2", "lfp_resonance2", "env_lpf_depth2", "attack2", "release2"}, --moonunit [two]
  {"note_length", "note_velocity", "midi_channel", "midi_device"}, --midi
  {"env1_amplitude", "env1_attack", "env1_decay"}, --crow 1+2
  {"env2_amplitude", "env2_attack", "env2_decay"}, --crow 3+4
  {"jf_mode", "jf_amp", "jf_voice"}, --crow ii jf
  {"wysn_mode", "wsyn_amp", "wsyn_curve", "wsyn_ramp", "wsyn_lpg_time", "wsyn_lpg_sym", "wsyn_fm_index", "wsyn_fm_env", "wsyn_fm_num", "wsyn_fm_den"} --crow ii wsyn
}

voice_param_names = {
  {"main level", "sine level", "saw level", "pulse level", "noise level", "supersaw", "pulse width", "pwm rate", "pwm depth", "cutoff", "resonance", "env depth", "attack", "release"}, --moonunit [one]
  {"main level", "sine level", "saw level", "pulse level", "noise level", "supersaw", "pulse width", "pwm rate", "pwm depth", "cutoff", "resonance", "env depth", "attack", "release"}, --moonunit [two]
  {"note length", "velocity", "channel", "device"}, --midi
  {"amplitude", "attack", "decay"}, --crow 1+2
  {"amplitude", "attack", "decay"}, --crow 3+4
  {"mode", "level", "voice"}, --crow ii jf
  {"mode", "level", "curve", "ramp", "lpg time", "lpg sym", "fm index", "fm env", "fm num", "fm den"} --crow ii wsyn
}

param_focus = {}
for i = 1, NUM_VOICES do
  param_focus[i] = 1
end

-------- scales --------
root_oct = 3
scale_notes = {}
note_map = {}
chord_map = {}
for i = 1, 12 do
  chord_map[i] = {}
end
chord_inversion = 0

-- note viz stuff
notenum_w = {24, 26, 28, 29, 31, 33, 35}
notenum_ba = {25, 27}
notenum_bb = {30, 32, 34}

noteis_w = {}
noteis_ba = {}
noteis_bb = {}

function build_scale()
  local root = params:get("root_note") % 12 + 24
  root_oct = math.floor((params:get("root_note") - root) / 12)
  scale_notes = mu.generate_scale_of_length(root, params:get("scale"), 50)
  local num_to_add = 50 - #scale_notes
  for i = 1, num_to_add do
    table.insert(scale_notes, scale_notes[50 - num_to_add])
  end
  set_root()
  set_keys()
end

function build_scale_map()
  note_map = mu.generate_scale_of_length(0, params:get("scale"), 100)
  local num_to_add = 100 - #scale_notes
  for i = 1, num_to_add do
    table.insert(scale_notes, scale_notes[100 - num_to_add])
  end
end

function build_chord_map()
  for i = 1, 12 do
    local note_num = 60 + (i - 1)
    chord_map[i] = {}
    chord_map[i] = mu.chord_types_for_note(note_num, params:get("root_note") % 12 + 24, scale_names[params:get("scale")])
    --print("note"..mu.note_num_to_name(note_num))
    --tab.print(chord_map[i])
  end
  set_chords()
end

function build_strum(notes)
  if #notes > 0 then
    chord_arp = {table.unpack(notes)}
    for i = 1, strum_num - 3 do
      table.insert(chord_arp, chord_arp[i] + 12)
    end
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
  noteis_w = {}
  noteis_ba = {}
  noteis_bb = {}
  for i, v in ipairs(notenum_w) do
    table.insert(noteis_w, notelookup(v))
  end
  for i, v in ipairs(notenum_ba) do
    table.insert(noteis_ba, notelookup(v))
  end
  for i, v in ipairs(notenum_bb) do
    table.insert(noteis_bb, notelookup(v))
  end
end

function set_chords()
  local off = GRIDSIZE == 128 and 0 or 8
  for i = 1, 12 do
    local x = i + 2
    for y = 5 + off, 7 + off do
      gkey[x][y].chord = false
    end
    if #chord_map[i] > 1 then
      for index, value in ipairs(chord_map[i]) do
        if value == "Major" then
          gkey[x][5 + off].chord = true
        elseif value == "Minor" then
          gkey[x][6 + off].chord = true
        elseif value == "Sus4" then
          gkey[x][7 + off].chord = true
        end
      end
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

function get_chord_type(x)
  local off = GRIDSIZE == 128 and 8 or 0
  if gkey[x][13 - off].active and gkey[x][14 - off].active and gkey[x][15 - off].active then
    return "Augmented"
  elseif not gkey[x][13 - off].active and gkey[x][14 - off].active and gkey[x][15 - off].active then
    return "Minor 7"
  elseif gkey[x][13 - off].active and not gkey[x][14 - off].active and gkey[x][15 - off].active then
    return "Major 7"
  elseif gkey[x][13 - off].active and gkey[x][14 - off].active and not gkey[x][15 - off].active then
    return "Diminished"
  elseif not gkey[x][13 - off].active and gkey[x][14 - off].active and not gkey[x][15 - off].active then
    return "Minor"
  elseif gkey[x][13 - off].active and not gkey[x][14 - off].active and not gkey[x][15 - off].active then
    return "Major"
  elseif not gkey[x][13 - off].active and not gkey[x][14 - off].active and gkey[x][15 - off].active then
    return "Sus4"
  end
end

function set_scale()
  build_scale()
  build_scale_map()
  build_chord_map()
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
  params:set("voice_out5", 3)
  params:set("voice_out6", 3)
end

function set_my_defaults()
  params:set("voice_out1", 1)
  params:set("voice_out2", 2)
  params:set("voice_out3", 3)
  params:set("midi_channel3", 4)
  params:set("voice_out4", 3)
  params:set("midi_channel4", 5)
  params:set("voice_out5", 3)
  params:set("midi_channel5", 6)
  params:set("voice_out6", 9)
end


-------- pattern recording --------

-- exec function
function event_exec(e)
  if e.t == eSCALE then
    local octave = (root_oct - e.root) * (#scale_intervals[params:get("scale")] - 1)
    local idx = util.clamp(e.note + transpose_value + octave, 1, #scale_notes)
    local note_num = scale_notes[idx]
    if e.action == "note_off" and params:get("note_length"..e.i) == 0 then
      mute_voice(e.i, note_num)
      remove_active_notes(e.p, e.i, note_num)
    elseif e.action == "note_on" then
      play_voice(e.i, note_num)
      add_active_notes(e.p, e.i, note_num)
      notes.viz = note_num
    end
  elseif e.t == eKEYS then
    if e.action == "note_off" and params:get("note_length"..e.i) == 0 then
      mute_voice(e.i, e.note)
      remove_active_notes(e.p, e.i, e.note)
    elseif e.action == "note_on" then
      play_voice(e.i, e.note)
      add_active_notes(e.p, e.i, e.note)
      notes.viz = e.note
    end
  elseif e.t == eDRUMS then
    play_voice(e.i, e.note, e.vel)
    clock.run(function()
      clock.sync(1/8)
      mute_voice(e.i, e.note)
    end)
  elseif e.t == eTRSP_SCALE then
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
        m[midi_out_dev]:note_on(e.note, e.vel, e.ch)
        add_active_notes(e.p, 7, e.note)
      elseif e.action == "note_off" then
        if params:get("glb_midi_in_quantization") == 2 then
          e.note = mu.snap_note_to_array(e.note, note_map)
        end
        m[midi_out_dev]:note_off(e.note, 0, e.ch)
        remove_active_notes(e.p, 7, e.note)
      end
    elseif e.dest > 0 then
      if params:get("glb_midi_in_quantization") == 2 then
        e.note = mu.snap_note_to_array(e.note, note_map)
      end
      if e.action == "note_on" then
        play_voice(e.dest, e.note, e.vel)
        add_active_notes(e.p, e.dest, e.note)
        notes.viz = e.note
      elseif e.action == "note_off" then
        mute_voice(e.dest, e.note, e.vel)
        remove_active_notes(e.p, e.dest, e.note)
      end
    end
  elseif e.t == eSMPL then
    if e.action == "play" then
      smpls.play(e.bank, e.slot)
      smpls.gridviz(e.bank, e.slot)
    end
  end
  dirtyscreen = true
end

pattern = {}
for i = 1, 8 do
  pattern[i] = mirror.new("pattern "..i)
  pattern[i].process = event_exec
  pattern[i].start_callback = function() step_one_indicator(i) set_pattern_length(i) kill_active_notes(i) end
  pattern[i].end_of_loop_callback = function() set_pattern_bank(i) end
  pattern[i].end_of_rec_callback = function() clock.run(function() clock.sleep(0.2) save_pattern_bank(i, p[i].bank) end) end
  pattern[i].end_callback = function() kill_active_notes(i) dirtygrid = true end
  pattern[i].step_callback = function() if (pattern_view or GRIDSIZE == 256) then dirtygrid = true end end
  pattern[i].active_notes = {}
  for voice = 1, NUM_VOICES + 1 do
    pattern[i].active_notes[voice] = {}
  end
end

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
end

function event(e)
  if key_quantize and not key_repeat then
    table.insert(quant_event, e)
  else
    event_record(e)
    event_exec(e)
  end
end

function event_q_clock()
  while true do
    clock.sync(quant_rate)
    if #quant_event > 0 then
      for k, e in pairs(quant_event) do
        event_record(e)
        event_exec(e)
      end
      quant_event = {}
    end
  end
end

p = {}
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
  p[i].step_min_viz = {}
  p[i].step_max_viz = {}
  p[i].beatnum = {}
  p[i].meter = {}
  p[i].length = {}
  p[i].manual_length = {}
  for j = 1, 3 do
    p[i].loop[j] = 1
    p[i].quantize[j] = 1/4
    p[i].count[j] = 0
    p[i].event[j] = {}
    p[i].endpoint[j] = 0
    p[i].endpoint_init[j] = 0
    p[i].step_min[j] = 0
    p[i].step_max[j] = 0
    p[i].step_min_viz[j] = 0
    p[i].step_max_viz[j] = 0
    p[i].beatnum[j] = 16
    p[i].meter[j] = 4/4
    p[i].length[j] = 16
    p[i].manual_length[j] = false
  end
end

function deep_copy(tbl)
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
    save_pattern_bank(i, p[i].bank)
  end
end

function update_pattern_length(i)
  if pattern[i].play == 0 then
    pattern[i].length = pattern[i].meter * pattern[i].beatnum
    pattern[i]:set_length(pattern[i].length)
    save_pattern_bank(i, p[i].bank)
  end
end

function reset_pattern_length(i, bank)
  p[i].endpoint[bank] = p[i].endpoint_init[bank]
  p[i].step_max[bank] = p[i].endpoint_init[bank]
  if (p[i].endpoint_init[bank] % 64 ~= 0 or p[i].endpoint_init[bank]< 128) then
    p[i].manual_length[bank] = true
  end
  if bank == p[i].bank then
    load_pattern_bank(i, bank)
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
    if (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config) then dirtyscreen = true end
  end
end

function clear_pattern_loops()
  for i = 1, 8 do
    if p[i].looping then
      p[i].looping = false
      clock.run(function()
        clock.sync(4)
        pattern[i].step = 0
        pattern[i].step_min = 0
        pattern[i].step_max = pattern[i].endpoint
        -- restore these so the loop points aren't saveed to the pattern bank
        p[i].step_min[p[i].bank] = 0
        p[i].step_max[p[i].bank] = pattern[i].endpoint
      end)
    end
  end
end

function add_active_notes(i, voice, note_num)
  table.insert(pattern[i].active_notes[voice], note_num)
  --tab.print(pattern[i].active_notes[voice])
end

function remove_active_notes(i, voice, note_num)
  table.remove(pattern[i].active_notes[voice], tab.key(pattern[i].active_notes[voice], note_num))
  --tab.print(pattern[i].active_notes[voice])
end

function kill_active_notes(i)
  --print("killed notes:")
  for voice = 1, NUM_VOICES do
    if #pattern[i].active_notes[voice] > 0 and pattern[i].endpoint > 0 then
      for _, note in ipairs(pattern[i].active_notes[voice]) do
        mute_voice(voice, note)
        --print(voice.." "..note)
      end
      pattern[i].active_notes[voice] = {}
    end
  end
end

function paste_seq_pattern(i)
  if #seq_notes > 0 then
    for n = 1, #seq_notes do
      local s = math.floor((n - 1) * (seq_rate * 64) + 1)
      local t = math.floor(s + (seq_rate * 64) - 1)
      --print("s = "..s.." t = "..t)
      if seq_notes[n] > 0 then
        if not pattern[i].event[s] then
          pattern[i].event[s] = {}
        end
        if params:get("keys_option"..key_focus) == 1 then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = seq_notes[n], action = "note_on"}
          table.insert(pattern[i].event[s], e)
        else
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = seq_notes[n], action = "note_on"}
          table.insert(pattern[i].event[s], e)
        end

        if not pattern[i].event[t] then
          pattern[i].event[t] = {}
        end
        if params:get("keys_option"..key_focus) == 1 then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = seq_notes[n], action = "note_off"}
          table.insert(pattern[i].event[t], e)
        else
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = seq_notes[n], action = "note_off"}
          table.insert(pattern[i].event[t], e)
        end
        pattern[i].count = pattern[i].count + 2
      end
    end
    pattern[i].endpoint = #seq_notes * (seq_rate * 64)
    pattern[i].endpoint_init = pattern[i].endpoint
    pattern[i].step_max = pattern[i].endpoint
    pattern[i].manual_length = true
    save_pattern_bank(i, p[i].bank)
  else
    show_message("seq pattern empty")
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
  p[dst].endpoint_init[dst_bank] = p[src].endpoint_init[src_bank]
  p[dst].step_min[dst_bank] = 0
  p[dst].step_max[dst_bank] = p[src].endpoint[src_bank]
  p[dst].beatnum[dst_bank] = p[src].beatnum[src_bank]
  p[dst].meter[dst_bank] = p[src].meter[src_bank]
  p[dst].length[dst_bank] = p[src].length[src_bank]
  p[dst].manual_length[dst_bank] = p[src].manual_length[src_bank]
  if dst_bank == p[dst].bank then
    load_pattern_bank(dst, dst_bank)
  end
end

function append_pattern(src, src_bank, dst, dst_bank)
  local copy = deep_copy(p[src].event[src_bank])
  for i = 1, p[src].endpoint[src_bank] do
    p[dst].event[dst_bank][p[dst].endpoint[dst_bank] + i] = copy[i]
  end
  p[dst].count[dst_bank] = p[dst].count[dst_bank] + p[src].count[src_bank]
  p[dst].endpoint[dst_bank] = p[dst].endpoint[dst_bank] + p[src].endpoint[src_bank]
  p[dst].step_max[dst_bank] = p[dst].endpoint[dst_bank]
  if not (p[src].manual_length[src_bank] or p[dst].manual_length[dst_bank]) then
    if ((p[src].length[src_bank] + p[dst].length[dst_bank]) * p[dst].meter[dst_bank]) % 4 == 0 then
      local num_beats = math.floor((p[src].length[src_bank] + p[dst].length[dst_bank]) * p[dst].meter[dst_bank])
      p[dst].beatnum[dst_bank] = num_beats
    else
      p[dst].manual_length[dst_bank] = true
    end
  end
  if dst_bank == p[dst].bank then
    load_pattern_bank(dst, dst_bank)
  end
end

function save_pattern_bank(i, bank)
  p[i].loop[bank] = pattern[i].loop
  p[i].quantize[bank] = pattern[i].quantize
  p[i].count[bank] = pattern[i].count
  p[i].event[bank] = deep_copy(pattern[i].event)
  p[i].endpoint[bank] = pattern[i].endpoint
  p[i].endpoint_init[bank] = pattern[i].endpoint_init
  p[i].beatnum[bank] = pattern[i].beatnum
  p[i].meter[bank] = pattern[i].meter
  p[i].length[bank] = pattern[i].length
  p[i].manual_length[bank] = pattern[i].manual_length
  --print("saved pattern "..i.." bank "..bank)
end

function load_pattern_bank(i, bank)
  pattern[i].count = p[i].count[bank]
  pattern[i].loop = p[i].loop[bank]
  pattern[i].quantize = p[i].quantize[bank]
  pattern[i].event = deep_copy(p[i].event[bank])
  pattern[i].endpoint = p[i].endpoint[bank]
  pattern[i].endpoint_init = p[i].endpoint_init[bank]
  pattern[i].step_min = 0
  pattern[i].step_max = p[i].endpoint[bank]
  pattern[i].beatnum = p[i].beatnum[bank]
  pattern[i].meter = p[i].meter[bank]
  pattern[i].length = p[i].length[bank]
  pattern[i].manual_length = p[i].manual_length[bank]
  p[i].looping = false
  set_pattern_params(i)
end

function clear_pattern_bank(i, bank)
  print("pattern "..i.." bank "..bank.." cleared")
  p[i].loop[bank] = 1
  p[i].quantize[bank] = 1/4
  p[i].count[bank] = 0
  p[i].event[bank] = {}
  p[i].endpoint[bank] = 0
  p[i].endpoint_init[bank] = 0
  p[i].step_min[bank] = 0
  p[i].step_max[bank] = 0
  p[i].beatnum[bank] = 16
  p[i].meter[bank] = 4/4
  p[i].length[bank] = 16
  p[i].manual_length[bank] = false
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

function midi.add()
  build_midi_device_list()
end

function midi.remove()
  clock.run(
    function()
      clock.sleep(0.2)
      build_midi_device_list()
    end
  )
end

function clock.transport.start()
  --?? what here / ideas ??
end

function clock.transport.stop()
  for i = 1, 8 do
    pattern[i]:stop()
    --pattern[i]:end_playback()
  end
  seq_active = false
  seq_step = 0
  dirtygrid = true
  all_notes_off()
end

function notes_off(i) -- per voice
  if i < 7 then
    m[i]:cc(123, 0, voice[i].midi_ch)
  end
end

function all_notes_off() -- all voices
  for i = 1, NUM_VOICES do
    m[i]:cc(123, 0, voice[i].midi_ch)
  end
end

function midi_events(data)
  local msg = midi.to_msg(data)
  if msg.ch == midi_in_ch then
    if msg.type == "note_on" or msg.type == "note_off" then
      local e = {t = eMIDI, p = pattern_focus, action = msg.type, note = msg.note, vel = msg.vel, ch = midi_out_ch, dest = midi_in_dest} event(e)
    end
  end
end

function set_midi_event_callback()
  midi.cleanup()
  m[midi_in_dev].event = midi_events
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

function toggle_seq()
  seq_active = not seq_active
  seq_step = 0
  if not seq_active then
    seq_notes = {}
  end
end

function run_seq()
  while true do
    clock.sync(seq_rate)
    if seq_step >= #seq_notes then
      seq_step = 0
    end
    seq_step = seq_step + 1
    if #seq_notes > 0 and seq_active then
      if seq_notes[seq_step] > 0 then
        local current_note = seq_notes[seq_step]
        if params:get("keys_option"..key_focus) == 1 then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = current_note, action = "note_on"} event(e)
        elseif params:get("keys_option"..key_focus) == 2 or params:get("keys_option"..key_focus) == 3 then
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = current_note, action = "note_on"} event(e)
        end
        if params:get("keys_option"..key_focus) == 1 then
          clock.run(function()
            clock.sync(seq_rate)
            local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = current_note, action = "note_off"} event(e)
          end)
        elseif params:get("keys_option"..key_focus) == 2 or params:get("keys_option"..key_focus) == 3 then
          clock.run(function()
            clock.sync(seq_rate)
            local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = current_note, action = "note_off"} event(e)
          end)    
        end
      end
    end
  end
end

function run_retrig()
  while true do
    clock.sync(rep_rate)
    -- note key repeat
    if key_repeat and #notes.held > 0 then
      for _, v in ipairs(notes.held) do
        if params:get("keys_option"..key_focus) == 1 then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = v, action = "note_on"} event(e)
        elseif params:get("keys_option"..key_focus) == 4 then
          local e = {t = eDRUMS, i = key_focus, note = v, vel = last_velocity} event(e)
        else
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = v, action = "note_on"} event(e)
        end
      end
    end
    -- sample key repeat // TODO: revisit this
    for bank = 1, 5 do
      if key_repeat and held_sample[bank] > 0 then
        local e = {t = eSMPL, action = "play", bank = bank, slot = held_sample[bank]} event(e)
      end
    end

  end
end

function autoharp()
  for i = 1, #chord_arp do
    local step = i
    if strum_direction == -1 then
      step = #chord_arp - (i - 1)
    end
    local note = chord_arp[step]
    local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = note, action = "note_on"} event(e)
    clock.run(function()
      clock.sleep(strum_rate)
      local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = note, action = "note_off"} event(e)
    end)
    clock.sleep(strum_rate)
  end
end

function get_repeat_rate()
  local off = GRIDSIZE == 128 and 0 or 8
  -- get key state
  local key1 = gkey[16][5 + off].active
  local key2 = gkey[16][6 + off].active
  local key3 = gkey[16][7 + off].active
  local key4 = gkey[16][8 + off].active
  -- get key_repeat state
  if (key1 or key2 or key3 or key4) then
    key_repeat = true
  else
    key_repeat = false
  end
  -- get repeat rate
  if key1 and not (key2 or key3 or key4) then
    rep_rate = 1/4 * 4
  elseif key2 and not (key1 or key3 or key4) then
    rep_rate = 1/8 * 4
  elseif key3 and not (key1 or key2 or key4) then
    rep_rate = 1/16 * 4
  elseif key4 and not (key1 or key2 or key3) then
    rep_rate = 1/32 * 4
  elseif key1 and key2 and not (key3 or key4) then
    rep_rate = 3/16 * 4
  elseif key2 and key3 and not (key1 or key4) then
    rep_rate = 3/32 * 4
  elseif key3 and key4 and not (key1 or key2) then
    rep_rate = 3/64 * 4
  elseif key1 and key3 and not (key2 or key4) then
    rep_rate = 1/6 * 4
  elseif key2 and key4 and not (key1 or key3) then
    rep_rate = 1/12 * 4
  elseif key1 and key4 and not (key2 or key3) then
    rep_rate = 1/24 * 4
  end
end


-------- init funtion --------
function init()
  -- get eng to softcut level
  eng_level = params:get("cut_input_eng")
  params:set("cut_input_eng", -inf)

  -- calc grid size
  get_grid_size()
  
  -- nb
  nb:init()

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

  params:add_option("key_quant_value", "key quantization", options.key_quant, 7)
  params:set_action("key_quant_value", function(idx) quant_rate = options.quant_value[idx] * 4 end)
  params:hide("key_quant_value")

  params:add_option("key_seq_rate", "seq rate", options.key_quant, 7)
  params:set_action("key_seq_rate", function(idx) seq_rate = options.quant_value[idx] * 4 end)
  params:hide("key_seq_rate")

  params:add_group("global_midi_group", "midi settings", 11)

  params:add_separator("glb_midi_in_params", "midi in")

  params:add_option("glb_midi_in_device", "midi in device", midi_devices, 1)
  params:set_action("glb_midi_in_device", function(val) m[midi_in_dev] = midi.connect(val) set_midi_event_callback() end)

  params:add_number("glb_midi_in_channel", "midi in channel", 1, 16, 14)
  params:set_action("glb_midi_in_channel", function(val) notes_off(midi_in_dev) midi_in_ch = val end)

  params:add_option("glb_midi_in_quantization", "map to scale", {"no", "yes"}, 1)

  params:add_option("glb_midi_in_destination", "send midi to..", {"midi out", "voice 1", "voice 2", "voice 3", "voice 4", "voice 5", "voice 6"})
  params:set_action("glb_midi_in_destination", function(dest) midi_in_dest = dest - 1 end)

  params:add_separator("glb_midi_out_params", "midi out")

  params:add_option("glb_midi_out_device", "midi out device", midi_devices, 1)
  params:set_action("glb_midi_out_device", function(val) m[midi_out_dev] = midi.connect(val) end)

  params:add_number("glb_midi_out_channel", "midi out channel", 1, 16, 1)
  params:set_action("glb_midi_out_channel", function(val) notes_off(midi_out_dev) midi_out_ch = val end)

  params:add_option("glb_midi_thru", "mirror voices", {"no", "yes"}, 1)
  params:set_action("glb_midi_thru", function(val) midi_thru = val == 2 and true or false end)

  params:add_control("note_length7", "note length", controlspec.new(0, 2, "lin", 0.01, 0.2, ""), function(param) return param:get() == 0 and "as played" or param:get().." s" end)
  params:set_action("note_length7", function(val) voice[midi_out_dev].length = val end)
  params:hide("note_length7")

  params:add_binary("glb_midi_panic", "don't panic", "trigger", 0)
  params:set_action("glb_midi_panic", function() all_notes_off() end)

  params:add_group("keyboard_group", "keyboard settings", 12)

  params:add_separator("scale_keys", "scale keys")
  params:add_number("scale_keys_y", "interval [y]", 1, 6, 4)
  params:set_action("scale_keys_y", function(val) sc_iy = val - 1 dirtygrid = true end)

  params:add_separator("chrom_keys", "chromatic keys")
  params:add_number("chrom_keys_x", "interval [x]", 1, 6, 1)
  params:set_action("chrom_keys_x", function(val) ch_ix = val dirtygrid = true end)
  params:add_number("chrom_keys_y", "interval [y]", 1, 6, 4)
  params:set_action("chrom_keys_y", function(val) ch_iy = val dirtygrid = true end)

  params:add_separator("chord_keys", "chord keys")
  params:add_number("arp_length", "arp length", 4, 12, 6)
  params:set_action("arp_length", function(val) strum_num = val end)

  params:add_separator("drum_keys", "drumpad keys")
  params:add_number("drum_root_note", "root note", 0, 127, 0, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:add_number("drum_vel_hi", "hi velocity", 1, 127, 100)
  params:add_number("drum_vel_mid", "mid velocity", 1, 127, 64)
  params:add_number("drum_vel_lo", "lo velocity", 1, 127, 32)

  -- patterns params
  params:add_group("patterns", "patterns", 48)
  params:hide("patterns")

  for i = 1, 8 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("patterns_playback"..i, "playback", options.pattern_play, 1)
    params:set_action("patterns_playback"..i, function(mode) pattern[i].loop = mode == 1 and 1 or 0 save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_quantize"..i, "quantize", options.pattern_quantize, 7)
    params:set_action("patterns_quantize"..i, function(idx) pattern[i].quantize = options.pattern_quantize_value[idx] save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_countin"..i, "count in", options.pattern_countin, 3)
    params:set_action("patterns_countin"..i, function() save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_meter"..i, "meter", options.pattern_meter, 3)
    params:set_action("patterns_meter"..i, function(idx) pattern[i].meter = options.meter_val[idx] update_pattern_length(i) end)

    params:add_number("patterns_beatnum"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("patterns_beatnum"..i, function(num) pattern[i].beatnum = num * 4 update_pattern_length(i) dirtygrid = true end)
  end

  -- voice params
  params:add_separator("voices", "voices")
  for i = 1, NUM_VOICES do
    params:add_group("voice_"..i, "voice "..i, 11)
    -- output
    params:add_option("voice_out"..i, "output", options.output, 1)
    params:set_action("voice_out"..i, function() set_voice_output() build_menu() end)
    -- mute
    params:add_option("voice_mute"..i, "mute", {"off", "on"}, 1)
    params:set_action("voice_mute"..i, function(val) voice[i].mute = val == 2 and true or false dirtygrid = true end)
    -- keyboard
    params:add_option("keys_option"..i, "keyboard type", {"scale", "chromatic", "chords", "drums"}, 1)
    params:set_action("keys_option"..i, function() dirtygrid = true build_menu() end)

    -- midi params
    params:add_option("midi_device"..i, "midi device", midi_devices, 1)
    params:set_action("midi_device"..i, function(val) m[i] = midi.connect(val) end)

    params:add_number("midi_channel"..i, "midi channel", 1, 16, i)
    params:set_action("midi_channel"..i, function(val) notes_off(i) voice[i].midi_ch = val end)

    params:add_number("note_velocity"..i, "velocity", 1, 127, 100)
    params:set_action("note_velocity"..i, function(val) voice[i].velocity = val end)

    params:add_control("note_length"..i, "note length", controlspec.new(0, 2, "lin", 0.01, 0, ""), function(param) return param:get() == 0 and "as played" or param:get().." s" end)
    params:set_action("note_length"..i, function(val) voice[i].length = val end)

    params:add_binary("midi_panic"..i, "don't panic", "trigger", 0)
    params:set_action("midi_panic"..i, function() notes_off(i) end)

    -- jf params
    params:add_option("jf_mode"..i, "jf mode", {"vox", "note"}, 2)
    params:set_action("jf_mode"..i, function() build_menu() end)

    params:add_number("jf_voice"..i, "jf voice", 1, 6, i)
    params:set_action("jf_voice"..i, function(vox) voice[i].jf_ch = vox end)

    params:add_control("jf_amp"..i, "jf level", controlspec.new(0.1, 10, "lin", 0.1, 8.0, "vpp"))
    params:set_action("jf_amp"..i, function(level)
      if params:get("jf_mode"..i) == 2 then
        for i = 1, 6 do voice[i].jf_amp = level end
      else
        voice[i].jf_amp = level
      end
    end)
  end

  params:add_separator("sound_params", "synthesis & cv")
  -- engine params
  --moons.add_params()
  moonunit.add_params()
  -- crow params
  params:add_group("crow_out_1+2", "crow [out 1+2]", 4)
  params:add_option("v8_type_1", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_1", function(x) if x == 1 then v8_std_1 = 12 else v8_std_1 = 10 end end)

  params:add_control("env1_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env1_amplitude", function(value) env1_amp = value end)

  params:add_control("env1_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env1_attack", function(value) env1_a = value end)

  params:add_control("env1_decay", "release", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env1_decay", function(value) env1_r = value end)

  params:add_group("crow_out_3+4", "crow [out 3+4]", 4)
  params:add_option("v8_type_2", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_2", function(x) if x == 1 then v8_std_2 = 12 else v8_std_2 = 10 end end)

  params:add_control("env2_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env2_amplitude", function(value) env2_amp = value end)

  params:add_control("env2_attack", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
  params:set_action("env2_attack", function(value) env2_a = value end)

  params:add_control("env2_decay", "release", controlspec.new(0.01, 1, "lin", 0.01, 0.4, "s"))
  params:set_action("env2_decay", function(value) env2_r = value end)

  -- wsyn
  params:add_group("wsyn_params", "crow [wsyn]", 10)
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
  -- nb params
  params:add_group("nb_voices", "notabene", 4)
  for i = 1, 2 do
    local name = {"[one]", "[two]"}
    nb:add_param("nb_"..i, "nb "..name[i].." player")
  end
  nb:add_player_params()

  -- samples params
  params:add_separator("samples_params", "samples")
  smpls.init()

  -- delay params
  params:add_separator("fx_params", "fx")
  softsync.init()

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
  --set_defaults()
  set_my_defaults()

  -- hardware callbacks
  m[midi_in_dev].event = midi_events
  -- script callbacks
  softcut.event_render(wave_render)

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
  clock.run(run_seq)
  clock.run(run_retrig)

end

-------- playback --------
function play_midi(i, note_num, velocity, channel)
  m[i]:note_on(note_num, velocity, channel)
  if voice[i].length > 0 then
    clock.run(function()
      clock.sleep(voice[i].length)
      m[i]:note_off(note_num, 0, channel)
    end)
  end
end

function play_nb(i, note_num, velocity)
  local player = params:lookup_param("nb_"..i):get_player()
  player:note_on(note_num, velocity)
  if voice[i].length > 0 then
    clock.run(function()
      clock.sleep(voice[i].length)
      player:note_off(note_num)
    end)
  end
end

function mute_voice(i, note_num)
  if voice[i].output == 3 or midi_thru then
    m[i]:note_off(note_num, 0, voice[i].midi_ch)
  elseif voice[i].output > 7 then
    local player = params:lookup_param("nb_"..(voice[i].output - 7)):get_player()
    player:note_off(note_num)
  end
end

function play_voice(i, note_num, vel)
  local velocity = vel or voice[i].velocity
  if not voice[i].mute then
    -- moonunit group 1
    if voice[i].output == 1 then
      pool_count_1 = pool_count_1 % 4 + 1
      local freq = mu.note_num_to_freq(note_num)
      engine.trig(pool_count_1, freq)
    -- moonunit group 2
    elseif voice[i].output == 2 then
      pool_count_2 = pool_count_2 % 4 + 5
      local freq = mu.note_num_to_freq(note_num)
      engine.trig(pool_count_2, freq)
    -- midi output
    elseif voice[i].output == 3 then
      play_midi(i, note_num, velocity, voice[i].midi_ch)
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
        crow.ii.jf.play_voice(voice[i].jf_ch, ((note_num - 60) / 12), voice[i].jf_amp)
      else
        crow.ii.jf.play_note(((note_num - 60) / 12), voice[i].jf_amp)
      end
    elseif voice[i].output == 7 then
      crow.ii.wsyn.play_note(((note_num - 60) / 12), wsyn_amp)
    elseif voice[i].output > 7 then
      play_nb(voice[i].output - 7, note_num, util.linlin(1, 127, 0, 1, velocity))
    end
    if midi_thru then
      local channel = midi_out_ch + i - 1
      play_midi(midi_out_dev, note_num, velocity, channel)
    end
  end
end


-------- norns interface --------
function enc(n, d)
  if n == 1 then
    pageNum = util.clamp(pageNum + d, 1, 3)
  end
  if (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config) then
    if n == 2 then
      if not pattern[pattern_focus].manual_length then
        if viewinfo == 0 then
          params:delta("patterns_meter"..pattern_focus, d)
        else
          params:delta("patterns_beatnum"..pattern_focus, d)
        end
      end
    elseif n == 3 then
      if shift then
        params:delta("key_quant_value", d)
      else
        if viewinfo == 0 then
          params:delta("patterns_quantize"..pattern_focus, d) 
        else
          params:delta("patterns_countin"..pattern_focus, d)
        end
      end
    end
  elseif pageNum == 1 then
    if n == 2 then
      if shift and not seq_active then
        params:delta("scale", d)
      end
    elseif n == 3 then
      if shift then
        if seq_active then
          params:delta("key_seq_rate", d)
        else
          params:delta("root_note", d)
        end
      end
    end
  elseif pageNum == 2 then
    local out_dest = params:get("voice_out"..voice_focus)
    if out_dest < 8 then
      if n == 2 then
        param_focus[voice_focus] = util.clamp(param_focus[voice_focus] + d, 1, #voice_params[out_dest])
      elseif n == 3 then
        local param = param_focus[voice_focus]
        if out_dest == 3 or out_dest == 6 then
          params:delta(voice_params[out_dest][param]..voice_focus, d)
        else
          params:delta(voice_params[out_dest][param], d)
        end
      end
    end
  elseif pageNum == 3 then
    if shift then
      local b = smpls.bank_focus
      local s = smpls.slot_focus
      if n == 2 then
        smpls.bank[b].slot[s].ns = util.clamp(smpls.bank[b].slot[s].ns + d / 500 , smpls.bank[b].slot[s].s, smpls.bank[b].slot[s].ne - 0.005)
      elseif n == 3 then
        smpls.bank[b].slot[s].ne = util.clamp(smpls.bank[b].slot[s].ne + d / 500 , smpls.bank[b].slot[s].ns + 0.005, smpls.bank[b].slot[s].e)
      end
    else
      if n == 2 then
        sampl_param = util.clamp(sampl_param + d, 1, 6)
      elseif n == 3 then
        local param = {"level_bank_", "pan_bank_", "send_bank_", "cutoff_bank_", "reso_bank_", "rate_bank_"}
        params:delta(param[sampl_param]..smpls.bank_focus.."_slot_"..smpls.slot_focus, d)
      end
    end
  end
  dirtygrid = true
  dirtyscreen = true
end

function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
    render_sample()
  end
  if n == 2 and z == 1 then
    if (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config) then
      if not shift then
        viewinfo = 1 - viewinfo
      end
    else
      if pageNum == 1 then
        transposing = not transposing
      elseif pageNum == 2 then
        voice_focus = util.clamp(voice_focus - 1, 1, 6)
      elseif pageNum == 3 then
        if shift then
          smpls.bank_focus = util.clamp(smpls.bank_focus - 1, 1, 5)
        else
          smpls.slot_focus = util.clamp(smpls.slot_focus - 1, 1, 4)
        end
      end
    end
  elseif n == 3 and z == 1 then
    if (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config) then
      pattern_focus = util.wrap(pattern_focus + 1, 1, 8)
    else
      if pageNum == 1 then
        if not transposing then
          transpose_value = 0
        end
      elseif pageNum == 2 then
        voice_focus = util.clamp(voice_focus + 1, 1, 6)
      elseif pageNum == 3 then
        if shift then
          smpls.bank_focus = util.clamp(smpls.bank_focus + 1, 1, 5)
        else
          smpls.slot_focus = util.clamp(smpls.slot_focus + 1, 1, 4)
        end
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function redraw()
  screen.clear()
  local sel = viewinfo == 0
  if (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config) then
    if shift then
      screen.font_size(16)
      screen.level(15)
      screen.move(64, 30)
      screen.text_center(params:string("key_quant_value"))
      screen.level(3)
      screen.move(64, 44)
      screen.text_center("key quant") 
    else
      local idx = tab.key(options.meter_val, pattern[pattern_focus].meter)
      screen.font_size(8)
      screen.level(15)
      screen.move(64, 12)
      screen.text_center("PATTERN "..pattern_focus.." BANK "..p[pattern_focus].bank)

      screen.level(sel and 15 or 4)
      screen.move(32, 28)
      screen.text_center(pattern[pattern_focus].manual_length and "-" or options.pattern_meter[idx])
      screen.move(96, 28)
      screen.text_center(params:string("patterns_quantize"..pattern_focus))
      screen.level(pattern_meter_config and 15 or 3)
      screen.move(32, 36)
      screen.text_center("meter")
      screen.level(3)
      screen.move(96, 36)
      screen.text_center("quantize")

      screen.level(not sel and 15 or 4)
      screen.move(32, 52)
      screen.text_center(pattern[pattern_focus].manual_length and "-" or params:string("patterns_beatnum"..pattern_focus))
      screen.move(96, 52)
      screen.text_center(params:string("patterns_countin"..pattern_focus))
      screen.level(pattern_length_config and 15 or 3)
      screen.move(32, 60)
      screen.text_center("length")
      screen.level(3)
      screen.move(96, 60)
      screen.text_center("count in")
    end
  else
    if pageNum == 1 then
      local offset = 16
      local white_keys = {"C", "D", "E", "F", "G", "A", "B"}
      local black_keys_a = {"C#", "D#"}
      local black_keys_b = {"F#", "G#", "A#"}

      for i = 1, #white_keys do
        screen.level((notes.viz - notenum_w[i]) % 12 == 0 and 15 or (noteis_w[i] and 4 or 1))
        screen.move(16 + (i - 1) * offset, 41)
        screen.font_size(8)
        screen.text_center(white_keys[i])
      end

      for i = 1, #black_keys_a do
        screen.level((notes.viz - notenum_ba[i]) % 12 == 0 and 15 or (noteis_ba[i] and 4 or 1))
        screen.move(24 + (i - 1) * offset, 29)
        screen.font_size(8)
        screen.text_center(black_keys_a[i])
      end

      for i = 1, #black_keys_b do
        screen.level((notes.viz - notenum_bb[i]) % 12 == 0 and 15 or (noteis_bb[i] and 4 or 1))
        screen.move(72 + (i - 1) * offset, 29)
        screen.font_size(8)
        screen.text_center(black_keys_b[i])
      end

      if shift and not collecting_notes then
        if seq_active then
          screen.level(4)
          screen.font_size(8)
          screen.move(6, 58)
          screen.text("seq rate")
          screen.level(8)
          screen.move(122, 58)
          screen.text_right(params:string("key_seq_rate"))
        else
          screen.level(8)
          screen.font_size(8)
          screen.move(8, 58)
          screen.text(params:string("scale"))
          screen.move(110, 58)
          screen.text(params:string("root_note"))
        end
      end
      local semitone = scale_notes[tab.key(scale_notes, params:get("root_note")) + transpose_value] - params:get("root_note")
      if transposing then
        screen.level(15)
        screen.font_size(8)
        screen.move(64, 12)
        if semitone > 0 then
          screen.text_center("transpose: +"..semitone)
        else
          screen.text_center("transpose: "..semitone)
        end
      end
      if semitone ~= 0 and not transposing then
        screen.level(8)
        screen.font_size(16)
        screen.move(64, 14)
        if semitone > 0 then
          screen.text_center("+"..semitone)
        else
          screen.text_center(semitone)
        end
      end
      if collecting_notes and #collected_notes > 0 then
        screen.level(8)
        screen.font_size(16)
        screen.move(64, 58)
        screen.text_center("step: "..#collected_notes)
      end
    elseif pageNum == 2 then
      screen.level(15)
      screen.font_size(8)
      screen.move(64, 10)
      screen.text_center("voice "..voice_focus.." - "..params:string("voice_out"..voice_focus))
      -- params
      local out_dest = params:get("voice_out"..voice_focus)
      local param = param_focus[voice_focus]
      screen.font_size(16)
      if out_dest < 8 then
        local off = get_mid(voice_param_names[out_dest][param])
        screen.level(12)
        screen.move(64, 39)
        if (out_dest == 3 or out_dest == 6) then
          screen.text_center(params:string(voice_params[out_dest][param]..voice_focus))
        else
          screen.text_center(params:string(voice_params[out_dest][param]))
        end
        screen.font_size(8)
        screen.level(6)
        screen.move(64, 55)
        screen.text_center(voice_param_names[out_dest][param])
        -- list right
        if param > 1 then
          screen.level(2)
          screen.move(64 - off - 12, 55)
          screen.text_right(voice_param_names[out_dest][param - 1].."  <")
        end
        -- list left
        if param < #voice_params[out_dest] then
          screen.level(2)
          screen.move(64 + off + 12, 55)
          screen.text(">  "..voice_param_names[out_dest][param + 1])
        end
      else
        screen.level(12)
        screen.move(64, 39)
        screen.text_center(params:string("nb_"..out_dest - 7))
        screen.font_size(8)
        screen.level(6)
        screen.move(64, 55)
        screen.text_center("edit in params")
      end
    elseif pageNum == 3 then
      local s_banks = {"A", "B", "C", "D", "E"}
      local b = smpls.bank_focus
      local s = smpls.slot_focus
      screen.level(15)
      screen.font_size(8)
      screen.move(64, 10)
      screen.text_center("sample "..s_banks[b]..""..s)
      -- filename
      screen.level(8)
      screen.move(64, 22)
      local name = params:string("load_bank_"..b.."_slot_"..s)
      screen.text_center("- "..truncateMiddle(name, 20, "-").." -")
      if shift then
        -- draw waveform
        screen.level(4)
        local x_pos = 0
        if #waveform_samples > 0 then
          for i, s in ipairs(waveform_samples) do
            local height = util.round(math.abs(s) * 12)
            screen.move(util.linlin(1, 128 , 7, 121, x_pos), 44 - height)
            screen.line_rel(0, 2 * height)
            screen.stroke()
            x_pos = x_pos + 1
          end
        end
        -- draw start and endpoints
        local b = smpls.bank_focus
        local s = smpls.slot_focus
        local start = smpls.bank[b].slot[s].s
        local stop = smpls.bank[b].slot[s].e
        screen.level(15)
        screen.move(util.linlin(smpls.bank[b].slot[s].s, smpls.bank[b].slot[s].e, 7, 121, smpls.bank[b].slot[s].ns), 28)
        screen.line_rel(0, 32)
        screen.level(8)
        screen.move(util.linlin(smpls.bank[b].slot[s].s, smpls.bank[b].slot[s].e, 7, 121, smpls.bank[b].slot[s].ne), 28)
        screen.line_rel(0, 32)
        screen.stroke()
      else
        -- params
        local param = {"level_bank_", "pan_bank_", "send_bank_", "cutoff_bank_", "reso_bank_", "rate_bank_"}
        local param_names = {"level", "pan", "send", "cutoff", "filter q", "rate"}
        local off = get_mid(param_names[sampl_param])
        screen.font_size(16)
        screen.level(12)
        screen.move(64, 39)
        screen.text_center(params:string(param[sampl_param]..b.."_slot_"..s))
        screen.font_size(8)
        screen.level(6)
        screen.move(64, 55)
        screen.text_center(param_names[sampl_param])
        -- list right
        if sampl_param > 1 then
          screen.level(2)
          screen.move(64 - off - 12, 55)
          screen.text_right(param_names[sampl_param - 1].."  <")
        end
        -- list left
        if sampl_param < #param then
          screen.level(2)
          screen.move(64 + off + 12, 55)
          screen.text(">  "..param_names[sampl_param + 1])
        end
      end
    end
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

function g.key(x, y, z)
  if GRIDSIZE == 128 then
    grd_one.func_keys(x, y, z)
    if y == 1 and x > 4 and x < 13 and z == 1 then
      local i = x - 4
      grd_one.pattern_keys(i)
    end
    if pattern_view then
      grd_one.pattern_grid(x, y, z)
    else
      grd_one.main_grid(x, y, z)
      if params:get("keys_option"..key_focus) == 1 then
        grd_one.scale_grid(x, y, z)
      elseif params:get("keys_option"..key_focus) == 2 then
        grd_one.chrom_grid(x, y, z)
      elseif params:get("keys_option"..key_focus) == 3 then
        grd_one.chord_grid(x, y, z)
      elseif params:get("keys_option"..key_focus) == 4 then
        grd_one.drum_grid(x, y, z)
      end
    end
  elseif GRIDSIZE == 256 then
    grd_zero.func_keys(x, y, z)
    if y == 7 and x > 4 and x < 13 and z == 1 then
      local i = x - 4
      grd_zero.pattern_keys(i)
    end
    grd_zero.pattern_grid(x, y, z)
    grd_zero.main_grid(x, y, z)
    if params:get("keys_option"..key_focus) == 1 then
      grd_zero.scale_grid(x, y, z)
    elseif params:get("keys_option"..key_focus) == 2 then
      grd_zero.chrom_grid(x, y, z)
    elseif params:get("keys_option"..key_focus) == 3 then
      grd_zero.chord_grid(x, y, z)
    elseif params:get("keys_option"..key_focus) == 4 then
      grd_zero.drum_grid(x, y, z)
    end
  end
  dirtygrid = true
end

function gridredraw()
  if GRIDSIZE == 128 then
    grd_one.draw()
  elseif GRIDSIZE == 256 then
    grd_zero.draw()
  end
end


-------- utilities --------
function r()
  norns.script.load(norns.state.script)
end

function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

function get_mid(str)
  local len = string.len(str) / 2
  local pix = len * 5
  return pix
end

function truncateMiddle(str, maxLength, separator)
  local maxLength = maxLength or 30
  local separator = separator or "..."
  str = string.sub(str, 1, -5)

  if (maxLength < 1) then return str end
  if (string.len(str) <= maxLength) then return str end
  if (maxLength == 1) then return string.sub(str, 1, 1) .. separator end

  local midpoint = math.ceil(string.len(str) / 2)
  local toremove = string.len(str) - maxLength
  local lstrip = math.ceil(toremove / 2)
  local rstrip = toremove - lstrip

  return string.sub(str, 1, midpoint - lstrip) .. separator .. string.sub(str, 1 + midpoint + rstrip)
end

function wave_render(ch, start, i, s)
  waveform_samples = {}
  waveform_samples = s
end

function render_sample()
  if pageNum == 3 and shift then
    local b = smpls.bank_focus
    local s = smpls.slot_focus
    softcut.render_buffer(1, smpls.bank[b].slot[s].s, smpls.bank[b].slot[s].l, 128)
    dirtyscreen = true
  end
end

function pan_display(param)
  local pos_right = ""
  local pos_left = ""
  if param == 0 then
    pos_right = ""
    pos_left = ""
  elseif param < -0.01 then
    pos_right = ""
    pos_left = "< "
  elseif param > 0.01 then
    pos_right = " >"
    pos_left = ""
  end
  return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
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
    if (voice[i].output == 3 or voice[i].output > 7) and params:get("keys_option"..i) < 4 then
      params:show("note_velocity"..i)
      params:show("note_length"..i)
    else
      params:hide("note_velocity"..i)
      params:hide("note_length"..i)
    end
    if voice[i].output == 3  then
      params:show("midi_device"..i)
      params:show("midi_channel"..i)
      params:show("midi_panic"..i)
    else
      params:hide("midi_device"..i)
      params:hide("midi_channel"..i)
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
  _menu.rebuild_params()
  dirtyscreen = true
end

function page_redraw(page)
  if pageNum == page then
    dirtyscreen = true
  end
end

function get_grid_size()
  if g.device then
    GRIDSIZE = g.device.cols * g.device.rows
  end
end

function grid.add()
  get_grid_size()
  dirtygrid = true
  gridredraw()
end

function cleanup()
  params:set("cut_input_eng", eng_level)
  grid.add = function() end
  midi.add = function() end
  midi.remove = function() end
  crow.ii.jf.mode(0)
end
