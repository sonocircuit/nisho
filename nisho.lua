-- nisho v1.8.0 @sonocircuit
-- llllllll.co/t/nisho
--
--   six voices & eight patterns
--        for performance
--                &
--           composition
--

--------------------------------------------------------------

engine.name = "Polyform"

local fs = require 'fileselect'
local mu = require 'musicutil'
local md = require 'core/mods'
local lt = require 'lattice'
local vx = require 'voice'
local lo = require 'lfo'

local polyform = include 'lib/nishos_polyform'
local reflect = include 'lib/nishos_reflection'
local midim = include 'lib/nishos_midiimport'
local drmfm = include 'lib/nishos_drmfm'
local grd = include 'lib/nishos_grid'
local nb = include 'lib/nb/lib/nb'

g = grid.connect()

-------- variables -------
local load_pset = false
local rotate_grid = false

-- constants
local GRIDSIZE = 0
local NUM_VOICES = 6

-- user mode
rytm_mode = false

-- ui variables
pageNum = 1
shift = false
autofocus = false
loading_page = false
kit_view = false
ansi_view = false
pattern_view = false
prgchange_view = false
key_repeat_view = false
trigs_config_view = false

-- preset and pattern loading
local loaded_pattern_data = nil
local view_pattern_import = false
local pattern_src = 1
local pattern_dst = 1
local pset_focus = 1
local midim_default_path = norns.state.data.."midi_files/"

-- keyboards
int_focus = 1
key_focus = 1
voice_focus = 1
strum_focus = 0
key_link = true
transposing = false
transpose_value = 0
scalekeys_y = 4
chromakeys_x = 5
chromakeys_y = 1

heldkey_int = 0
heldkey_key = 0 
heldkey_kit = 0

drum_root_note = 0
drum_vel_hi = 100
drum_vel_mid = 64
drum_vel_lo = 32
drum_vel_last = 100

drm_mute = {}
drm_mute.key = {}
drm_mute.group = {}
for i = 1, 12 do
  drm_mute.key[i] = false
end
for n = 1, 6 do
  drm_mute.group[n] = {}
  for i = 1, 12 do
    drm_mute.group[n][i] = false
  end
end

-- kit
kit_mode = 1
kit_mod_keys = 1
kit_root_note = 60
kit_midi_dev = 7
kit_midi_ch = 1
kit_velocity = 100
kit_oct = 0
kit_held = {}
held_bank = 0
midi_bank = 0

kit_edit_mutes = false
kit_mute_all = false
kit_mute = {}
kit_mute.focus = 1
kit_mute.active = false
kit_mute.key = {}
kit_mute.group = {}
for i = 1, 16 do
  kit_mute.key[i] = false
end
for n = 1, 6 do
  kit_mute.group[n] = {}
  for i = 1, 16 do
    kit_mute.group[n][i] = false
  end
end

-- drmfm
local perfclock = nil
perftime = 8 -- beats
drmfm_voice_focus = 1

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

-- key repeat
local rep_rate = 1/4
local rep_rates = {1/4, 1/8, 3/8, 1/16, 1/3, 3/16, 1/6, 1/32, 3/64, 1/12, 5/16, 3/32, 7/16, 1/24, 9/16}
local rep_rate_names = {"1/4", "1/8", "3/8", "1/16", "1/3", "3/16", "1/6", "1/32", "3/64", "1/12", "5/16", "3/32", "7/16", "1/24", "9/16"}
latch_key_repeat = false
key_repeat = false

--trig patterns
trigs_edit = false
trigs_focus = 1
trig_step = 0

-- chord
chord_any = false
chord_play = true
chord_strum = false
chord_inversion = 1
chord_oct_shift = 0
last_chord_root = 0
strum_count = 6
strum_mode = 1
strum_skew = 0
strum_rate = 0.1
strum_drift = 0

-- scale
root_oct = 3 -- number of octaves root_note differs from root_base. required for changing root note after pattern rec.
root_note = 60 -- root note set by scale param. corresponds to note.home
root_base = 24 -- lowest note of the scale
current_scale = 1
scale_notes = {}

-- key viz
pulse_bar = false
pulse_beat = false
pulse_key_fast = 8
pulse_key_mid = 4
pulse_key_slow = 4
hide_metronome = false
bar_val = 4

-- screen viz
local view_message = ""

-- key quantization
local quant_event = {}
key_quantize = false
quant_rate = 1/4

-- patterns
pattern_rec_mode = "queued"
pattern_overdub = false
copy_src = {state = false, pattern = nil, bank = nil}
pattern_clear = false
pattern_focus = 1
bank_focus = 1
keyquant_edit = false
pattern_bank_page = 0
pattern_voicemap = false
rec_enabled = false
stop_all = false
stop_all_timer = nil

-- events
eSCALE = 1
eKEYS = 2
eDRUMS = 3
eMIDI = 4
eTRSP_SCALE = 5
eKIT = 6
eANSI = 7

local options = {}
options.key_quant = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
options.quant_value = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
options.pattern_play = {"loop", "oneshot"}
options.pattern_launch = {"manual", "beat", "bar"}
options.pattern_quantize = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/24", "1/32", "3/128", "1/48", "1/64"}
options.pattern_quantize_value = {1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}
options.pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
options.meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}
options.output = {"polyform [mono]", "polyform [poly]", "midi", "crow [out 1+2]", "crow [out 3+4]", "crow [jf]", "crow [wsyn]", "nb [one]", "nb [two]"}
options.wsyn_jack = {"ramp", "curve", "fm env", "fm index", "lpg time", "lpg symmetry", "gate", "pitch", "fm ratio num", "fm ratio denom"}

-- voices
voice = {}
for i = 1, NUM_VOICES + 1 do -- 6 voices + 1 midi out
  voice[i] = {}
  voice[i].note_id = {}
  voice[i].mute = false
  voice[i].sustain = false
  voice[i].held_notes = {}
  voice[i].keys_option = 1
  voice[i].length = 0.2
  voice[i].velocity = 100
  voice[i].midi_ch = i
  voice[i].midi_cc = {}
  voice[i].midi_cc_name = {}
  for n = 1, 4 do
    voice[i].midi_cc[n] = 0
    voice[i].midi_cc_name[n] = ""
  end
end

-- crow
local caw = {}
caw.is = false
caw.env_shapes = {'logarithmic', 'linear', 'exponential'}
for i = 1, 2 do
  caw[i] = {}
  caw[i].active = false
  caw[i].v8_std = 12
  caw[i].v8 = 0
  caw[i].pb_depth = 7
  caw[i].at_depth = 5
  caw[i].mw_depth = 5
  caw[i].pb_v8 = 0
  caw[i].slew = 0
  caw[i].legato = false
  caw[i].env_amp = 8
  caw[i].env_a = 0
  caw[i].env_d = 0.4
  caw[i].env_s = 0.8
  caw[i].env_r = 0.6
  caw[i].env_curve = 'linear'
  caw[i].count = 0
end

-- jf
local jf = {}
jf.num_mono = 0
jf.poly_alloc = vx.new(6, 2)
jf.poly_low = 1
jf.poly_notes = {}
for i = 1, 6 do
  jf[i] = {}
  jf[i].ch = i
  jf[i].mode = 1
  jf[i].count = 0
  jf[i].amp = 5
  jf[i].pb_depth = 7
  jf[i].pb_v8 = 0
  jf[i].v8 = 0
end

-- wsyn
local wsyn = {}
wsyn.alloc = vx.new(4, 2)
wsyn.notes = {}
wsyn.amp = 5
wsyn.pb_v8 = 0
wsyn.pb_depth = 7
wsyn.at_depth = 5
wsyn.mw_depth = 5
for i = 1, 4 do
  wsyn[i] = {}
  wsyn[i].v8 = 0
end

-- ansible
ansi_held = {}
local ansi_cv = {}
for i = 1, 4 do
  ansi_cv[i] = {}
  ansi_cv[i].lvl = 0
  ansi_cv[i].min = 0
  ansi_cv[i].max = 10
  ansi_cv[i].lfo = {}
end

-- pitchbend
pb = {}
pb_res = 0.01
pb_timer = nil
for i = 1, NUM_VOICES do
  pb[i] = {}
  pb[i].dir = 1
  pb[i].rise = 0.1
  pb[i].fall = 0.1
  pb[i].value = 0
  pb[i].timer = nil
end

-- modwheel
mw = {}
mw_res = 0.01
mw_timer = nil
for i = 1, NUM_VOICES do
  mw[i] = {}
  mw[i].rise = 0.1
  mw[i].fall = 0.1
  mw[i].value = 0
  mw[i].timer = nil
end

-- aftertouch
at = {}
at_res = 0.01
at_timer = nil
for i = 1, NUM_VOICES do
  at[i] = {}
  at[i].rise = 0.1
  at[i].fall = 0.1
  at[i].value = 0
  at[i].timer = nil
end

-- chords
local chord_values = {1, 2, 4, 3, 5, 6, 7}
local current_chord = {}
local chord_arp = {}
local chord = {}
for i = 1, 12 do
  chord[i] = {}
  chord[i].is = {}
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

crd = {}
for i = 1, 12 do
  crd[i] = {}
  for s = 1, 3 do
    crd[i][s] = {}
    crd[i][s].key = 0
    crd[i][s].viz = 0
  end
end

-- notes
notes_last = 1
notes_home = 1
notes_held = {}
-- keep track of current octave per voice
notes_oct_int = {}
notes_oct_key = {}
for i = 1, NUM_VOICES do
  notes_oct_int[i] = 0
  notes_oct_key[i] = 0
end

-- note viz
local nv = {}
nv.name = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
nv.notes = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}
nv.is = {}
nv.root = {}
nv.viz = {}
for i = 1, 12 do
  nv.is[i] = false
  nv.root[i] = false
  nv.viz[i] = false
end

-- trigs
trigs = {}
for i = 1, 8 do -- with 128 only two are in use
  trigs[i] = {}
  trigs[i].step_max = 16
  trigs[i].pattern = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].prob = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].vel = {0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8}
end

-- midi
local midi_in_dev = 9
local midi_in_ch = 1
local midi_in_dest = 0
local midi_in_quant = false
local midi_out_dev = 8
local midi_out_ch = 1
local midi_thru = false
midi_rytm_dev = 10
midi_rytm_ch = 1

m = {}
for i = 1, 10 do -- 6 voices + kit(7) + midi out(8) + midi in(9) + rytm out(10)
  m[i] = midi.connect()
end

mcc = {} -- midi cc's sent via kit
for i = 1, 16 do
  mcc[i] = {}
  mcc[i].num = 0
  mcc[i].min = 0
  mcc[i].max = 127
end

-- parameter UI
local voice_param_focus = {}
for i = 1, NUM_VOICES do
  voice_param_focus[i] = 1
end

local voice_params = {
  {"polyform_main_amp_1", "polyform_mix_1", "polyform_noise_mix_1", "polyform_noise_crackle_1",
  "polyform_saw_tune_1", "polyform_saw_shape_1", "polyform_swm_rate_1", "polyform_swm_depth_1",
  "polyform_pulse_tune_1", "polyform_pulse_width_1", "polyform_pwm_rate_1", "polyform_pwm_depth_1",
  "polyform_lpf_cutoff_1", "polyform_lpf_resonance_1", "polyform_env_lpf_depth_1", "polyform_hpf_cutoff_1",
  "polyform_env_type_1", "polyform_env_curve_1", "polyform_attack_1", "polyform_decay_1",
  "polyform_sustain_1", "polyform_release_1", "polyform_vib_freq_1", "polyform_vib_depth_1"}, --polyform [one]

  {"polyform_main_amp_2", "polyform_mix_2", "polyform_noise_mix_2", "polyform_noise_crackle_2",
  "polyform_saw_tune_2", "polyform_saw_shape_2", "polyform_swm_rate_2", "polyform_swm_depth_2",
  "polyform_pulse_tune_2", "polyform_pulse_width_2", "polyform_pwm_rate_2", "polyform_pwm_depth_2",
  "polyform_lpf_cutoff_2", "polyform_lpf_resonance_2", "polyform_env_lpf_depth_2", "polyform_hpf_cutoff_2",
  "polyform_env_type_2", "polyform_env_curve_2", "polyform_attack_2", "polyform_decay_2",
  "polyform_sustain_2", "polyform_release_2", "polyform_vib_freq_2", "polyform_vib_depth_2"}, --polyform [two]

  {"note_length_", "note_velocity_", "midi_device_", "midi_channel_",
  "midi_cc_val_1_", "midi_cc_val_2_", "midi_cc_val_3_", "midi_cc_val_4_"}, --midi

  {"crow_env_amp_1", "crow_env_shape_1", "crow_env_attack_1", "crow_env_decay_1",
  "crow_env_sustain_1", "crow_env_release_1", "crow_legato_1", "crow_v8_slew_1"}, --crow 1+2
  {"crow_env_amp_2", "crow_env_shape_2", "crow_env_attack_2", "crow_env_decay_2",
  "crow_env_sustain_2", "crow_env_release_2", "crow_legato_2", "crow_v8_slew_2"}, --crow 3+4

  {"jf_amp_", "jf_mode_"}, --crow ii jf

  {"wysn_mode", "wsyn_amp", "wsyn_curve", "wsyn_ramp", "wsyn_lpg_time",
  "wsyn_lpg_sym", "wsyn_fm_index", "wsyn_fm_env", "wsyn_fm_num", "wsyn_fm_den"} --crow ii wsyn
}

local voice_param_names = {
  {"main   level", "saw/pulse", "noise   level", "noise   crackle",
  "saw   tune", "saw   shape", "saw   mod   rate", "saw   mod   depth",
  "pulse   tune", "pulse   width", "pwm   rate", "pwm   depth",
  "lpf   cutoff", "lpf   resonance", "env   depth", "hpf   cutoff",
  "env   type", "env   curve", "attack", "decay",
  "sustain", "release", "vibrato   rate", "vibrato   depth"}, --polyform [one]

  {"main   level", "saw/pulse", "noise   level", "noise   crackle",
  "saw   tune", "saw   shape", "saw   mod   rate", "saw   mod   depth",
  "pulse   tune", "pulse   width", "pwm   rate", "pwm   depth",
  "lpf   cutoff", "lpf   resonance", "env   depth", "hpf   cutoff",
  "env   type", "env   curve", "attack", "decay",
  "sustain", "release", "vibrato   rate", "vibrato   depth"}, --polyform [two]

  {"note   length", "velocity", "device", "channel", "cc  A", "cc  B", "cc  C", "cc  D"}, -- midi

  {"amplitude", "env   shape", "attack", "decay", "sustain", "release", "legato", "slew   time"}, --crow 1+2
  {"amplitude", "env   shape", "attack", "decay", "sustain", "release", "legato", "slew   time"}, --crow 3+4

  {"level", "mode"}, --crow ii jf
  
  {"mode", "level", "curve", "ramp", "lpg   time",
  "lpg   sym", "fm   index", "fm   env", "fm   num", "fm   den"} --crow ii wsyn
}

local pattern_param_focus = 1
local pattern_e2_params = {"patterns_meter_", "patterns_launch_", "patterns_playback_"}
local pattern_e3_params = {"patterns_barnum_", "patterns_quantize_", ""}
local pattern_e2_names = {"meter", "launch", "playback"}
local pattern_e3_names = {"length", "quantize", ""}

local drmfm_param_focus = 1
local drmfm_e2_params = {"drmfm_level_", "drmfm_sendA_", "drmfm_freq_", "drmfm_decay_", "drmfm_sweep_time_", "drmfm_mod_ratio_", "drmfm_mod_amp_", "drmfm_mod_dest_", "drmfm_noise_amp_", "drmfm_cutoff_lpf_"}
local drmfm_e3_params = {"drmfm_pan_", "drmfm_sendB_", "drmfm_tune_", "drmfm_decay_mod_",  "drmfm_sweep_depth_", "drmfm_mod_time_", "drmfm_mod_fb_",  "drmfm_fold_", "drmfm_noise_decay_","drmfm_cutoff_hpf_"}
local drmfm_e2_names = {"level", "sendA", "pitch", "decay", "sweep   time", "mod   ratio", "mod   amp", "mod   dest", "noise   amp", "cutoff   lpf"}
local drmfm_e3_names = {"pan", "sendB", "tune", "decay   s&h",  "sweep   depth", "mod   time", "mod   fb", "wavefold", "noise   decay","cutoff   hpf"}


-------- scales --------
function build_scale()
  -- build scale
  root_base = root_note % 12 + 24
  root_oct = math.floor((root_note - root_base) / 12)
  scale_notes = mu.generate_scale_of_length(root_base, current_scale, 50)
  note_map = mu.generate_scale_of_length(root_note % 12, current_scale, 100)
  notes_home = tab.key(scale_notes, root_note)
  notes_last = notes_home
  -- set note viz
  nv.is = {}
  nv.root = {}
  for i, v in ipairs(nv.notes) do
    table.insert(nv.is, notelookup(v + 24))
    if v + 24 == root_base then
      table.insert(nv.root, true)
    else
      table.insert(nv.root, false)
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

function set_note_viz(note_num, state)
  nv.viz[tab.key(nv.notes, note_num % 12)] = state
  page_redraw(1)
end

-- chord stuff
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

function build_chord_map()
  for i = 1, 12 do
    local note_num = 59 + i
    local chordmap = mu.chord_types_for_note(note_num, root_base, scale_names[current_scale])
    for s = 1, 3 do
      crd[i][s].viz = 0
    end
    for t = 1, 7 do
      chord[i].is[t] = false
    end
    if tab.contains(chordmap, "Augmented") then
      for s = 1, 3 do
        crd[i][s].viz = 2
      end
      chord[i].is[7] = true
    end
    if tab.contains(chordmap, "Diminished") then
      for s = 1, 2 do
        crd[i][s].viz = 2
      end
      chord[i].is[4] = true
    end
    if tab.contains(chordmap, "Major") then
      crd[i][1].viz = 9
      chord[i].is[1] = true
    end
    if tab.contains(chordmap, "Minor") then
      crd[i][2].viz = 9
      chord[i].is[2] = true
    end
    if tab.contains(chordmap, "Sus4") then
      crd[i][3].viz = 9
      chord[i].is[3] = true
    end
    if tab.contains(chordmap, "Major 7") then
      if tab.contains(chordmap, "Sus4") then
        crd[i][3].viz = 6
      else
        crd[i][3].viz = 3
      end
      chord[i].is[5] = true
    end
    if tab.contains(chordmap, "Minor 7") then
      if tab.contains(chordmap, "Sus4") then
        crd[i][3].viz = 6
      else
        crd[i][3].viz = 3
      end
      chord[i].is[6] = true
    end
  end
end

function clear_chord()
  if #current_chord > 0 then
    for index, value in ipairs(current_chord) do
      local e = {t = eKEYS, i = key_focus, note = value, action = "note_off"} event(e)
    end
    notes_held = {}
    current_chord = {}
  end
end

function play_chord(i)
  local i = i or last_chord_root
  local chord_type = chord_values[tonumber(tostring(crd[i][3].key..crd[i][2].key..crd[i][1].key), 2)]
  if chord[i].is[chord_type] or chord_any then
    if key_repeat and #current_chord == 0 then
      trig_step = 0
    end
    clear_chord()
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

function set_scale()
  build_scale()
  build_chord_map()
  page_redraw(1)
end

------- voice management --------
function set_voice_output(i, val)
  voice[i].output = val
  manage_ii()
  alloc_jf_voices()
  voice_menu(i)
  p[i].prc_type = val < 3 and val or 3
end

function manage_ii()
  local num_ii = 0
  local crow_1 = 0
  local crow_2 = 0
  for i = 1, NUM_VOICES do
    if voice[i].output == 6 then
      num_ii = num_ii + 1
    end
    if voice[i].output == 7 then
      crow.ii.wsyn.voices(4)
    end
    if voice[i].output == 4 then
      crow_1 = crow_1 + 1
    end
    if voice[i].output == 5 then
      crow_2 = crow_2 + 1
    end
  end
  if num_ii > 0 then
    crow.ii.jf.mode(1)
  else
    crow.ii.jf.mode(0)
  end
  caw[1].active = crow_1 > 0 and true or false
  caw[2].active = crow_2 > 0 and true or false
end

function get_jf_mono_voices()
  local num = 0
  for i = 1, 6 do
    if jf[i].mode == 1 and voice[i].output == 6 then
      num = num + 1
    end
  end
  return num
end

function alloc_jf_voices()
  jf.num_mono = get_jf_mono_voices()
  -- set mono voice channel
  for i = 1, 6 do
    if voice[i].output == 6 and jf[i].mode == 1 then
      if jf.num_mono > 0 and jf[i].ch > jf.num_mono then
        params:set("jf_voice_"..i, jf.num_mono)
      end
    end
  end
  -- re-allocate poly voices
  local alloc_num = 6 - jf.num_mono
  jf.poly_alloc = nil
  jf.poly_alloc = vx.new(alloc_num, 2)
  jf.poly_low = jf.num_mono + 1
end

function set_jf_levels(i, level)
  if jf[i].mode == 2 then
    for i = 1, 6 do
      if voice[i].output == 6 and jf[i].mode == 2 then
        jf[i].amp = level
      end
    end
  else
    jf[i].amp = level
  end
end


-------- patterns and events --------
function event_exec(e, n)
  if e.t == eSCALE then
    if not voice[e.i].mute then
      local octave = (root_oct - e.root) * (#scale_intervals[current_scale] - 1)
      local note_num = scale_notes[util.clamp(e.note + transpose_value + octave, 1, #scale_notes)]
      local id = scale_notes[util.clamp(e.note + octave, 1, #scale_notes)]
      if e.action == "note_off" and voice[e.i].length == 0 then
        if voice[e.i].note_id[id] ~= nil then
          voice_note_off(e.i, voice[e.i].note_id[id])
          remove_active_notes(n, e.i, voice[e.i].note_id[id])
          voice[e.i].note_id[id] = nil
        end
      elseif e.action == "note_on" then
        voice_note_on(e.i, note_num, e.vel)
        add_active_notes(n, e.i, note_num)
        voice[e.i].note_id[id] = note_num
      end
    end
  elseif e.t == eKEYS then
    if not voice[e.i].mute then
      if e.action == "note_off" and voice[e.i].length == 0 then
        voice_note_off(e.i, e.note)
        remove_active_notes(n, e.i, e.note)
      elseif e.action == "note_on" then
        voice_note_on(e.i, e.note, e.vel)
        add_active_notes(n, e.i, e.note)
      end
    end
  elseif e.t == eDRUMS then
    local drm_voice = (e.note % 12) + 1 -- TODO: take drum root note in account!
    if not (voice[e.i].mute or drm_mute.key[drm_voice]) then
      voice_note_on(e.i, e.note, e.vel)
      clock.run(function()
        clock.sync(1/8)
        voice_note_off(e.i, e.note)
      end)
    end
  elseif e.t == eTRSP_SCALE then
    local home_note = tab.key(scale_notes, root_note)
    transpose_value = util.clamp(transpose_value + e.interval, -home_note + 1, #scale_notes - home_note)
    if e.interval == 0 then
      transpose_value = 0
    end
  elseif e.t == eMIDI then
    if e.action == "note_off" then
      m[midi_out_dev]:note_off(e.note, 0, e.ch)
      remove_active_notes(n, midi_out_dev, e.note)
    elseif e.action == "note_on" then    
      m[midi_out_dev]:note_on(e.note, e.vel, e.ch)
      add_active_notes(n, midi_out_dev, e.note)
    end
  elseif e.t == eKIT then
    local kit_voice = (e.note % 16) + 1
    if not (kit_mute_all or kit_mute.key[kit_voice]) then
      if kit_mode == 1 then
        drmfm.trig(e.note, e.vel)
      else
        play_kit(e.note, e.vel)
      end
    end
    grd.kitviz(e.note)
  elseif e.t == eANSI then
    crow.ii.ansible.trigger_pulse(e.i)
    grd.ansiviz(e.i)
  end
end

function event_rec(e)
  if not pattern_voicemap then
    pattern[pattern_focus]:watch(e)
  elseif e.i == pattern_focus then
    pattern[pattern_focus]:watch(e)
  end
end

function event(e)
  if (e.t == eKIT and not key_repeat) or (key_quantize and not (key_repeat or seq_active)) then
    table.insert(quant_event, e)
  else
    event_rec(e)
    event_exec(e)
  end
end

function event_q_clock()
  while true do
    clock.sync(quant_rate)
    if #quant_event > 0 then
      for _, e in ipairs(quant_event) do
        event_rec(e)
        event_exec(e)
      end
      quant_event = {}
    end
  end
end

pattern = {}
for i = 1, 8 do
  pattern[i] = reflect.new(i)
  pattern[i].process = event_exec
  pattern[i].start_callback = function() step_one_indicator(i) set_pattern_length(i) clear_active_notes(i) end
  pattern[i].start_rec_callback = function() catch_held_notes(i, "note_on") end
  pattern[i].end_of_loop_callback = function() update_pattern_bank(i) end
  pattern[i].end_of_rec_callback = function() catch_held_notes(i, "note_off") clock.run(function() clock.sleep(0.2) save_pattern_bank(i, p[i].bank) end) end
  pattern[i].end_callback = function() clear_active_notes(i) dirtygrid = true end
  pattern[i].step_callback = function() track_pattern_pos(i) end
  pattern[i].meter = 4/4
  pattern[i].barnum = 4
  pattern[i].length = 16
  pattern[i].launch = 3
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
  p[i].launch = {}
  p[i].quantize = {}
  p[i].count = {}
  p[i].event = {}
  p[i].endpoint = {}
  p[i].endpoint_init = {}
  p[i].step_min_viz = {}
  p[i].step_max_viz = {}
  p[i].barnum = {}
  p[i].meter = {}
  p[i].length = {}
  p[i].manual_length = {}
  p[i].prc_enabled = false
  p[i].prc_pulse = false
  p[i].prc_type = 5
  p[i].prc_ch = i
  p[i].prc_num = {}
  p[i].prc_option = {}
  for j = 1, 24 do
    p[i].loop[j] = 1
    p[i].launch[j] = 3
    p[i].quantize[j] = 1/4
    p[i].count[j] = 0
    p[i].event[j] = {}
    p[i].endpoint[j] = 0
    p[i].endpoint_init[j] = 0
    p[i].step_min_viz[j] = 0
    p[i].step_max_viz[j] = 0
    p[i].barnum[j] = 4
    p[i].meter[j] = 4/4
    p[i].length[j] = 16
    p[i].manual_length[j] = false
    p[i].prc_num[j] = 0
    p[i].prc_option[j] = 2
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

function track_pattern_pos(i)
  local size = math.floor(pattern[i].endpoint / 16)
  if pattern[i].step % size == 1 then
    local prev_pos = pattern[i].position
    pattern[i].position = math.floor((pattern[i].step) / size) + 1
    if (pattern_view or GRIDSIZE == 256) and i == pattern_focus then dirtygrid = true end
  end
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

function catch_held_notes(i, action)
  if #notes_held > 0 then
    local s = action == "note_on" and (pattern[i].step_min + 1) or pattern[i].step_max
    for n, v in ipairs(notes_held) do
      if voice[key_focus].keys_option == 1 then
        local e = {t = eSCALE, i = key_focus, root = root_oct, note = v, action = action}
        pattern[i]:insert(e, s)
      else
        local e = {t = eKEYS, i = key_focus, note = v, action = action}
        pattern[i]:insert(e, s)
      end
    end
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

function clear_active_notes(i)
  for voice = 1, NUM_VOICES do
    if #pattern[i].active_notes[voice] > 0 and pattern[i].endpoint > 0 then
      for _, note in ipairs(pattern[i].active_notes[voice]) do
        voice_note_off(voice, note)
      end
      pattern[i].active_notes[voice] = {}
    end
  end
end

function set_pattern_length(i)
  if pattern[i].rec == 0 then
    local prev_length = pattern[i].length
    pattern[i].length = pattern[i].meter * pattern[i].barnum * 4
    if prev_length ~= pattern[i].length then
      pattern[i]:set_length(pattern[i].length)
      save_pattern_bank(i, p[i].bank)
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
  if (p[i].endpoint_init[bank] % 64 ~= 0 or p[i].endpoint_init[bank] < 128) then
    p[i].manual_length[bank] = true
  end
  if bank == p[i].bank then
    load_pattern_bank(i, bank)
  end
end

function save_pattern_bank(i, bank)
  p[i].loop[bank] = pattern[i].loop
  p[i].launch[bank] = pattern[i].launch
  p[i].quantize[bank] = pattern[i].quantize
  p[i].count[bank] = pattern[i].count
  p[i].event[bank] = deep_copy(pattern[i].event)
  p[i].endpoint[bank] = pattern[i].endpoint
  p[i].endpoint_init[bank] = pattern[i].endpoint_init
  p[i].barnum[bank] = pattern[i].barnum
  p[i].meter[bank] = pattern[i].meter
  p[i].length[bank] = pattern[i].length
  p[i].manual_length[bank] = pattern[i].manual_length
  page_redraw(3)
end

function load_pattern_bank(i, bank)
  p[i].looping = false
  pattern[i].manual_length = p[i].manual_length[bank]
  pattern[i].count = p[i].count[bank]
  pattern[i].loop = p[i].loop[bank]
  pattern[i].launch = p[i].launch[bank]
  pattern[i].quantize = p[i].quantize[bank]
  pattern[i].event = deep_copy(p[i].event[bank])
  pattern[i].endpoint = p[i].endpoint[bank]
  pattern[i].endpoint_init = p[i].endpoint_init[bank]
  pattern[i].step_min = 0
  pattern[i].step_max = p[i].endpoint[bank]
  pattern[i].barnum = p[i].barnum[bank]
  pattern[i].meter = p[i].meter[bank]
  pattern[i].length = p[i].length[bank]
  params:set("patterns_playback_"..i, pattern[i].loop == 1 and 1 or 2)
  params:set("patterns_quantize_"..i, tab.key(options.pattern_quantize_value, pattern[i].quantize))
  params:set("patterns_launch_"..i, pattern[i].launch)
  if not pattern[i].manual_length then
    params:set("patterns_barnum_"..i, math.floor(util.clamp(pattern[i].barnum, 1, 16)))
    params:set("patterns_meter_"..i, tab.key(options.meter_val, pattern[i].meter))
  end
  if pattern[i].play == 1 and pattern[i].count == 0 then
    pattern[i]:stop()
  end
  page_redraw(3)
end

function clear_pattern_bank(i, bank)
  p[i].loop[bank] = 1
  p[i].quantize[bank] = 1/4
  p[i].count[bank] = 0
  p[i].event[bank] = {}
  p[i].endpoint[bank] = 0
  p[i].endpoint_init[bank] = 0
  p[i].manual_length[bank] = false
  p[i].looping = false
  if p[i].bank == bank then
    clear_active_notes(i)
    pattern[i]:clear()
  end
  show_message("pattern   cleared")
end

function update_pattern_bank(i)
  if p[i].stop or p[i].count[p[i].load] == 0 then
    if pattern[i].play == 1 then
      pattern[i]:stop()
    end
    p[i].stop = false
  end
  if p[i].load then
    p[i].bank = p[i].load
    clear_active_notes(i)
    load_pattern_bank(i, p[i].bank)
    send_program_change(i, p[i].bank)
    p[i].load = nil
  end
  page_redraw(3)
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
      clock.sync(bar_val)
      for i = 1, 8 do
        if p[i].stop and pattern[i].play == 1 then
          pattern[i]:stop()
          p[i].stop = false
        end
      end
      stop_all = false
    end)
  end
  -- rytm mode
  if pattern_overdub and rytm_mode then
    m[midi_rytm_dev]:program_change(127, midi_rytm_ch) -- send prg change to Analog Rytm -> pattern h16 is blank
  end
end

function copy_pattern(src, src_bank, dst, dst_bank)
  p[dst].loop[dst_bank] = p[src].loop[src_bank]
  p[dst].quantize[dst_bank] = p[src].quantize[src_bank]
  p[dst].count[dst_bank] = p[src].count[src_bank]
  p[dst].event[dst_bank] = deep_copy(p[src].event[src_bank])
  p[dst].endpoint[dst_bank] = p[src].endpoint[src_bank]
  p[dst].endpoint_init[dst_bank] = p[src].endpoint_init[src_bank]
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
      local e = math.floor(s + ((seq_rate / 2) * 64))
      if seq_notes[n] > 0 then
        if not p[i].event[bank][s] then
          p[i].event[bank][s] = {}
        end
        if not p[i].event[bank][e] then
          p[i].event[bank][e] = {}
        end
        if voice[key_focus].keys_option == 1 then
          local on = {t = eSCALE, i = key_focus, root = root_oct, note = seq_notes[n], action = "note_on"}
          local off = {t = eSCALE, i = key_focus, root = root_oct, note = seq_notes[n], action = "note_off"}
          table.insert(p[i].event[bank][s], on)
          table.insert(p[i].event[bank][e], off)
        else
          local on = {t = eKEYS, i = key_focus, note = seq_notes[n], action = "note_on"}
          local off = {t = eKEYS, i = key_focus, note = seq_notes[n], action = "note_off"}
          table.insert(p[i].event[bank][s], on)
          table.insert(p[i].event[bank][e], off)
        end
        p[i].count[bank] = p[i].count[bank] + 2
      end
    end
    p[i].endpoint[bank] = #seq_notes * (seq_rate * 64)
    p[i].endpoint_init[bank] = p[i].endpoint[bank]
    p[i].manual_length[bank] = true
    load_pattern_bank(i, bank)
  else
    show_message("sequence    empty")
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
    p[i].load = 1
    p[i].prc_enabled = pattern_data[i].prc_enabled
    p[i].prc_ch = pattern_data[i].prc_ch
    if pattern[i].play == 1 then
      clock.run(function()
        clock.sync(bar_val)
        update_pattern_bank(i)
      end)
    else
      update_pattern_bank(i)
    end
  end
  page_redraw(3)
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

function clear_all_patterns()
  for i = 1, 8 do
    clear_active_notes(i)
    pattern[i]:clear()
    p[i].bank = 1
    for bank = 1, 24 do
      p[i].loop[bank] = 1
      p[i].launch[bank] = 3
      p[i].quantize[bank] = 1/4
      p[i].count[bank] = 0
      p[i].event[bank] = {}
      p[i].endpoint[bank] = 0
      p[i].endpoint_init[bank] = 0
      p[i].barnum[bank] = 4
      p[i].meter[bank] = 4/4
      p[i].length[bank] = 16
      p[i].manual_length[bank] = false
      p[i].prc_num[bank] = 0
      p[i].prc_option[bank] = 2
    end
    load_pattern_bank(i, 1)
    show_message("all   patterns   cleared")
  end
end

function send_program_change(i, bank)
  -- send prg change
  if p[i].prc_enabled and p[i].prc_num[bank] ~= 0 then
    if p[i].prc_type == 5 then
      local group = p[i].prc_num[bank]
      local delay = p[i].prc_option[bank] == 1 and -1/4 or 0 
      clock.run(function()
        clock.sync(bar_val, delay)
        if group < 0 then
          clear_kit_mutes()
        else
          set_kit_mutes(group)
        end
      end)
    else -- track program changes
      if (p[i].prc_option[bank] == 2 or pattern[i].play == 1) then
        if p[i].prc_type == 3 then
          m[i]:program_change(p[i].prc_num[bank] - 1, p[i].prc_ch)
        elseif p[i].prc_type < 3 then
          polyform.prc_load(p[i].prc_num[bank], p[i].prc_type)
        elseif p[i].prc_type == 4 then  
          drmfm.prc_load(p[i].prc_num[bank])
        end
      end
    end
    p[i].prc_pulse = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(1/30)
      p[i].prc_pulse = false
      dirtygrid = true
    end)
  end
end

-------- midi --------
function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local name = midi.vports[i].name
    local id = string.len(name) > 8 and str_format(name, 8, "") or name
    table.insert(midi_devices, i..": "..id)
  end
end

function midi_add_callback()
  build_midi_device_list()
end

function midi_remove_callback()
  clock.run(function()
    clock.sleep(0.2)
    build_midi_device_list()
  end)
end

function start_callback()
  seq_step = 0
  trig_step = 0
  counter = 3
end

function stop_callback()
  for i = 1, 8 do
    pattern[i]:stop()
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

function set_midi_event_callback()
  for i = 1, 16 do
    midi.vports[i].event = nil
  end
  m[midi_in_dev].event = midi_events
end

function midi_events(data)
  local msg = midi.to_msg(data)
  if msg.type == "note_on" or msg.type == "note_off" then
    local destination = midi_in_dest == 0 and msg.ch or midi_in_dest
    local channel = midi_in_dest == 0 and (util.wrap(destination, 1, 8)) or midi_in_ch
    if msg.ch == channel then
      if midi_in_quant and destination ~= 7 then
        msg.note = mu.snap_note_to_array(msg.note, note_map)
      end
      if destination == 8 then
        local e = {t = eMIDI, i = 8, note = msg.note, vel = msg.vel, ch = midi_out_ch, action = msg.type} event(e)
      elseif destination == 7 and msg.type == "note_on" then
        local e = {t = eKIT, i = 7, note = msg.note, vel = msg.vel} event(e)
      else
        local e = {t = eKEYS, i = destination, note = msg.note, vel = msg.vel, action = msg.type} event(e)
      end
    end
  end
end


-------- clock coroutines --------
function ledpulse_fast()
  pulse_key_fast = pulse_key_fast == 8 and 12 or 8
  if (rec_enabled or stop_all) then
    dirtygrid = true
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
    clock.sync(bar_val)
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
    if #seq_notes > 0 and seq_active then
      if seq_step >= #seq_notes then
        seq_step = 0
      end
      if trig_step >= trigs[trigs_focus].step_max then
        trig_step = 0
      end
      trig_step = trig_step + 1
      seq_step = seq_step + 1
      if seq_notes[seq_step] > 0 and trigs[trigs_focus].pattern[trig_step] == 1 then
        if trigs[trigs_focus].prob[trig_step] >= math.random() then
          local current_note = seq_notes[seq_step]
          local current_vel = math.floor(util.linlin(0, 1, 0, 127, trigs[trigs_focus].vel[trig_step])) 
          if voice[key_focus].keys_option == 1 then
            local e = {t = eSCALE, i = key_focus, root = root_oct, note = current_note, vel = current_vel, action = "note_on"} event(e)
            clock.run(function()
              clock.sync(seq_rate / 2)
              local e = {t = eSCALE, i = key_focus, root = root_oct, note = current_note, action = "note_off"} event(e)
            end)
          elseif voice[key_focus].keys_option == 2 or voice[key_focus].keys_option == 3 then
            local e = {t = eKEYS, i = key_focus, note = current_note, vel = current_vel, action = "note_on"} event(e)
            clock.run(function()
              clock.sync(seq_rate / 2)
              local e = {t = eKEYS, i = key_focus, note = current_note, action = "note_off"} event(e)
            end)    
          end
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
      if trigs[trigs_focus].pattern[trig_step] == 1 then
        if trigs[trigs_focus].prob[trig_step] >= math.random() then
          local current_vel = math.floor(util.linlin(0, 1, 0, 127, trigs[trigs_focus].vel[trig_step]))
          -- held notes
          if #notes_held > 0 then
            for _, v in ipairs(notes_held) do
              if voice[key_focus].keys_option == 1 then
                local e = {t = eSCALE, i = key_focus, root = root_oct, note = v, vel = current_vel, action = "note_on"} event(e)
                clock.run(function()
                  clock.sync(rep_rate / 2)
                  local e = {t = eSCALE, i = key_focus, root = root_oct, note = v, action = "note_off"} event(e)
                end)
              elseif voice[key_focus].keys_option == 4 then
                local e = {t = eDRUMS, i = key_focus, note = v, vel = current_vel} event(e)
              else
                local e = {t = eKEYS, i = key_focus, note = v, vel = current_vel, action = "note_on"} event(e)
                clock.run(function()
                  clock.sync(rep_rate / 2)
                  local e = {t = eKEYS, i = key_focus, note = v, action = "note_off"} event(e)
                end)    
              end
            end
          end
          -- sustained notes for all voices
          for i = 1, NUM_VOICES do
            if voice[i].sustain then
              for _, v in ipairs(voice[i].held_notes) do
                if voice[i].keys_option == 1 then
                  local e = {t = eSCALE, i = i, root = root_oct, note = v, vel = current_vel, action = "note_on"} event(e)
                  clock.run(function()
                    clock.sync(rep_rate / 2)
                    local e = {t = eSCALE, i = i, root = root_oct, note = v, action = "note_off"} event(e)
                  end)
                elseif voice[i].keys_option == 2 then
                  local e = {t = eKEYS, i = i, note = v, vel = current_vel, action = "note_on"} event(e)
                  clock.run(function()
                    clock.sync(rep_rate / 2)
                    local e = {t = eKEYS, i = i, note = v, action = "note_off"} event(e)
                  end)    
                end
              end
            end
          end
          -- held kit notes
          if #kit_held > 0 then
            for _, v in ipairs(kit_held) do
              local e = {t = eKIT, i = 7, note = v, vel = current_vel} event(e)
            end
          end
          -- held ansi keys
          if #ansi_held > 0 then
            for _, v in ipairs(ansi_held) do
              local e = {t = eANSI, i = v} event(e)
            end
          end
        end
      end
      if trigs_config_view then dirtygrid = true end
    end
  end
end

function autostrum()
  local endpoint = strum_count + chord_inversion - 1
  -- strum loop
  for i = chord_inversion, endpoint do
    local step = i
    local pos = i - chord_inversion + 1
    -- calc index (step)
    if strum_mode == 2 then
      if pos % 2 == 0 then
        step = endpoint - pos + 2
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
    if step < 1 then step = 1 end
    -- calc rate
    local rate_var = math.random(-12, 12) * strum_drift
    local rate = strum_rate + rate_var
    if strum_skew > 0 then
      rate = strum_rate + ((endpoint - (i - 1)) * strum_skew * 0.001)
    elseif strum_skew < 0 then
      rate = strum_rate - (i * strum_skew * 0.001)
    end
    -- play note
    local voice = strum_focus > 0 and strum_focus or key_focus
    local note = chord_arp[step] + (12 * chord_oct_shift)
    local e = {t = eKEYS, i = voice, note = note, action = "note_on"}
    if key_quantize then
      table.insert(quant_event, e)
    else
      event(e)
    end
    clock.run(function()
      clock.sleep(rate)
      local e = {t = eKEYS, i = voice, note = note, action = "note_off"} event(e)
      if key_quantize then
        table.insert(quant_event, e)
      else
        event(e)
      end
    end)
    clock.sleep(rate)
  end
end

-------- misc, other and the rest --------
function clear_all_notes()
  local focus = {key_focus, int_focus}
  for i = 1, 2 do
    if #notes_held > 0 then
      for _, note in ipairs(notes_held) do
        voice_note_off(voice[focus[i]].output, note)
      end
    end
  end
  for i = 1, 8 do
    if pattern[i].play == 1 then
      clear_active_notes(i)
    end
  end
  for i = 1, 12 do
    nv.viz[i] = false
  end
  nb:stop_all()
  notes_held = {}
end

function set_repeat_rate(k1, k2, k3, k4, keypress)
  if not key_repeat then trig_step = 0 end
  key_repeat = (k1 + k2 + k3 + k4) > 0 and true or false
  local idx = tonumber(tostring(k4..k3..k2..k1), 2)
  if idx > 0 then
    rep_rate = rep_rates[idx] * 4
    if keypress == 1 then
      show_message("repeat  rate:  "..rep_rate_names[idx])
    end
  end
end

function set_kit_mutes(group)
  kit_mute.focus = group
  kit_mute.active = true
  for i = 1, 16 do
    kit_mute.key[i] = kit_mute.group[group][i]
  end
  for i = 1, 12 do
    drm_mute.key[i] = drm_mute.group[group][i]
    if rytm_mode then
      local state = drm_mute.group[group][i] and 127 or 0
      m[midi_rytm_dev]:cc(94, state, i)
    end
  end
end

function clear_kit_mutes()
  kit_mute.active = false
  for i = 1, 16 do
    kit_mute.key[i] = false
  end
  for i = 1, 12 do
    drm_mute.key[i] = false
    if rytm_mode then
      m[midi_rytm_dev]:cc(94, 0, i)
    end
  end
end

function rytm_mute_all()
  if rytm_mode then
    for i = 1, 12 do
      m[midi_rytm_dev]:cc(94, 127, i)
    end
  end
end

function run_drmf_perf()
  if perfclock ~= nil then
    clock.cancel(perfclock)
  end
  perfclock = clock.run(function()
    local counter = 0
    local inc = perftime * 4
    local d = 100 / inc
    while counter < perftime do
      clock.sync(1/4)
      params:delta("drmfm_perf_amt", d)
      counter = counter + (1/4)
    end 
  end)
end

function cancel_drmf_perf()
  if perfclock ~= nil then
    clock.cancel(perfclock)
  end
  params:set("drmfm_perf_amt", 0)
end

function display_output_volt(i)
  local volts = util.linlin(0, 1, ansi_cv[i].min, ansi_cv[i].max, ansi_cv[i].lvl)
  return round_form(volts, 0.1, "v")
end

function clamp_range(i)
  if ansi_cv[i].min >= ansi_cv[i].max then
    params:set("ansible_cv_"..i.."_min", ansi_cv[i].max - 0.1)
  end
  if ansi_cv[i].max <= ansi_cv[i].min then
    params:set("ansible_cv_"..i.."_max", ansi_cv[i].min + 0.1)
  end
end

function set_output_volt(i)
  local volts = util.linlin(0, 1, ansi_cv[i].min, ansi_cv[i].max, ansi_cv[i].lvl)
  crow.ii.ansible.cv(i, volts)
end

-------- pb, modwheeeel and aftertouch --------

-- pitchbend
function pb_ramp_up(i, dir)
  local inc = (1 - pb[i].value) / (pb[i].rise / pb_res)
  while pb[i].value < 1 do
    clock.sleep(at_res)
    pb[i].value = util.clamp(pb[i].value + inc, 0, 1)
    send_pitchbend(i, pb[i].value, dir)
  end
end

function pb_ramp_down(i, dir)
  local inc = pb[i].value / (pb[i].fall / pb_res)
  while pb[i].value > 0 do
    clock.sleep(pb_res)
    pb[i].value = util.clamp(pb[i].value - inc, 0, 1)
    send_pitchbend(i, pb[i].value, dir)
  end
end

function send_pitchbend(i, val, dir)
  if voice[i].output < 3 then
    local min = i == 1 and 1 or 3
    local max = i == 1 and 2 or 8
    for voice = min, max do
      engine.pb_depth(voice, val * dir)
    end
  elseif voice[i].output == 3 then
    local m_val = math.floor(val * 8192)
    if dir == 1 then
      m_val = util.clamp(m_val + 8192, 0, 16383)
    else
      m_val = util.clamp(8192 - m_val, 0, 16383)
    end
    m[i]:pitchbend(m_val, voice[i].midi_ch)
  elseif voice[i].output == 4 or voice[i].output == 5 then
    local n = voice[i].output - 3
    local pb = (caw[n].pb_depth / caw[n].v8_std) * val * dir
    local v8 = caw[n].v8 + pb
    caw[n].pb_v8 = pb
    if caw[n].count > 0 then
      crow.output[(n == 1 and 1 or 3)].volts = v8
    end
  elseif voice[i].output == 6 then
    if jf[i].mode == 1 then
      local pb = (jf[i].pb_depth / 12) * val * dir
      local v8 = jf[jf[i].ch].v8 + pb
      jf[jf[i].ch].pb_v8 = pb
      crow.ii.jf.pitch(jf[i].ch, v8)
    else
      for n = jf.poly_low, 6 do
        local pb = (jf[i].pb_depth / 12) * val * dir
        local v8 = jf[n].v8 + pb
        jf[n].pb_v8 = pb
        crow.ii.jf.pitch(n, v8)
      end
    end
  elseif voice[i].output == 7 then
    local pb = (wsyn.pb_depth / 12) * val * dir
    wsyn.pb_v8 = pb
    for n = 1, 4 do
      local v8 = wsyn[n].v8 + pb
      crow.ii.wsyn.pitch(n, v8)
    end
  elseif voice[i].output > 7 then
    local n = voice[i].output - 7
    local player = params:lookup_param("nb_"..n):get_player()
    player:pitch_bend(nil, val) -- what are the specs for global pitchbend?
  end
  dirtygrid = true
end

-- modwheel
function mw_ramp_up(i)
  local inc = (1 - mw[i].value) / (mw[i].rise / mw_res)
  while mw[i].value < 1 do
    clock.sleep(mw_res)
    mw[i].value = util.clamp(mw[i].value + inc, 0, 1)
    send_modwheel(i, mw[i].value)
  end
end

function mw_ramp_down(i)
  local inc = mw[i].value / (mw[i].fall / mw_res)
  while mw[i].value > 0 do
    clock.sleep(mw_res)
    mw[i].value = util.clamp(mw[i].value - inc, 0, 1)
    send_modwheel(i, mw[i].value)
  end
end

function send_modwheel(i, val)
  if voice[i].output < 3 then
    local min = i == 1 and 1 or 3
    local max = i == 1 and 2 or 8
    for voice = min, max do
      engine.mod_wheel(voice, val)
    end
  elseif voice[i].output == 3 then
    local m_val = math.floor(util.linlin(0, 1, 0, 127, val))
    m[i]:cc(1, m_val, voice[i].midi_ch)
  elseif voice[i].output == 4 or voice[i].output == 5 then
    local n = voice[i].output - 3
    local u = n == 1 and 2 or 1
    if not caw[u].active then
      local out = n == 1 and 4 or 2
      crow.output[out].volts = caw[n].mw_depth * val
    end
  elseif voice[i].output > 7 then
    local n = voice[i].output - 7
    local player = params:lookup_param("nb_"..n):get_player()
    player:modulate(val)
  end
  dirtygrid = true
end

-- aftertouch
function at_ramp_up(i)
  local inc = (1 - at[i].value) / (at[i].rise / at_res)
  while at[i].value < 1 do
    clock.sleep(at_res)
    at[i].value = util.clamp(at[i].value + inc, 0, 1)
    send_aftertouch(i, at[i].value)
  end
end

function at_ramp_down(i)
  local inc = at[i].value / (at[i].fall / at_res)
  while at[i].value > 0 do
    clock.sleep(at_res)
    at[i].value = util.clamp(at[i].value - inc, 0, 1)
    send_aftertouch(i, at[i].value)
  end
end

function send_aftertouch(i, val)
  if voice[i].output < 3 then
    local min = i == 1 and 1 or 3
    local max = i == 1 and 2 or 8
    for voice = min, max do
      engine.vibrato_rmod(voice, polyform.rate_mode * val)
      engine.vibrato_dmod(voice, polyform.depth_mod * val)
    end  
  elseif voice[i].output == 3 then
    local m_val = math.floor(util.linlin(0, 1, 0, 127, val))
    m[i]:channel_pressure(m_val, voice[i].midi_ch)
  elseif voice[i].output == 4 or voice[i].output == 5 then
    local n = voice[i].output - 3
    local u = n == 1 and 2 or 1
    if not caw[u].active then
      local out = n == 1 and 3 or 1
      crow.output[out].volts = caw[n].at_depth * val
    end
  elseif voice[i].output > 7 then
    local n = voice[i].output - 7
    local player = params:lookup_param("nb_"..n):get_player()
    player:modulate(val)
  end
  dirtygrid = true
end

-------- playback --------
function voice_note_on(i, note_num, velocity)
  local vel = velocity or voice[i].velocity
  if (voice[i].output == 1 or voice[i].output == 2) then
    polyform.note_on(voice[i].output, note_num, vel)
  elseif voice[i].output == 3 then
    m[i]:note_on(note_num, vel, voice[i].midi_ch)
    if voice[i].length > 0 then
      clock.run(function()
        clock.sleep(voice[i].length)
        m[i]:note_off(note_num, 0, voice[i].midi_ch)
        if pageNum == 1 then set_note_viz(note_num, false) end
      end)
    end
  elseif (voice[i].output == 4 or voice[i].output == 5) then
    crow_note_on(voice[i].output - 3, note_num, vel)
  elseif voice[i].output == 6 then
    jf_note_on(i, note_num, vel)
  elseif voice[i].output == 7 then
    wsyn_note_on(note_num, vel)
  elseif voice[i].output > 7 then
    nb_note_on(voice[i].output - 7, note_num, vel)
  end
  if midi_thru then
    local channel = midi_out_ch + i - 1
    m[midi_out_dev]:note_on(note_num, vel, channel)
  end
  if pageNum == 1 then set_note_viz(note_num, true) end
end

function voice_note_off(i, note_num)
  if (voice[i].output == 1 or voice[i].output == 2) then
    polyform.note_off(voice[i].output, note_num)
  elseif voice[i].output == 3 then
    m[i]:note_off(note_num, 0, voice[i].midi_ch)
  elseif (voice[i].output == 4 or voice[i].output == 5) then
    crow_note_off(i)
  elseif voice[i].output == 6 then
    jf_note_off(i, note_num)
  elseif voice[i].output == 7 then
    wsyn_note_off(note_num)
  elseif voice[i].output > 7 then
    nb_note_off(i, note_num)
  end
  if midi_thru then
    local channel = midi_out_ch + i - 1
    m[midi_out_dev]:note_off(note_num, 0, channel)
  end
  if pageNum == 1 then set_note_viz(note_num, false) end
end

function dont_panic(voice)
  if voice < 3 then
    polyform.panic(voice)
  elseif (voice == 3 or voice > 7) then
    notes_off(voice)
  elseif (voice == 4 or voice == 5) then
    crow_panic(voice - 3)
  elseif voice == 6 then
    jf_panic()
  elseif voice == 7 then
    wsyn_panic()
  elseif voice > 7 then
    local player = params:lookup_param("nb_"..voice):get_player()
    player:stop_all()
  end
end

function crow_note_on(i, note_num, velocity)
  local vel = util.linlin(0, 127, 0, 1, (velocity or 127))
  local cv = i == 1 and 1 or 3
  local env = i == 1 and 2 or 4
  local v = ((note_num - 60) / caw[i].v8_std)
  local v8 = v + caw[i].pb_v8
  caw[i].v8 = v
  if caw[i].count > 0 then
    crow.output[cv].action = string.format("{ to(%f,%f,sine) }", v8, caw[i].slew)
    crow.output[cv]()
  else
    crow.output[cv].volts = v8
  end
  if caw[i].count > 0 and caw[i].legato then
    crow.output[env].action = string.format("{ to(%f,%f,'%s') }", caw[i].env_amp * caw[i].env_s * vel, caw[i].env_d, caw[i].env_curve)
  else
    crow.output[env].action = string.format("{ to(%f,%f,'%s'), to(%f,%f,'%s') }", caw[i].env_amp * vel, caw[i].env_a, caw[i].env_curve, caw[i].env_amp * caw[i].env_s * velocity, caw[i].env_d, caw[i].env_curve)
  end
  crow.output[env]()
  caw[i].count = caw[i].count + 1
end

function crow_note_off(i)
  local n = voice[i].output - 3
  local env = n == 1 and 2 or 4
  caw[n].count = caw[n].count - 1
  if caw[n].count <= 0 then
    caw[n].count = 0
    crow.output[env].action = string.format("{ to(%f,%f,'%s') }", 0, caw[n].env_r, caw[n].env_curve)
    crow.output[env]()
  end
end

function crow_panic(i)
  local env = i == 1 and 2 or 4
  crow.output[env].action = string.format("{ to(%f,%f) }", 0, 0)
  crow.output[env]()
  caw[i].count = 0
end

function jf_note_on(i, note_num, velocity)
  local vel = util.linlin(0, 127, 0, 1, (velocity or 127))
  local v = (note_num - 60) / 12
  if jf[i].mode == 1 then
    local v8 = v + jf[jf[i].ch].pb_v8
    jf[jf[i].ch].v8 = v
    crow.ii.jf.play_voice(jf[i].ch, v8, jf[i].amp * vel)
    jf[i].count = jf[i].count + 1
  else
    local slot = jf.poly_notes[note_num]
    if slot == nil then
      slot = jf.poly_alloc:get()
      slot.count = 1
    end
    slot.on_release = function()
      crow.ii.jf.trigger(slot.id + jf.num_mono, 0)
    end
    jf.poly_notes[note_num] = slot
    local v8 = v + jf[slot.id + jf.num_mono].pb_v8
    jf[slot.id + jf.num_mono].v8 = v
    crow.ii.jf.play_voice(slot.id + jf.num_mono, v8, jf[i].amp * vel)
  end
end

function jf_note_off(i, note_num)
  if jf[i].mode == 1 then
    jf[i].count = jf[i].count - 1
    if jf[i].count < 0 then jf[i].count = 0 end
    if jf[i].count == 0 then
      crow.ii.jf.trigger(jf[i].ch, 0)
    end
  else
    local slot = jf.poly_notes[note_num]
    if slot ~= nil then
      jf.poly_alloc:release(slot)
    end
    jf.poly_notes[note_num] = nil
  end
end

function jf_panic()
  for i = 1, 6 do
    crow.ii.jf.trigger(i, 0)
    jf[i].count = 0
  end
end

function wsyn_note_on(note_num, velocity)
  local vel = util.linlin(0, 127, 0, 1, (velocity or 127))
  local v = (note_num - 60) / 12
  local v8 = v + wsyn.pb_v8
  local slot = wsyn.notes[note_num]
  if slot == nil then
    slot = wsyn.alloc:get()
    slot.count = 1
  end
  slot.on_release = function()
    crow.ii.wsyn.velocity(slot.id, 0)
  end
  wsyn.notes[note_num] = slot
  wsyn[slot.id].v8 = v
  crow.ii.wsyn.play_voice(slot.id, v8, wsyn.amp * vel)  
end

function wsyn_note_off(note_num)
  local slot = wsyn.notes[note_num]
  if slot ~= nil then
    wsyn.alloc:release(slot)
  end
  wsyn.notes[note_num] = nil
end

function wsyn_panic()
  for i = 1, 4 do
    crow.ii.wsyn.velocity(i, 0)
  end
end

function nb_note_on(i, note_num, velocity)
  local player = params:lookup_param("nb_"..i):get_player()
  player:note_on(note_num, velocity)
  if voice[i].length > 0 then
    clock.run(function()
      clock.sleep(voice[i].length)
      player:note_off(note_num)
      if pageNum == 1 then set_note_viz(note_num, false) end
    end)
  end
end

function nb_note_off(i, note_num)
  local player = params:lookup_param("nb_"..(voice[i].output - 7)):get_player()
  player:note_off(note_num)
end

function play_kit(note_num, velocity)
  local velocity = velocity or kit_velocity
  m[kit_midi_dev]:note_on(note_num, velocity, kit_midi_ch)
  clock.run(function()
    clock.sync(1/4)
    m[kit_midi_dev]:note_off(note_num, 0, kit_midi_ch)
  end)
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

function pset_write_callback(filename, name, number)
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
    pattern_data[i].trigs_prob = {table.unpack(trigs[i].prob)}
    pattern_data[i].trigs_vel = {table.unpack(trigs[i].vel)}
    pattern_data[i].bank = p[i].bank
    pattern_data[i].loop = {}
    pattern_data[i].launch = {}
    pattern_data[i].quantize = {}
    pattern_data[i].count = {}
    pattern_data[i].event = {}
    pattern_data[i].endpoint = {}
    pattern_data[i].barnum = {}
    pattern_data[i].meter = {}
    pattern_data[i].length = {}
    pattern_data[i].manual_length = {}
    pattern_data[i].prc_enabled = p[i].prc_enabled
    pattern_data[i].prc_ch = p[i].prc_ch
    pattern_data[i].prc_num = {}
    pattern_data[i].prc_option = {}
    for j = 1, 24 do
      pattern_data[i].loop[j] = p[i].loop[j]
      pattern_data[i].launch[j] = p[i].launch[j]
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

function pset_read_callback(filename, silent, number)
  local loaded_file = io.open(filename, "r")
  if loaded_file then
    io.input(loaded_file)
    local pset_id = string.sub(io.read(), 4, -1)
    io.close(loaded_file)
    -- load sesh data
    pattern_data = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
    clear_all_notes()
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
        if pattern_data[i].launch ~= nil then
          p[i].launch[j] = pattern_data[i].launch[j]
        else
          print("no launch data")
        end
      end
      p[i].prc_enabled = pattern_data[i].prc_enabled
      p[i].prc_ch = pattern_data[i].prc_ch
      p[i].bank = 1
      pattern_bank_page = 0
      load_pattern_bank(i, 1)
      trigs[i].step_max = pattern_data[i].trigs_max
      trigs[i].pattern = {table.unpack(pattern_data[i].trigs_pattern)}
      if pattern_data[i].trigs_prob then
        trigs[i].prob = {table.unpack(pattern_data[i].trigs_prob)}
        trigs[i].vel = {table.unpack(pattern_data[i].trigs_vel)}
      else
        print("some trig data missing")
      end
    end
    dirtyscreen = true
    dirtygrid = true
    print("finished reading pset:'"..pset_id.."'")
  end
end

function pset_delete_callback(filename, name, number)
  norns.system_cmd("rm -r "..norns.state.data.."patterns/"..number.."/")
  pset_focus = 1
  build_pset_list()
  print("finished deleting pset:'"..name.."'")
end

function load_midi_files(filename)
  if filename ~= "cancel" and filename ~= "" and filename ~= midim_default_path then
    midim.convert_all(filename)
    show_message("midi   files   loaded")
    loading_page = false
  end
  screenredrawtimer:start()
  dirtyscreen = true
end


--------------------- INIT! INNIT? -----------------------
function init()

  -- calc grid size
  get_grid_size()

  -- build pset list
  build_pset_list()

  -- midi import
  if util.file_exists(midim_default_path) == false then
    util.make_dir(midim_default_path)
  end

  -- check for crow
  if norns.crow.connected() then
    caw.is = true
  end
  
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

  params:add_option("page_autofocus", "autofocus", {"off", "on"}, 1)
  params:set_action("page_autofocus", function(mode) autofocus = mode == 2 and true or false end)

  params:add_option("metronome_viz", "metronome", {"hide", "show"}, 2)
  params:set_action("metronome_viz", function(mode) set_metronome(mode) end)

  params:add_option("pattern_mapping", "pattern alloc", {"free", "voices"}, 1)
  params:set_action("pattern_mapping", function(mode) pattern_voicemap = mode == 2 and true or false end)

  params:add_number("time_signature", "time signature", 2, 9, 4, function(param) return param:get().."/4" end)
  params:set_action("time_signature", function(val) bar_val = val end)
        
  params:add_option("key_quant_value", "key quantization", options.key_quant, 7)
  params:set_action("key_quant_value", function(idx) quant_rate = options.quant_value[idx] * 4 end)
  
  params:add_option("key_seq_rate", "seq rate", options.key_quant, 7)
  params:set_action("key_seq_rate", function(idx) seq_rate = options.quant_value[idx] * 4 end)
  params:hide("key_seq_rate")

  -- kit settings
  params:add_group("kit_group", "kit settings", 35)

  params:add_option("kit_dest", "kit mode", {"drmFM", "midi"}, 1)
  params:set_action("kit_dest", function(mode)
    kit_mode = mode
    p[7].prc_type = mode == 2 and 3 or 4
    kit_mode_menu()
  end)

  params:add_number("kit_root_note", "kit base note", 0, 24, 12, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("kit_root_note", function(val) kit_root_note = val - 12 dirtygrid = true end)

  params:add_option("kit_out_device", "kit out device", midi_devices, 1)
  params:set_action("kit_out_device", function(val) m[kit_midi_dev] = midi.connect(val) end)

  params:add_number("kit_midi_channel", "kit midi channel", 1, 16, 1)
  params:set_action("kit_midi_channel", function(val) kit_midi_ch = val end)

  params:add_number("kit_note_velocity", "kit velocity", 1, 127, 100)
  params:set_action("kit_note_velocity", function(val) kit_velocity = val end)

  params:add_option("kit_mod_key_mode", "kit mod keys", {"mutes", "midi cc"}, 1)
  params:set_action("kit_mod_key_mode", function(mode) kit_mod_keys = mode kit_mod_menu() end)

  params:add_binary("kit_clear_mutes", "clear mutes", "trigger", 0)
  params:set_action("kit_clear_mutes", function() clear_kit_mutes() end)

  for i = 1, 4 do
    params:add_separator("kit_cc_bank_"..i, "kit midi cc bank "..i)
    for n = 1, 2 do
      local name = {"A", "B"}
      params:add_number("kit_cc_num_"..name[n].."_"..i, "cc "..name[n].." number", 0, 127, 19 + n + (i - 1) * 2)
      params:set_action("kit_cc_num_"..name[n].."_"..i, function(num) mcc[(i - 1) * 2 + n].num = num end)

      params:add_number("kit_cc_max_"..name[n].."_"..i, "cc "..name[n].." hold val", 0, 127, 127)
      params:set_action("kit_cc_max_"..name[n].."_"..i, function(num) mcc[(i - 1) * 2 + n].max = num end)

      params:add_number("kit_cc_min_"..name[n].."_"..i, "cc "..name[n].." release val", 0, 127, 0)
      params:set_action("kit_cc_min_"..name[n].."_"..i, function(num) mcc[(i - 1) * 2 + n].min = num end)
    end
  end

  -- kit and drm mute groups
  params:add_group("kit_mute_groups", "kit mute groups", 96)
  for i = 1, 16 do
    for n = 1, 6 do
      params:add_option("kit_mute_key_"..i.."_group_"..n, "kit mute key "..i.." group "..n, {"off", "on"}, 1)
      params:set_action("kit_mute_key_"..i.."_group_"..n, function(option) kit_mute.group[n][i] = option == 2 and true or false end)
    end
  end
  params:hide("kit_mute_groups")

  params:add_group("drm_mute_groups", "drm mute groups", 72)
  for i = 1, 12 do
    for n = 1, 6 do
      params:add_option("drm_mute_key_"..i.."_group_"..n, "drm mute key "..i.." group "..n, {"off", "on"}, 1)
      params:set_action("drm_mute_key_"..i.."_group_"..n, function(option) drm_mute.group[n][i] = option == 2 and true or false end)
    end
  end
  params:hide("drm_mute_groups")

  -- midi i/o params
  params:add_group("global_midi_group", "midi settings", 10)

  params:add_separator("glb_midi_in_params", "midi in")

  params:add_option("glb_midi_in_device", "midi in device", midi_devices, 1)
  params:set_action("glb_midi_in_device", function(val) m[midi_in_dev] = midi.connect(val) set_midi_event_callback() end)

  params:add_option("glb_midi_in_destination", "send midi to..", {"all voices", "voice 1", "voice 2", "voice 3", "voice 4", "voice 5", "voice 6", "kit", "midi out"}, 1)
  params:set_action("glb_midi_in_destination", function(dest)
    midi_in_dest = dest - 1
    all_notes_off()
    if dest > 1 then
      params:hide("glb_midi_in_channel")
    else
      params:show("glb_midi_in_channel")
    end
    _menu.rebuild_params()
    dirtyscreen = true
  end)

  params:add_number("glb_midi_in_channel", "midi in channel", 1, 16, 1)
  params:set_action("glb_midi_in_channel", function(val) notes_off(midi_in_dev) midi_in_ch = val end)

  params:add_option("glb_midi_in_quantization", "map to scale", {"no", "yes"}, 1)
  params:set_action("glb_midi_in_quantization", function(mode) midi_in_quant = mode == 2 and true or false end)

  params:add_separator("glb_midi_out_params", "midi out")

  params:add_option("glb_midi_out_device", "midi out device", midi_devices, 1)
  params:set_action("glb_midi_out_device", function(val) m[midi_out_dev] = midi.connect(val) end)

  params:add_number("glb_midi_out_channel", "midi out channel", 1, 16, 1)
  params:set_action("glb_midi_out_channel", function(val) notes_off(midi_out_dev) midi_out_ch = val end)

  params:add_option("glb_midi_thru", "mirror voices", {"no", "yes"}, 1)
  params:set_action("glb_midi_thru", function(val) midi_thru = val == 2 and true or false end)

  params:add_binary("glb_midi_panic", "don't panic", "trigger", 0)
  params:set_action("glb_midi_panic", function() all_notes_off() end)

  -- keyboard settings
  params:add_group("keyboard_group", "keyboard settings", 17)

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

  params:add_number("strm_rate", "strum rate", 10, 100, 70, function(param) return round_form((1 / strum_rate), 0.01,"hz") end)
  params:set_action("strm_rate", function(val) strum_rate = (110 - val) / 200 end)

  params:add_number("strm_skew", "strum skew", -30, 30, 0, function(param) return round_form((util.linlin(-30, 30, -100, 100, param:get())), 1,"%") end)
  params:set_action("strm_skew", function(val) strum_skew = val end)

  params:add_number("strm_drift", "strum drift", 0, 100, 0, function(param) return round_form(param:get(), 1,"%") end)
  params:set_action("strm_drift", function(val) strum_drift = val / 10000 end)

  params:add_separator("drum_keys", "drum keys")

  params:add_number("drum_root_note", "drumpad root note", 0, 127, 0, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("drum_root_note", function(val) drum_root_note = val end)

  params:add_number("drum_vel_hi", "hi velocity", 1, 127, 100)
  params:set_action("drum_vel_hi", function(val) drum_vel_hi = val end)

  params:add_number("drum_vel_mid", "mid velocity", 1, 127, 64)
  params:set_action("drum_vel_mid", function(val) drum_vel_mid = val end)

  params:add_number("drum_vel_lo", "lo velocity", 1, 127, 32)
  params:set_action("drum_vel_lo", function(val) drum_vel_lo = val end)

  -- rytm params
  params:add_group("rytm_params", "rytm settings", 2)
  if not rytm_mode then params:hide("rytm_params") end

  params:add_option("rytm_out_device", "rytm out device", midi_devices, 2)
  params:set_action("rytm_out_device", function(val) m[midi_rytm_dev] = midi.connect(val) end)

  params:add_number("rytm_out_channel", "rytm out channel", 1, 16, 14)
  params:set_action("rytm_out_channel", function(val) midi_rytm_ch = val end)

  -- octave params
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
  params:add_group("pattern_parameters", "pattern parameters", 40)
  params:hide("pattern_parameters")
  for i = 1, 8 do
  
    params:add_option("patterns_playback_"..i, "playback", options.pattern_play, 1)
    params:set_action("patterns_playback_"..i, function(mode)
      pattern[i].loop = mode == 1 and 1 or 0
      p[i].loop[p[i].bank] = pattern[i].loop
    end)

    params:add_option("patterns_quantize_"..i, "quantize", options.pattern_quantize, 13)
    params:set_action("patterns_quantize_"..i, function(idx)
      pattern[i].quantize = options.pattern_quantize_value[idx]
      p[i].quantize[p[i].bank] = pattern[i].quantize
    end)

    params:add_option("patterns_launch_"..i, "launch mode", options.pattern_launch, 3)
    params:set_action("patterns_launch_"..i, function(mode)
      pattern[i].launch = mode
      p[i].launch[p[i].bank] = mode
    end)

    params:add_option("patterns_meter_"..i, "meter", options.pattern_meter, 3)
    params:set_action("patterns_meter_"..i, function(idx)
      pattern[i].meter = options.meter_val[idx]
      p[i].meter[p[i].bank] = options.meter_val[idx]
      update_pattern_length(i)
    end)

    params:add_number("patterns_barnum_"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("patterns_barnum_"..i, function(num)
      pattern[i].barnum = num
      p[i].barnum[p[i].bank] = num
      update_pattern_length(i)
      dirtygrid = true
    end)
  end

  -- voice params
  params:add_separator("voices", "voices")
  for i = 1, NUM_VOICES do
    params:add_group("voice_"..i, "voice "..i, 35)
    -- output
    params:add_option("voice_out_"..i, "output", options.output, (i > 2 and 3 or i))
    params:set_action("voice_out_"..i, function(val) set_voice_output(i, val) end)
    -- mute
    params:add_option("voice_mute_"..i, "mute", {"off", "on"}, 1)
    params:set_action("voice_mute_"..i, function(mode)
      voice[i].mute = mode == 2 and true or false
      if mode == 2 then dont_panic(i) end
      dirtygrid = true
    end)
    -- keyboard
    params:add_option("keys_option_"..i, "keyboard type", {"scale", "chromatic", "chords", "drums"}, 1)
    params:set_action("keys_option_"..i, function(val) voice[i].keys_option = val dirtygrid = true voice_menu(i) end)
    params:hide("keys_option_"..i)

    -- midi params
    params:add_option("midi_device_"..i, "midi device", midi_devices, 1)
    params:set_action("midi_device_"..i, function(val) m[i] = midi.connect(val) end)

    params:add_number("midi_channel_"..i, "midi channel", 1, 16, i)
    params:set_action("midi_channel_"..i, function(val) notes_off(i) voice[i].midi_ch = val end)

    params:add_number("note_velocity_"..i, "velocity", 1, 127, 100)
    params:set_action("note_velocity_"..i, function(val) voice[i].velocity = val end)

    params:add_control("note_length_"..i, "note length", controlspec.new(0, 2, "lin", 0.01, 0), function(param) return param:get() == 0 and "manual" or param:get().." s" end)
    params:set_action("note_length_"..i, function(val) voice[i].length = val end)

    params:add_binary("dont_panic_"..i, "don't panic!", "trigger", 0)
    params:set_action("dont_panic_"..i, function() dont_panic(i) end)

    -- jf params
    params:add_separator("jf_params_"..i, "jf settings")
    params:add_option("jf_mode_"..i, "mode", {"mono", "poly"}, 1)
    params:set_action("jf_mode_"..i, function(mode) jf[i].mode = mode voice_menu(i) alloc_jf_voices() jf_panic() end)

    params:add_number("jf_voice_"..i, "voice", 1, 6, i)
    params:set_action("jf_voice_"..i, function(vox) jf[i].ch = vox alloc_jf_voices() end)

    params:add_control("jf_amp_"..i, "level", controlspec.new(0.1, 10, "lin", 0.1, 8.0, "vpp"))
    params:set_action("jf_amp_"..i, function(level) set_jf_levels(i, level) end)

    params:add_number("jf_pitchbend_"..i, "pitchbend", 0, 24, 7, function(param) return "±"..param:get().."st" end)
    params:set_action("jf_pitchbend_"..i, function(value) jf[i].pb_depth = value end)

    params:add_separator("pb_settings"..i, "pitchbend")
    params:add_control("pitchbend_rise_"..i, "rise", controlspec.new(0.1, 10, "lin", 0.1, 0.1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("pitchbend_rise_"..i, function(val) pb[i].rise = val end)

    params:add_control("pitchbend_fall_"..i, "fall", controlspec.new(0.1, 10, "lin", 0.1, 0.1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("pitchbend_fall_"..i, function(val) pb[i].fall = val end)

    params:add_separator("mw_settings"..i, "modwheel")
    params:add_control("modwheel_rise_"..i, "rise", controlspec.new(0.1, 10, "lin", 0.1, 0.1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("modwheel_rise_"..i, function(val) mw[i].rise = val end)

    params:add_control("modwheel_fall_"..i, "fall", controlspec.new(0.1, 10, "lin", 0.1, 0.1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("modwheel_fall_"..i, function(val) mw[i].fall = val end)

    params:add_separator("at_settings"..i, "aftertouch")
    params:add_control("aftertouch_rise_"..i, "rise", controlspec.new(0.1, 10, "lin", 0.1, 0.1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("aftertouch_rise_"..i, function(val) at[i].rise = val end)

    params:add_control("aftertouch_fall_"..i, "fall", controlspec.new(0.1, 10, "lin", 0.1, 0.1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("aftertouch_fall_"..i, function(val) at[i].fall = val end)

    params:add_separator("voice_midi_cc_"..i, "midi cc's")
    for n = 1, 4 do
      local name = {"A", "B", "C", "D"}
      params:add_text("midi_cc_name_"..n.."_"..i, "cc "..name[n].." name", "cc "..name[n])
      params:set_action("midi_cc_name_"..n.."_"..i, function(txt) if txt then voice[i].midi_cc_name[n] = txt end end)

      params:add_number("midi_cc_dest_"..n.."_"..i, "cc "..name[n].." number", 0, 127, 0, function(param) return param:get() == 0 and "off" or param:get() end)
      params:set_action("midi_cc_dest_"..n.."_"..i, function(num) voice[i].midi_cc[n] = num end)

      params:add_number("midi_cc_val_"..n.."_"..i, "cc "..name[n].." value", 0, 127, 0)
      params:set_action("midi_cc_val_"..n.."_"..i, function(val) if voice[i].midi_cc[n] > 0 then m[i]:cc(voice[i].midi_cc[n], val, voice[i].midi_ch) end end)
    end
    
  end

  params:add_separator("sound_params", "synthesis & cv")
  -- polyform params
  polyform.init()

  -- crow params
  local crow_options = {"crow [out 1+2]", "crow [out 3+4]"}
  for i = 1, 2 do
    params:add_group("crow_out_"..i, crow_options[i], 15)
    if not caw.is then params:hide("crow_out_"..i) end

    params:add_separator("crow_pitch_params_"..i, "pitch")

    params:add_option("crow_v8_type_"..i, "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
    params:set_action("crow_v8_type_"..i, function(mode) caw[i].v8_std = mode == 1 and 12 or 10 end)

    params:add_option("crow_legato_"..i, "legato", {"off", "on"}, 1)
    params:set_action("crow_legato_"..i, function(mode) caw[i].legato = mode == 2 and true or false end)

    params:add_control("crow_v8_slew_"..i, "slew rate", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_v8_slew_"..i, function(value) caw[i].slew = value end)

    params:add_number("crow_pitchbend_"..i, "pitchbend", 0, 24, 7, function(param) return "±"..param:get().."st" end)
    params:set_action("crow_pitchbend_"..i, function(value) caw[i].pb_depth = value end)

    params:add_separator("crow_env_params_"..i, "envelope")

    params:add_control("crow_env_amp_"..i, "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8), function(param) return round_form(param:get(), 0.01, "v") end)
    params:set_action("crow_env_amp_"..i, function(value) caw[i].env_amp = value end)

    params:add_option("crow_env_shape_"..i, "env curve", {"exp", "lin", "log"}, 1)
    params:set_action("crow_env_shape_"..i, function(idx) caw[i].env_curve = caw.env_shapes[idx] end)

    params:add_control("crow_env_attack_"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0.001), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_env_attack_"..i, function(value) caw[i].env_a = value end)

    params:add_control("crow_env_decay_"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.4), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_env_decay_"..i, function(value) caw[i].env_d = value end)

    params:add_control("crow_env_sustain_"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("crow_env_sustain_"..i, function(value) caw[i].env_s = value end)

    params:add_control("crow_env_release_"..i, "release", controlspec.new(0.01, 10, "exp", 0, 0.8), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_env_release_"..i, function(value) caw[i].env_r = value end)

    params:add_separator("crow_mod_params_"..i, "modulation")
    local atout = {"[out 3]", "[out 1]"}
    local mwout = {"[out 4]", "[out 2]"}

    params:add_control("crow_at_depth"..i, "aftertouch "..atout[i], controlspec.new(-5, 10, "lin", 0.1, 5), function(param) return round_form(param:get(), 0.01, "v") end)
    params:set_action("crow_at_depth"..i, function(value) caw[i].at_depth = value end)

    params:add_control("crow_mw_depth"..i, "modwheel "..mwout[i], controlspec.new(-5, 10, "lin", 0.1, 5), function(param) return round_form(param:get(), 0.01, "v") end)
    params:set_action("crow_mw_depth"..i, function(value) caw[i].mw_depth = value end)

  end

  -- jf params
  params:add_group("jf_params", "crow [jf]", 2)
  if not caw.is then params:hide("jf_params") end

  params:add_option("jf_run_mode", "jf run mode", {"off", "on"}, 1)
  params:set_action("jf_run_mode", function(mode) crow.ii.jf.run_mode(mode - 1) end)

  params:add_control("jf_run", "jf run", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("jf_run", function(volts) crow.ii.jf.run(volts) end)

  -- wsyn params
  params:add_group("wsyn_params", "crow [wsyn]", 15)
  if not caw.is then params:hide("wsyn_params") end

  params:add_separator("wysn_synth", "synth")

  params:add_option("wysn_mode", "wsyn mode", {"hold", "lpg"}, 2)
  params:set_action("wysn_mode", function(mode)
    crow.ii.wsyn.ar_mode(mode - 1)
    if mode == 1 then
      params:hide("wsyn_lpg_time")
      params:hide("wsyn_lpg_sym")
    else
      params:show("wsyn_lpg_time")
      params:show("wsyn_lpg_sym")
    end
    _menu.rebuild_params()
    dirtyscreen = true
  end)

  params:add_control("wsyn_lpg_time", "lpg time", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_lpg_time", function(v) crow.ii.wsyn.lpg_time(v) end)

  params:add_control("wsyn_lpg_sym", "lpg symmetry", controlspec.new(-5, 5, "lin", 0, -5, "v"))
  params:set_action("wsyn_lpg_sym", function(v) crow.ii.wsyn.lpg_symmetry(v) end)

  params:add_control("wsyn_amp", "level", controlspec.new(0, 10, "lin", 0, 5, "vpp"))
  params:set_action("wsyn_amp", function(level) wsyn.amp = level end)

  params:add_control("wsyn_curve", "curve",  controlspec.new(-5, 5, "lin", 0, 5, "v"))
  params:set_action("wsyn_curve", function(v) crow.ii.wsyn.curve(v) end)

  params:add_control("wsyn_ramp", "ramp", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_ramp", function(v) crow.ii.wsyn.ramp(v) end)

  params:add_control("wsyn_fm_index", "fm index", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_fm_index", function(v) crow.ii.wsyn.fm_index(v) end)

  params:add_control("wsyn_fm_env", "fm envelope", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wsyn_fm_env", function(v) crow.ii.wsyn.fm_env(v) end)

  params:add_number("wsyn_fm_num", "fm ratio num", 1, 16, 1)
  params:set_action("wsyn_fm_num", function(num) crow.ii.wsyn.fm_ratio(num, params:get("wsyn_fm_den")) end)

  params:add_number("wsyn_fm_den", "fm ratio denom", 1, 16, 2)
  params:set_action("wsyn_fm_den", function(denom) crow.ii.wsyn.fm_ratio(params:get("wsyn_fm_num"), denom) end)

  params:add_number("wsyn_pitchbend", "pitchbend", 0, 24, 7, function(param) return "±"..param:get().."st" end)
  params:set_action("wsyn_pitchbend", function(value) wsyn.pb_depth = value end)

  params:add_separator("wysn_modulation", "modulation")

  params:add_option("wsyn_this", "this jack", options.wsyn_jack, 1)
  params:set_action("wsyn_this", function(dest) crow.ii.wsyn.patch(1, dest) end)

  params:add_option("wsyn_that", "that jack", options.wsyn_jack, 2)
  params:set_action("wsyn_that", function(dest) crow.ii.wsyn.patch(2, dest) end)


  -- ansible cv params
  params:add_group("ansible_params", "crow [ansible]", (4 + 15) * 4)
  if not caw.is then params:hide("ansible_params") end

  for i = 1, 4 do
    params:add_separator("ansible_cv_"..i, "ansible cv "..i)

    params:add_control("ansible_cv_"..i.."_level", "level", controlspec.new(0, 1, "lin", 0, 0), function() return display_output_volt(i) end)
    params:set_action("ansible_cv_"..i.."_level", function(val) ansi_cv[i].lvl = val set_output_volt(i) end)

    params:add_control("ansible_cv_"..i.."_min", "min", controlspec.new(0, 10, "lin", 0, 0), function(param) return round_form(param:get(), 0.1, "v") end)
    params:set_action("ansible_cv_"..i.."_min", function(val) ansi_cv[i].min = val clamp_range(i) set_output_volt(i) end)
    
    params:add_control("ansible_cv_"..i.."_max", "max", controlspec.new(0, 10, "lin", 0, 10), function(param) return round_form(param:get(), 0.1, "v") end)
    params:set_action("ansible_cv_"..i.."_max", function(val) ansi_cv[i].max = val clamp_range(i) set_output_volt(i) end)

    ansi_cv[i].lfo = lo:add{min = 0, max = 1, baseline = 'min'}
    ansi_cv[i].lfo:add_params("ansi_cv_lfo_"..i, "cv out "..i.." lfo")
    ansi_cv[i].lfo:set("action", function(scaled, raw) params:set("ansible_cv_"..i.."_level", scaled) end) 
  end

  -- drmFM params
  drmfm.add_params()

  -- nb params
  params:add_group("nb_voices", "nb [players]", 4)
  for i = 1, 2 do
    local name = {"[one]", "[two]"}
    nb:add_param("nb_"..i, "nb "..name[i].." player")
  end
  nb:add_player_params()

  -- fx separator
  if md.is_loaded("fx") then
    params:add_separator("fx_params", "fx")
  end

  -- callbacks
  grid.add = grid_add_callback
  midi.add = midi_add_callback
  midi.remove = midi_remove_callback
  clock.transport.start = start_callback
  clock.transport.stop = stop_callback

  params.action_write = pset_write_callback
  params.action_read = pset_read_callback
  params.action_delete = pset_delete_callback

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
  vizclock = lt:new()

  fastpulse = vizclock:new_sprocket{
    action = function() ledpulse_fast() end,
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

  -- bang params
  if load_pset then
    params:default()
  else
    params:bang()
  end

end

-------- norns interface --------
function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if keyquant_edit then
    if n == 2 then
      show_message("start")
    elseif n == 3 then
      show_message("stop")
    end
  elseif loading_page then
    if n == 2 and z == 1 then
      if shift then
        clear_all_patterns()
      else
        view_pattern_import = not view_pattern_import
        if view_pattern_import then
          load_pattern_data(pset_list[pset_focus])
        else
          loaded_pattern_data = nil
        end
      end
    end
    if view_pattern_import then
      if n == 3 and z == 1 then
        if shift then
          screenredrawtimer:stop()
          fs.enter(midim_default_path, function(filename) load_midi_files(filename) end)
          shift = false
        else
          load_pattern_slot(pattern_src, pattern_dst)
          show_message("slot    loaded")
        end
      end
    else
      if n == 3 and z == 1 then
        if shift then
          load_patterns(pset_list[pset_focus])
          show_message("patterns    loaded")
        else
          local num = get_pset_num(pset_list[pset_focus])
          params:read(num)
          show_message("pset    loaded")
        end
        loading_page = false
      end
    end
  elseif prgchange_view then
    -- do nothing yet
  elseif trigs_edit then
    -- do nothing yet
  else
    if pageNum == 1 then
      if n == 2 and z == 1 then
        transposing = not transposing
      elseif n == 3 and z == 1 then
        if not transposing then
          transpose_value = 0
        end
      end
      dirtygrid = true
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
    elseif pageNum == 3 then
      if n > 1 and z == 1 then
        local d = n == 2 and -1 or 1
        if shift then
          if n == 2 then
            pattern[pattern_focus].manual_length = false
            pattern[pattern_focus].length = pattern[pattern_focus].meter * pattern[pattern_focus].barnum * 4
            pattern[pattern_focus]:set_length(pattern[pattern_focus].length)
            save_pattern_bank(pattern_focus, p[pattern_focus].bank)
          elseif n == 3 then
            reset_pattern_length(pattern_focus, p[pattern_focus].bank)
          end
        else
          pattern_param_focus = util.wrap(pattern_param_focus + d, 1, 3)
        end
      end
      dirtygrid = true
    elseif pageNum == 4 then
      if n > 1 and z == 1 then
        local d = n == 2 and -1 or 1
        if shift then
          drmfm_voice_focus = util.wrap(drmfm_voice_focus + d, 1, 16)
        else
          drmfm_param_focus = util.wrap(drmfm_param_focus + d, 1, #drmfm_e2_names)
        end        
      end    
    end
  end
  dirtyscreen = true
end

function enc(n, d)
  local pageMax = kit_mode == 1 and 4 or 3
  if n == 1 then
    pageNum = util.clamp(pageNum + d, 1, pageMax)
    if pageNum == 1 then
      for i = 1, 12 do
        nv.viz[i] = false
      end
    end
  end
  if keyquant_edit then
    if n == 2 then
      params:delta("time_signature", d)
    elseif n == 3 then
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
      if p[pattern_focus].prc_type < 3 then
        p[pattern_focus].prc_num[bank_focus] = util.clamp(p[pattern_focus].prc_num[bank_focus] + d, 0, 127)
      elseif p[pattern_focus].prc_type == 4 then
        p[pattern_focus].prc_num[bank_focus] = util.clamp(p[pattern_focus].prc_num[bank_focus] + d, 0, 127)
      elseif  p[pattern_focus].prc_type == 5 then
          p[pattern_focus].prc_num[bank_focus] = util.clamp(p[pattern_focus].prc_num[bank_focus] + d, -1, 6)
      else
        if shift and p[pattern_focus].prc_type == 3 then
          p[pattern_focus].prc_ch = util.clamp(p[pattern_focus].prc_ch + d, 1, 16)
        else
          p[pattern_focus].prc_num[bank_focus] = util.clamp(p[pattern_focus].prc_num[bank_focus] + d, 0, 127)
        end
      end
    elseif n == 3 then
      p[pattern_focus].prc_option[bank_focus] = util.clamp(p[pattern_focus].prc_option[bank_focus] + d, 1, 2)
    end
  elseif trigs_edit then
    if n == 2 then
      trigs[trigs_focus].prob[trig_step_focus] = util.clamp(trigs[trigs_focus].prob[trig_step_focus] + d/100, 0, 1)
    elseif n == 3 then
      trigs[trigs_focus].vel[trig_step_focus] = util.clamp(trigs[trigs_focus].vel[trig_step_focus] + d/100, 0, 1)
    end
    dirtygrid = true
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
        if dest < 3 and (param == 5 or param == 9) and shift and off == 0 then d = d > 0 and 120 or -120 end
        params:delta(voice_params[dest][param + off], d)
      end
    end
  elseif pageNum == 3 then
    if not (pattern_param_focus == 1 and ((pattern_rec_mode == "free" and pattern[pattern_focus].endpoint == 0) or pattern[pattern_focus].manual_length)) then
      if n == 2 then
        params:delta(pattern_e2_params[pattern_param_focus]..pattern_focus, d)
      elseif n == 3 and pattern_param_focus ~= 3 then
        params:delta(pattern_e3_params[pattern_param_focus]..pattern_focus, d)
      end
    end
  elseif pageNum == 4 then
    if shift then
      if n == 2 then
        params:delta("drmfm_perf_time", d)
      elseif n == 3 then
        params:delta("drmfm_perf_slot", d)
      end
    else
      if n == 2 then
        params:delta(drmfm_e2_params[drmfm_param_focus]..drmfm_voice_focus, d)
      elseif n == 3 then
        params:delta(drmfm_e3_params[drmfm_param_focus]..drmfm_voice_focus, d)
      end
    end
  end
  dirtyscreen = true
end

function redraw()
  screen.clear()
  screen.font_face(2)
  if keyquant_edit then
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("timing")
    screen.font_size(16)
    screen.move(30, 39)
    screen.text_center(params:string("time_signature"))
    screen.move(98, 39)
    screen.text_center(params:string("key_quant_value"))
    screen.font_size(8)
    screen.level(4)
    screen.move(30, 60)
    screen.text_center("time  signature")
    screen.move(98, 60)
    screen.text_center("key  quantization") 
  elseif loading_page then
    screen.line_width(1)
    if view_pattern_import then
      if shift then
        screen.font_size(16)
        screen.level(15)
        screen.move(64, 39)
        screen.text_center("load midi")
      else
        screen.font_size(8)
        screen.level(15)
        screen.move(64, 12)
        screen.text_center(pset_list[pset_focus].."  -  PATTERN  SLOTS")
        screen.font_size(16)
        screen.level(4)
        screen.move(64, 39)
        screen.text_center(">")
        screen.level(15)
        screen.move(30, 39)
        screen.text_center(pattern_src)
        screen.move(98, 39)
        screen.text_center(pattern_dst)
      end
      -- actions
      screen.font_size(8)
      screen.level(4)
      screen.move(4, 60)
      screen.text("back")
      screen.level(10)
      screen.move(124, 60)
      if shift then
        screen.text_right(">  select")
      else
        screen.text_right(">  import")
      end
    else
      screen.font_size(8)
      screen.level(15)
      screen.move(64, 12)
      screen.text_center(shift and "PATTERNS" or "PRESET")
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
      screen.text(shift and "clear   all <" or "import")
      screen.level(10)
      screen.move(124, 60)
      screen.text_right(shift and ">  load   all" or ">  load   pset")
    end
  elseif prgchange_view then
    local launch_options = {{"play", "load"}, {"upbeat", "dnbeat"}}
    local launch_mode = p[pattern_focus].prc_option[bank_focus]
    local num = p[pattern_focus].prc_num[bank_focus]
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    local name = pattern_focus < 7 and "voice    "..pattern_focus or (pattern_focus == 7 and "kit" or "drm   mute")
    screen.text_center(name.."      bank   "..bank_focus)
    -- param list
    screen.level(4)
    screen.move(30, 60)
    if shift and p[pattern_focus].prc_type == 3 then 
      screen.text_center("prg    channel")
    else
      local txt = "prg    msg"
      if p[pattern_focus].prc_type < 3 then
        txt = "polyform   patch"
      elseif p[pattern_focus].prc_type == 4 then
        txt = "drmfm   kit"
      elseif p[pattern_focus].prc_type == 5 then
        txt = "mute   group"
      end
      screen.text_center(txt)
    end
    screen.move(98, 60)
    screen.text_center("launch")
    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    if shift and p[pattern_focus].prc_type == 3 then 
      screen.text_center(p[pattern_focus].prc_ch)
    else
      screen.text_center(num == 0 and "off" or (num == -1 and "clear" or num))
    end
    screen.move(98, 39)
    screen.text_center(launch_options[pattern_focus == 8 and 2 or 1][launch_mode])
  elseif trigs_edit then
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("step    "..trig_step_focus)
    screen.font_size(16)
    screen.move(30, 39)
    screen.text_center(util.round(trigs[trigs_focus].prob[trig_step_focus] * 100, 1).."%")
    screen.move(98, 39)
    screen.text_center(util.round(trigs[trigs_focus].vel[trig_step_focus] * 100, 1).."%")
    screen.font_size(8)
    screen.level(4)
    screen.move(30, 60)
    screen.text_center("probability")
    screen.move(98, 60)
    screen.text_center("velocity") 
  else
    if pageNum == 1 then
      for i = 1, 12 do
        local off_x = i > 5 and 8 or 0
        local off_y = (i == 2 or i == 4 or i == 7 or i == 9 or i == 11) and -12 or 0
        screen.level(nv.viz[i] and 15 or (nv.is[i] and 6 or 1))
        if nv.root[i] then
          screen.move(16 + off_x + (i - 1) * 8, 44 + off_y)
          screen.font_size(8)
          screen.text_center(".")
        end
        screen.move(16 + off_x + (i - 1) * 8, 41 + off_y)
        screen.font_size(nv.viz[i] and 16 or 8)
        screen.text_center(nv.name[i])
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
      screen.text_center("voice "..voice_focus.." - "..params:string("voice_out_"..voice_focus))
      -- param list
      local dest = voice[voice_focus].output
      local param = voice_param_focus[voice_focus]
      if dest < 8 then
        -- param names
        screen.level(4)
        if dest == 3 and param > 4 then
          screen.move(30, 60)
          screen.text_center(voice[voice_focus].midi_cc_name[param - 4])
          screen.move(98, 60)
          screen.text_center(voice[voice_focus].midi_cc_name[param - 3])
        else
          screen.move(30, 60)
          screen.text_center(voice_param_names[dest][param])
          screen.move(98, 60)
          screen.text_center(voice_param_names[dest][param + 1])
        end
        -- param values
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
          screen.text_center(params:string(voice_params[dest][param]))
        end
        screen.move(98, 39)
        if (dest == 3 or dest == 6) then
          screen.text_center(params:string(voice_params[dest][param + 1]..voice_focus))
        else
          if dest < 3 then
            if param == 5 then
              local width = 50
              local offset = params:get(voice_params[dest][param + 1]) * 25 + 25
              screen.line_width(2)
              screen.move(74, 40)
              screen.line_rel(0 + offset, -16)
              screen.move(74 + width, 40)
              screen.line_rel(-width + offset, -16)
              screen.stroke()
            else
              screen.text_center(params:string(voice_params[dest][param + 1]))
            end
          else
            screen.text_center(params:string(voice_params[dest][param + 1]))
          end
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
    elseif pageNum == 3 then
      screen.font_size(8)
      screen.level(15)
      screen.move(64, 12)
      screen.text_center("pattern   "..pattern_focus.."       bank   "..p[pattern_focus].bank)
      if shift then
        local current_length = pattern[pattern_focus].meter * pattern[pattern_focus].barnum * 4
        screen.level((pattern[pattern_focus].manual_length or current_length ~= pattern[pattern_focus].length) and 15 or 2)
        screen.move(30, 60)
        screen.text_center("set")
        screen.move(98, 60)
        screen.level(pattern[pattern_focus].endpoint ~= pattern[pattern_focus].endpoint_init and 15 or 2)
        screen.text_center("reset")
        screen.font_size(16)
        screen.level(10)
        screen.move(64, 39)
        screen.text_center((pattern[pattern_focus].endpoint / 64).."  beats")
      else
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
      end
    elseif pageNum == 4 and kit_mode == 1 then
      screen.font_size(8)
      screen.level(15)
      screen.move(64, 12)
      if shift then
        screen.text_center("drmFM   performance   macros")
        -- param list
        screen.level(4)
        screen.move(30, 60)
        screen.text_center("duration")
        screen.move(98, 60)
        screen.text_center("slot")
        screen.level(15)
        screen.font_size(16)
        screen.move(30, 39)
        screen.text_center(params:string("drmfm_perf_time"))
        screen.move(98, 39)
        screen.text_center(params:string("drmfm_perf_slot"))
      else
        screen.text_center("drmFM   voice   "..drmfm_voice_focus)
        -- param list
        screen.level(4)
        screen.move(30, 60)
        screen.text_center(drmfm_e2_names[drmfm_param_focus])
        screen.move(98, 60)
        screen.text_center(drmfm_e3_names[drmfm_param_focus])
        screen.level(15)
        screen.font_size(16)
        screen.move(30, 39)
        screen.text_center(params:string(drmfm_e2_params[drmfm_param_focus]..drmfm_voice_focus))
        screen.move(98, 39)
        screen.text_center(params:string(drmfm_e3_params[drmfm_param_focus]..drmfm_voice_focus))
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
  if GRIDSIZE == 256 then
    grd.zero_keys(x, y, z)
  elseif GRIDSIZE == 128 then
    grd.one_keys(x, y, z)
  end
  dirtygrid = true
end 

function gridredraw()
  if GRIDSIZE == 256 then
    grd.zero_draw()
  elseif GRIDSIZE == 128 then
    grd.one_draw()
  end
end



-------- utilities --------
function r()
  norns.script.load(norns.state.script)
end

function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
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

function page_redraw(page)
  if pageNum == page then
    dirtyscreen = true
  end
end

function grid_add_callback()
  get_grid_size()
end

function get_grid_size()
  if g then
    GRIDSIZE = g.cols * g.rows
  end
  if GRIDSIZE == 256 and rotate_grid then
    g:rotation(1) -- 1 is 90°
  end
  dirtygrid = true
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
  if msg_clock ~= nil then
    clock.cancel(msg_clock)
  end
  msg_clock = clock.run(function()
    view_message = message
    dirtyscreen = true
    local dur = string.len(message) > 20 and 1.6 or 0.8
    clock.sleep(dur)
    view_message = ""
    dirtyscreen = true
    msg_clock = nil
  end)
end

function voice_menu(i)
  if (voice[i].output == 3 or voice[i].output == 8 or voice[i].output == 9) and voice[i].keys_option < 4 then
    params:show("note_velocity_"..i)
    params:show("note_length_"..i)
  else
    params:hide("note_velocity_"..i)
    params:hide("note_length_"..i)
  end
  if voice[i].output == 3  then
    params:show("midi_device_"..i)
    params:show("midi_channel_"..i)
    params:show("voice_midi_cc_"..i)
    for n = 1, 4 do
      params:show("midi_cc_name_"..n.."_"..i)
      params:show("midi_cc_dest_"..n.."_"..i)
      params:show("midi_cc_val_"..n.."_"..i)
    end
  else
    params:hide("midi_device_"..i)
    params:hide("midi_channel_"..i)
    params:hide("voice_midi_cc_"..i)
    for n = 1, 4 do
      params:hide("midi_cc_name_"..n.."_"..i)
      params:hide("midi_cc_dest_"..n.."_"..i)
      params:hide("midi_cc_val_"..n.."_"..i)
    end
  end
  if voice[i].output == 6 then
    if params:get("jf_mode_"..i) == 1 then
      params:show("jf_voice_"..i)
    else
      params:hide("jf_voice_"..i)
    end
    params:show("jf_params_"..i)
    params:show("jf_amp_"..i)
    params:show("jf_mode_"..i)
    params:show("jf_pitchbend_"..i)
  else
    params:hide("jf_params_"..i)
    params:hide("jf_mode_"..i)
    params:hide("jf_voice_"..i)
    params:hide("jf_amp_"..i)
    params:hide("jf_pitchbend_"..i)
  end
  _menu.rebuild_params()
  dirtyscreen = true
end

function kit_mode_menu()
  if kit_mode == 2 then
    pageNum = 1
    params:show("kit_out_device")
    params:show("kit_root_note")
    params:show("kit_midi_channel")
    params:show("kit_note_velocity")
  else
    params:hide("kit_out_device")
    params:hide("kit_root_note")
    params:hide("kit_midi_channel")
    params:hide("kit_note_velocity")
    params:set("kit_root_note", 12)
    params:set("kit_octaves", 0)
  end
  _menu.rebuild_params()
  dirtyscreen = true
end

function kit_mod_menu()
  if kit_mod_keys == 2 then
    params:hide("kit_clear_mutes")
    for i = 1, 4 do
      params:show("kit_cc_bank_"..i)
      for n = 1, 2 do
        local name = {"A", "B"}
        params:show("kit_cc_num_"..name[n].."_"..i)
        params:show("kit_cc_min_"..name[n].."_"..i)
        params:show("kit_cc_max_"..name[n].."_"..i)
      end
    end
  else
    params:show("kit_clear_mutes")
    for i = 1, 4 do
      params:hide("kit_cc_bank_"..i)
      for n = 1, 2 do
        local name = {"A", "B"}
        params:hide("kit_cc_num_"..name[n].."_"..i)
        params:hide("kit_cc_min_"..name[n].."_"..i)
        params:hide("kit_cc_max_"..name[n].."_"..i)
      end
    end
  end
  _menu.rebuild_params()
  dirtyscreen = true
end

function show_banner()
  local banner = {
    {1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1},
    {1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1},
    {1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1},
    {1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1},
  }
  local hi = GRIDSIZE == 256 and 7 or 3
  local lo = GRIDSIZE == 256 and 10 or 6
  g:all(0)
  for x = 1, 16 do
    for y = hi, lo do
      g:led(x, y, banner[y - hi + 1][x] * 5)
    end
  end
  g:refresh()
end

function cleanup()
  clear_all_notes()
  show_banner()
  crow.ii.jf.mode(0)
end
