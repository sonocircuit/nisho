-- nisho v1.6.2 @sonocircuit
-- llllllll.co/t/nisho
--
--   six voices & eight patterns
--        for performance
--                &
--           composition
--
 
---------------------------------------------------------------------------
-- TODO: ditch adsr for engine or figure out how to add a sensible note allocation
-- TODO: fix crow env shapes -> not responding to 'exp' 'lin' 'log'
-- KNOWN BUG: patterns not catching more than 1 note at step_one (onset pattern rec)
-- KNOWN BUG: notes off values are not transposed -> hanging notes when transposing and note length is set to "played".
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

-- constants
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

-- keyboards
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

-- kit
kit_view = false
kit_root_note = 60
kit_midi_dev = 7
kit_midi_ch = 1
kit_velocity = 100
kit_oct = 0
kit_held = {}
held_bank = 0
midi_bank = 0

-- sequencer
seq_notes = {}
prev_seq_notes = {}
collected_notes = {}
seq_active = false
sequencer_config = false
collecting_notes = false
appending_notes = false
notes_added = false
seq_step = 0
seq_rate = 1/4
seq_hold = false

-- key repeat
key_repeat_view = false
latch_key_repeat = false
key_repeat = false
rep_rate = 1/4

--trig patterns
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

-- midi
midi_in_dev = 9
midi_in_ch = 1
midi_in_dest = 0
midi_in_quant = false
midi_out_dev = 7
midi_out_ch = 1
midi_thru = false

-- chord
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

-- scale
root_oct = 3 -- number of octaves root_note differs from root_base. required for changing root note after pattern rec.
root_note = 60 -- root note set by scale param. corresponds to note.home
root_base = 24 -- lowest note of the scale
current_scale = 1
scale_notes = {}

-- notes
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

-- note viz
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

-- key viz
pulse_bar = false
pulse_beat = false
pulse_key_fast = 8
pulse_key_mid = 4
pulse_key_slow = 4
hide_metronome = false

-- preset and pattern loading
loading_page = false
view_pattern_import = false
pattern_src = 1
pattern_dst = 1
pset_focus = 1
loaded_pattern_data = nil

-- program change loading
prgchange_view = false

-- screen viz
view_message = ""

-- key quantization
key_quantize = false
quant_rate = 16
quant_event = {}

-- patterns
pattern_rec_mode = "queued"
pattern_overdub = false
copying_pattern = false
copy_src = {state = false, pattern = nil, bank = nil}
pasting_pattern = false
duplicating_pattern = false
appending_pattern = false
pattern_reset = false
pattern_clear = false
pattern_view = false
pattern_len_edit = false
pattern_focus = 1
bank_focus = 1
keyquant_edit = false
pattern_bank_page = 0

stop_all = false
stop_all_timer = nil

-- events
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
  voice[i].midi_cc = {}
  voice[i].jf_ch = i
  voice[i].jf_amp = 5
  for n = 1, 4 do
    voice[i].midi_cc[n] = 0
  end
end

synthvoice = {}
for i = 1, 2 do
  synthvoice[i] = i + (i - 1) * 3
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
for i = 1, 9 do -- 6 voices + kit(7) + midi out(8) + midi in(9)
  m[i] = midi.connect()
end

mcc = {} -- midi cc's sent via kit
for i = 1, 16 do
  mcc[i] = {}
  mcc[i].num = 0
  mcc[i].min = 0
  mcc[i].max = 127
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

voice_params = {
  {"main_amp1", "pan1", "formant_amp1", "pulse_amp1", "noise_amp1", "noise_crackle1",
  "formant_shape1", "formant_curve1", "formant_type1", "formant_width1", "pulse_tune1", "pulse_width1",
  "pwm_rate1", "pwm_depth1", "lpf_cutoff1", "lpf_resonance1", "env_lpf_depth1", "hpf_cutoff1",
  "attack1", "decay1", "sustain1", "release1", "env_type1", "env_curve1", "vib_freq1", "vib_depth1"}, --polyform [one]
  {"main_amp2", "pan2", "formant_amp2", "pulse_amp2", "noise_amp2", "noise_crackle2",
  "formant_shape2", "formant_curve2", "formant_type2", "formant_width2", "pulse_tune2", "pulse_width2",
  "pwm_rate2", "pwm_depth2", "lpf_cutoff2", "lpf_resonance2", "env_lpf_depth2", "hpf_cutoff2",
  "attack2", "decay2", "sustain2", "release2", "env_type2", "env_curve2","vib_freq2", "vib_depth2"}, --polyform [two]
  {"note_length", "note_velocity", "midi_device", "midi_channel", "midi_cc_val_1_", "midi_cc_val_2_", "midi_cc_val_3_", "midi_cc_val_4_"}, --midi
  {"env1_amplitude", "env1_shape", "env1_attack", "env1_decay"}, --crow 1+2
  {"env2_amplitude", "env2_shape", "env2_attack", "env2_decay"}, --crow 3+4
  {"jf_amp", "jf_voice"}, --crow ii jf
  {"wysn_mode", "wsyn_amp", "wsyn_curve", "wsyn_ramp", "wsyn_lpg_time", "wsyn_lpg_sym",
  "wsyn_fm_index", "wsyn_fm_env", "wsyn_fm_num", "wsyn_fm_den"} --crow ii wsyn
}

voice_param_names = {
  {"main   level", "pan", "formant   level", "pulse   level", "noise   level", "noise   crackle",
  "formant   shape", "formant   curve", "formant   type", "formant   width",
  "pulse   tune", "pulse   width", "pwm   rate", "pwm   depth", "lpf   cutoff", "lpf   resonance",
  "env   depth", "hpf   cutoff", "attack", "decay", "sustain", "release", "env   type", "env   curve", "vibrato   rate", "vibrato   depth"}, --polyform [one]
  {"main   level", "pan", "formant   level", "pulse   level", "noise   level", "noise   crackle",
  "formant   shape", "formant   curve", "formant   type", "formant   width",
  "pulse   tune", "pulse   width", "pwm   rate", "pwm   depth", "lpf   cutoff", "lpf   resonance",
  "env   depth", "hpf   cutoff", "attack", "decay", "sustain", "release", "env   type", "env   curve", "vibrato   rate", "vibrato   depth"}, --polyform [two]
  {"note   length", "velocity", "device", "channel", "cc A", "cc B", "cc C", "cc D"}, --
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
pattern_e3_params = {"patterns_barnum_", "patterns_quantize_", ""}
pattern_e2_names = {"meter", "launch", "playback"}
pattern_e3_names = {"length", "quantize", ""}

-------- scales --------
function build_scale()
  root_base = root_note % 12 + 24
  root_oct = math.floor((root_note - root_base) / 12)
  scale_notes = mu.generate_scale_of_length(root_base, current_scale, 50)
  note_map = mu.generate_scale_of_length(root_note % 12, current_scale, 100)
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
      local e = {t = eKEYS, i = key_focus, note = value, action = "note_off"} event(e)
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
      for index, value in ipairs(current_chord) do
        chord[index].event = {t = eKEYS, i = key_focus, note = value, action = "note_on"} event(chord[index].event)
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
      notes_added = true
    end
    -- play seq
    if seq_active and not (collecting_notes or appending_notes) then
      if #chord_arp > 0 then
        seq_notes = {}
        for note = chord_inversion, strum_count + chord_inversion do
          table.insert(seq_notes, chord_arp[note])
          table.insert(prev_seq_notes, chord_arp[note])
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

function set_my_defaults() -- my standard setup
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
  params:set("midi_device3", 1)
  params:set("midi_channel3", 4)
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
  params:set("midi_channel6", 1)
end


-------- pattern recording --------
function event_exec(e, n)
  if e.t == eSCALE then
    local octave = (root_oct - e.root) * (#scale_intervals[current_scale] - 1)
    local idx = util.clamp(e.note + transpose_value + octave, 1, #scale_notes)
    local note_num = scale_notes[idx]
    if e.action == "note_off" and voice[e.i].length == 0 then
      mute_voice(e.i, note_num)
      remove_active_notes(n, e.i, note_num)
    elseif e.action == "note_on" then
      play_voice(e.i, note_num)
      add_active_notes(n, e.i, note_num)
      notes_viz = note_num
    end
  elseif e.t == eKEYS then
    if e.action == "note_off" and voice[e.i].length == 0 then
      mute_voice(e.i, e.note)
      remove_active_notes(n, e.i, e.note)
    elseif e.action == "note_on" then
      play_voice(e.i, e.note)
      add_active_notes(n, e.i, e.note)
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
    if e.action == "note_on" then    
      m[midi_out_dev]:note_on(e.note, e.vel, e.ch)
      add_active_notes(n, 7, e.note)
    elseif e.action == "note_off" then
      m[midi_out_dev]:note_off(e.note, 0, e.ch)
      remove_active_notes(n, 7, e.note)
    end
  elseif e.t == eKIT then
    play_kit(e.note)
    kit_gridviz(e.note)
  end
  dirtyscreen = true
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

pattern = {}
for i = 1, 8 do
  pattern[i] = mirror.new(i)
  pattern[i].process = event_exec
  pattern[i].start_callback = function() step_one_indicator(i) set_pattern_length(i) kill_active_notes(i) end
  pattern[i].end_of_loop_callback = function() update_pattern_bank(i) end
  pattern[i].end_of_rec_callback = function() clock.run(function() clock.sleep(0.2) save_pattern_bank(i, p[i].bank) end) end
  pattern[i].end_callback = function() kill_active_notes(i) dirtygrid = true end
  pattern[i].step_callback = function() if (pattern_view or GRIDSIZE == 256) then dirtygrid = true end end
  pattern[i].meter = 4/4
  pattern[i].barnum = 4
  pattern[i].length = 16
  pattern[i].active_notes = {}
  for voice = 1, NUM_VOICES + 1 do
    pattern[i].active_notes[voice] = {}
  end
end

p = {}
for i = 1, 8 do
  p[i] = {}
  p[i].bank = 1
  p[i].load = nil
  p[i].stop = false
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
  p[i].barnum = {}
  p[i].meter = {}
  p[i].length = {}
  p[i].manual_length = {}
  p[i].prc_enabled = false
  p[i].prc_ch = i
  p[i].prc_num = {}
  p[i].prc_option = {}
  for j = 1, 24 do
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
    p[i].barnum[j] = 4
    p[i].meter[j] = 4/4
    p[i].length[j] = 16
    p[i].manual_length[j] = false
    p[i].prc_num[j] = 0
    p[i].prc_option[j] = 1
  end
end

function add_active_notes(i, voice, note_num)
  if i ~= nil then
    table.insert(pattern[i].active_notes[voice], note_num)
  end
end

function remove_active_notes(i, voice, note_num)
  if i ~= nil then
    table.remove(pattern[i].active_notes[voice], tab.key(pattern[i].active_notes[voice], note_num))
  end
end

function kill_active_notes(i)
  for voice = 1, NUM_VOICES do
    if #pattern[i].active_notes[voice] > 0 and pattern[i].endpoint > 0 then
      for _, note in ipairs(pattern[i].active_notes[voice]) do
        mute_voice(voice, note)
      end
      pattern[i].active_notes[voice] = {}
    end
  end
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
  if pattern[i].rec == 0 then
    local prev_length = pattern[i].length
    pattern[i].length = pattern[i].meter * pattern[i].barnum * 4
    if prev_length ~= pattern[i].length then
      pattern[i]:set_length(pattern[i].length)
      save_pattern_bank(i, p[i].bank)
      --print("saved pattern bank", i, p[i].bank)
    end
  end
end

function update_pattern_length(i)
  if pattern[i].play == 0 then
    set_pattern_length(i)
  end
end

function reset_pattern_length(i, bank)
  p[i].endpoint[bank] = p[i].endpoint_init[bank]
  p[i].step_max[bank] = p[i].endpoint_init[bank]
  if (p[i].endpoint_init[bank] % 64 ~= 0 or p[i].endpoint_init[bank] < 128) then
    p[i].manual_length[bank] = true
  end
  if bank == p[i].bank then
    load_pattern_bank(i, bank)
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

function copy_pattern(src, src_bank, dst, dst_bank)
  p[dst].loop[dst_bank] = p[src].loop[src_bank]
  p[dst].quantize[dst_bank] = p[src].quantize[src_bank]
  p[dst].count[dst_bank] = p[src].count[src_bank]
  p[dst].event[dst_bank] = deep_copy(p[src].event[src_bank])
  p[dst].endpoint[dst_bank] = p[src].endpoint[src_bank]
  p[dst].endpoint_init[dst_bank] = p[src].endpoint_init[src_bank]
  p[dst].step_min[dst_bank] = 0
  p[dst].step_max[dst_bank] = p[src].endpoint[src_bank]
  p[dst].barnum[dst_bank] = p[src].barnum[src_bank]
  p[dst].meter[dst_bank] = p[src].meter[src_bank]
  p[dst].length[dst_bank] = p[src].length[src_bank]
  p[dst].manual_length[dst_bank] = p[src].manual_length[src_bank]
  if dst_bank == p[dst].bank then
    load_pattern_bank(dst, dst_bank)
  end
end

function append_pattern(src, src_bank, dst, dst_bank, src_s, src_e)
  local s = src_s or 0
  local e = src_e or p[src].endpoint[src_bank]
  local length = e and (e - s) or p[src].endpoint[src_bank]
  -- append pattern
  local copy = deep_copy(p[src].event[src_bank])
  for i = s, e do
    p[dst].event[dst_bank][p[dst].endpoint[dst_bank] + (i - s)] = copy[i]
  end
  -- set endpoint
  p[dst].count[dst_bank] = p[dst].count[dst_bank] + p[src].count[src_bank]
  p[dst].endpoint[dst_bank] = p[dst].endpoint[dst_bank] + length
  p[dst].step_max[dst_bank] = p[dst].endpoint[dst_bank]
  p[dst].endpoint_init[dst_bank] = p[dst].endpoint[dst_bank]
  -- get bar and meter values
  if ((p[dst].endpoint[dst_bank] % 64 == 0) and (p[dst].endpoint[dst_bank] >= 128)) then
    p[dst].manual_length[dst_bank] = false
    -- calc values
    local num_beats = (p[dst].endpoint[dst_bank] / 64)
    local current_meter = p[dst].meter[dst_bank]
    local bar_count = num_beats / (current_meter * 4)
    -- check bar-size
    if bar_count % 1 == 0 then
      p[dst].barnum[dst_bank] = bar_count
    else
      -- get closest fit
      local n = p[dst].endpoint[dst_bank] > 128 and 2 or 1
      for i = n, #options.meter_val do
        local new_meter = options.meter_val[i]
        local new_count = num_beats / (new_meter * 4)
        if new_count % 1 == 0 then
          p[dst].barnum[dst_bank] = new_count
          p[dst].meter[dst_bank] = new_meter
          goto continue
        end
      end
    end
  else
    p[dst].manual_length[dst_bank] = true
  end
  ::continue::
  -- load pattern
  if dst_bank == p[dst].bank then
    load_pattern_bank(dst, dst_bank)
  end
end

function paste_seq_pattern(i)
  local bank = p[i].bank
  if #seq_notes > 0 then
    for n = 1, #seq_notes do
      local s = math.floor((n - 1) * (seq_rate * 64) + 1)
      local t = math.floor(s + (seq_rate * 64) - 1)
      if seq_notes[n] > 0 then
        if not p[i].event[bank][s] then
          p[i].event[bank][s] = {}
        end
        if voice[key_focus].keys_option == 1 then
          local e = {t = eSCALE, i = key_focus, root = root_oct, note = seq_notes[n], action = "note_on"}
          table.insert(p[i].event[bank][s], e)
        else
          local e = {t = eKEYS, i = key_focus, note = seq_notes[n], action = "note_on"}
          table.insert(p[i].event[bank][s], e)
        end
        if not p[i].event[bank][t] then
          p[i].event[bank][t] = {}
        end
        if voice[key_focus].keys_option == 1 then
          local e = {t = eSCALE, i = key_focus, root = root_oct, note = seq_notes[n], action = "note_off"}
          table.insert(p[i].event[bank][t], e)
        else
          local e = {t = eKEYS, i = key_focus, note = seq_notes[n], action = "note_off"}
          table.insert(p[i].event[bank][t], e)
        end
        p[i].count[bank] = p[i].count[bank] + 2
      end
    end
    p[i].endpoint[bank] = #seq_notes * (seq_rate * 64)
    p[i].endpoint_init[bank] = p[i].endpoint[bank]
    p[i].step_max[bank] = p[i].endpoint[bank]
    p[i].manual_length[bank] = true
    load_pattern_bank(i, bank)
  else
    print("seq pattern empty")
  end
end

function save_pattern_bank(i, bank)
  p[i].loop[bank] = pattern[i].loop
  p[i].quantize[bank] = pattern[i].quantize
  p[i].count[bank] = pattern[i].count
  p[i].event[bank] = deep_copy(pattern[i].event)
  p[i].endpoint[bank] = pattern[i].endpoint
  p[i].endpoint_init[bank] = pattern[i].endpoint_init
  p[i].barnum[bank] = pattern[i].barnum
  p[i].meter[bank] = pattern[i].meter
  p[i].length[bank] = pattern[i].length
  p[i].manual_length[bank] = pattern[i].manual_length
  --print("saved pattern "..i.." bank "..bank)
end

function load_pattern_bank(i, bank)
  p[i].looping = false
  pattern[i].count = p[i].count[bank]
  pattern[i].loop = p[i].loop[bank]
  pattern[i].quantize = p[i].quantize[bank]
  pattern[i].event = deep_copy(p[i].event[bank])
  pattern[i].endpoint = p[i].endpoint[bank]
  pattern[i].endpoint_init = p[i].endpoint_init[bank]
  pattern[i].step_min = 0
  pattern[i].step_max = p[i].endpoint[bank]
  pattern[i].barnum = p[i].barnum[bank]
  pattern[i].meter = p[i].meter[bank]
  pattern[i].length = p[i].length[bank]
  pattern[i].manual_length = p[i].manual_length[bank]
  params:set("patterns_playback_"..i, pattern[i].loop == 1 and 1 or 2)
  params:set("patterns_quantize_"..i, tab.key(options.pattern_quantize_value, pattern[i].quantize))
  if not pattern[i].manual_length then
    params:set("patterns_barnum_"..i, math.floor(util.clamp(pattern[i].barnum, 1, 16)))
    params:set("patterns_meter_"..i, tab.key(options.meter_val, pattern[i].meter))
  end
  dirtyscreen = true
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
  p[i].barnum[bank] = 4
  p[i].meter[bank] = 4/4
  p[i].length[bank] = 16
  p[i].manual_length[bank] = false
  p[i].looping = false
  if p[i].bank == bank then
    load_pattern_bank(i, bank)
  end
end

function update_pattern_bank(i)
  if p[i].stop or p[i].count[p[i].load] == 0 then
    pattern[i]:end_playback()
    p[i].stop = false
  end
  if p[i].load then
    p[i].bank = p[i].load
    kill_active_notes(i)
    load_pattern_bank(i, p[i].bank)
    send_program_change(i, p[i].bank)
    p[i].load = nil
  end
end

function stop_all_patterns()
  if stop_all then
    for i = 1, 8 do
      p[i].stop = false
      stop_all = false
    end
    if stop_all_timer ~= nil then
      clock.cancel(stop_all_timer)
      stop_all_timer = nil
    end
  else
    stop_all = true
    for i = 1, 8 do
      if pattern[i].play == 1 then
        p[i].stop = true
      end
    end
    stop_all_timer = clock.run(function()
      clock.sync(4)
      for i = 1, 8 do
        if p[i].stop and pattern[i].play == 1 then
          p[i].stop = false
          pattern[i]:end_playback()
        end
      end
      stop_all = false
    end)
  end
end

function load_patterns(pset_id)
  -- load sesh data
  local number = string.format("%02d", get_pset_num(pset_id))
  local pattern_data = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
  for i = 1, 8 do
    for j = 1, 24 do
      p[i].loop[j] = pattern_data[i].loop[j]
      p[i].quantize[j] = pattern_data[i].quantize[j]
      p[i].count[j] = pattern_data[i].count[j]
      p[i].event[j] = deep_copy(pattern_data[i].event[j])
      p[i].endpoint[j] = pattern_data[i].endpoint[j]
      p[i].endpoint_init[j] = pattern_data[i].endpoint[j]
      p[i].meter[j] = pattern_data[i].meter[j]
      p[i].barnum[j] = pattern_data[i].barnum[j]
      p[i].length[j] = pattern_data[i].length[j]
      p[i].manual_length[j] = pattern_data[i].manual_length[j]
      p[i].prc_num[j] = pattern_data[i].prc_num[j]
      p[i].prc_option[j] = pattern_data[i].prc_option[j]
    end
    load_pattern_bank(i, 1)
    p[i].prc_enabled = pattern_data[i].prc_enabled
    params:set("patterns_prg_change_"..i, p[i].prc_ch)
  end
  show_message("patterns    loaded")
  dirtyscreen = true
  dirtygrid = true
end

function load_pattern_data(pset_id)
  local number = string.format("%02d", get_pset_num(pset_id))
  local filename = norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data"
  loaded_pattern_data = tab.load(filename)
  if #loaded_pattern_data > 0 then
    print("loaded: "..filename)
  else
    print("loading pattern data failed")
  end
end

function load_pattern_slot(from, to)
  if loaded_pattern_data then
    for i = 1, 8 do
      p[i].loop[to] = loaded_pattern_data[i].loop[from]
      p[i].quantize[to] = loaded_pattern_data[i].quantize[from]
      p[i].count[to] = loaded_pattern_data[i].count[from]
      p[i].event[to] = deep_copy(loaded_pattern_data[i].event[from])
      p[i].endpoint[to] = loaded_pattern_data[i].endpoint[from]
      p[i].endpoint_init[to] = loaded_pattern_data[i].endpoint[from]
      p[i].barnum[to] = loaded_pattern_data[i].barnum[from]
      p[i].meter[to] = loaded_pattern_data[i].meter[from]
      p[i].length[to] = loaded_pattern_data[i].length[from]
      p[i].manual_length[to] = loaded_pattern_data[i].manual_length[from]
      if to == p[i].bank then
        load_pattern_bank(i, to)
      end
    end
    show_message("pattern    slot   imported")
  else
    print("pattern data not loaded")
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

function midi.add()
  build_midi_device_list()
end

function midi.remove()
  clock.run(function()
    clock.sleep(0.2)
    build_midi_device_list()
  end)
end

function clock.tempo_change_handler(bpm)
  -- nothing yet
end

function clock.transport.start()
  seq_step = 0
  trig_step = 0
  counter = 3
end

function clock.transport.stop()
  for i = 1, 8 do
    pattern[i]:end_playback()
    p[i].stop = false
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
      if midi_in_quant then
        msg.note = mu.snap_note_to_array(msg.note, note_map)
      end
      local p = pattern[pattern_focus].rec_enabled == 1 and pattern_focus or nil
      if midi_in_dest == 0 then
        local e = {t = eMIDI, p = p, action = msg.type, note = msg.note, vel = msg.vel, ch = midi_out_ch} event(e)
      elseif midi_in_dest == 7 and msg.type == "note_on" then
        local e = {t = eKIT, note = msg.note} event(e)
      else
        local e = {t = eKEYS, p = p, i = midi_in_dest, note = msg.note, action = msg.type} event(e)
      end
    elseif msg.type == "program_change" then -- use program change to load psets
        params:read(msg.val + 1)
    end
  end
end

function send_program_change(i, bank)
  if p[i].prc_enabled and p[i].prc_num[bank] > 0 then
    if i > 6 then
      if p[i].prc_option[bank] == 2 then
        m[i]:program_change(p[i].prc_num[bank], p[i].prc_ch)
      elseif pattern[i].play == 1 then
        m[i]:program_change(p[i].prc_num[bank], p[i].prc_ch)
      end
    else
      if voice[i].output == 3 then
        if p[i].prc_option[bank] == 2 then
          m[i]:program_change(p[i].prc_num[bank], p[i].prc_ch)
        elseif pattern[i].play == 1 then
          m[i]:program_change(p[i].prc_num[bank], p[i].prc_ch)
        end
      end
    end
  end
end

function set_midi_event_callback()
  --midi.cleanup()
  for _, dev in pairs(midi.devices) do
    dev.event = nil -- clear previous assignments
  end
  m[midi_in_dev].event = midi_events
end

-------- clock coroutines --------
function ledpulse_fast()
  pulse_key_fast = pulse_key_fast == 8 and 12 or 8
  for i = 1, 8 do
    if pattern[i].rec == 1 or stop_all then
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
  if (copy_src or latch_key_repeat or sequencer_config or pattern_clear or prgchange_view) then
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
    if midi_thru then
      local channel = midi_out_ch + i - 1
      m[midi_out_dev]:note_on(note_num, velocity, channel)
    end
    -- polyform 1 and 2
    if (voice[i].output == 1 or voice[i].output == 2) then
      local synth = voice[i].output
      local offset = synth == 1 and 0 or 4
      synthvoice[synth] = synthvoice[synth] % 4 + 1 + offset
      local freq = mu.note_num_to_freq(note_num)
      engine.trig(synthvoice[synth], freq)
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
    clock.sync(1/4)
    m[kit_midi_dev]:note_off(note_num, 0, kit_midi_ch)
  end)
end

function mute_voice(i, note_num)
  if voice[i].output == 1 or voice[i].output == 2 then
    --free_voice
  elseif voice[i].output == 3 then
    m[i]:note_off(note_num, 0, voice[i].midi_ch)
  elseif voice[i].output > 7 then
    local player = params:lookup_param("nb_"..(voice[i].output - 7)):get_player()
    player:note_off(note_num)
  end
  if midi_thru then
    local channel = midi_out_ch + i - 1
    m[midi_out_dev]:note_off(note_num, 0, channel)
  end
end

--------------------- PSET MANAGEMENT -----------------------

function build_pset_list()
  local files_data = util.scandir(norns.state.data)
  pset_list = {}
  for i = 1, #files_data do
    if files_data[i]:match("^.+(%..+)$") == ".pset" then
      local loaded_file = io.open(norns.state.data..files_data[i], "r")
      if loaded_file then
        io.input(loaded_file)
        local pset_name = string.sub(io.read(), 4, -1)
        table.insert(pset_list, pset_name)
        io.close(loaded_file)
      end
    end
  end
end

function get_pset_num(name)
  local files_data = util.scandir(norns.state.data)
  for i = 1, #files_data do
    if files_data[i]:match("^.+(%..+)$") == ".pset" then
      local loaded_file = io.open(norns.state.data..files_data[i], "r")
      if loaded_file then
        io.input(loaded_file)
        local pset_id = string.sub(io.read(), 4, -1)
        if name == pset_id then
          local filename = norns.state.data..files_data[i]
          local pset_string = string.sub(filename, string.len(filename) - 6, -1)
          local number = pset_string:gsub(".pset", "")
          return util.round(number, 1) -- better to use tonumber?
        end
        io.close(loaded_file)
      end
    end
  end
end


function init()
  -- calc grid size
  get_grid_size()

  -- build pset list
  build_pset_list()

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

  params:add_option("glb_midi_in_destination", "send midi to..", {"midi out", "voice 1", "voice 2", "voice 3", "voice 4", "voice 5", "voice 6", "kit"})
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


  params:add_group("keyboard_group", "keyboard settings", 49)

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

  params:add_number("strm_length", "strum length", 4, 12, 6, function(param) return round_form((param:get()), 1," notes") end)
  params:set_action("strm_length", function(val) strum_count = val end)

  params:add_option("strm_mode", "strum mode", {"up", "alt lo", "random", "alt hi", "down"}, 1)
  params:set_action("strm_mode", function(val) strum_mode = val end)

  params:add_number("strm_skew", "strum skew", -30, 30, 0, function(param) return round_form((util.linlin(-30, 30, -100, 100, param:get())), 1,"%") end)
  params:set_action("strm_skew", function(val) strum_skew = val end)

  params:add_number("strm_rate", "strum rate", 4, 100, 20, function(param) return round_form((1 / param:get()), 0.001,"hz") end)
  params:set_action("strm_rate", function(val) strum_rate = val / 200 end)

  params:add_separator("drum_keys", "drum keys")

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

  for i = 1, 4 do
    params:add_separator("kit_cc_bank_"..i, "kit midi cc bank "..i)
    for n = 1, 2 do
      local name = {"A", "B"}
      params:add_number("kit_cc_num_"..name[n].."_"..i, "cc "..name[n].." number", 0, 127, 19 + n + (i - 1) * 2)
      params:set_action("kit_cc_num_"..name[n].."_"..i, function(num) mcc[(i - 1) * 2 + n].num = num end)

      params:add_number("kit_cc_min_"..name[n].."_"..i, "cc "..name[n].." min", 0, 127, 0)
      params:set_action("kit_cc_min_"..name[n].."_"..i, function(num) mcc[(i - 1) * 2 + n].min = num end)

      params:add_number("kit_cc_max_"..name[n].."_"..i, "cc "..name[n].." max", 0, 127, 127)
      params:set_action("kit_cc_max_"..name[n].."_"..i, function(num) mcc[(i - 1) * 2 + n].max = num end)
    end
  end

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
  params:add_group("pattern_parameters", "pattern parameters", 56)
  params:hide("pattern_parameters")
  for i = 1, 8 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("patterns_playback_"..i, "playback", options.pattern_play, 1)
    params:set_action("patterns_playback_"..i, function(mode) pattern[i].loop = mode == 1 and 1 or 0 save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_quantize_"..i, "quantize", options.pattern_quantize, 7)
    params:set_action("patterns_quantize_"..i, function(idx) pattern[i].quantize = options.pattern_quantize_value[idx] save_pattern_bank(i, p[i].bank) end)

    params:add_option("patterns_launch_"..i, "launch mode", options.pattern_launch, 3)
    params:set_action("patterns_launch_"..i, function() end)

    params:add_option("patterns_meter_"..i, "meter", options.pattern_meter, 3)
    params:set_action("patterns_meter_"..i, function(idx) pattern[i].meter = options.meter_val[idx] update_pattern_length(i) end)

    params:add_number("patterns_barnum_"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("patterns_barnum_"..i, function(num) pattern[i].barnum = num update_pattern_length(i) dirtygrid = true end)

    params:add_number("patterns_prg_change_"..i, "prg change ch", 1, 16, i)
    params:set_action("patterns_prg_change_"..i, function(num) p[i].prc_ch = num end)
  end

  -- voice params
  params:add_separator("voices", "voices")
  for i = 1, NUM_VOICES do
    params:add_group("voice_"..i, "voice "..i, 20)
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

    params:add_separator("voice_midi_cc"..i, "midi cc's")
    for n = 1, 4 do
      local name = {"A", "C", "C", "D"}
      params:add_number("midi_cc_dest_"..n.."_"..i, "cc "..name[n].." number", 0, 127, 0, function(param) return param:get() == 0 and "off" or param:get() end)
      params:set_action("midi_cc_dest_"..n.."_"..i, function(num) voice[i].midi_cc[n] = num end)

      params:add_number("midi_cc_val_"..n.."_"..i, "cc "..name[n].." value", 0, 127, 0)
      params:set_action("midi_cc_val_"..n.."_"..i, function(val) if voice[i].midi_cc[n] > 0 then m[i]:cc(voice[i].midi_cc[n], val, voice[i].midi_ch) end end)
    end

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
    for i = 1, 8 do
      -- paste data
      pattern_data[i] = {}
      pattern_data[i].trigs_max = trigs[i].step_max
      pattern_data[i].trigs_pattern = {table.unpack(trigs[i].pattern)}
      pattern_data[i].bank = p[i].bank
      pattern_data[i].prc_enabled = p[i].prc_enabled
      pattern_data[i].prc_ch = p[i].prc_ch
      pattern_data[i].prc_num = {}
      pattern_data[i].prc_option = {}
      pattern_data[i].loop = {}
      pattern_data[i].quantize = {}
      pattern_data[i].count = {}
      pattern_data[i].event = {}
      pattern_data[i].endpoint = {}
      pattern_data[i].barnum = {}
      pattern_data[i].meter = {}
      pattern_data[i].length = {}
      pattern_data[i].manual_length = {}
      for j = 1, 24 do
        pattern_data[i].loop[j] = p[i].loop[j]
        pattern_data[i].quantize[j] = p[i].quantize[j]
        pattern_data[i].count[j] = p[i].count[j]
        pattern_data[i].event[j] = deep_copy(p[i].event[j])
        pattern_data[i].endpoint[j] = p[i].endpoint[j]
        pattern_data[i].meter[j] = p[i].meter[j]
        pattern_data[i].barnum[j] = p[i].barnum[j]
        pattern_data[i].length[j] = p[i].length[j]
        pattern_data[i].manual_length[j] = p[i].manual_length[j]
        pattern_data[i].prc_num[j] = p[i].prc_num[j]
        pattern_data[i].prc_option[j] = p[i].prc_option[j]
      end
    end
    -- rebuild pset list
    build_pset_list()
    -- save table
    clock.run(function() 
      clock.sleep(0.5)
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
      pattern_data = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
      for i = 1, 8 do
        for j = 1, 24 do
          p[i].loop[j] = pattern_data[i].loop[j]
          p[i].quantize[j] = pattern_data[i].quantize[j]
          p[i].count[j] = pattern_data[i].count[j]
          p[i].event[j] = deep_copy(pattern_data[i].event[j])
          p[i].endpoint[j] = pattern_data[i].endpoint[j]
          p[i].endpoint_init[j] = pattern_data[i].endpoint[j]
          p[i].meter[j] = pattern_data[i].meter[j]
          p[i].barnum[j] = pattern_data[i].barnum[j]
          p[i].length[j] = pattern_data[i].length[j]
          p[i].manual_length[j] = pattern_data[i].manual_length[j]
          p[i].prc_num[j] = pattern_data[i].prc_num[j]
          p[i].prc_option[j] = pattern_data[i].prc_option[j]
        end
        load_pattern_bank(i, 1)
        trigs[i].step_max = pattern_data[i].trigs_max
        trigs[i].pattern = {table.unpack(pattern_data[i].trigs_pattern)}
        p[i].prc_enabled = pattern_data[i].prc_enabled
        params:set("patterns_prg_change_"..i, p[i].prc_ch)
      end
      dirtyscreen = true
      dirtygrid = true
      print("finished reading pset:'"..pset_id.."'")
    end
  end

  params.action_delete = function(filename, name, number)
    norns.system_cmd("rm -r "..norns.state.data.."patterns/"..number.."/")
    pset_focus = 1
    build_pset_list()
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
  if loading_page then
    if n == 2 and z == 1 then
      view_pattern_import = not view_pattern_import
      if view_pattern_import then
        load_pattern_data(pset_list[pset_focus])
      else
        loaded_pattern_data = nil
      end
    end
    if view_pattern_import then
      if n == 3 and z == 1 then
        load_pattern_slot(pattern_src, pattern_dst)
        show_message("slot    loaded")
      end
    else
      if n == 3 and z == 1 then
        if shift then
          local num = get_pset_num(pset_list[pset_focus])
          params:read(num)
          show_message("pset    loaded")
        else
          load_patterns(pset_list[pset_focus])
          show_message("patterns    loaded")
        end
        loading_page = false
      end
    end
  elseif prgchange_view then
    -- do nothing yet
  elseif (pattern_view or pageNum == 3) then
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
  elseif loading_page then
    if view_pattern_import then
      if n == 2 then
        pattern_src = util.clamp(pattern_src + d, 1, 24)
      elseif n == 3 then
        pattern_dst = util.clamp(pattern_dst + d, 1, 24)
      end
    else
      if n == 2 then
        pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
      elseif n == 3 then
        pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
      end
    end
  elseif prgchange_view then
    if n == 2 then
      if shift then
        params:delta("patterns_prg_change_"..pattern_focus, d)
      else
        p[pattern_focus].prc_num[bank_focus] = util.clamp(p[pattern_focus].prc_num[bank_focus] + d, 0, 127)
      end
    elseif n == 3 then
      p[pattern_focus].prc_option[bank_focus] = util.clamp(p[pattern_focus].prc_option[bank_focus] + d, 1, 2)
    end
  elseif (pattern_view or pageNum == 3) then
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
  elseif loading_page then
    screen.font_size(8)
    screen.line_width(1)
    if view_pattern_import then
      screen.level(15)
      screen.move(64, 12)
      screen.text_center(pset_list[pset_focus].."  -  PATTERN  SLOTS")
      -- pattern slots
      screen.font_size(16)
      screen.level(4)
      screen.move(64, 39)
      screen.text_center(">")
      screen.level(15)
      screen.move(30, 39)
      screen.text_center(pattern_src)
      screen.move(98, 39)
      screen.text_center(pattern_dst)
      -- actions
      screen.font_size(8)
      screen.level(4)
      screen.move(4, 60)
      screen.text("back")
      screen.level(10)
      screen.move(124, 60)
      screen.text_right(">  import")
    else
      screen.level(15)
      screen.move(64, 12)
      screen.text_center(shift and "PRESET" or "PATTERNS")
      -- show pset names
      if #pset_list > 0 then
        local off = get_mid(pset_list[pset_focus])
        screen.level(12)
        screen.rect(64 - off, 28, off * 2 + 2, 10)
        screen.fill()
        screen.level(0)
        screen.move(64, 36)
        screen.text_center(pset_list[pset_focus])
        -- list right
        if pset_focus > 1 then
          screen.level(4)
          screen.move(64 - off - 14, 36)
          screen.text_right(pset_list[pset_focus - 1])
        end
        -- list left
        if pset_focus < #pset_list then
          screen.level(2)
          screen.move(64 + off + 14, 36)
          screen.text(pset_list[pset_focus + 1])
        end
      else
        screen.level(2)
        screen.move(64, 36)
        screen.text_center("NO   PSETS")
      end
      -- frame
      screen.level(10)
      screen.move(4, 18)
      screen.line_rel(120, 0)
      screen.move(4, 50)
      screen.line_rel(120, 0)
      screen.stroke()
      -- actions
      screen.level(4)
      screen.move(4, 60)
      screen.text(shift and "" or "import")
      screen.level(10)
      screen.move(124, 60)
      screen.text_right(shift and ">  bang!" or ">  load")
    end
  elseif prgchange_view then
    local options = {"play", "load"}
    local num = p[pattern_focus].prc_num[bank_focus]
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    local name = pattern_focus < 7 and "voice    "..pattern_focus or (pattern_focus == 7 and "kit" or "midi   out")
    screen.text_center(name.."      bank   "..bank_focus)
    -- param list
    screen.level(4)
    screen.move(30, 60)
    if shift then 
      screen.text_center("prg    channel")
    else
      screen.text_center("prg    msg")
    end
    screen.move(98, 60)
    screen.text_center("launch")

    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    if shift then
      screen.text_center(p[pattern_focus].prc_ch)
    else
      screen.text_center(num == 0 and "off" or num)
    end
    screen.move(98, 39)
    screen.text_center(options[p[pattern_focus].prc_option[bank_focus]])
  elseif (pattern_view or pageNum == 3) then
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
    local state = (pattern[pattern_focus].endpoint / 64 == pattern[pattern_focus].meter * pattern[pattern_focus].barnum * 4) and true or false
    screen.level((state or pattern[pattern_focus].manual) and 15 or 4)
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
          if dest == 3 and param == 3 then
            screen.text_center(str_format(params:string(voice_params[dest][param]..voice_focus), 7, ""))
          else
            screen.text_center(params:string(voice_params[dest][param]..voice_focus))
          end
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
    screen.line_width(1)
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

function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
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

function str_format(str, maxLength, separator)
  local maxLength = maxLength or 30
  local separator = separator or "..."

  if (maxLength < 1) then return str end
  if (string.len(str) <= maxLength) then return str end
  if (maxLength == 1) then return string.sub(str, 1, 1) .. separator end

  local midpoint = math.ceil(string.len(str) / 2)
  local toremove = string.len(str) - maxLength
  local lstrip = math.ceil(toremove / 2)
  local rstrip = toremove - lstrip

  return string.sub(str, 1, midpoint - lstrip) .. separator .. string.sub(str, 1 + midpoint + rstrip)
end

function get_mid(str)
  local len = string.len(str) / 2
  local pix = len * 5
  return pix
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
    if (voice[i].output == 3 or voice[i].output == 8 or  voice[i].output == 9) and voice[i].keys_option < 4 then
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
      params:show("voice_midi_cc"..i)
      for n = 1, 4 do
        params:show("midi_cc_dest_"..n.."_"..i)
        params:show("midi_cc_val_"..n.."_"..i)
      end
    else
      params:hide("midi_device"..i)
      params:hide("midi_channel"..i)
      params:hide("midi_panic"..i)
      params:hide("voice_midi_cc"..i)
      for n = 1, 4 do
        params:hide("midi_cc_dest_"..n.."_"..i)
        params:hide("midi_cc_val_"..n.."_"..i)
      end
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
