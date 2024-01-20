-- nisho v1.5.5 @sonocircuit
-- llllllll.co/t/nisho
--
-- six voices and eight patterns
-- for performance and composition
--
-- for docs go to:
-- >> github.com/sonocircuit
--    /nisho
--
-- or smb into:s
-- >> code/nisho/doc
--

---------------------------------------------------------------------------
-- TODO: fix crow env shapes -> not working
-- TODO: engine -> change formant waveshape behaviour / fix mod envelope click
-- KNOWN BUG: patterns not catching more than 1 note at step_one
-- KNOWN BUG: hanging notes: notes off values are shifted while transposing and length set to "played"
---------------------------------------------------------------------------

engine.name = "Formantpulse" 

mu = require 'musicutil'
lattice = require 'lattice'

polyform = include 'lib/nishos_polyform'
softsync = include 'lib/nishos_softsync'
grd_zero = include 'lib/nishos_grid_zero'
grd_one = include 'lib/nishos_grid_one'
mirror = include 'lib/nishos_reflection'
nb = include 'nb/lib/nb'

g = grid.connect()

-------- variables -------
load_pset = false
rotate_grid = false

GRIDSIZE = 0
NUM_VOICES = 6

-- ui variables
pageNum = 1
shift = false

-- modifier keys
mod_a = false
mod_b = false
mod_c = false
mod_d = false

-- keyboard variables
int_focus = 1
key_focus = 1
voice_focus = 1
strum_focus = 1
key_link = true -- link keyboard to interval keys
transposing = false -- activate transpose_mode
transpose_value = 0
scalekeys_y = 4 -- scale keys
chromakeys_x = 5 -- chromatic keys x
chromakeys_y = 1 -- chromatic keys y

drum_root_note = 0
drum_vel_hi = 100
drum_vel_mid = 64
drum_vel_lo = 32
drum_vel_last = 100

-- keep track of the number of pressed keys
heldkey_int = 0
heldkey_key = 0 
heldkey_kit = 0 

-- kit variables
kit_view = false
kit_root_note = 60
kit_midi_dev = 9
kit_midi_ch = 1
kit_velocity = 100
kit_oct = 0
kit_held = {}

-- sequencer variables
seq_notes = {}
collected_notes = {}
seq_active = false
sequencer_config = false
collecting_notes = false
appending_notes = false
seq_step = 0
seq_rate = 1/4
seq_hold = false

-- key repeat variables
key_repeat_view = false
latch_key_repeat = false
key_repeat = false
rep_rate = 1/4

--trig variables
trigs_config_view = false
set_trigs_end = false
trigs_focus = 1
trig_step = 0
trigs_reset = false

-- crow
v8_std_1 = 12
v8_std_2 = 12
env1_amp = 8
env1_crv = 'log'
env1_a = 0
env1_r = 0.4
env2_amp = 8
env2_crv = 'log'
env2_a = 0
env2_r = 0.4
env_shapes = {'lin','log','exp'} -- TODO: env shapes not working
wsyn_amp = 5

-- eng voices
synth_voice_1 = 1
synth_voice_2 = 0

-- midi
midi_in_dev = 8
midi_in_ch = 1
midi_in_dest = 0
midi_in_quant = false
midi_out_dev = 7
midi_out_ch = 1
midi_thru = false
midi_thru_dur = 0.1

midi_control = false -- hidden option, grid zero only, not documented. please read the code or ask.
midi_view = false 

-- chord variables
chord_any = false
chord_play = true
chord_strum = false
chord_inversion = 1
chord_oct_shift = 0
last_chord_root = 0
strum_count_options = false
strum_mode_options = false
strum_skew_options = false
strum_count = 6
strum_mode = 1
strum_skew = 0
strum_rate = 0.1
strum_step = 0

-- scale variables
root_oct = 3 -- number of octaves root_note differs from root_base. used to set transpose
root_note = 60 -- root note set by scale param. corresponds to note.home
root_base = 24 -- lowest note of the scale
current_scale = 1
scale_notes = {}

-- note variables
notes_held = {}
notes_oct_int = {}
notes_oct_key = {}
for i = 1, NUM_VOICES do
  notes_oct_int[i] = 0
  notes_oct_key[i] = 0
end
notes_last = 1
notes_home = 1
notes_viz = 60

-- note viz variables
notenum_w = {24, 26, 28, 29, 31, 33, 35}
notenum_b1 = {25, 27}
notenum_b2 = {30, 32, 34}

white_keys = {"C", "D", "E", "F", "G", "A", "B"}
black_keys_1 = {"C#", "D#"}
black_keys_2 = {"F#", "G#", "A#"}
noteis_w = {}
noteis_b1 = {}
noteis_b1sym = {}
noteis_b1 = {}
noteis_b2sym = {}

-- key viz variables
pulse_bar = false
pulse_beat = false
pulse_key_fast = 8
pulse_key_mid = 4
pulse_key_slow = 4
hide_metronome = false

-- screen viz
view_message = ""

-- key quantization
key_quantize = false
quant_rate = 16
quant_event = {}

-- pattern variables
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
pattern_view = false
pattern_focus = 1
keyquant_edit = false

-- event variables
eSCALE = 1
eKEYS = 2
eDRUMS = 3
eMIDI = 4
eTRSP_SCALE = 5
eKIT = 6

-------- tables --------
options = {}
options.key_quant = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
options.quant_value = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
options.pattern_play = {"loop", "oneshot"}
options.pattern_launch = {"manual", "beat", "bar"}
options.pattern_quantize = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/24", "1/32", "3/128", "1/48", "1/64"}
options.pattern_quantize_value = {1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}
options.pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
options.meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}
options.output = {"polyform [one]", "polyform [two]", "midi", "crow 1+2", "crow 3+4", "crow ii jf", "crow ii wsyn", "nb [one]", "nb [two]"}

voice = {}
for i = 1, NUM_VOICES + 1 do -- 6 voices + 1 midi out
  voice[i] = {}
  voice[i].mute = false
  voice[i].keys_option = 1
  voice[i].length = 0.2
  voice[i].velocity = 100
  voice[i].midi_ch = i
  voice[i].midi_ch = i
  voice[i].jf_ch = i
  voice[i].jf_amp = 5
end

chord_arp = {}
current_chord = {}
chord = {}
for i = 1, 12 do
  chord[i] = {}
  chord[i].is = {}
  chord[i].map = {}
  chord[i].event = {}
  chord[i].notes = {}
  chord[i].strum = {}
  for t = 1, 7 do
    chord[i].is[t] = false
    chord[i].notes[t] = {}
    chord[i].strum[t] = {}
    for n = 1, 4 do
      chord[i].notes[t][n] = {}
    end
  end
end

trigs = {}
for i = 1, 8 do
  trigs[i] = {}
  trigs[i].step_max = 16
  trigs[i].pattern = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
end

m = {}
for i = 1, 9 do -- 6 voices + in + out + kit
  m[i] = midi.connect()
end

gkey = {}
for x = 1, 16 do
  gkey[x] = {}
  for y = 1, 16 do
    gkey[x][y] = {}
    gkey[x][y].active = false
    gkey[x][y].chord_viz = 0
    gkey[x][y].note = 0
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

voicetab = {}
voicenotes = {}
lastvoice = {}
for i = 1, 2 do
  voicetab[i] = {0, 0, 0, 0}
  voicenotes[i] = {0, 0, 0, 0}
  lastvoice[i] = {}
end

voice_params = {
  {"main_amp1", "pan1", "formant_amp1", "pulse_amp1", "noise_amp1", "noise_crackle1",
  "formant_shape1", "formant_curve1", "formant_type1", "formant_width1", "pulse_tune1", "pulse_width1",
  "pwm_rate1", "pwm_depth1", "lpf_cutoff1", "lpf_resonance1", "env_lpf_depth1", "hpf_cutoff1",
  "attack1", "release1", "vib_freq1", "vib_depth1"}, --polyform [one]
  {"main_amp2", "pan2", "formant_amp2", "pulse_amp2", "noise_amp2", "noise_crackle2",
  "formant_shape2", "formant_curve2", "formant_type2", "formant_width2", "pulse_tune2", "pulse_width2",
  "pwm_rate2", "pwm_depth2", "lpf_cutoff2", "lpf_resonance2", "env_lpf_depth2", "hpf_cutoff2",
  "attack2", "release2", "vib_freq2", "vib_depth2"}, --polyform [two]
  {"note_length", "note_velocity", "midi_device", "midi_channel"}, --midi
  {"env1_amplitude", "env1_shape", "env1_attack", "env1_decay"}, --crow 1+2
  {"env2_amplitude", "enve_shape", "env2_attack", "env2_decay"}, --crow 3+4
  {"jf_amp", "jf_voice"}, --crow ii jf
  {"wysn_mode", "wsyn_amp", "wsyn_curve", "wsyn_ramp", "wsyn_lpg_time", "wsyn_lpg_sym",
  "wsyn_fm_index", "wsyn_fm_env", "wsyn_fm_num", "wsyn_fm_den"} --crow ii wsyn
}

voice_param_names = {
  {"main   level", "pan", "formant   level", "pulse   level", "noise   level", "noise   crackle",
  "formant   shape", "formant   curve", "formant   type", "formant   width",
  "pulse   tune", "pulse   width", "pwm   rate", "pwm   depth", "lpf   cutoff", "lpf   resonance",
  "env   depth", "hpf   cutoff", "attack", "release", "vibrato   rate", "vibrato   depth"}, --polyform [one]
  {"main   level", "pan", "formant   level", "pulse   level", "noise   level", "noise   crackle",
  "formant   shape", "formant   curve", "formant   type", "formant   width",
  "pulse   tune", "pulse   width", "pwm   rate", "pwm   depth", "lpf   cutoff", "lpf   resonance",
  "env   depth", "hpf   cutoff", "attack", "release", "vibrato   rate", "vibrato   depth"}, --polyform [two]
  {"note   length", "velocity", "device", "channel"}, --midi
  {"amplitude", "shape", "attack", "decay"}, --crow 1+2
  {"amplitude", "shape", "attack", "decay"}, --crow 3+4
  {"level", "voice"}, --crow ii jf
  {"mode", "level", "curve", "ramp", "lpg   time", "lpg   sym", "fm   index", "fm   env", "fm   num", "fm   den"} --crow ii wsyn
}

voice_param_focus = {}
for i = 1, NUM_VOICES do
  voice_param_focus[i] = 1
end

pattern_param_focus = 1
pattern_e2_params = {"patterns_meter_", "patterns_launch_", "patterns_playback_"}
pattern_e3_params = {"patterns_beatnum_", "patterns_quantize_", ""}
pattern_e2_names = {"meter", "launch", "playback"}
pattern_e3_names = {"length", "quantize", ""}

-------- scales --------
function build_scale()
  root_base = root_note % 12 + 24
  root_oct = math.floor((root_note - root_base) / 12)
  scale_notes = mu.generate_scale_of_length(root_base, current_scale, 50)
  notes_home = tab.key(scale_notes, root_note)
  set_note_viz()
end

function set_note_viz()
  noteis_w = {} -- white keys
  noteis_b1 = {} -- C#, D#
  noteis_b1sym = {}
  noteis_b2 = {} -- F#, G#, A#
  noteis_b2sym = {}
  for i, v in ipairs(notenum_w) do
    table.insert(noteis_w, notelookup(v))
  end
  for i, v in ipairs(notenum_b1) do
    table.insert(noteis_b1, notelookup(v))
  end
  for i, v in ipairs(notenum_b2) do
    table.insert(noteis_b2, notelookup(v))
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

function kill_held_notes(focus)
  if #notes_held > 0 then
    for _, note in ipairs(notes_held) do
      mute_voice(voice[focus].output, note)
      --print(voice.." "..note)
    end
    notes_held = {}
  end
end

function build_chords()
  for i = 1, 12 do
    local root = 59 + i
    local chord_type = {"Major", "Minor", "Sus4", "Diminished", "Major 7", "Minor 7", "Augmented"}
    for t = 1, 7 do
      for n = 1, 4 do
        chord[i].notes[t][n] = mu.generate_chord(root, chord_type[t], n - 1)
      end
      chord[i].strum[t] = {table.unpack(chord[i].notes[t][1])}
      for note = 1, 12 do
        table.insert(chord[i].strum[t], chord[i].strum[t][note] + 12)
      end
    end
  end
end

function kill_chord()
  if #current_chord > 0 then
    for index, value in ipairs(current_chord) do
      local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = value, action = "note_off"} event(e)
    end
    current_chord = {}
    notes_held = {}
  end
end

function play_chord(i)
  local i = i or last_chord_root
  local chord_type = get_chord_type(i + 2)
  if chord[i].is[chord_type] or chord_any then
    kill_chord()
    -- set chord and strum notes
    current_chord = {}
    for _, value in ipairs(chord[i].notes[chord_type][chord_inversion]) do
      table.insert(current_chord, value + (12 * notes_oct_key[key_focus]))
      table.insert(notes_held, value + (12 * notes_oct_key[key_focus]))
    end
    chord_arp = {}
    for _, value in ipairs(chord[i].strum[chord_type]) do
      table.insert(chord_arp, value + (12 * notes_oct_key[key_focus]))
    end
    -- play chord
    if chord_play and #current_chord > 0 and not key_repeat then
      local p = pattern[pattern_focus].rec_enabled == 1 and pattern_focus or nil
      for index, value in ipairs(current_chord) do
        chord[index].event = {t = eKEYS, p = p, i = key_focus, note = value, action = "note_on"} event(chord[index].event)
      end
    end
    -- strum chord
    if chord_strum then
      if strum_clock ~= nil then
        clock.cancel(strum_clock)
      end
      strum_clock = clock.run(autostrum)
    end
    -- collect or append notes to seq
    if collecting_notes and not appending_notes then
      for i, v in ipairs(current_chord) do
        table.insert(collected_notes, v)
      end
    elseif appending_notes and not collecting_notes then
      for i, v in ipairs(current_chord) do
        table.insert(seq_notes, v)
      end
    end
    -- play seq
    if seq_active and not (collecting_notes or appending_notes) then
      if #chord_arp > 0 then
        seq_notes = {}
        for note = chord_inversion, strum_count + chord_inversion do
          table.insert(seq_notes, chord_arp[note])
        end
        if heldkey_key > 0 then
          trig_step = 0
        end
        seq_step = 0
      end
    end
  end
end

function get_chord_type(x)
  local off = GRIDSIZE == 128 and 8 or 0
  if gkey[x][13 - off].active and gkey[x][14 - off].active and gkey[x][15 - off].active then
    return 7 --"Augmented"
  elseif not gkey[x][13 - off].active and gkey[x][14 - off].active and gkey[x][15 - off].active then
    return 6 --"Minor 7"
  elseif gkey[x][13 - off].active and not gkey[x][14 - off].active and gkey[x][15 - off].active then
    return 5 --"Major 7"
  elseif gkey[x][13 - off].active and gkey[x][14 - off].active and not gkey[x][15 - off].active then
    return 4 --"Diminished"
  elseif not gkey[x][13 - off].active and gkey[x][14 - off].active and not gkey[x][15 - off].active then
    return 2 --"Minor"
  elseif gkey[x][13 - off].active and not gkey[x][14 - off].active and not gkey[x][15 - off].active then
    return 1 --"Major"
  elseif not gkey[x][13 - off].active and not gkey[x][14 - off].active and gkey[x][15 - off].active then
    return 3 --"Sus4"
  end
end

function build_chord_map()
  for i = 1, 12 do
    local note_num = 59 + i
    chord[i].map = {}
    chord[i].map = mu.chord_types_for_note(note_num, root_base, scale_names[current_scale])
    --print("note"..mu.note_num_to_name(note_num))
    --tab.print(chord[i].map)
  end
  set_chord_viz()
end

function set_chord_viz()
  local off = GRIDSIZE == 128 and 0 or 8
  for i = 1, 12 do
    local x = i + 2
    for y = 5 + off, 7 + off do
      gkey[x][y].chord_viz = 0
    end
    for t = 1, 7 do
      chord[i].is[t] = false
    end
    if #chord[i].map > 0 then
      if tab.contains(chord[i].map, "Augmented") then
        gkey[x][5 + off].chord_viz = 2
        gkey[x][6 + off].chord_viz = 2
        gkey[x][7 + off].chord_viz = 2
        chord[i].is[7] = true
      end
      if tab.contains(chord[i].map, "Diminished") then
        gkey[x][5 + off].chord_viz = 2
        gkey[x][6 + off].chord_viz = 2
        chord[i].is[4] = true
      end
      if tab.contains(chord[i].map, "Major") then
        gkey[x][5 + off].chord_viz = 9
        chord[i].is[1] = true
      end
      if tab.contains(chord[i].map, "Minor") then
        gkey[x][6 + off].chord_viz = 9
        chord[i].is[2] = true
      end
      if tab.contains(chord[i].map, "Sus4") then
        gkey[x][7 + off].chord_viz = 9
        chord[i].is[3] = true
      end
      if tab.contains(chord[i].map, "Major 7") then
        if tab.contains(chord[i].map, "Sus4") then
          gkey[x][7 + off].chord_viz = 6
        else
          gkey[x][7 + off].chord_viz = 3
        end
        chord[i].is[5] = true
      end
      if tab.contains(chord[i].map, "Minor 7") then
        if tab.contains(chord[i].map, "Sus4") then
          gkey[x][7 + off].chord_viz = 6
        else
          gkey[x][7 + off].chord_viz = 3
        end
        chord[i].is[6] = true
      end
    end
  end
end

function set_scale()
  build_scale()
  build_chord_map()
  dirtyscreen = true
end

------- voice settings --------
function manage_ii()
  local num_ii = 0
  for i = 1, NUM_VOICES do
    if voice[i].output == 6 then
      num_ii = num_ii + 1
    end
    if voice[i].output == 7 then
      crow.ii.wsyn.voices(4)
    end
  end
  if num_ii > 0 then
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
  -- set midi 2host ch1
  params:set("glb_midi_in_device", 3)
  params:set("glb_midi_in_channel", 1)
  params:set("glb_midi_out_device", 3)
  params:set("glb_midi_out_channel", 1)
  -- set kit midi 2host ch 7
  params:set("kit_out_device", 3)
  params:set("kit_midi_channel", 7)
  -- voice settings:
  params:set("voice_out1", 1)
  params:set("voice_out2", 2)
  -- midi out 2host ch 8
  params:set("voice_out3", 3)
  params:set("midi_device3", 3)
  params:set("midi_channel3", 8)
  -- analog 4 t1
  params:set("voice_out4", 3)
  params:set("midi_device4", 1)
  params:set("midi_channel4", 5)
  -- analog 4 t2
  params:set("voice_out5", 3)
  params:set("midi_device5", 1)
  params:set("midi_channel5", 6)
  -- prophet 6
  params:set("voice_out6", 3)
  params:set("midi_device6", 1)
  params:set("midi_channel6", 4)
end



-------- pattern recording --------
function event_exec(e)
  if e.t == eSCALE then
    local octave = (root_oct - e.root) * (#scale_intervals[current_scale] - 1)
    local idx = util.clamp(e.note + transpose_value + octave, 1, #scale_notes)
    local note_num = scale_notes[idx]
    if e.action == "note_off" and voice[e.i].length == 0 then
      mute_voice(e.i, note_num)
      remove_active_notes(e.p, e.i, note_num)
    elseif e.action == "note_on" then
      play_voice(e.i, note_num)
      add_active_notes(e.p, e.i, note_num)
      notes_viz = note_num
    end
  elseif e.t == eKEYS then
    if e.action == "note_off" and voice[e.i].length == 0 then
      mute_voice(e.i, e.note)
      remove_active_notes(e.p, e.i, e.note)
    elseif e.action == "note_on" then
      play_voice(e.i, e.note)
      add_active_notes(e.p, e.i, e.note)
      notes_viz = e.note
    end
  elseif e.t == eDRUMS then
    play_voice(e.i, e.note, e.vel)
    clock.run(function()
      clock.sync(1/8)
      mute_voice(e.i, e.note)
    end)
  elseif e.t == eTRSP_SCALE then
    local home_note = tab.key(scale_notes, root_note)
    transpose_value = util.clamp(transpose_value + e.interval, -home_note + 1, #scale_notes - home_note)
    if e.interval == 0 then
      transpose_value = 0
    end
  elseif e.t == eMIDI then
    if e.dest == 0 then
      if e.action == "note_on" then
        if midi_in_quant then
          e.note = mu.snap_note_to_array(e.note, note_map)
        end
        m[midi_out_dev]:note_on(e.note, e.vel, e.ch)
        add_active_notes(e.p, 7, e.note)
      elseif e.action == "note_off" then
        if midi_in_quant then
          e.note = mu.snap_note_to_array(e.note, note_map)
        end
        m[midi_out_dev]:note_off(e.note, 0, e.ch)
        remove_active_notes(e.p, 7, e.note)
      end
    elseif e.dest > 0 then
      if midi_in_quant then
        e.note = mu.snap_note_to_array(e.note, note_map)
      end
      if e.action == "note_on" then
        play_voice(e.dest, e.note, e.vel)
        add_active_notes(e.p, e.dest, e.note)
        notes_viz = e.note
      elseif e.action == "note_off" then
        mute_voice(e.dest, e.note, e.vel)
        remove_active_notes(e.p, e.dest, e.note)
      end
    end
  elseif e.t == eKIT then
    play_kit(e.note)
    kit_gridviz(e.note)
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
  pattern[i].end_callback = function() kill_active_notes(i) dirtygrid = true  end
  pattern[i].step_callback = function() if (pattern_view or GRIDSIZE == 256) then dirtygrid = true end end
  pattern[i].active_notes = {}
  for voice = 1, NUM_VOICES do
    pattern[i].active_notes[voice] = {}
  end
end

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
end

function event(e)
  if key_quantize and not (key_repeat or seq_active) then
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

function num_rec_enabled()
  local num_enabled = 0
  for i = 1, 8 do
    if pattern[i].rec_enabled > 0 then
      num_enabled = num_enabled + 1
    end
  end
  return num_enabled
end

function step_one_indicator(i)
  pattern[i].pulse_key = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(1/15)
    pattern[i].pulse_key = false
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
  if i ~= nil then
    table.insert(pattern[i].active_notes[voice], note_num)
  --tab.print(pattern[i].active_notes[voice])
  end
end

function remove_active_notes(i, voice, note_num)
  if i ~= nil then
    table.remove(pattern[i].active_notes[voice], tab.key(pattern[i].active_notes[voice], note_num))
  --tab.print(pattern[i].active_notes[voice])
  end
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
      if seq_notes[n] > 0 then
        if not pattern[i].event[s] then
          pattern[i].event[s] = {}
        end
        if voice[key_focus].keys_option == 1 then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = seq_notes[n], action = "note_on"}
          table.insert(pattern[i].event[s], e)
        else
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = seq_notes[n], action = "note_on"}
          table.insert(pattern[i].event[s], e)
        end
        if not pattern[i].event[t] then
          pattern[i].event[t] = {}
        end
        if voice[key_focus].keys_option == 1 then
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
    print("seq pattern empty")
  end
end

function set_pattern_params(i)
  params:set("patterns_playback_"..i, pattern[i].loop == 1 and 1 or 2)
  params:set("patterns_quantize_"..i, tab.key(options.pattern_quantize_value, pattern[i].quantize))
  params:set("patterns_beatnum_"..i, math.floor(pattern[i].beatnum / 4))
  params:set("patterns_meter_"..i, tab.key(options.meter_val, pattern[i].meter))
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
  clock.run(function()
    clock.sleep(0.2)
    build_midi_device_list()
  end)
end

function clock.tempo_change_handler(tempo)
  midi_thru_dur = 60/tempo * 1/4
end

function clock.transport.start()
  seq_step = 0
  trig_step = 0
  counter = 3
end

function clock.transport.stop()
  for i = 1, 8 do
    pattern[i]:end_playback()
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
  if msg.type == "program_change" then -- use program change to load psets
    if msg.ch == 1 then
      params:read(msg.val + 1)
    end
  end
end

function set_midi_event_callback()
  midi.cleanup()
  m[midi_in_dev].event = midi_events
end

-------- clock coroutines --------
function ledpulse_fast()
  pulse_key_fast = pulse_key_fast == 8 and 12 or 8
  for i = 1, 8 do
    if pattern[i].rec == 1 then
      dirtygrid = true
    end
  end
end

function ledpulse_mid()
  pulse_key_mid = util.wrap(pulse_key_mid + 1, 4, 12)
  if (trigs_config_view or transposing) then
    dirtygrid = true
  end
end

function ledpulse_slow()
  pulse_key_slow = util.wrap(pulse_key_slow + 1, 4, 12)
  for i = 1, 8 do
    if p[i].load then
      dirtygrid = true
    end
  end
  if (copy_src or latch_key_repeat or sequencer_config or pattern_clear) then
    dirtygrid = true
  end
end

function ledpulse_bar()
  while true do
    clock.sync(4)
    pulse_bar = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(1/30)
      pulse_bar = false
      dirtygrid = true
    end)
  end
end

function ledpulse_beat()
  while true do
    clock.sync(1)
    pulse_beat = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(1/30)
      pulse_beat = false
      dirtygrid = true
    end)
  end
end

function set_metronome(mode)
  if mode == 1 then
    clock.cancel(barviz)
    clock.cancel(beatviz)
    hide_metronome = true
  else
    barviz = clock.run(ledpulse_bar)
    beatviz = clock.run(ledpulse_beat)
    hide_metronome = false
  end
end

function run_seq()
  while true do
    clock.sync(seq_rate)
    if seq_step >= #seq_notes then
      seq_step = 0
    end
    if #seq_notes > 0 and seq_active then
      if trig_step >= trigs[trigs_focus].step_max then
        trig_step = 0
      end
      trig_step = trig_step + 1
      seq_step = seq_step + 1
      if seq_notes[seq_step] > 0 and trigs[trigs_focus].pattern[trig_step] == 1 then
        local current_note = seq_notes[seq_step]
        local p = pattern[pattern_focus].rec == 1 and pattern_focus or nil
        if voice[key_focus].keys_option == 1 then
          local e = {t = eSCALE, p = p, i = key_focus, root = root_oct, note = current_note, action = "note_on"} event(e)
          clock.run(function()
            clock.sync(seq_rate / 2)
            local e = {t = eSCALE, p = p, i = key_focus, root = root_oct, note = current_note, action = "note_off"} event(e)
          end)
        elseif voice[key_focus].keys_option == 2 or voice[key_focus].keys_option == 3 then
          local e = {t = eKEYS, p = p, i = key_focus, note = current_note, action = "note_on"} event(e)
          clock.run(function()
            clock.sync(seq_rate / 2)
            local e = {t = eKEYS, p = p, i = key_focus, note = current_note, action = "note_off"} event(e)
          end)    
        end
      end
      if trigs_config_view then dirtygrid = true end
    end
  end
end

function run_keyrepeat()
  while true do
    clock.sync(rep_rate)
    if key_repeat then
      if trig_step >= trigs[trigs_focus].step_max then
        trig_step = 0
      end
      trig_step = trig_step + 1
      if #notes_held > 0 and trigs[trigs_focus].pattern[trig_step] == 1 then
        for _, v in ipairs(notes_held) do
          local p = pattern[pattern_focus].rec == 1 and pattern_focus or nil
          if voice[key_focus].keys_option == 1 then
            local e = {t = eSCALE, p = p, i = key_focus, root = root_oct, note = v, action = "note_on"} event(e)
            clock.run(function()
              clock.sync(rep_rate / 2)
              local e = {t = eSCALE, p = p, i = key_focus, root = root_oct, note = v, action = "note_off"} event(e)
            end)
          elseif voice[key_focus].keys_option == 4 then
            local e = {t = eDRUMS, i = key_focus, note = v, vel = drum_vel_last} event(e)
          else
            local e = {t = eKEYS, p = p, i = key_focus, note = v, action = "note_on"} event(e)
            clock.run(function()
              clock.sync(rep_rate / 2)
              local e = {t = eKEYS, p = p, i = key_focus, note = v, action = "note_off"} event(e)
            end)    
          end
        end
      end
      if #kit_held > 0 and trigs[trigs_focus].pattern[trig_step] == 1 then
        for _, v in ipairs(kit_held) do
          local e = {t = eKIT, note = v} event(e)
        end
      end
      if trigs_config_view then dirtygrid = true end
    end
  end
end

function autostrum()
  local rate = strum_rate
  local endpoint = strum_count + chord_inversion - 1
  for i = chord_inversion, endpoint do
    local step = i
    local pos = i - chord_inversion + 1
    if strum_mode == 2 then
      if pos % 2 == 0 then
        step = endpoint - pos + 1
      end
    elseif strum_mode == 3 then
      step = math.random(chord_inversion, endpoint)
    elseif strum_mode == 4 then
      if pos % 2 ~= 0 then
        step = endpoint - pos
      end
    elseif strum_mode == 5 then
      step = endpoint - pos + 1
    end
    if step > 15 then step = 15 end
    local note = chord_arp[step] + (12 * chord_oct_shift)
    local e = {t = eKEYS, p = pattern_focus, i = strum_focus, note = note, action = "note_on"} event(e)
    clock.run(function()
      clock.sleep(rate)
      local e = {t = eKEYS, p = pattern_focus, i = strum_focus, note = note, action = "note_off"} event(e)
    end)
    clock.sleep(rate)
    rate = rate - (i * strum_skew * 0.001)
  end
end

function set_repeat_rate()
  local off = GRIDSIZE == 128 and 0 or 8
  -- get key state
  local key1 = gkey[16][5 + off].active
  local key2 = gkey[16][6 + off].active
  local key3 = gkey[16][7 + off].active
  local key4 = gkey[16][8 + off].active
  -- get key_repeat state
  if not key_repeat then
    trig_step = 0
  end
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

function kit_gridviz(note_num)
  local n = note_num - (kit_oct * 16) - 47
  local x = (n > 8 and n - 5 or n + 3)
  local y = (n > 8 and 1 or 2) + (GRIDSIZE == 128 and 2 or 9)
  if x > 3 and x < 12 then
    gkey[x][y].active = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(1/30)
      gkey[x][y].active = false
      dirtygrid = true
    end)
  end
end

-------- playback --------
function play_voice(i, note_num, vel)
  local velocity = vel or voice[i].velocity
  if not voice[i].mute then
    -- polyform group 1
    if (voice[i].output == 1 or voice[i].output == 2) then
      local synth = voice[i].output
      local offset = synth == 1 and 0 or 4
      for i, v in ipairs(voicetab[synth]) do
        if v == 0 then
          voicenotes[synth][i] = note_num
          voicetab[synth][i] = 1
          local freq = mu.note_num_to_freq(note_num)
          engine.trig(i + offset, freq)
          table.insert(lastvoice[synth], 1, i)
          return
        end
      end
      if not tab.contains(voicetab[synth], 0) then
        local voice = lastvoice[synth][4]
        voicenotes[synth][voice] = note_num
        voicetab[synth][voice] = 1
        local freq = mu.note_num_to_freq(note_num)
        engine.trig(voice + offset, freq)
        table.insert(lastvoice[synth], 1, voice)
      end
    elseif voice[i].output == 3 then
      play_midi(i, note_num, velocity, voice[i].midi_ch)
    -- crow output 1+2
    elseif voice[i].output == 4 then
      crow.output[1].volts = ((note_num - 60) / v8_std_1)
      crow.output[2].action = "ar("..env1_a..", "..env1_r..", "..env1_amp..", "..env1_crv..")"
      crow.output[2]()
    -- crow output 3+4
    elseif voice[i].output == 5 then
      crow.output[3].volts = ((note_num - 60) / v8_std_2)
      crow.output[4].action = "ar("..env2_a..", "..env2_r..", "..env2_amp..", "..env2_crv..")"
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
      play_midi(midi_out_dev, note_num, velocity, channel, midi_thru_dur)
    end
  end
end

function play_midi(i, note_num, velocity, channel, duration)
  local duration = duration or voice[i].length
  m[i]:note_on(note_num, velocity, channel)
  if duration > 0 then
    clock.run(function()
      clock.sleep(duration)
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

function play_kit(note_num)
  m[kit_midi_dev]:note_on(note_num, kit_velocity, kit_midi_ch)
  clock.run(function()
    clock.sync(1/8)
    m[kit_midi_dev]:note_off(note_num, 0, kit_midi_ch)
  end)
end

function mute_voice(i, note_num)
  if voice[i].output == 1 or voice[i].output == 2 then
    free_voice(voice[i].output, note_num)
  elseif voice[i].output == 3 then
    m[i]:note_off(note_num, 0, voice[i].midi_ch)
  elseif voice[i].output > 7 then
    local player = params:lookup_param("nb_"..(voice[i].output - 7)):get_player()
    player:note_off(note_num)
  end
end

function free_voice(i, note_num)
  if tab.contains(voicenotes[i], note_num) then
    local offset = i == 1 and 0 or 4
    local voice = tab.key(voicenotes[i], note_num)
    engine.stop(voice + offset)
    voicetab[i][voice] = 0
    voicenotes[i][voice] = 0
    if not tab.contains(voicetab[i], 1) then
      lastvoice[i] = {}
    end
  end
end


function init()
  -- calc grid size
  get_grid_size()

  -- get eng to softcut level
  --eng_level = params:get("cut_input_eng")
  --params:set("cut_input_eng", -inf)

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

  -- populate chord tables
  build_chords()

  -- build midi device list
  build_midi_device_list()
 
  -- global params
  params:add_separator("global_settings", "global")

  params:add_option("scale", "scale", scale_names, 2)
  params:set_action("scale", function(val) current_scale = val set_scale() dirtygrid = true end)

  params:add_number("root_note", "root note", 24, 84, 60, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("root_note", function(val) root_note = val set_scale() dirtygrid = true end)

  params:add_option("metronome_viz", "metronome", {"hide", "show"}, 2)
  params:set_action("metronome_viz", function(mode) set_metronome(mode) end)
        
  params:add_option("key_quant_value", "key quantization", options.key_quant, 7)
  params:set_action("key_quant_value", function(idx) quant_rate = options.quant_value[idx] * 4 end)
  params:hide("key_quant_value")
  
  params:add_option("key_seq_rate", "seq rate", options.key_quant, 7)
  params:set_action("key_seq_rate", function(idx) seq_rate = options.quant_value[idx] * 4 end)
  params:hide("key_seq_rate")


  params:add_group("global_midi_group", "midi settings", 10)

  params:add_separator("glb_midi_in_params", "midi in")

  params:add_option("glb_midi_in_device", "midi in device", midi_devices, 1)
  params:set_action("glb_midi_in_device", function(val) m[midi_in_dev] = midi.connect(val) set_midi_event_callback() end)

  params:add_number("glb_midi_in_channel", "midi in channel", 1, 16, 14)
  params:set_action("glb_midi_in_channel", function(val) notes_off(midi_in_dev) midi_in_ch = val end)

  params:add_option("glb_midi_in_quantization", "map to scale", {"no", "yes"}, 1)
  params:set_action("glb_midi_in_quantization", function(mode) midi_in_quant = mode == 2 and true or false end)

  params:add_option("glb_midi_in_destination", "send midi to..", {"midi out", "voice 1", "voice 2", "voice 3", "voice 4", "voice 5", "voice 6"})
  params:set_action("glb_midi_in_destination", function(dest) midi_in_dest = dest - 1 end)

  params:add_separator("glb_midi_out_params", "midi out")

  params:add_option("glb_midi_out_device", "midi out device", midi_devices, 1)
  params:set_action("glb_midi_out_device", function(val) m[midi_out_dev] = midi.connect(val) end)

  params:add_number("glb_midi_out_channel", "midi out channel", 1, 16, 1)
  params:set_action("glb_midi_out_channel", function(val) notes_off(midi_out_dev) midi_out_ch = val end)

  params:add_option("glb_midi_thru", "mirror voices", {"no", "yes"}, 1)
  params:set_action("glb_midi_thru", function(val) midi_thru = val == 2 and true or false end)

  params:add_binary("glb_midi_panic", "don't panic", "trigger", 0)
  params:set_action("glb_midi_panic", function() all_notes_off() end)


  params:add_group("keyboard_group", "keyboard settings", 21)

  params:add_separator("scale_keys", "scale keys")

  params:add_number("scale_keys_y", "interval [y]", 1, 6, 4)
  params:set_action("scale_keys_y", function(val) scalekeys_y = val - 1 dirtygrid = true end)

  params:add_separator("chrom_keys", "chromatic keys")

  params:add_number("chrom_keys_x", "interval [x]", 1, 6, 1)
  params:set_action("chrom_keys_x", function(val) chromakeys_x = val dirtygrid = true end)

  params:add_number("chrom_keys_y", "interval [y]", 1, 6, 5)
  params:set_action("chrom_keys_y", function(val) chromakeys_y = val dirtygrid = true end)

  params:add_separator("chord_keys", "chord keys")

  params:add_option("chord_limit", "limit to scale", {"no", "yes"}, 2)
  params:set_action("chord_limit", function(mode) chord_any = mode == 1 and true or false end)

  params:add_number("strm_length", "strum length", 4, 12, 6, function(param) return round_form((param:get()), 1,"notes") end)
  params:set_action("strm_length", function(val) strum_count = val end)

  params:add_option("strm_mode", "strum mode", {"up", "alt lo", "random", "alt hi", "down"}, 1)
  params:set_action("strm_mode", function(val) strum_mode = val end)

  params:add_number("strm_skew", "strum skew", -30, 30, 0, function(param) return round_form((util.linlin(-30, 30, -100, 100, param:get())), 1,"%") end)
  params:set_action("strm_skew", function(val) strum_skew = val end)

  params:add_number("strm_rate", "strum rate", 4, 100, 20, function(param) return round_form((1 / param:get()), 0.001,"hz") end)
  params:set_action("strm_rate", function(val) strum_rate = val / 200 end)

  params:add_separator("drum_keys", "drumpad keys")

  params:add_number("drum_root_note", "drumpad root note", 0, 127, 0, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("drum_root_note", function(val) drum_root_note = val end)

  params:add_number("drum_vel_hi", "hi velocity", 1, 127, 100)
  params:set_action("drum_vel_hi", function(val) drum_vel_hi = val end)

  params:add_number("drum_vel_mid", "mid velocity", 1, 127, 64)
  params:set_action("drum_vel_mid", function(val) drum_vel_mid = val end)

  params:add_number("drum_vel_lo", "lo velocity", 1, 127, 32)
  params:set_action("drum_vel_lo", function(val) drum_vel_lo = val end)

  params:add_separator("kit_keys", "kit keys")

  params:add_option("kit_out_device", "kit out device", midi_devices, 1)
  params:set_action("kit_out_device", function(val) m[kit_midi_dev] = midi.connect(val) end)

  params:add_number("kit_midi_channel", "kit midi channel", 1, 16, 7)
  params:set_action("kit_midi_channel", function(val) kit_midi_ch = val end)

  params:add_number("kit_root_note", "kit root note", 24, 84, 60, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("kit_root_note", function(val) kit_root_note = val dirtygrid = true end)

  params:add_number("kit_note_velocity", "kit velocity", 1, 127, 100)
  params:set_action("kit_note_velocity", function(val) kit_velocity = val end)

  params:add_group("octave_params", "octaves", 14)
  params:hide("octave_params")

  for i = 1, NUM_VOICES do
    params:add_number("interval_octaves_"..i, "interval octaves", -3, 3, 0)
    params:set_action("interval_octaves_"..i, function(val) notes_oct_int[i] = val end)

    params:add_number("keys_octaves_"..i, "keys octaves", -3, 3, 0)
    params:set_action("keys_octaves_"..i, function(val) notes_oct_key[i] = val end)
  end

  params:add_number("strum_octaves", "strum octaves", -3, 3, 0)
  params:set_action("strum_octaves", function(val) chord_oct_shift = val end)

  params:add_number("kit_octaves", "kit octaves", -3, 3, 0)
  params:set_action("kit_octaves", function(val) kit_oct = val end)

  -- patterns params
  params:add_group("patterns", "patterns", 48)
  params:hide("patterns")
  for i = 1, 8 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("patterns_playback_"..i, "playback", options.pattern_play, 1)
    params:set_action("patterns_playback_"..i, function(mode) pattern[i].loop = mode == 1 and 1 or 0 save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_quantize_"..i, "quantize", options.pattern_quantize, 7)
    params:set_action("patterns_quantize_"..i, function(idx) pattern[i].quantize = options.pattern_quantize_value[idx] save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_launch_"..i, "launch mode", options.pattern_launch, 3)
    params:set_action("patterns_launch_"..i, function() save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_meter_"..i, "meter", options.pattern_meter, 3)
    params:set_action("patterns_meter_"..i, function(idx) pattern[i].meter = options.meter_val[idx] update_pattern_length(i) end)

    params:add_number("patterns_beatnum_"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("patterns_beatnum_"..i, function(num) pattern[i].beatnum = num * 4 update_pattern_length(i) dirtygrid = true end)
  end

  -- voice params
  params:add_separator("voices", "voices")
  for i = 1, NUM_VOICES do
    params:add_group("voice_"..i, "voice "..i, 11)
    -- output
    params:add_option("voice_out"..i, "output", options.output, 1)
    params:set_action("voice_out"..i, function(val) voice[i].output = val manage_ii() build_menu() end)
    -- mute
    params:add_option("voice_mute"..i, "mute", {"off", "on"}, 1)
    params:set_action("voice_mute"..i, function(val) voice[i].mute = val == 2 and true or false dirtygrid = true end)
    -- keyboard
    params:add_option("keys_option"..i, "keyboard type", {"scale", "chromatic", "chords", "drums"}, 1)
    params:set_action("keys_option"..i, function(val) voice[i].keys_option = val dirtygrid = true build_menu() end)

    -- midi params
    params:add_option("midi_device"..i, "midi device", midi_devices, 1)
    params:set_action("midi_device"..i, function(val) m[i] = midi.connect(val) end)

    params:add_number("midi_channel"..i, "midi channel", 1, 16, i)
    params:set_action("midi_channel"..i, function(val) notes_off(i) voice[i].midi_ch = val end)

    params:add_number("note_velocity"..i, "velocity", 1, 127, 100)
    params:set_action("note_velocity"..i, function(val) voice[i].velocity = val end)

    params:add_control("note_length"..i, "note length", controlspec.new(0, 2, "lin", 0.01, 0, ""), function(param) return param:get() == 0 and "played" or param:get().." s" end)
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
  polyform.add_params()
  -- crow params
  params:add_group("crow_out_1+2", "crow [out 1+2]", 5)
  params:add_option("v8_type_1", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_1", function(x) if x == 1 then v8_std_1 = 12 else v8_std_1 = 10 end end)

  params:add_control("env1_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env1_amplitude", function(value) env1_amp = value end)

  params:add_option("env1_shape", "env shape", env_shapes, 2)
  params:set_action("env1_shape", function(mode) env1_crv = env_shapes[mode] end)

  params:add_control("env1_attack", "attack", controlspec.new(0.00, 10, "lin", 0.01, 0.00, "s"))
  params:set_action("env1_attack", function(value) env1_a = value end)

  params:add_control("env1_decay", "release", controlspec.new(0.01, 10, "lin", 0.01, 0.4, "s"))
  params:set_action("env1_decay", function(value) env1_r = value end)

  params:add_group("crow_out_3+4", "crow [out 3+4]", 5)
  params:add_option("v8_type_2", "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
  params:set_action("v8_type_2", function(x) if x == 1 then v8_std_2 = 12 else v8_std_2 = 10 end end)

  params:add_control("env2_amplitude", "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
  params:set_action("env2_amplitude", function(value) env2_amp = value end)

  params:add_option("env2_shape", "env shape", env_shapes, 2)
  params:set_action("env2_shape", function(mode) env2_crv = env_shapes[mode] end)

  params:add_control("env2_attack", "attack", controlspec.new(0.00, 10, "lin", 0.01, 0.00, "s"))
  params:set_action("env2_attack", function(value) env2_a = value end)

  params:add_control("env2_decay", "release", controlspec.new(0.01, 10, "lin", 0.01, 0.4, "s"))
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
        pattern_data[i].trigs_max = trigs[i].step_max
        pattern_data[i].trigs_pattern = {table.unpack(trigs[i].pattern)}
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
    --softcut.buffer_clear()
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
        if pattern_data[i].trigs_max then -- TODO: remove when saved all psets
          trigs[i].step_max = pattern_data[i].trigs_max
          trigs[i].pattern = {table.unpack(pattern_data[i].trigs_pattern)}
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
  notes_last = notes_home
  --set_defaults()
  set_my_defaults()
  midi_thru_dur = clock.get_beat_sec() * 1/4

  -- hardware callbacks
  m[midi_in_dev].event = midi_events

  -- metros
  hardwareredrawtimer = metro.init(hardware_redraw, 1/30, -1)
  hardwareredrawtimer:start()
  dirtygrid = true

  screenredrawtimer = metro.init(screen_redraw, 1/15, -1)
  screenredrawtimer:start()
  dirtyscreen = true

  -- clocks
  clock.run(event_q_clock)
  clock.run(run_seq)
  clock.run(run_keyrepeat)

  -- lattice
  vizclock = lattice:new()

  fastpulse = vizclock:new_sprocket{
    action = function(t) ledpulse_fast() end,
    division = 1/32,
    enabled = true
  }

  midpulse = vizclock:new_sprocket{
    action = function() ledpulse_mid() end,
    division = 1/24,
    enabled = true
  }

  slowpulse = vizclock:new_sprocket{
    action = function() ledpulse_slow() end,
    division = 1/12,
    enabled = true
  }

  vizclock:start()

end

-------- norns interface --------
function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config or pageNum == 3) then
    if n > 1 and z == 1 then
      local d = n == 2 and -1 or 1
      if shift then
        pattern_focus = util.wrap(pattern_focus + d, 1, 8)
      else
        pattern_param_focus = util.wrap(pattern_param_focus + d, 1, 3)
      end
    end
  else
    if pageNum == 1 then
      if n == 2 and z == 1 then
        transposing = not transposing
      elseif n == 3 and z == 1 then
        if not transposing then
          transpose_value = 0
        end
      end
    elseif pageNum == 2 then
      if n > 1 and z == 1 then
        if shift then
          local d = n == 2 and -1 or 1
          voice_focus = util.wrap(voice_focus + d, 1, 6)
        else
          local d = n == 2 and -2 or 2
          if voice[voice_focus].output < 8 then
            voice_param_focus[voice_focus] = util.wrap(voice_param_focus[voice_focus] + d, 1, #voice_params[voice[voice_focus].output])
          end
        end        
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function enc(n, d)
  if n == 1 then
    pageNum = util.clamp(pageNum + d, 1, 3)
  end
  if keyquant_edit then
    if n > 1 then
      params:delta("key_quant_value", d)
    end
  elseif (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config or pageNum == 3) then
    if not (pattern_param_focus == 1 and ((pattern_rec_mode == "free" and pattern[pattern_focus].endpoint == 0) or pattern[pattern_focus].manual_length)) then
      if n == 2 then
        params:delta(pattern_e2_params[pattern_param_focus]..pattern_focus, d)
      elseif n == 3 and pattern_param_focus ~= 3 then
        params:delta(pattern_e3_params[pattern_param_focus]..pattern_focus, d)
      end
      dirtyscreen = true
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
    local dest = voice[voice_focus].output
    local param = voice_param_focus[voice_focus]
    if dest < 8 and n > 1 then
      local off = n == 2 and 0 or 1
      if dest == 3 or dest == 6 then
        params:delta(voice_params[dest][param + off]..voice_focus, d)
      else
        params:delta(voice_params[dest][param + off], d)
      end
    end
  end
  dirtygrid = true
  dirtyscreen = true
end

function redraw()
  screen.clear()
  screen.font_face(2)
  if keyquant_edit then
    screen.font_size(16)
    screen.level(15)
    screen.move(64, 28)
    screen.text_center(params:string("key_quant_value"))
    screen.level(3)
    screen.move(64, 46)
    screen.text_center("key     quantization") 
  elseif (pattern_view or pattern_meter_config or pattern_length_config or pattern_options_config or pageNum == 3) then
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("pattern   "..pattern_focus.."       bank   "..p[pattern_focus].bank)
    -- param list
    screen.level(4)
    screen.move(30, 60)
    screen.text_center(pattern_e2_names[pattern_param_focus])
    screen.move(98, 60)
    screen.text_center(pattern_e3_names[pattern_param_focus])

    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    if pattern_param_focus == 1 and ((pattern_rec_mode == "free" and pattern[pattern_focus].endpoint == 0) or pattern[pattern_focus].manual_length) then
      screen.text_center("-")
    else
      screen.text_center(params:string(pattern_e2_params[pattern_param_focus]..pattern_focus))
    end
    screen.move(98, 39)
    if (pattern_param_focus == 1 and ((pattern_rec_mode == "free" and pattern[pattern_focus].endpoint == 0) or pattern[pattern_focus].manual_length)) or pattern_param_focus == 3 then
      screen.text_center("-")
    else
      screen.text_center(params:string(pattern_e3_params[pattern_param_focus]..pattern_focus))
    end
  else
    if pageNum == 1 then
      local offset = 16

      for i = 1, #white_keys do
        screen.level((notes_viz - notenum_w[i]) % 12 == 0 and 15 or (noteis_w[i] and 6 or 1))
        screen.move(16 + (i - 1) * offset, 41)
        screen.font_size(8)
        screen.text_center(white_keys[i])
      end

      for i = 1, #black_keys_1 do
        screen.level((notes_viz - notenum_b1[i]) % 12 == 0 and 15 or (noteis_b1[i] and 6 or 1))
        screen.move(24 + (i - 1) * offset, 29)
        screen.font_size(8)
        screen.text_center(black_keys_1[i])
      end

      for i = 1, #black_keys_2 do
        screen.level((notes_viz - notenum_b2[i]) % 12 == 0 and 15 or (noteis_b2[i] and 6 or 1))
        screen.move(72 + (i - 1) * offset, 29)
        screen.font_size(8)
        screen.text_center(black_keys_2[i])
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
      local semitone = scale_notes[tab.key(scale_notes, root_note) + transpose_value] - root_note
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
      screen.move(64, 12)
      screen.text_center("voice "..voice_focus.." - "..params:string("voice_out"..voice_focus))
      -- param list
      local dest = voice[voice_focus].output
      local param = voice_param_focus[voice_focus]
      if dest < 8 then
        screen.level(4)
        screen.move(30, 60)
        screen.text_center(voice_param_names[dest][param])
        screen.move(98, 60)
        screen.text_center(voice_param_names[dest][param + 1])

        screen.font_size(16)
        screen.level(15)
        screen.move(30, 39)
        if (dest == 3 or dest == 6) then
          screen.text_center(params:string(voice_params[dest][param]..voice_focus))
        else
          if dest < 3 then
            if param == 7 then
              local width = 50
              local offset = params:get(voice_params[dest][param]) * 25 + 25
              screen.line_width(2)
              screen.move(6, 40)
              --screen.curve_rel (x1, y1, x2, y2, 0 + offset, -16)
              screen.line_rel(0 + offset, -16)
              screen.move(6 + width, 40)
              screen.line_rel(-width + offset, -16)
              screen.stroke()
            else
              screen.text_center(params:string(voice_params[dest][param]))
            end
          else
            screen.text_center(params:string(voice_params[dest][param]))
          end
        end
        screen.move(98, 39)
        if (dest == 3 or dest == 6) then
          screen.text_center(params:string(voice_params[dest][param + 1]..voice_focus))
        else
          screen.text_center(params:string(voice_params[dest][param + 1]))
        end
      else
        screen.font_size(16)
        screen.level(12)
        screen.move(64, 39)
        screen.text_center(params:string("nb_"..dest - 7))
        screen.font_size(8)
        screen.level(6)
        screen.move(64, 55)
        screen.text_center("edit in params")
      end
    end
  end
  -- display messages
  if view_message ~= "" then
    screen.clear()
    screen.font_size(8)
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
    grd_one.keys(x, y, z)
  elseif GRIDSIZE == 256 then
    grd_zero.keys(x, y, z)
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

function round_form(param, quant, form)
  return(util.round(param, quant)..form)
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

function build_menu()
  for i = 1, NUM_VOICES do
    if (voice[i].output == 3 or voice[i].output == 8 or voice[i].output == 9) and voice[i].keys_option < 4 then
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
  if g then
    GRIDSIZE = g.cols * g.rows
  end
  if GRIDSIZE == 256 and rotate_grid then
    g:rotation(1) -- 1 is 90°
  end
end

function grid.add()
  get_grid_size()
  dirtygrid = true
end

function cleanup()
  --params:set("cut_input_eng", eng_level)
  if GRIDSIZE == 128 then
    grd_one.end_msg()
  elseif GRIDSIZE == 256 then
    grd_zero.end_msg()
  end
  grid.add = function() end
  midi.add = function() end
  midi.remove = function() end
  crow.ii.jf.mode(0)
end
