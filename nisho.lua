-- nisho v2.0.0b @sonocircuit
-- llllllll.co/t/nisho
--
--   six voices & eight patterns
--        for performance
--                &
--           composition
--

engine.name = "Nisho"

local fs = require 'fileselect'
local mu = require 'musicutil'
local lt = require 'lattice'
local vx = require 'voice'

local polyform = include 'lib/nsh_polyform'
local reflect = include 'lib/nsh_reflection'
local midim = include 'lib/nsh_midiimport'
local grd = include 'lib/nsh_grid'
local fx = include 'lib/nsh_fx'
local nb = include 'lib/nb/lib/nb'

drmfm = include 'lib/nsh_drmfm'
caw = include 'lib/nsh_crow'


-------- variables -------
-- user variables
local load_pset = false
local load_tempo = true
local rotate_grid = false
local rytm_mode = false

-- constants
NUM_VOICES = 6

-- ui variables
ui = {}
ui.autofocus = false
ui.timer = nil
ui.shift = false
ui.page = 1
ui.num_pages = 4
ui.voice_focus = 1
ui.pset_focus = 1
ui.kit_focus = 1
ui.kit_action = 1

ui.keyquant_view = false
ui.pattern_view = false
ui.preset_view = false
ui.keyedit_view = false
ui.prgchg_view = false
ui.import_view = false
ui.trigs_view = false
ui.kit_view = false
ui.kit_options = false

ui.iso_y = 4

ui.msg = ""
ui.msg_timer = nil

ui.popup_view = false
ui.popup_msg = ""
ui.popup_yfunc = nil
ui.popup_nfunc = nil
ui.popup_yargs = {}
ui.popup_nargs = {}

screenredrawtimer = nil
hardwareredrawtimer = nil
dirtyscreen = false
dirtygrid = false

-- key viz
viz = {}
viz.metro = false
viz.bar = false
viz.beat = false
viz.key_fast = 8
viz.key_mid = 4
viz.key_slow = 4

-- voices
voice = {}
voice.int = 1
voice.keys = 1
voice.strum = 0
for i = 1, NUM_VOICES do
  voice[i] = {}
  voice[i].output = 1
  voice[i].note_id = {}
  voice[i].mute = false
  voice[i].sustaining = false
  voice[i].sustained = {}
  voice[i].keys_option = 1
  voice[i].velocity = 100
  voice[i].midi_ch = i
end

-- drum keys
drm = {}
drm.root = 0
drm.vel = 100
drm.vel_hi = 100
drm.vel_mid = 64
drm.vel_lo = 32

-- notes
notes = {}
notes.names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
notes.last = 1
notes.home = 1
notes.scale_root = 24
notes.scale_oct = 7
notes.scale_active = 1
notes.trsp_active = false
notes.trsp_int = 0

notes.int = {}
notes.kit = {}
notes.keys = {}
notes.cmem = {}
notes.kmem = {}
notes.chrd = {}
notes.ansi = {}
notes.active = {}

notes.scale = {}
notes.int_oct = {}
notes.key_oct = {}
for i = 1, NUM_VOICES do
  notes.int_oct[i] = 0
  notes.key_oct[i] = 0
end

hrmy = {}
hrmy.config = false
hrmy.latch = false
hrmy.active = 1
hrmy.slot = {}
for i = 1, 8 do
  hrmy.slot[i] = {scale = 1, root = 12}
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

-- chords
chrd = {}
chrd.types = {"Augmented", "Diminished", "Major", "Minor", "Sus4", "Major 7", "Minor 7"}
chrd.id = {"aug", "dim", "maj", "min", "sus4", "maj7", "min7"}
chrd.idx = {3, 4, 2, 5, 6, 7, 1}
chrd.name = ""
chrd.mode = true
chrd.strm = false
chrd.inv = 1
chrd.prev_inv = 1
chrd.edit_inv = false
chrd.oct_off = 0
chrd.current = 0
chrd.strm_num = 6
chrd.strm_mode = 1
chrd.strm_skew = 0
chrd.strm_rate = 0.1
chrd.strm_drift = 0
chrd.preview = false
chrd.strm_edit = false
chrd.strm_len_edit = false
chrd.strm_mode_edit = false
chrd.strm_skew_edit = false

chrd.key = {}
chrd.viz = {}
chrd.nts = {}
for i = 1, 12 do -- root
  chrd.key[i] = {}
  chrd.viz[i] = {}
  chrd.nts[i] = {}
  for s = 1, 3 do
    chrd.key[i][s] = 0
    chrd.viz[i][s] = 0
  end
  for t = 1, 7 do -- type
    chrd.nts[i][t] = {}
    for n = 1, 4 do -- inversion
      chrd.nts[i][t][n] = {}
    end
  end
end

-- chord mem
cmem = {}
cmem.rec = false
cmem.clear = false
cmem.copying = false
cmem.copy_src = 0
cmem.active = 13
cmem.focus = 13
cmem.link = true
for i = 1, 16 do
  cmem[i] = {}
  cmem[i].notes = {}
  cmem[i].trigs = 0 -- 0 corresponds to the focused one. otherwise it can be linked to 1-8.
end

-- sequencer
seq = {}
seq.rate_ids = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
seq.rate_val = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
seq.active = false
seq.hold = false
seq.step = 0
seq.rate = 1/4
seq.notes = {}
seq.prev_notes = {}
seq.collected = {}
seq.sustained = {}
seq.config = false
seq.polyseq = false
seq.appending = false
seq.collecting = false
seq.notes_added = false

-- key repeat
rep = {}
rep.rate_ids = {"1/4", "1/8", "3/8", "1/16", "1/3", "3/16", "1/6", "1/32", "3/64", "1/12", "5/16", "3/32", "7/16", "1/24", "9/16"}
rep.rate_val = {1/4, 1/8, 3/8, 1/16, 1/3, 3/16, 1/6, 1/32, 3/64, 1/12, 5/16, 3/32, 7/16, 1/24, 9/16}
rep.active = false
rep.hold = false
rep.rate = 1/4
rep.view = false

-- trigs
trigs = {}
trigs.view_shortpress = false
trigs.view_timer = nil
trigs.edit_shortpress = false
trigs.edit_timer = nil
trigs.edit_trig = false
trigs.nudging = false
trigs.copying = false
trigs.copy_data = {}
trigs.set_end = false
trigs.pattern_reset = false
trigs.reset_mode_view = false
trigs.focus = 1
trigs.step = 0
trigs.step_focus = 1
trigs.lock = false
trigs.reset_mode = 1
trigs.ratrnd = {1, 1, 1, 2, 2, 2, 4, 1, 2, 1, 3, 4, 2, 4, 1, 3, 5, 5}
for i = 1, 8 do
  trigs[i] = {}
  trigs[i].step_max = 16
  trigs[i].pattern = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].prob = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].skip = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].vel = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].ratnum = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].ratvel = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

-- mutes (kit and drumkeys)
mute = {}
mute.edit = false
mute.all = false
mute.focus = 1
mute.active = false
mute.drm_key = {}
mute.kit_key = {}
mute.drm_group = {}
mute.kit_group = {}
for i = 1, 12 do
  mute.drm_key[i] = false
end
for i = 1, 16 do
  mute.kit_key[i] = false
end
for n = 1, 6 do
  mute.drm_group[n] = {}
  mute.kit_group[n] = {}
  for i = 1, 12 do
    mute.drm_group[n][i] = false
  end
  for i = 1, 16 do
    mute.kit_group[n][i] = false
  end
end

-- velocity
vl = {}
vl.res = 0.01
for i = 1, NUM_VOICES do
  vl[i] = {}
  vl[i].baseline = 100
  vl[i].voice = 100
  vl[i].hi = 100
  vl[i].lo = 40
  vl[i].rise = 1
  vl[i].fall = 0.5
  vl[i].value = 0
  vl[i].timer = nil
end

-- pitchbend
pb = {}
pb_res = 0.01
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
for i = 1, NUM_VOICES do
  at[i] = {}
  at[i].rise = 0.1
  at[i].fall = 0.1
  at[i].value = 0
  at[i].timer = nil
end

-- midi
local m = {}
m.in_id = 7
m.in_ch = 1
m.in_dst = 0
m.out_id = 8
m.out_ch = 1
m.tsrp_id = 9
m.rytm_id = 10
m.rytm_ch = 1
m.qnt = false
m.thru = false
for i = 1, 10 do -- 6 voices + midi in(7) + midi out(8) + transport(9) + rytm out(10)
  m[i] = midi.connect()
end

-- key quantization
quant = {}
quant.event = {}
quant.active = false
quant.rate = 1/4
quant.bar = 4

-- events
eSCALE = 1
eCHROM = 2
eDRUMS = 3
eMIDI = 4
eANSI = 5
eKIT = 6

-- output destinations
PF1 = 1 
PF2 = 2 
MID = 3
CW1 = 4
CW2 = 5
JFN = 6
WSY = 7    
NB1 = 8
NB2 = 9  

-- parameter UI
local prms = {}
prms.voice_outputs = {"polyform [mono]", "polyform [poly]", "midi", "crow [out 1+2]", "crow [out 3+4]", "crow [jf]", "crow [wsyn]", "nb [one]", "nb [two]"}
prms.voice_param = {1, 1, 1, 1, 1, 1}
prms.plymod_param = {1, 1, 1, 1, 1, 1}
prms.trigs_param = 1
prms.voice = {}
for i = 1, #prms.voice_outputs do
  prms.voice[i] = {
    ids = {},
    nms = {},
    num = 0
  }
end

prms.polyform_ids = {
  {
    "main_amp", "send_a", "mix", "saw_tune", "saw_fm_ratio", "swm_rate",  "pulse_tune", "pwm_rate", "lpf_cutoff", "lpf_env_depth",
    "hpf_cutoff", "hpf_env_depth", "attack", "sustain", "vib_freq", "vib_delay", "drift_freq", "drift_env"
  },
  {
    "drive", "send_b", "noise_mix", "saw_shape", "saw_fm_index", "swm_depth", "pulse_width", "pwm_depth", "lpf_resonance", "lpf_keytrack",
    "hpf_resonance", "hpf_keytrack", "decay", "release", "vib_depth", "vib_onset", "drift_cutoff", "drift_pan"
  },
  {
    "modwheel_amt", "mod_osc_mix", "mod_send_a", "mod_saw_shape", "mod_fm_ratio", "mod_pulse_width", "mod_cutoff_lpf", "vib_freqmod", "mod_env_curve", "mod_attack", "mod_sustain"
  },
  {
    "mod_env_amp", "mod_noise_level", "mod_send_b", "mod_swm_depth", "mod_fm_index", "mod_pwm_depth", "mod_cutoff_hpf", "vib_depthmod", "mod_delay", "mod_decay", "mod_release"
  }
}
prms.polyform_nms = {
  {
    "main   level", "delay   send", "mix   [saw/pulse]", "saw   tune", "fm   ratio", "shape  mod  rate",  "pulse   tune", "pwm   rate", "lpf   cutoff", "lpf   env  depth",
    "hpf   cutoff", "hpf   env  depth", "attack", "sustain", "vibrato   freq", "vibrato   delay", "freq   drift", "env   drift"
  },
  {
    "drive", "reverb   send", "noise", "wave   shape", "fm   index", "shape  mod  depth", "pulse   width", "pwm   depth", "lpf   resonance", "lpf   keytrack",
    "hpf   resonance", "hpf   keytrack", "decay", "release", "vibrato   depth", "vibrato   onset", "lpf   drift", "pan   drift"
  },
  {
    "modwheel   amt", "mix   [saw/pulse]", "delay   send", "wave   shape", "fm   ratio", "pulse   width", "lpf   cutoff", "vibrato   rate", "env   curve", "attack", "sustain"
  },
  {
    "mod   env   level", "noise", "reverb   send", "shape  mod  depth", "fm   index", "pwm   depth", "hpf   cutoff", "vibrato   depth", "env   delay", "decay", "release"
  }
}

prms.crow_ids = {
  {"v8_type", "legato", "env_amp", "env_attack", "env_sustain", "mw_depth"},
  {"pitchbend", "v8_slew", "env_shape", "env_decay", "env_release","at_depth"}
}
prms.crow_nms = {
  {"v/oct   type", "legato", "env   amplitude", "attack", "sustain", "modwheel"},
  {"pitchbend", "slew   rate", "env   shape", "decay", "release","aftertouch"}
}

prms.kit_param = {DM = 1, UW = 1, MIDI = 1}
prms.kit = {
  DM = {
    {"level", "pan", "send_a", "pitch", "decay", "mod1", "mod3", "mod5", "mod7"},
    {"dist", "pan_drift", "send_b", "tune", "decay_drift", "mod2", "mod4", "mod6", "mod8"}
  },
  UW = {
    {"level", "pan", "send_a", "uw_mode", "pitch", "mod3", "mod5", "mod7"}, 
    {"dist", "pan_drift", "send_b", "mod2", "mod1", "mod4", "mod6", "mod8",}
  },
  MIDI = {
    {"midi_device", "midi_note", "midi_ccA_num"},
    {"midi_channel", "midi_vel", "midi_ccB_num"}
  }
}
prms.kitmod_param = {DM = 1, UW = 1, MIDI = 1}
prms.kitmod = {
  DM = {
    {"model", "dist_pmc", "send_a_pmc", "mod1_pmc", "mod3_pmc", "mod5_pmc", "mod7_pmc"},
    {"choke", "decay_pmc", "send_b_pmc", "mod2_pmc", "mod4_pmc", "mod6_pmc", "mod8_pmc"}
  },
  UW = {
    {"model", "dist_pmc", "send_a_pmc", "mod1_pmc", "mod3_pmc", "mod5_pmc", "mod7_pmc"},
    {"choke", "dist_pmc", "send_b_pmc", "mod2_pmc", "mod4_pmc", "mod6_pmc", "mod8_pmc"}
  },
  MIDI = {
    {"model", "midi_ccA_pmc"},
    {"midi_mode", "midi_ccB_pmc"}
  }
}

prms.ptn_param = 1
prms.ptn_ids = {
  {"patterns_meter_", "patterns_launch_", "patterns_glb_transpose_", "patterns_alloc_"},
  {"patterns_barnum_", "patterns_playback_", "patterns_transpose_", "patterns_quantize_"}
}
prms.ptn_nms = {
  {"meter", "launch", "glb   trsp", "allocate"},
  {"length", "playback", "transpose", "quantize"}
}

prms.keys_param = 1
prms.keys_ids = {
  {"voice_out", "velocity_lo", "velocity_rise", "pitchbend_rise", "modwheel_rise", "aftertouch_rise"},
  {"voice_out", "velocity_hi", "velocity_fall", "pitchbend_fall", "modwheel_fall", "aftertouch_fall"}
}
prms.keys_nms = {
  {"", "low", "rise", "rise", "rise", "rise"},
  {"", "high", "fall", "fall", "fall", "fall"}
}
prms.keys_setting = {"output", "velocity", "velocity", "pitchbend", "modwheel", "aftertouch"}

prms.quant_ids = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
prms.quant_val = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}

prms.ptn_launch = {"manual", "beat", "bar"}
prms.ptn_playback = {"loop", "oneshot"}
prms.ptn_quant_ids = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/24", "1/32", "3/128", "1/48", "1/64"}
prms.ptn_quant_val = {1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}
prms.ptn_meter_ids = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
prms.ptn_meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}


function build_voice_params()
  -- polyform & crow
  for n = PF1, PF2 do
    for e = 1, 4 do
      prms.voice[n].ids[e] = {}
      prms.voice[n].nms[e] = {}
      for i, v in ipairs(prms.polyform_ids[e]) do
        prms.voice[n].ids[e][i] = "polyform_"..v.."_"..n 
      end
      for i, v in ipairs(prms.polyform_nms[e]) do
        prms.voice[n].nms[e][i] = v
      end
    end
    for e = 1, 2 do
      prms.voice[n + 3].ids[e] = {}
      prms.voice[n + 3].nms[e] = {}
      for i, v in ipairs(prms.crow_ids[e]) do
        prms.voice[n + 3].ids[e][i] = "crow_"..v.."_"..n 
      end
      for i, v in ipairs(prms.crow_nms[e]) do
        prms.voice[n + 3].nms[e][i] = v
      end
    end
  end
  -- midi
  prms.voice[MID].ids = {
    {"midi_device_"},
    {"midi_channel_"}
  } 
  prms.voice[MID].nms = {
      {"device"},
      {"channel"}
  }
  -- jf
  prms.voice[JFN].ids = {
    {"jf_mode", "jf_pitchbend", "jf_mono_voice", "jf_run_mode"},
    {"jf_amp", "jf_detune", "jf_poly_voices", "jf_run_voltage"}
  }
  prms.voice[JFN].nms = {
    {"mode", "pitchbend", "mono   voice", "run   mode"},
    {"level", "detune", "polyphony", "run   voltage"}
  } 
  -- wysn
  prms.voice[WSY].ids = {
    {"wysn_mode", "wsyn_curve", "wsyn_lpg_time", "wsyn_fm_index", "wsyn_fm_num"},
    {"wsyn_amp", "wsyn_ramp", "wsyn_lpg_sym", "wsyn_fm_env", "wsyn_fm_den"}
  }
  prms.voice[WSY].nms = {
    {"mode", "curve", "lpg   time", "fm   index", "fm   num", "fm   den"},
    {"level", "ramp", "lpg   sym", "fm   env", "fm   den"}
  }
end

function reset_voiceparam()
  local ptab = prms.voice[voice[ui.voice_focus].output].ids[1]
  if ptab then
    if prms.voice_param[ui.voice_focus] > #ptab then
      prms.voice_param[ui.voice_focus] = 1
    end
  end
end

function set_voice_output(i, val)
  voice[i].output = val
  p[i].prc_type = val < 3 and val or 3
  caw.manage_ii()
  reset_voiceparam()
end

function autofocus_timer()
  if ui.autofocus then
    if ui.timer ~= nil then
      clock.cancel(ui.timer)
    end
    ui.timer = clock.run(function()
      clock.sleep(20)
      ui.page = 1
      dirtyscreen = true
      ui.timer = nil
    end)
  end
end

function focus_page(page)
  if ui.autofocus then
    ui.page = page
    dirtyscreen = true
    autofocus_timer()
  else
    page_redraw(page)
  end
end

-------- patterns and events --------
function event_exec(e, n)
  if e.t == eSCALE then
    if not voice[e.i].mute then
      local ptn_trsp = n ~= nil and ptn[n].transpose or 0
      local glb_trsp = n ~= nil and (ptn[n].glb_transpose and notes.trsp_int) or 0
      local note_num = notes.scale[util.clamp(e.note + ptn_trsp + glb_trsp, 1, #notes.scale)]
      if e.action == "note_off" then
        if voice[e.i].note_id[e.note] ~= nil then
          voice_note_off(e.i, voice[e.i].note_id[e.note])
          remove_active_notes(n, e.i, voice[e.i].note_id[e.note])
          voice[e.i].note_id[e.note] = nil
        end
      elseif e.action == "note_on" then 
        voice_note_on(e.i, note_num, e.vel)
        add_active_notes(n, e.i, note_num)
        voice[e.i].note_id[e.note] = note_num
      end
    end
  elseif e.t == eCHROM then
    if not voice[e.i].mute then
      if e.action == "note_off" then
        voice_note_off(e.i, e.note)
        remove_active_notes(n, e.i, e.note)
      elseif e.action == "note_on" then
        voice_note_on(e.i, e.note, e.vel)
        add_active_notes(n, e.i, e.note)
      end
    end
  elseif e.t == eDRUMS then
    local drm_voice = (e.note % 12) + 1
    if not (voice[e.i].mute or mute.drm_key[drm_voice]) then
      voice_note_on(e.i, e.note, e.vel)
      clock.run(function()
        clock.sync(1/8)
        voice_note_off(e.i, e.note)
      end)
    end
  elseif e.t == eMIDI then
    if e.action == "note_off" then
      m[m.out_id]:note_off(e.note, 0, m.out_ch)
      remove_active_notes(n, 8, e.note)
    elseif e.action == "note_on" then    
      m[m.out_id]:note_on(e.note, e.vel, m.out_ch)
      add_active_notes(n, 8, e.note)
    end
  elseif e.t == eKIT then
    if e.action == nil then -- TODO: remove when converted patterns
      drmfm.trig(e.note, e.vel)
    elseif e.action == "note_off" then
      drmfm.stop(e.note)
      remove_active_notes(n, 7, e.note)
    elseif e.action == "note_on" then
      drmfm.trig(e.note, e.vel)
      add_active_notes(n, 7, e.note)
    end
    if m.thru then
      if e.action == "note_off" then
        m[m.out_id]:note_off(e.note, 0, m.out_ch + 6)
      elseif e.action == "note_on" then
        m[m.out_id]:note_on(e.note, e.vel, m.out_ch + 6)
      end
    end
  elseif e.t == eANSI then
    caw.ansi_trigger(e.i)
  end
end

function event_rec(e)
  if not (ptn[ptn.focus].play == 0 and e.action == "note_off") then
    local alloc = ptn[ptn.focus].alloc 
    if (alloc > 0 and e.i == alloc) or alloc == 0 then
      ptn[ptn.focus]:watch(e)
    end
  end
end

function event(e)
  if quant.active then
    table.insert(quant.event, e)
  else
    event_rec(e)
    event_exec(e)
  end
end

function event_nq(e)
  event_rec(e)
  event_exec(e)
end

function event_q_clock()
  while true do
    clock.sync(quant.rate)
    if #quant.event > 0 then
      local events = quant.event
      quant.event = {}
      for _, e in ipairs(events) do
        event_rec(e)
        event_exec(e)
      end
    end
  end
end

-- pattern players
ptn = {}
-- preset and pattern loading
ptn.midi_path = norns.state.data.."midi_files/"
ptn.data = nil
ptn.src = 1
ptn.dst = 1
ptn.remap_src = 1
ptn.remap_dst = 1
-- patterns
ptn.rec_mode = "queued"
ptn.overdub_active = false
ptn.oneshot_overdub = false
ptn.copying = false
ptn.pasting = false
ptn.duplicating = false
ptn.appending = false
ptn.copy = {state = false, pattern = nil, bank = nil}
ptn.clear = false
ptn.focus = 1
ptn.bank = 1
ptn.page = 0
ptn.rec_enabled = false
ptn.stop_all = false
ptn.stop_timer = nil
ptn.loop_set_q = 1
ptn.loop_clr_q = 4
for i = 1, 8 do
  ptn[i] = reflect.new(i)
  ptn[i].process = event_exec
  ptn[i].start_callback = function() step_one_viz(i) set_pattern_length(i) clear_active_notes(i) end
  ptn[i].start_rec_callback = function() catch_held_notes(i, "note_on") end
  ptn[i].end_of_loop_callback = function() update_pattern_bank(i) end
  ptn[i].end_of_rec_callback = function() catch_held_notes(i, "note_off") clock.run(function() clock.sleep(0.2) save_pattern_bank(i, p[i].bank) end) end
  ptn[i].end_callback = function() clear_active_notes(i) dirtygrid = true end
  ptn[i].step_callback = function() track_pattern_pos(i) end
  ptn[i].meter = 4/4
  ptn[i].barnum = 4
  ptn[i].length = 16
  ptn[i].launch = 3
  ptn[i].transpose = 0
  ptn[i].alloc = 0
  ptn[i].glb_transpose = false
  ptn[i].active_notes = {}
  for voice = 1, NUM_VOICES + 2 do
    ptn[i].active_notes[voice] = {}
  end
end

-- pattern bank slots (24 slots per player) organized as 8 banks
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
    if ptn[i].rec_enabled > 0 then
      num_enabled = num_enabled + 1
    end
  end
  return num_enabled
end

function track_pattern_pos(i)
  local size = math.floor(ptn[i].endpoint / 16)
  if ptn[i].step % size == 1 then
    local prev_pos = ptn[i].position
    ptn[i].position = math.floor((ptn[i].step) / size) + 1
    if i == ptn.focus then dirtygrid = true end
  end
end

function step_one_viz(i)
  ptn[i].pulse_key = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(1/30)
    ptn[i].pulse_key = false
    dirtygrid = true
  end)
end
 
function catch_held_notes(i, action)
  if #notes.active > 0 and not (seq.active or rep.active) then
    if ptn.rec_mode ~= "synced" and action == "note_on" then
      return
    else
      for _, note in ipairs(notes.active) do
        if voice[voice.keys].keys_option < 4 then
          local note = note + notes.trsp_int
          local e = {t = eSCALE, i = voice.keys, note = note, vel = voice[voice.keys].velocity, action = action}
          local alloc = ptn[ptn.focus].alloc 
          if (alloc > 0 and e.i == alloc) or alloc == 0 then
            ptn[i]:watch(e, ptn[i].step)
          end
        end
      end
    end
  end
end

local function table_remove(t, note)
  for k = #t, 1, -1 do
    if t[k] == note then
      table.remove(t, k)
      break
    end
  end
end

function add_active_notes(i, voice, note_num)
  if i ~= nil then
    table.insert(ptn[i].active_notes[voice], note_num)
  end
end

function remove_active_notes(i, voice, note_num)
  if i ~= nil then
    table_remove(ptn[i].active_notes[voice], note_num)
  end
end

function clear_active_notes(i)
  for voice = 1, 8 do
    if #ptn[i].active_notes[voice] > 0 and ptn[i].endpoint > 0 then
      for _, note in ipairs(ptn[i].active_notes[voice]) do
        if voice < 7 then
          voice_note_off(voice, note)
        elseif voice == 7 then
          drmfm.stop(note)
        elseif voice == 8 then
          m[m.out_id]:note_off(note, 0, m.out_ch)
        end
      end
      ptn[i].active_notes[voice] = {}
    end
  end
end

function set_pattern_length(i)
  if ptn[i].rec == 0 then
    local prev_length = ptn[i].length
    ptn[i].length = ptn[i].meter * ptn[i].barnum * 4
    if prev_length ~= ptn[i].length then
      ptn[i]:set_length(ptn[i].length)
      save_pattern_bank(i, p[i].bank)
    end
  end
end

function update_pattern_length(i)
  if ptn[i].play == 0 then
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
  p[i].loop[bank] = ptn[i].loop
  p[i].launch[bank] = ptn[i].launch
  p[i].quantize[bank] = ptn[i].quantize
  p[i].count[bank] = ptn[i].count
  p[i].event[bank] = deep_copy(ptn[i].event)
  p[i].endpoint[bank] = ptn[i].endpoint
  p[i].endpoint_init[bank] = ptn[i].endpoint_init
  p[i].barnum[bank] = ptn[i].barnum
  p[i].meter[bank] = ptn[i].meter
  p[i].length[bank] = ptn[i].length
  p[i].manual_length[bank] = ptn[i].manual_length
  page_redraw(3)
  dirtygrid = true
end

function load_pattern_bank(i, bank)
  p[i].looping = false
  ptn[i].manual_length = p[i].manual_length[bank]
  ptn[i].count = p[i].count[bank]
  ptn[i].loop = p[i].loop[bank]
  ptn[i].launch = p[i].launch[bank]
  ptn[i].quantize = p[i].quantize[bank]
  ptn[i].event = deep_copy(p[i].event[bank])
  ptn[i].endpoint = p[i].endpoint[bank]
  ptn[i].endpoint_init = p[i].endpoint_init[bank]
  ptn[i].step_min = 0
  ptn[i].step_max = p[i].endpoint[bank]
  ptn[i].barnum = p[i].barnum[bank]
  ptn[i].meter = p[i].meter[bank]
  ptn[i].length = p[i].length[bank]

  params:set("patterns_playback_"..i, ptn[i].loop == 1 and 1 or 2)
  params:set("patterns_quantize_"..i, tab.key(prms.ptn_quant_val, ptn[i].quantize))
  params:set("patterns_launch_"..i, ptn[i].launch)
  params:set("patterns_transpose_"..i, 0)
  if not ptn[i].manual_length then
    params:set("patterns_barnum_"..i, math.floor(util.clamp(ptn[i].barnum, 1, 16)))
    params:set("patterns_meter_"..i, tab.key(prms.ptn_meter_val, ptn[i].meter))
  end
  if ptn[i].play == 1 and ptn[i].count == 0 then
    ptn[i]:stop()
  end
  page_redraw(3)
  dirtygrid = true
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
    ptn[i]:clear()
  end
  show_message("pattern   cleared")
end

function update_pattern_bank(i)
  if p[i].stop or p[i].count[p[i].load] == 0 then
    if ptn[i].play == 1 then
      ptn[i]:stop()
    end
    p[i].stop = false
  end
  if p[i].load then
    p[i].bank = p[i].load
    clear_active_notes(i)
    load_pattern_bank(i, p[i].bank)
    p[i].load = nil
  end
  page_redraw(3)
end

function stop_all_patterns()
  if ptn.stop_all then
    for i = 1, 8 do
      p[i].stop = false
      ptn.stop_all = false
    end
    if ptn.stop_timer ~= nil then
      clock.cancel(ptn.stop_timer)
      ptn.stop_timer = nil
    end
  else
    ptn.stop_all = true
    for i = 1, 8 do
      if ptn[i].play == 1 then
        p[i].stop = true
      end
    end
    ptn.stop_timer = clock.run(function()
      clock.sync(quant.bar)
      for i = 1, 8 do
        if p[i].stop and ptn[i].play == 1 then
          ptn[i]:stop()
          p[i].stop = false
        end
      end
      ptn.stop_all = false
    end)
  end
  -- rytm mode
  if rytm_mode then
    m[m.rytm_id]:program_change(127, m.rytm_ch) -- send prg change to Analog Rytm -> pattern h16 is blank
  end
end

function remap_pattern_voice(i, src, dst)
  if ptn[i].count > 0 then
    local events = deep_copy(ptn[i].event)
    for s, _ in pairs(events) do
      for n, e in pairs(events[s]) do
        if e.i == src then
          ptn[i].event[s][n].i = dst
          p[i].event[p[i].bank][s][n].i = dst
        end
      end
    end
    show_message("pattern    remapped")
  end
end

function transpose_pattern(i, deg)
  if ptn[i].count > 0 then
    local events = deep_copy(ptn[i].event)
    for s, _ in pairs(events) do
      for n, e in pairs(events[s]) do
        if e.t == eSCALE then
          local new_note = util.clamp(e.note + deg, 1, #notes.scale)
          ptn[i].event[s][n].note = new_note
          p[i].event[p[i].bank][s][n].note = new_note
        end
      end
    end
    params:set("patterns_transpose_"..ptn.focus, 0)
    show_message("pattern    transposed")
  end
end

-- temp func to convert old patterns. call via maiden.
function convert_kit(i)
  if ptn[i].count > 0 then
    local events = deep_copy(ptn[i].event)
    for s, _ in pairs(events) do
      for n, e in pairs(events[s]) do
        if e.t == eKIT then
          local new_note = (e.note % 16) + 1
          ptn[i].event[s][n].note = new_note
          p[i].event[p[i].bank][s][n].note = new_note
          if e.action == nil then
            ptn[i].event[s][n].action = "note_on"
            p[i].event[p[i].bank][s][n].action = "note_on"
          end
        end
      end
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
      for i = n, #prms.ptn_meter_val do
        local new_meter = prms.ptn_meter_val[i]
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
  if #seq.notes > 0 then
    local n_len = seq.rate * 64
    for n = 1, #seq.notes do
      local s = math.floor((n - 1) * n_len + 1)
      local e = math.floor(s + n_len - 1)
      if seq.notes[n] > 0 then
        if not p[i].event[bank][s] then
          p[i].event[bank][s] = {}
        end
        if not p[i].event[bank][e] then
          p[i].event[bank][e] = {}
        end
        local note = seq.notes[n] + notes.trsp_int
        local on = {t = eSCALE, i = voice.keys, note = note, vel = voice[voice.keys].velocity, action = "note_on"}
        local off = {t = eSCALE, i = voice.keys, note = note, action = "note_off"}
        table.insert(p[i].event[bank][s], on)
        table.insert(p[i].event[bank][e], off)
        p[i].count[bank] = p[i].count[bank] + 2
      end
    end
    p[i].endpoint[bank] = #seq.notes * n_len
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
  local data = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
  for i = 1, 8 do
    for j = 1, 24 do
      p[i].loop[j] = data.ptn[i].loop[j]
      p[i].quantize[j] = data.ptn[i].quantize[j]
      p[i].count[j] = data.ptn[i].count[j]
      p[i].event[j] = deep_copy(data.ptn[i].event[j])
      p[i].endpoint[j] = data.ptn[i].endpoint[j]
      p[i].endpoint_init[j] = data.ptn[i].endpoint[j]
      p[i].meter[j] = data.ptn[i].meter[j]
      p[i].barnum[j] = data.ptn[i].barnum[j]
      p[i].length[j] = data.ptn[i].length[j]
      p[i].manual_length[j] = data.ptn[i].manual_length[j]
      p[i].prc_num[j] = data.ptn[i].prc_num[j]
      p[i].prc_option[j] = data.ptn[i].prc_option[j]
    end
    p[i].load = 1
    p[i].prc_enabled = data.ptn[i].prc_enabled
    p[i].prc_ch = data.ptn[i].prc_ch
    if ptn[i].play == 1 then
      clock.run(function()
        clock.sync(quant.bar)
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
  local data = tab.load(filename)
  ptn.data = data.ptn
  --print("loaded: "..filename)
end

function load_pattern_slot(from, to)
  if ptn.data then
    for i = 1, 8 do
      p[i].loop[to] = ptn.data[i].loop[from]
      p[i].quantize[to] = ptn.data[i].quantize[from]
      p[i].count[to] = ptn.data[i].count[from]
      p[i].event[to] = deep_copy(ptn.data[i].event[from])
      p[i].endpoint[to] = ptn.data[i].endpoint[from]
      p[i].endpoint_init[to] = ptn.data[i].endpoint[from]
      p[i].barnum[to] = ptn.data[i].barnum[from]
      p[i].meter[to] = ptn.data[i].meter[from]
      p[i].length[to] = ptn.data[i].length[from]
      p[i].manual_length[to] = ptn.data[i].manual_length[from]
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
    ptn[i]:clear()
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

function clear_kit_voice(i, vox) -- TODO: fix
  if ptn[i].count > 0 then
    local events = deep_copy(ptn[i].event)
    local num_cleared = 0
    for s, _ in pairs(events) do
      for n, e in pairs(events[s]) do
        if e.t == eKIT and e.note == vox then
          ptn[i].event[s][n] = nil
          p[i].event[p[i].bank][s][n] = nil
          num_cleared = num_cleared + 1
        end
      end
    end
    if num_cleared > 0 then
      show_message("voice  "..vox..":  cleared    "..num_cleared.."   events")
    else
      show_message("no   events   found")
    end
  end
end

function viz_program_change(i)
  p[i].prc_pulse = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(1/30)
    p[i].prc_pulse = false
    dirtygrid = true
  end)
end

function send_mutes_change(bank, beat_sync)
  if p[8].prc_enabled and p[8].prc_num[bank] ~= 0 then
    local offset = p[8].prc_option[bank] == 1 and 0 or 1/4
    clock.run(function()
      clock.sync(beat_sync, offset)
      if p[8].prc_num[bank] < 0 then
        clear_mutes()
      else
        set_mutes(p[8].prc_num[bank])
      end
      viz_program_change(8)
    end)
  end
end

function send_program_change(i, beat_sync)
  local bank = p[i].bank
  if i < 8 then
    if p[i].prc_enabled and p[i].prc_num[bank] ~= 0 then
      if (p[i].prc_option[bank] == 2 or ptn[i].play == 1) then
        if p[i].prc_type == 3 then
          m[i]:program_change(p[i].prc_num[bank] - 1, p[i].prc_ch)
        elseif p[i].prc_type < 3 then
          polyform.prc_load(p[i].prc_num[bank], p[i].prc_type)
        elseif p[i].prc_type == 4 then  
          drmfm.prc_load(p[i].prc_num[bank])
        end
      end
      viz_program_change(i)
    end
  end
end

-------- scales --------
function build_scale()
  -- build scale
  notes.scale = mu.generate_scale(notes.scale_root, notes.scale_active, 9)
  notes.scale_oct = #scale_intervals[notes.scale_active] - 1
  notes.home = tab.key(notes.scale, notes.scale_root + 36)
  notes.last = notes.home
  -- set note viz
  for i = 1, 12 do
    nv.is[i] = tab.contains(notes.scale, i + 47)
    nv.root[i] = (notes.scale_root % 12 + 1) == i
  end
  build_chords()
  dirtygrid = true
end

-- chord stuff
function clear_chord_entries(i)
  for t = 1, 7 do
    chrd.nts[i][t] = {}
  end
  for s = 1, 3 do
    chrd.viz[i][s] = 0
  end
end

function set_chord_viz(i, chord_type)
  if chord_type == "Augmented" then
    for s = 1, 3 do
      chrd.viz[i][s] = 2
    end
  elseif chord_type == "Diminished" then
    for s = 1, 2 do
      chrd.viz[i][s] = 2
    end
  elseif chord_type == "Major" then
    chrd.viz[i][1] = 9
  elseif chord_type == "Minor" then
    chrd.viz[i][2] = 9
  elseif chord_type == "Sus4" then
    chrd.viz[i][3] = 9
  elseif chord_type == "Major 7" then
    chrd.viz[i][3] = chrd.viz[i][3] == 9 and 6 or 3
  elseif chord_type == "Minor 7" then
    chrd.viz[i][3] = chrd.viz[i][3] == 9 and 6 or 3
  end
end

function build_chords()
  for i = 1, 12 do
    clear_chord_entries(i)
    local note_num = i + 23
    local cmap = mu.chord_types_for_note(note_num, notes.scale_root, notes.scale_active)
    if next(cmap) then
      for _, cm in ipairs(cmap) do
        for t, ct in ipairs(chrd.types) do
          if cm == ct then
            for n = 1, 4 do
              chrd.nts[i][t][n] = {}
              local c = mu.generate_chord(note_num, ct, n - 1)
              for pos, note in ipairs(c) do
                chrd.nts[i][t][n][pos] = tab.key(notes.scale, note)
              end
              chrd.nts[i][t].strum = {table.unpack(chrd.nts[i][t][1])}
              for add = 1, 12 do
                table.insert(chrd.nts[i][t].strum, chrd.nts[i][t].strum[add] + notes.scale_oct)
              end
            end
            set_chord_viz(i, ct)
          end
        end
      end   
    end
  end
end

-------- midi --------
function build_midi_device_list()
  midi_devices = {}
  midi_device_nms = {}
  for i = 1, #midi.vports do
    local name = midi.vports[i].name
    local id = string.len(name) > 8 and str_format(name, 8, "") or name
    table.insert(midi_devices, i..": "..id)
    table.insert(midi_device_nms, id)
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
  seq.step = 0
  trigs.step = 0
end

function stop_callback()
  for i = 1, 8 do
    ptn[i]:stop()
    p[i].stop = false
  end
  seq.active = false
  seq.step = 0
  dirtygrid = true
  clear_all_notes()
end

function clock_tempo_callback()
  fx.update_rates()
end

function midi_panic(i) -- per voice
  if i < 7 then
    m[i]:cc(123, 0, voice[i].midi_ch)
  end
end

function all_midi_panic() -- all voices
  for i = 1, NUM_VOICES do
    m[i]:cc(123, 0, voice[i].midi_ch)
  end
end

function set_midi_event_callback()
  for i = 1, 16 do
    if midi.vports[i].event == midi_events then
      midi.vports[i].event = nil
      --print("midi port "..i.." cleared")
    end
  end
  m[m.in_id].event = midi_events
end

function midi_events(data)
  local msg = midi.to_msg(data)
  if msg.type == "note_on" or msg.type == "note_off" then
    local dest = m.in_dst == 0 and msg.ch or m.in_dst
    local channel = m.in_dst == 0 and (util.wrap(dest, 1, 8)) or m.in_ch
    if msg.ch == channel then
      if m.qnt and dest ~= 7 then
        msg.note = mu.snap_note_to_array(msg.note, notes.scale)
      end
      if dest == 8 then
        local e = {t = eMIDI, i = 8, note = msg.note, vel = msg.vel, action = msg.type} event(e)
      elseif dest == 7 then
        local e = {t = eKIT, i = 7, note = (msg.note % 16 + 1), vel = msg.vel, action = msg.type} event(e)
      elseif m.qnt then
        local note = tab.key(notes.scale, msg.note) + notes.trsp_int
        local e = {t = eSCALE, i = dest, note = note, vel = msg.vel, action = msg.type} event(e)
      else
        local e = {t = eCHROM, i = dest, note = msg.note, vel = msg.vel, action = msg.type} event(e)
      end
    end
  end
end


-------- clock coroutines --------

-------- viz --------
function ledpulse_fast()
  viz.key_fast = viz.key_fast == 8 and 12 or 8
  if (ptn.rec_enabled or ptn.stop_all or mute.all) then
    dirtygrid = true
  end
end

function ledpulse_mid()
  viz.key_mid = util.wrap(viz.key_mid + 1, 4, 12)
  if (ui.trigs_view or notes.trsp_active or cmem.copy_src > 0) then
    dirtygrid = true
  end
  if ui.page == 3 and ui.shift then
    dirtyscreen = true
  end
end

function ledpulse_slow()
  viz.key_slow = util.wrap(viz.key_slow + 1, 4, 12)
  for i = 1, 8 do
    if p[i].load then
      dirtygrid = true
    end
    if ptn[i].play_queued then
      dirtygrid = true
    end
  end
  if (ptn.copy or rep.hold or seq.config or ptn.clear or ui.prgchg_view or seq.polyseq or not cmem.link) then
    dirtygrid = true
  end
end

function ledpulse_bar()
  while true do
    clock.sync(quant.bar)
    viz.bar = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(1/30)
      viz.bar = false
      dirtygrid = true
    end)
  end
end

function ledpulse_beat()
  while true do
    clock.sync(1)
    viz.beat = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(1/30)
      viz.beat = false
      dirtygrid = true
    end)
  end
end

function set_metronome(mode)
  if mode == 1 then
    if barviz then
      clock.cancel(barviz)
      barviz = nil
    end
    if beatviz then
      clock.cancel(beatviz)
      beatviz = nil
    end    
    viz.metro = false
  else
    barviz = clock.run(ledpulse_bar)
    beatviz = clock.run(ledpulse_beat)
    viz.metro = true
  end
end


-------- seq and key-repeat --------
function ratchet(rate, repeats, vel_start, vel_step, func, ...)
  local rate = rate / repeats
  local n = 0
  while n < repeats do
    local vel = vel_start + (vel_step * n)
    func(..., vel, rate)
    n = n + 1
    clock.sync(rate)
  end
end

function scale_seq(voice, note, vel, rate)
  local e = {t = eSCALE, i = voice, note = note, vel = vel, action = "note_on"} event_nq(e)
  clock.run(function()
    clock.sync(rate / 2)
    local e = {t = eSCALE, i = voice, note = note, action = "note_off"} event_nq(e)
  end)
end

function play_seq(note, vel, rate)
  local voice = voice.keys
  if seq.polyseq then
    for _, held_note in ipairs(notes.keys) do
      local note = held_note + note - seq.notes[1]
      scale_seq(voice, note, vel, rate)
    end
    if #seq.sustained > 0 then
      for _, held_note in ipairs(seq.sustained) do
        local note = held_note + note - seq.notes[1]
        scale_seq(voice, note, vel, rate)
      end
    end
  else
    scale_seq(voice, note, vel, rate)
  end
end

function run_seq()
  while true do
    clock.sync(seq.rate)
    if seq.active then
      if trigs.step >= trigs[trigs.focus].step_max then trigs.step = 0 end
      trigs.step = trigs.step + 1
      if trigs[trigs.focus].pattern[trigs.step] == 1 and #seq.notes > 0 then
        if seq.step >= #seq.notes then seq.step = 0 end
        seq.step = seq.step + 1
        if trigs[trigs.focus].prob[trigs.step] >= math.random() then
          local note = seq.notes[seq.step] + notes.trsp_int
          if seq.notes[seq.step] > 0 then
            local vel = math.floor(voice[voice.keys].velocity * trigs[trigs.focus].vel[trigs.step])
            local repeats = trigs[trigs.focus].ratnum[trigs.step]
            if repeats == 1 then
              play_seq(note, vel, seq.rate)
            else
              if repeats == 0 then repeats = trigs.ratrnd[math.random(1, #trigs.ratrnd)] end
              local vel_dif = math.floor(vel * trigs[trigs.focus].ratvel[trigs.step])
              local vel_step = math.floor(vel_dif / repeats)
              local vel_start = vel_dif > 0 and vel - vel_dif or vel
              clock.run(ratchet, seq.rate, repeats, vel_start, vel_step, play_seq, note)
            end
          end
        end
      end
      if ui.trigs_view then dirtygrid = true end
    end
  end
end

function scale_rep(notetab, vel, rate)
  local i = voice.keys
  for _, note in ipairs(notetab) do
    local note = note + notes.trsp_int
    local e = {t = eSCALE, i = i, note = note, vel = vel, action = "note_on"} event_nq(e)
    clock.run(function()
      clock.sync(rate / 2)
      local e = {t = eSCALE, i = i, note = note, action = "note_off"} event_nq(e)
    end)
  end
end

function drum_rep(notetab, vel)
  for _, note in ipairs(notetab) do
    local e = {t = eDRUMS, i = voice.keys, note = note, vel = vel} event_nq(e)
  end
end

function kit_rep(notetab, vel, rate)
  for _, note in ipairs(notetab) do
    local e = {t = eKIT, i = 7, note = note, vel = vel, action = "note_on"} event_nq(e)
  end
  clock.run(function()
    clock.sync(rate / 2)
    for _, note in ipairs(notetab) do
      local e = {t = eKIT, i = 7, note = note, action = "note_off"} event_nq(e)
    end
  end)    
end

function ansi_rep(notetab)
  for _, note in ipairs(notetab) do
    local e = {t = eANSI, i = note} event_nq(e)  
  end
end

function run_keyrepeat()
  while true do
    clock.sync(rep.rate)
    if rep.active then
      if trigs.step >= trigs[trigs.focus].step_max then trigs.step = 0 end
      trigs.step = trigs.step + 1
      if trigs[trigs.focus].pattern[trigs.step] == 1 then
        if trigs[trigs.focus].prob[trigs.step] >= math.random() then
          local vel = math.floor(voice[voice.keys].velocity * trigs[trigs.focus].vel[trigs.step])
          local repeats = trigs[trigs.focus].ratnum[trigs.step]
          if repeats == 0 then repeats = trigs.ratrnd[math.random(1, #trigs.ratrnd)] end
          -- held notes
          if #notes.active > 0 then
            local func = voice[voice.keys].keys_option < 4 and scale_rep or drum_rep
            if func == drum_rep then vel = drm.vel end
            if repeats == 1 then
              func(notes.active, vel, rep.rate)
            else
              local vel_dif = math.floor(vel * trigs[trigs.focus].ratvel[trigs.step])
              local vel_step = math.floor(vel_dif / repeats)
              local vel_start = vel_dif > 0 and vel - vel_dif or vel
              clock.run(ratchet, rep.rate, repeats, vel_start, vel_step, func, notes.active)
            end
          end
          -- sustained notes
          if voice[voice.keys].sustaining then
            if repeats == 1 then
              scale_rep(voice[voice.keys].sustained, vel, rep.rate)
            else
              local vel_dif = math.floor(vel * trigs[trigs.focus].ratvel[trigs.step])
              local vel_step = math.floor(vel_dif / repeats)
              local vel_start = vel_dif > 0 and vel - vel_dif or vel              
              clock.run(ratchet, rep.rate, repeats, vel_start, vel_step, scale_rep, voice[voice.keys].sustained)
            end
          end
          -- kit notes
          if #notes.kit > 0 then
            local kit_vel = math.floor(127 * trigs[trigs.focus].vel[trigs.step])
            if repeats == 1 then
              kit_rep(notes.kit, kit_vel, rep.rate)
            else
              local vel_dif = math.floor(kit_vel * trigs[trigs.focus].ratvel[trigs.step])
              local vel_step = math.floor(vel_dif / repeats)
              local vel_start = vel_dif > 0 and kit_vel - vel_dif or kit_vel
              clock.run(ratchet, rep.rate, repeats, vel_start, vel_step, kit_rep, notes.kit)
            end
          end
          -- ansible notes
          if #notes.ansi > 0 then
            if repeats == 1 then
              ansi_rep(notes.ansi)
            else
              clock.run(ratchet, rep.rate, repeats, vel, 0, ansi_rep, notes.ansi)
            end
          end
        end
      end
      if ui.trigs_view then dirtygrid = true end
    end
  end
end


-------- drum & kit mutes --------

function edit_drum_mutes(i)
  mute.drm_key[i] = not mute.drm_key[i]
  if mute.active then
    mute.drm_group[mute.focus][i] = mute.drm_key[i]
  end
  if rytm_mode then
    m[m.rytm_id]:cc(94, mute.drm_key[i] and 127 or 0, i)
  end
end

function edit_kit_mutes(i)
  mute.kit_key[i] = not mute.kit_key[i]
  if mute.active then
    mute.kit_group[mute.focus][i] = mute.kit_key[i]
  end
end

function set_mutes(mute_group)
  mute.focus = mute_group
  mute.active = true
  for i = 1, 16 do
    mute.kit_key[i] = mute.kit_group[mute_group][i]
  end
  for i = 1, 12 do
    mute.drm_key[i] = mute.drm_group[mute_group][i]
    if rytm_mode then
      local state = mute.drm_group[mute_group][i] and 127 or 0
      m[m.rytm_id]:cc(94, state, i)
    end
  end
end

function clear_mutes()
  mute.active = false
  for i = 1, 16 do
    mute.kit_key[i] = false
  end
  for i = 1, 12 do
    mute.drm_key[i] = false
    if rytm_mode then
      m[m.rytm_id]:cc(94, 0, i)
    end
  end
end

function mute_all(z)
  mute.all = z == 1 and true or false
  if mute.all then
    if rytm_mode then
      for i = 1, 12 do
        m[m.rytm_id]:cc(94, 127, i)
      end
    end
  else
    if mute.active then
      set_mutes(mute.focus)
    else
      clear_mutes()
    end
  end  
end

-------- velocity, pb, modwheeeel and aftertouch --------

-- velocity
function update_velocity(i, option)
  vl[i].baseline = vl[i][option]
  voice[i].velocity = vl[i].baseline
end

function set_velocity(i, val)
  voice[i].velocity = math.floor(util.linlin(0, 1, vl[i].baseline, 127, val))
  dirtygrid = true
end

function vl_ramp_up(i)
  local inc = (1 - vl[i].value) / (vl[i].rise / vl.res)
  while vl[i].value < 1 do
    vl[i].value = util.clamp(vl[i].value + inc, 0, 1)
    set_velocity(i, vl[i].value)
    clock.sleep(vl.res)
  end
end

function vl_ramp_down(i)
  local inc = vl[i].value / (vl[i].fall / vl.res)
  while vl[i].value > 0 do
    vl[i].value = util.clamp(vl[i].value - inc, 0, 1)
    set_velocity(i, vl[i].value)
    clock.sleep(vl.res)
  end
end

-- pitchbend
function pb_ramp_up(i, dir)
  local inc = (1 - pb[i].value) / (pb[i].rise / pb_res)
  while pb[i].value < 1 do
    pb[i].value = util.clamp(pb[i].value + inc, 0, 1)
    send_pitchbend(i, pb[i].value, dir)
    clock.sleep(pb_res) -- error correction: time * 0.93946
  end
end

function pb_ramp_down(i, dir)
  local inc = pb[i].value / (pb[i].fall / pb_res)
  while pb[i].value > 0 do
    pb[i].value = util.clamp(pb[i].value - inc, 0, 1)
    send_pitchbend(i, pb[i].value, dir)
    clock.sleep(pb_res)
  end
end

function send_pitchbend(i, val, dir)
  if voice[i].output == PF1 or voice[i].output == PF2 then
    polyform.set_pitchbend(voice[i].output, val * dir)
  elseif voice[i].output == MID then
    local m_val = math.floor(val * 8192)
    if dir == 1 then
      m_val = util.clamp(m_val + 8192, 0, 16383)
    else
      m_val = util.clamp(8192 - m_val, 0, 16383)
    end
    m[i]:pitchbend(m_val, voice[i].midi_ch)
  elseif voice[i].output == CW1 or voice[i].output == CW2 then
    local n = voice[i].output - CW1 + 1
    caw.crow_pitchbend(n, val, dir)
  elseif voice[i].output == JFN then
    caw.jf_pitchbend(i, val, dir)
  elseif voice[i].output == WSY then
    caw.wsyn_pitchbend(val, dir)
  elseif voice[i].output == NB1 or voice[i].output == NB2 then
    local n = voice[i].output - NB1 + 1
    local player = params:lookup_param("nb_"..n):get_player()
    player:pitch_bend(nil, val * dir)
  end
  dirtygrid = true
end

-- modwheel
function mw_ramp_up(i)
  local inc = (1 - mw[i].value) / (mw[i].rise / mw_res)
  while mw[i].value < 1 do
    mw[i].value = util.clamp(mw[i].value + inc, 0, 1)
    send_modwheel(i, mw[i].value)
    clock.sleep(mw_res)
  end
end

function mw_ramp_down(i)
  local inc = mw[i].value / (mw[i].fall / mw_res)
  while mw[i].value > 0 do
    mw[i].value = util.clamp(mw[i].value - inc, 0, 1)
    send_modwheel(i, mw[i].value)
    clock.sleep(mw_res)
  end
end

function send_modwheel(i, val)
  if voice[i].output == PF1 or voice[i].output == PF2 then
    polyform.set_modwheel(voice[i].output, val)
  elseif voice[i].output == MID then
    local m_val = math.floor(util.linlin(0, 1, 0, 127, val))
    m[i]:cc(1, m_val, voice[i].midi_ch)
  elseif voice[i].output == CW1 or voice[i].output == CW2 then
    local n = voice[i].output - CW1 + 1
    caw.crow_modwheel(n, val)
  elseif voice[i].output == NB1 or voice[i].output == NB2 then
    local n = voice[i].output - NB1 + 1
    local player = params:lookup_param("nb_"..n):get_player()
    player:modulate(val)
  end
  dirtygrid = true
end

-- aftertouch
function at_ramp_up(i)
  local inc = (1 - at[i].value) / (at[i].rise / at_res)
  while at[i].value < 1 do
    at[i].value = util.clamp(at[i].value + inc, 0, 1)
    send_aftertouch(i, at[i].value)
    clock.sleep(at_res)
  end
end

function at_ramp_down(i)
  local inc = at[i].value / (at[i].fall / at_res)
  while at[i].value > 0 do
    at[i].value = util.clamp(at[i].value - inc, 0, 1)
    send_aftertouch(i, at[i].value)
    clock.sleep(at_res)
  end
end

function send_aftertouch(i, val)
  if voice[i].output == PF1 or voice[i].output == PF2 then
    polyform.set_aftertouch(voice[i].output, val)
  elseif voice[i].output == MID then
    local m_val = math.floor(util.linlin(0, 1, 0, 127, val))
    m[i]:channel_pressure(m_val, voice[i].midi_ch)
  elseif voice[i].output == CW1 or voice[i].output == CW2 then
    local n = voice[i].output - CW1 + 1
    caw.crow_aftertouch(n, val)
  elseif voice[i].output == NB1 or voice[i].output == NB2 then
    local n = voice[i].output - NB1 + 1
    local player = params:lookup_param("nb_"..n):get_player()
    player:modulate(val)
  end
  dirtygrid = true
end

-------- playback --------
function voice_notes_on(i, note_tab)
  for _, note in ipairs(note_tab) do
    local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
    voice_note_on(i, note_num, voice[i].velocity)
  end
end

function voice_notes_off(i, note_tab)
  for _, note in ipairs(note_tab) do
    local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
    voice_note_off(i, note_num)
  end
end

function voice_note_on(i, note_num, vel)
  if (voice[i].output == PF1 or voice[i].output == PF2) then
    polyform.note_on(voice[i].output, note_num, vel)
  elseif voice[i].output == MID then
    m[i]:note_on(note_num, vel, voice[i].midi_ch)
  elseif (voice[i].output == CW1 or voice[i].output == CW2) then
    caw.crow_note_on(voice[i].output - CW1 + 1, note_num, vel)
  elseif voice[i].output == JFN then
    caw.jf_note_on(note_num, vel)
  elseif voice[i].output == WSY then
    caw.wsyn_note_on(note_num, vel)
  elseif voice[i].output == NB1 or voice[i].output == NB2 then
    local player = params:lookup_param("nb_"..(voice[i].output - NB1 + 1)):get_player()
    local vel = util.linlin(0, 127, 0, 1, (vel or 127))
    player:note_on(note_num, vel)
  end
  if m.thru then
    local channel = m.out_ch + i - 1
    m[m.out_id]:note_on(note_num, vel, channel)
  end
  nv.viz[tab.key(nv.notes, note_num % 12)] = true
  if ui.page == 1 then
    dirtyscreen = true
  end
end

function voice_note_off(i, note_num)
  if (voice[i].output == PF1 or voice[i].output == PF2) then
    polyform.note_off(voice[i].output, note_num)
  elseif voice[i].output == MID then
    m[i]:note_off(note_num, 0, voice[i].midi_ch)
  elseif (voice[i].output == CW1 or voice[i].output == CW2) then
    caw.crow_note_off(voice[i].output - CW1 + 1)
  elseif voice[i].output == JFN then
    caw.jf_note_off(i, note_num)
  elseif voice[i].output == WSY then
    caw.wsyn_note_off(note_num)
  elseif voice[i].output == NB1 or voice[i].output == NB2 then
    local player = params:lookup_param("nb_"..voice[i].output - NB1 + 1):get_player()
    player:note_off(note_num)
  end
  if m.thru then
    local channel = m.out_ch + i - 1
    m[m.out_id]:note_off(note_num, 0, channel)
  end
  nv.viz[tab.key(nv.notes, note_num % 12)] = false
  if ui.page == 1 then
    dirtyscreen = true
  end
end

function clear_held_notes(i, src)
  if #notes[src] > 0 then
    voice_notes_off(i, notes[src])
    notes[src] = {}
  end
  if src ~= "int" then notes.active = {} end
  if src == "chrd" then chrd.name = "" end
  for i = 1, 12 do
    nv.viz[i] = false
  end
end

function clear_all_notes()
  clear_held_notes(voice.int, "int")
  clear_held_notes(voice.keys, "keys")
  clear_held_notes(voice.keys, "cmem")
  clear_held_notes(voice.keys, "chrd")
  for i = 1, 8 do
    clear_active_notes(i)
  end
  nb:stop_all()
  notes.active = {}
  notes.keys = {}
  notes.int = {}
  notes.kit = {}
  notes.ansi = {}
end

function dont_panic(i)
  local voice = voice[i].output
  if voice == PF1 or voice == PF2 then
    polyform.panic(voice)
  elseif voice == MID then
    midi_panic(voice)
  elseif (voice == CW1 or voice == CW2) then
    caw.crow_panic(voice - CW1 + 1)
  elseif voice == JFN then
    caw.jf_panic()
  elseif voice == WSY then
    caw.wsyn_panic()
  elseif voice == NB1 or voice == NB2 then
    local player = params:lookup_param("nb_"..(voice - 7)):get_player()
    player:stop_all()
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

function pset_write_callback(filename, name, number)
  -- make directory
  os.execute("mkdir -p "..norns.state.data.."patterns/"..number.."/")
  -- save pattern data
  for i = 1, 8 do
    save_pattern_bank(i, p[i].bank)
  end
  -- collect data
  local pdata = {}
  pdata.nisho_v2_0 = true
  -- save patterns
  pdata.ptn = {}
  for i = 1, 8 do
    pdata.ptn[i] = {}
    pdata.ptn[i].glb_transpose = ptn[i].glb_transpose
    pdata.ptn[i].transpose = ptn[i].transpose
    pdata.ptn[i].alloc = ptn[i].alloc
    pdata.ptn[i].bank = p[i].bank
    pdata.ptn[i].loop = {}
    pdata.ptn[i].launch = {}
    pdata.ptn[i].quantize = {}
    pdata.ptn[i].count = {}
    pdata.ptn[i].event = {}
    pdata.ptn[i].endpoint = {}
    pdata.ptn[i].barnum = {}
    pdata.ptn[i].meter = {}
    pdata.ptn[i].length = {}
    pdata.ptn[i].manual_length = {}
    pdata.ptn[i].prc_enabled = p[i].prc_enabled
    pdata.ptn[i].prc_ch = p[i].prc_ch
    pdata.ptn[i].prc_num = {}
    pdata.ptn[i].prc_option = {}
    for j = 1, 24 do
      pdata.ptn[i].loop[j] = p[i].loop[j]
      pdata.ptn[i].launch[j] = p[i].launch[j]
      pdata.ptn[i].quantize[j] = p[i].quantize[j]
      pdata.ptn[i].count[j] = p[i].count[j]
      pdata.ptn[i].event[j] = deep_copy(p[i].event[j])
      pdata.ptn[i].endpoint[j] = p[i].endpoint[j]
      pdata.ptn[i].meter[j] = p[i].meter[j]
      pdata.ptn[i].barnum[j] = p[i].barnum[j]
      pdata.ptn[i].length[j] = p[i].length[j]
      pdata.ptn[i].manual_length[j] = p[i].manual_length[j]
      pdata.ptn[i].prc_num[j] = p[i].prc_num[j]
      pdata.ptn[i].prc_option[j] = p[i].prc_option[j]
    end
  end
  -- save trigs
  pdata.trigs = {}
  for i = 1, 8 do
    pdata.trigs[i] = {}
    pdata.trigs[i].max = trigs[i].step_max
    pdata.trigs[i].pattern = {table.unpack(trigs[i].pattern)}
    pdata.trigs[i].prob = {table.unpack(trigs[i].prob)}
    pdata.trigs[i].vel = {table.unpack(trigs[i].vel)}
    pdata.trigs[i].ratnum = {table.unpack(trigs[i].ratnum)}
    pdata.trigs[i].ratvel = {table.unpack(trigs[i].ratvel)}
  end
  -- save cmem
  pdata.cmem = {}
  for i = 1, 16 do
    pdata.cmem[i] = {}
    pdata.cmem[i].notes = {table.unpack(cmem[i].notes)}
    pdata.cmem[i].trigs = cmem[i].trigs
  end
  -- save mutes
  pdata.mutes_drm = deep_copy(mute.drm_group)
  pdata.mutes_kit = deep_copy(mute.kit_group)
  -- save harmony slots
  pdata.hrmy_active = hrmy.active
  pdata.hrmy_slot = deep_copy(hrmy.slot)
  -- save tempo
  pdata.tempo = params:get("clock_tempo")
  -- rebuild pset list
  build_pset_list()
  -- write data
  clock.run(function() 
    clock.sleep(0.5)
    tab.save(pdata, norns.state.data.."patterns/"..number.."/"..name.."_pattern.data")
    print("finished writing pset: "..name)
  end)
end

function pset_read_callback(filename, silent, number)
  local loaded_file = io.open(filename, "r")
  if loaded_file then
    clear_all_notes()
    io.input(loaded_file)
    local pset_id = string.sub(io.read(), 4, -1)
    io.close(loaded_file)
    -- load sesh data
    local pdata = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
    if pdata.nisho_v2_0 then
      -- load patterns
      for i = 1, 8 do
        for j = 1, 24 do
          p[i].loop[j] = pdata.ptn[i].loop[j]
          p[i].quantize[j] = pdata.ptn[i].quantize[j]
          p[i].count[j] = pdata.ptn[i].count[j]
          p[i].event[j] = deep_copy(pdata.ptn[i].event[j])
          p[i].endpoint[j] = pdata.ptn[i].endpoint[j]
          p[i].endpoint_init[j] = pdata.ptn[i].endpoint[j]
          p[i].meter[j] = pdata.ptn[i].meter[j]
          p[i].barnum[j] = pdata.ptn[i].barnum[j]
          p[i].length[j] = pdata.ptn[i].length[j]
          p[i].manual_length[j] = pdata.ptn[i].manual_length[j]
          p[i].prc_num[j] = pdata.ptn[i].prc_num[j]
          p[i].prc_option[j] = pdata.ptn[i].prc_option[j]
          p[i].launch[j] = pdata.ptn[i].launch[j]
        end
        p[i].prc_enabled = pdata.ptn[i].prc_enabled
        p[i].prc_ch = pdata.ptn[i].prc_ch
        p[i].bank = 1
        ptn.page = 0
        load_pattern_bank(i, 1)
      end
      -- load trigs
      for i = 1, 8 do
        trigs[i].step_max = pdata.trigs[i].max
        trigs[i].pattern = {table.unpack(pdata.trigs[i].pattern)}
        trigs[i].prob = {table.unpack(pdata.trigs[i].prob)}
        trigs[i].vel = {table.unpack(pdata.trigs[i].vel)}
        trigs[i].ratnum = {table.unpack(pdata.trigs[i].ratnum)}
        trigs[i].ratvel = {table.unpack(pdata.trigs[i].ratvel)}
      end
      -- load cmem
      for i = 1, 16 do
        cmem[i].notes = {table.unpack(pdata.cmem[i].notes)}
        cmem[i].trigs = pdata.cmem[i].trigs
      end
      -- load mutes
      mute.drm_group = deep_copy(pdata.mutes_drm)
      mute.kit_group = deep_copy(pdata.mutes_kit)
      -- load harmony
      hrmy.active = pdata.hrmy_active
      hrmy.slot = deep_copy(pdata.hrmy_slot)
      -- load tempo
      if load_tempo then
        params:set("clock_tempo", pdata.tempo)
      end
      fx.update_rates()
      dirtyscreen = true
      dirtygrid = true
      print("finished reading pset: "..pset_id)
    else
      print("loading old pset")
      for i = 1, 8 do
        for j = 1, 24 do
          p[i].loop[j] = pdata[i].loop[j]
          p[i].quantize[j] = pdata[i].quantize[j]
          p[i].count[j] = pdata[i].count[j]
          p[i].event[j] = deep_copy(pdata[i].event[j])
          p[i].endpoint[j] = pdata[i].endpoint[j]
          p[i].endpoint_init[j] = pdata[i].endpoint[j]
          p[i].meter[j] = pdata[i].meter[j]
          p[i].barnum[j] = pdata[i].barnum[j]
          p[i].length[j] = pdata[i].length[j]
          p[i].manual_length[j] = pdata[i].manual_length[j]
          p[i].prc_num[j] = pdata[i].prc_num[j]
          p[i].prc_option[j] = pdata[i].prc_option[j]
          if pdata[i].launch ~= nil then
            p[i].launch[j] = pdata[i].launch[j]
          else
            print("no launch data")
          end
        end
        p[i].prc_enabled = pdata[i].prc_enabled
        p[i].prc_ch = pdata[i].prc_ch
        p[i].bank = 1
        ptn.page = 0
        load_pattern_bank(i, 1)
        trigs[i].step_max = pdata[i].trigs_max
        trigs[i].pattern = {table.unpack(pdata[i].trigs_pattern)}
        if pdata[i].trigs_ratnum then
          trigs[i].ratnum = {table.unpack(pdata[i].trigs_ratnum)}
          trigs[i].ratvel = {table.unpack(pdata[i].trigs_ratvel)}
        else
          print("some trig data missing")
        end
      end
      for i = 1, 16 do
        if pdata.cmem[i].notes then
          cmem[i].notes = {table.unpack(pdata.cmem[i].notes)}
          cmem[i].trigs = pdata.cmem[i].trigs
        else
          cmem[i].notes = {table.unpack(pdata.cmem[i])}
        end
      end
      if load_tempo then
        params:set("clock_tempo", pdata.tempo)
      end
      if pdata.hrmy then
        hrmy.slot = deep_copy(pdata.hrmy)
        if pdata.hrmy_active then
          hrmy.active = pdata.hrmy_active
        else
          hrmy.active = 1
        end
      end
      fx.update_rates()
      dirtyscreen = true
      dirtygrid = true
      print("finished reading pset: "..pset_id)
    end
  end
end

function pset_delete_callback(filename, name, number)
  norns.system_cmd("rm -r "..norns.state.data.."patterns/"..number.."/")
  ui.pset_focus = 1
  build_pset_list()
  print("finished deleting pset: "..name)
end

function load_midi_files(filename, quantize)
  if filename ~= "cancel" and filename ~= "" and filename ~= ptn.midi_path then
    midim.convert_all(filename, quantize)
    show_message("midi   files   loaded")
    ui.preset_view = false
  end
end


--------------------- INIT! INNIT? -----------------------
function init()

  -- get grid size
  grd.get_size()

  -- midi import
  if util.file_exists(ptn.midi_path) == false then
    util.make_dir(ptn.midi_path)
  end

  -- detect crow
  caw.detect()
   
  -- populate scale_names table
  scale_names = {}
  for i = 1, #mu.SCALES do
    table.insert(scale_names, string.lower(mu.SCALES[i].name))
  end

  -- populate scale intervals
  scale_intervals = {}
  for i = 1, #mu.SCALES do
    scale_intervals[i] = {table.unpack(mu.SCALES[i].intervals)}
  end

  -- build stuff
  build_midi_device_list()
  build_voice_params()
  build_pset_list()
  
  -- global params
  params:add_separator("global_settings", "global")

  params:add_option("scale", "scale", scale_names, 2)
  params:set_action("scale", function(val)
    notes.scale_active = val
    hrmy.slot[hrmy.active].scale = val
    build_scale()
    page_redraw(1)
  end)

  params:add_number("notes_root_scale", "root note", 0, 24, 12, function(param) return mu.note_num_to_name(param:get() + 36, true) end)
  params:set_action("notes_root_scale", function(val)
    notes.scale_root = val
    hrmy.slot[hrmy.active].root = val
    build_scale()
    page_redraw(1)
  end)

  params:add_option("page_autofocus", "autofocus", {"off", "on"}, 2)
  params:set_action("page_autofocus", function(mode) ui.autofocus = mode == 2 and true or false end)

  params:add_group("timing", "timing", 6)
  params:add_option("metronome_viz", "metronome", {"hide", "show"}, 2)
  params:set_action("metronome_viz", function(mode) set_metronome(mode) end)

  params:add_number("time_signature", "time signature", 2, 9, 4, function(param) return param:get().."/4" end)
  params:set_action("time_signature", function(val) quant.bar = val end)
        
  params:add_option("key_quant_value", "key quantization", prms.quant_ids, 7)
  params:set_action("key_quant_value", function(idx) quant.rate = prms.quant_val[idx] * 4 end)
  
  params:add_option("key_seq_rate", "sequencer rate", seq.rate_ids, 7)
  params:set_action("key_seq_rate", function(idx) seq.rate = seq.rate_val[idx] * 4 end)

  params:add_option("ptn_loop_set_q", "set pattern loop", prms.ptn_launch, 2)
  params:set_action("ptn_loop_set_q", function(mode) ptn.loop_set_q = mode end)

  params:add_option("ptn_loop_clr_q", "clear pattern loop", prms.ptn_launch, 2)
  params:set_action("ptn_loop_clr_q", function(mode) ptn.loop_clr_q = mode end)

  -- midi i/o params
  params:add_group("global_midi_group", "midi i/o", 12)

  params:add_separator("glb_midi_in_params", "midi in")

  params:add_option("glb_midi_in_device", "midi in device", midi_devices, 1)
  params:set_action("glb_midi_in_device", function(val) m[m.in_id] = midi.connect(val) set_midi_event_callback() end)

  params:add_option("glb_midi_in_destination", "send midi to..", {"all voices", "voice 1", "voice 2", "voice 3", "voice 4", "voice 5", "voice 6", "kit", "midi out"}, 1)
  params:set_action("glb_midi_in_destination", function(dest)
    m.in_dst = dest - 1
    all_midi_panic()
    if dest > 1 then
      params:hide("glb_midi_in_channel")
    else
      params:show("glb_midi_in_channel")
    end
    _menu.rebuild_params()
  end)
  
  params:add_number("glb_midi_in_channel", "midi in channel", 1, 16, 1)
  params:set_action("glb_midi_in_channel", function(val) midi_panic(m.in_id) m.in_ch = val end)

  params:add_option("glb_midi_in_quantization", "map to scale", {"no", "yes"}, 1)
  params:set_action("glb_midi_in_quantization", function(mode) m.qnt = mode == 2 and true or false end)

  params:add_separator("glb_midi_out_params", "midi out")

  params:add_option("glb_midi_out_device", "midi out device", midi_devices, 1)
  params:set_action("glb_midi_out_device", function(val) midi_panic(m.out_id) m[m.out_id] = midi.connect(val) end)

  params:add_number("glb_midi_out_channel", "midi out channel", 1, 16, 1)
  params:set_action("glb_midi_out_channel", function(val) midi_panic(m.out_id) m.out_ch = val end)

  params:add_option("glb_midi_thru", "mirror voices", {"no", "yes"}, 1)
  params:set_action("glb_midi_thru", function(val) m.thru = val == 2 and true or false end)

  params:add_binary("glb_midi_panic", "don't panic", "trigger", 0)
  params:set_action("glb_midi_panic", function() all_midi_panic() end)

  params:add_separator("glb_midi_transport_params", "midi transport")

  params:add_option("glb_midi_transport_device", "midi device", midi_devices, 1)
  params:set_action("glb_midi_transport_device", function(val) m[m.tsrp_id] = midi.connect(val) end)


  -- keyboard settings
  params:add_group("keyboard_group", "kb options", 14)

  params:add_separator("scale_keys", "scale keys")

  params:add_number("scale_keys_y", "degree [y]", 1, 6, 4)
  params:set_action("scale_keys_y", function(val) ui.iso_y = val - 1 dirtygrid = true end)

  params:add_separator("chord_keys", "chord keys")

  params:add_number("strm_length", "strum length", 4, 12, 6, function(param) return round_form((param:get()), 1," notes") end)
  params:set_action("strm_length", function(val) chrd.strm_num = val end)

  params:add_option("strm_mode", "strum mode", {"up", "alt lo", "random", "alt hi", "down"}, 1)
  params:set_action("strm_mode", function(val) chrd.strm_mode = val end)

  params:add_number("strm_rate", "strum rate", 10, 100, 70, function(param) return round_form((1 / chrd.strm_rate), 0.01,"hz") end)
  params:set_action("strm_rate", function(val) chrd.strm_rate = (110 - val) / 200 end)

  params:add_number("strm_skew", "strum skew", -30, 30, 0, function(param) return round_form((util.linlin(-30, 30, -100, 100, param:get())), 1,"%") end)
  params:set_action("strm_skew", function(val) chrd.strm_skew = val end)

  params:add_number("strm_drift", "strum drift", 0, 100, 0, function(param) return round_form(param:get(), 1,"%") end)
  params:set_action("strm_drift", function(val) chrd.strm_drift = val / 10000 end)

  params:add_separator("drum_keys", "drum keys")
  params:add_number("drum_root", "drumpad root note", 0, 127, 0, function(param) return mu.note_num_to_name(param:get(), true) end)
  params:set_action("drum_root", function(val) drm.root = val end)

  params:add_number("drum_vel_hi", "hi velocity", 1, 127, 100)
  params:set_action("drum_vel_hi", function(val) drm.vel_hi = val end)

  params:add_number("drum_vel_mid", "mid velocity", 1, 127, 64)
  params:set_action("drum_vel_mid", function(val) drm.vel_mid = val end)

  params:add_number("drum_vel_lo", "lo velocity", 1, 127, 32)
  params:set_action("drum_vel_lo", function(val) drm.vel_lo = val end)

  params:add_option("trigs_rst_mode", "trig reset mode", {"manual", "lock", "beat", "bar"}, 1)
  params:set_action("trigs_rst_mode", function(mode) trigs.reset_mode = mode end)
  params:hide("trigs_rst_mode")

  -- rytm params
  params:add_group("rytm_params", "rytm settings", 2)
  if not rytm_mode then params:hide("rytm_params") end

  params:add_option("rytm_out_device", "rytm out device", midi_devices, 2)
  params:set_action("rytm_out_device", function(val) m[m.rytm_id] = midi.connect(val) end)

  params:add_number("rytm_out_channel", "rytm out channel", 1, 16, 16)
  params:set_action("rytm_out_channel", function(val) m.rytm_ch = val end)

  -- octave params
  params:add_group("octave_params", "octaves", 13)
  params:hide("octave_params")

  params:add_number("strum_octaves", "strum octaves", -3, 3, 0)
  params:set_action("strum_octaves", function(val) chrd.oct_off = val end)

  for i = 1, NUM_VOICES do
    params:add_number("interval_octaves_"..i, "interval octaves", -3, 3, 0)
    params:set_action("interval_octaves_"..i, function(val) notes.int_oct[i] = val end)

    params:add_number("keys_octaves_"..i, "keys octaves", -3, 3, 0)
    params:set_action("keys_octaves_"..i, function(val) notes.key_oct[i] = val end)
  end

  -- patterns params
  params:add_group("pattern_parameters", "pattern parameters", 64)
  params:hide("pattern_parameters")
  for i = 1, 8 do
  
    params:add_option("patterns_playback_"..i, "playback", prms.ptn_playback, 1)
    params:set_action("patterns_playback_"..i, function(mode)
      ptn[i].loop = mode == 1 and 1 or 0
      p[i].loop[p[i].bank] = ptn[i].loop
    end)

    params:add_option("patterns_quantize_"..i, "quantize", prms.ptn_quant_ids, 13)
    params:set_action("patterns_quantize_"..i, function(idx)
      ptn[i].quantize = prms.ptn_quant_val[idx]
      p[i].quantize[p[i].bank] = ptn[i].quantize
    end)

    params:add_option("patterns_launch_"..i, "launch mode", prms.ptn_launch, 3)
    params:set_action("patterns_launch_"..i, function(mode)
      ptn[i].launch = mode
      p[i].launch[p[i].bank] = mode
    end)

    params:add_option("patterns_meter_"..i, "meter", prms.ptn_meter_ids, 3)
    params:set_action("patterns_meter_"..i, function(idx)
      ptn[i].meter = prms.ptn_meter_val[idx]
      p[i].meter[p[i].bank] = prms.ptn_meter_val[idx]
      update_pattern_length(i)
    end)

    params:add_number("patterns_barnum_"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("patterns_barnum_"..i, function(num)
      ptn[i].barnum = num
      p[i].barnum[p[i].bank] = num
      update_pattern_length(i)
      dirtygrid = true
    end)

    params:add_option("patterns_glb_transpose_"..i, "global transpose", {"off", "on"}, 1)
    params:set_action("patterns_glb_transpose_"..i, function(val)
      ptn[i].glb_transpose = val == 2 and true or false
    end)

    params:add_number("patterns_transpose_"..i, "transpose", -12, 12, 0, function(param) return param:get().." deg" end)
    params:set_action("patterns_transpose_"..i, function(val)
      ptn[i].transpose = val
    end)

    params:add_option("patterns_alloc_"..i, "allocate", {"free", "voice 1", "voice 2", "voice 3", "voice 4", "voice 5", "voice 6", "kit", "midi"}, 1)
    params:set_action("patterns_alloc_"..i, function(val)
      ptn[i].alloc = val - 1
    end)
  end

  -- voice params
  params:add_group("voices", "voices", 15 * NUM_VOICES)
  params:hide("voices")
  for i = 1, NUM_VOICES do
    -- output
    params:add_option("voice_out_"..i, "output", prms.voice_outputs, (i > 2 and 3 or i))
    params:set_action("voice_out_"..i, function(val) set_voice_output(i, val) end)
    -- mute
    params:add_option("voice_mute_"..i, "mute", {"off", "on"}, 1)
    params:set_action("voice_mute_"..i, function(mode) voice[i].mute = mode == 2 and true or false end)
    -- keyboard
    params:add_option("keys_option_"..i, "keyboard type", {"scale", "memory", "chords", "drums"}, 1)
    params:set_action("keys_option_"..i, function(val) voice[i].keys_option = val dirtygrid = true end)
    -- midi params
    params:add_option("midi_device_"..i, "midi device", midi_devices, 1)
    params:set_action("midi_device_"..i, function(val) m[i] = midi.connect(val) end)

    params:add_number("midi_channel_"..i, "midi channel", 1, 16, i)
    params:set_action("midi_channel_"..i, function(val) midi_panic(i) voice[i].midi_ch = val end)

    params:add_number("velocity_lo_"..i, "lo velocity", 1, 64, 64)
    params:set_action("velocity_lo_"..i, function(val) vl[i].lo = val update_velocity(i, "lo") end)

    params:add_number("velocity_hi_"..i, "hi velocity", 65, 127, 100)
    params:set_action("velocity_hi_"..i, function(val) vl[i].hi = val update_velocity(i, "hi") end)

    params:add_control("velocity_rise_"..i, "rise", controlspec.new(0.1, 10, "lin", 0.1, 1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("velocity_rise_"..i, function(val) vl[i].rise = val end)

    params:add_control("velocity_fall_"..i, "fall", controlspec.new(0.1, 10, "lin", 0.1, 0.5), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("velocity_fall_"..i, function(val) vl[i].fall = val end)

    params:add_control("pitchbend_rise_"..i, "rise", controlspec.new(0.1, 10, "lin", 0.1, 0.2), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("pitchbend_rise_"..i, function(val) pb[i].rise = val end)

    params:add_control("pitchbend_fall_"..i, "fall", controlspec.new(0.1, 10, "lin", 0.1, 0.1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("pitchbend_fall_"..i, function(val) pb[i].fall = val end)

    params:add_control("modwheel_rise_"..i, "rise", controlspec.new(0.1, 10, "lin", 0.1, 1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("modwheel_rise_"..i, function(val) mw[i].rise = val end)

    params:add_control("modwheel_fall_"..i, "fall", controlspec.new(0.1, 10, "lin", 0.1, 0.5), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("modwheel_fall_"..i, function(val) mw[i].fall = val end)

    params:add_control("aftertouch_rise_"..i, "rise", controlspec.new(0.1, 10, "lin", 0.1, 1), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("aftertouch_rise_"..i, function(val) at[i].rise = val end)

    params:add_control("aftertouch_fall_"..i, "fall", controlspec.new(0.1, 10, "lin", 0.1, 0.5), function(param) return round_form(param:get(), 0.1, "s") end)
    params:set_action("aftertouch_fall_"..i, function(val) at[i].fall = val end)
  end

  params:add_separator("sound_params", "synthesis & cv")
  -- polyform params
  polyform.init()
  
  -- crow params
  caw.init()
  
  -- ext in
  params:add_group("adc_input", "input [stereo]", 5)
  -- toggle
  params:add_option("adc_input_routing", "input > engine", {"off", "on"}, 1)
  params:set_action("adc_input_routing", function(x)
    engine.input_toggle(x - 1)
    if x == 1 then
      engine.input_set_param("level", params:get("adc_input_level"))
      engine.input_set_param("drive", params:get("adc_input_drive"))
      engine.input_set_param("sendA", params:get("adc_input_send_a"))
      engine.input_set_param("sendB", params:get("adc_input_send_b"))
    end
  end)
  -- level
  params:add_control("adc_input_level", "level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("adc_input_level", function(x) engine.input_set_param("level", x) end)
  -- drive
  params:add_control("adc_input_drive", "drive", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("adc_input_drive", function(x) engine.input_set_param("drive", x) end)
  -- send a
  params:add_control("adc_input_send_a", "delay send", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("adc_input_send_a", function(x) engine.input_set_param("sendA", x) end)
  -- send b
  params:add_control("adc_input_send_b", "reverb send", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("adc_input_send_b", function(x) engine.input_set_param("sendB", x) end)
  
  -- drmFM params
  drmfm.init()
  
  -- nb params
  params:add_group("nb_players", "nb [players]", 4)
  for i = 1, 2 do
    local name = {"[one]", "[two]"}
    nb:add_param("nb_"..i, "nb "..name[i].." player")
  end
  nb:add_player_params()
  
  -- fx
  params:add_separator("fx_params", "fx")
  fx.init()

  -- callbacks
  grid.add = grid_add_callback
  midi.add = midi_add_callback
  midi.remove = midi_remove_callback

  clock.transport.start = start_callback
  clock.transport.stop = stop_callback
  clock.tempo_change_handler = clock_tempo_callback

  params.action_write = pset_write_callback
  params.action_read = pset_read_callback
  params.action_delete = pset_delete_callback

  -- metros
  hardwareredrawtimer = metro.init(hardware_redraw, 1/30, -1)
  hardwareredrawtimer:start()
  dirtygrid = true

  screenredrawtimer = metro.init(screen_redraw, 1/30, -1)
  screenredrawtimer:start()
  dirtyscreen = true

  -- clocks
  evt_clk = clock.run(event_q_clock)
  seq_clk = clock.run(run_seq)
  rep_clk = clock.run(run_keyrepeat)

  -- lattice
  vizclock = lt:new()

  fastpulse = vizclock:new_sprocket{
    action = ledpulse_fast,
    division = 1/32,
    enabled = true
  }

  midpulse = vizclock:new_sprocket{
    action = ledpulse_mid,
    division = 1/24,
    enabled = true
  }

  slowpulse = vizclock:new_sprocket{
    action = ledpulse_slow,
    division = 1/12,
    enabled = true
  }

  vizclock:start()

  -- bang params
  if load_pset then
    params:default()
  else
    params:bang()
    drmfm.load_default()
  end

  -- set defaults
  fx.update_rates()
  p[7].prc_type = 4
  p[8].prc_type = 5
  
end

-------- norns interface --------
function key(n, z)
  if n == 1 then
    ui.shift = z == 1 and true or false
  end
  if ui.popup_view then
    if z == 1 then
      if n == 2 then
        popup_exec("no")
      elseif n == 3 then
        popup_exec("yes")
      end
    end
  elseif ui.keyquant_view then
    if n == 2 then
      if params:get("clock_source") == 3 then
        clock.link.stop()
      else
        m[m.tsrp_id]:stop()
      end
      stop_callback()
      show_message("stop")
    elseif n == 3 then
      if params:get("clock_source") == 3 then
        clock.link.start()
        show_message("> start")
        start_callback()
      else
        show_message("starting...", 10)
        clock.run(function()
          clock.sync(quant.bar)
          m[m.tsrp_id]:start()
          show_message("> start")
          start_callback()
        end)
      end
    end
  elseif ui.preset_view then
    if n == 2 and z == 1 then
      if ui.shift then
        local popy = {func = clear_all_patterns, args = {}}
        popup_set("clear   all   patterns", popy)
      else
        ui.import_view = not ui.import_view
        if ui.import_view then
          load_pattern_data(pset_list[ui.pset_focus])
        else
          ptn.data = nil
        end
      end
    end
    if ui.import_view then
      if n == 3 and z == 1 then
        if ui.shift then
          screenredrawtimer:stop()
          fs.enter(ptn.midi_path, function(filename)
            if filename ~= 'cancel' then
              local popy = {func = load_midi_files, args = {filename, true}}
              local popn = {func = load_midi_files, args = {filename, false}}
              popup_set("map   to   scale", popy, popn)
            end
            screenredrawtimer:start()
            dirtyscreen = true
          end)
          ui.shift = false
        else
          load_pattern_slot(ptn.src, ptn.dst)
          show_message("slot    loaded")
        end
      end
    else
      if n == 3 and z == 1 then
        if ui.shift then
          load_patterns(pset_list[ui.pset_focus])
          show_message("patterns    loaded")
        else
          local num = get_pset_num(pset_list[ui.pset_focus])
          params:read(num)
          show_message("pset    loaded")
        end
        ui.preset_view = false
      end
    end
  elseif ui.prgchg_view then
    -- do nothing yet
  elseif trigs.edit_trig then
    if n > 1 and z == 1 then
      local d = n == 2 and -1 or 1
      prms.trigs_param = util.wrap(prms.trigs_param + d, 1, 2)
    end
  elseif trigs.reset_mode_view then
    -- do nothing yet
  elseif ui.keyedit_view then
    if n > 1 and z == 1 then
      local d = n == 2 and -1 or 1
      prms.keys_param = util.wrap(prms.keys_param + d, 1, #prms.keys_ids[1])
    end
  elseif ui.kit_options then
    if ui.kit_action == 3 then
      if z == 0 then
        if ui.shift then
          if n == 2 then
            drmfm.save_kit()
          elseif n == 3 then
            drmfm.save_voice()
          end
          ui.shift = false
        else
          if n == 2 then
            drmfm.load_kit()
          elseif n == 3 then
            drmfm.load_voice()
          end
        end
      end
    elseif ui.kit_action == 4 then
      if drmfm.get_model(ui.kit_focus) == "UW" then
        if n == 2 and z == 1 then
          local msg = "clear   sample"
          local popy = {func = drmfm.clear_sample, args = {ui.kit_focus}}
          popup_set(msg, popy)
        elseif n == 3 and z == 1 then
          drmfm.load_sample(ui.kit_focus)
        end
      end
    end
  else
    if ui.page == 1 then
      if z == 1 and ui.shift then
        if n == 2 then
          show_message("transport   stop")
        elseif n == 3 then
          show_message("transport   start")
        end
      end
      dirtygrid = true
    elseif ui.page == 2 then
      if n > 1 and z == 1 then
        local d = n == 2 and -1 or 1
        if ui.shift then
          if prms.voice[voice[ui.voice_focus].output].ids[3] then
            prms.plymod_param[ui.voice_focus] = util.wrap(prms.plymod_param[ui.voice_focus] + d, 1, #prms.voice[voice[ui.voice_focus].output].ids[3])
          end
        else
          prms.voice_param[ui.voice_focus] = util.wrap(prms.voice_param[ui.voice_focus] + d, 1, #prms.voice[voice[ui.voice_focus].output].ids[1])
        end        
      end 
    elseif ui.page == 3 then
      if n > 1 and z == 1 then
        if ui.shift then
          if prms.ptn_param == 1 then
            if n == 2 then
              ptn[ptn.focus].manual_length = false
              ptn[ptn.focus].length = ptn[ptn.focus].meter * ptn[ptn.focus].barnum * 4
              ptn[ptn.focus]:set_length(ptn[ptn.focus].length)
              save_pattern_bank(ptn.focus, p[ptn.focus].bank)
            elseif n == 3 then
              reset_pattern_length(ptn.focus, p[ptn.focus].bank)
            end
          elseif prms.ptn_param == 2 then
            remap_pattern_voice(ptn.focus, ptn.remap_src, ptn.remap_dst)
          elseif prms.ptn_param == 3 then
            transpose_pattern(ptn.focus, ptn[ptn.focus].transpose)
          end
        else
          local d = n == 2 and -1 or 1
          prms.ptn_param = util.wrap(prms.ptn_param + d, 1, #prms.ptn_ids[1])
        end
      end
      dirtygrid = true
    elseif ui.page == 4 then
      if n > 1 and z == 1 then
        local d = n == 2 and -1 or 1
        local model = drmfm.get_model(ui.kit_focus)
        local mprms = (model == "MIDI" or model == "UW") and model or "DM"
        if ui.shift then
          prms.kitmod_param[mprms] = util.wrap(prms.kitmod_param[mprms] + d, 1, #prms.kitmod[mprms][1])
        else
          prms.kit_param[mprms] = util.wrap(prms.kit_param[mprms] + d, 1, #prms.kit[mprms][1])
        end        
      end   
    end
  end
  autofocus_timer()
  dirtyscreen = true
end

function enc(n, d)
  if n == 1 then
    ui.page = util.clamp(ui.page + d, 1, ui.num_pages)
    if ui.page == 1 then
      for i = 1, 12 do
        nv.viz[i] = false
      end
    end
  end
  if ui.popup_view then
    -- ignore
  elseif ui.keyquant_view then
    if n == 2 then
      params:delta("time_signature", d)
    elseif n == 3 then
      params:delta("key_quant_value", d)
    end
  elseif ui.preset_view then
    if ui.import_view then
      if n == 2 then
        ptn.src = util.clamp(ptn.src + d, 1, 24)
      elseif n == 3 then
        ptn.dst = util.clamp(ptn.dst + d, 1, 24)
      end
    else
      if n == 2 then
        ui.pset_focus = util.clamp(ui.pset_focus + d, 1, #pset_list)
      elseif n == 3 then
        ui.pset_focus = util.clamp(ui.pset_focus + d, 1, #pset_list)
      end
    end
  elseif ui.prgchg_view then
    if n == 2 then
      if p[ptn.focus].prc_type < 3 then
        p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, 0, 127)
      elseif p[ptn.focus].prc_type == 4 then
        p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, 0, 127)
      elseif p[ptn.focus].prc_type == 5 then
          p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, -1, 6)
      else
        if ui.shift and p[ptn.focus].prc_type == 3 then
          p[ptn.focus].prc_ch = util.clamp(p[ptn.focus].prc_ch + d, 1, 16)
        else
          p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, 0, 127)
        end
      end
    elseif n == 3 then
      p[ptn.focus].prc_option[ptn.bank] = util.clamp(p[ptn.focus].prc_option[ptn.bank] + d, 1, 2)
    end
  elseif trigs.edit_trig then
    if prms.trigs_param == 1 then
      if n == 2 then
        trigs[trigs.focus].prob[trigs.step_focus] = util.clamp(trigs[trigs.focus].prob[trigs.step_focus] + d/100, 0.01, 1)
      elseif n == 3 then
        trigs[trigs.focus].vel[trigs.step_focus] = util.clamp(trigs[trigs.focus].vel[trigs.step_focus] + d/100, 0.01, 1)
      end
    elseif prms.trigs_param == 2 then
      if n == 2 then
        trigs[trigs.focus].ratnum[trigs.step_focus] = util.clamp(trigs[trigs.focus].ratnum[trigs.step_focus] + d, 0, 8)
      elseif n == 3 then
        trigs[trigs.focus].ratvel[trigs.step_focus] = util.clamp(trigs[trigs.focus].ratvel[trigs.step_focus] + d/100, -1, 1)
      end
    end
    dirtygrid = true
  elseif trigs.reset_mode_view then
    if n > 1 then
      params:delta("trigs_rst_mode", d)
    end
  elseif ui.keyedit_view then
    if n > 1 then
      params:delta(prms.keys_ids[n - 1][prms.keys_param].."_"..voice.keys, d)
      if prms.keys_param == 1 and caw.detected() == false then
        if d > 0 and voice[voice.keys].output == CW1 then
          params:set("voice_out_"..voice.keys, 8)
        elseif d < 0 and voice[voice.keys].output == WSY then
          params:set("voice_out_"..voice.keys, 3)
        end
      end
    end
  elseif ui.kit_options then
    if n == 2 then
      ui.kit_action = util.clamp(ui.kit_action + d, 1, 4)
    elseif n == 3 then
      if ui.kit_action == 1 then
        params:delta("drmfm_perf_time", d)
      elseif ui.kit_action == 3 then
        ui.kit_focus = util.clamp(ui.kit_focus + d, 1, 16)
        params:set("drmfm_selected_voice", ui.kit_focus)
      elseif ui.kit_action == 4 then
        params:delta("drmfm_uw_sample_"..ui.kit_focus, d)
      end
    end
  elseif ui.page == 1 then
    if n == 2 then
      if hrmy.config or (ui.shift and not seq.active) then
        params:delta("scale", d)
      end
    elseif n == 3 then
      if hrmy.config or (ui.shift and not seq.active) then
        params:delta("notes_root_scale", d)
      elseif seq.active and ui.shift then
        params:delta("key_seq_rate", d)
      end
    end
  elseif ui.page == 2 then
    if n > 1 then
      local out = voice[ui.voice_focus].output
      if ui.shift and out < MID then
        local idx = prms.plymod_param[ui.voice_focus]
        params:delta(prms.voice[out].ids[n + 1][idx], d)
      elseif out < NB1 then
        local idx = prms.voice_param[ui.voice_focus]
        local param = prms.voice[out].ids[n - 1][idx]
        local s = out == 3 and ui.voice_focus or ""
        params:delta(param..s, d)
      elseif out == NB1 then
        params:delta("nb_1", d)
      elseif out == NB2 then
        params:delta("nb_2", d)
      end
    end
  elseif ui.page == 3 then
    if ui.shift then
      if prms.ptn_param == 2 then
        if n == 2 then
          ptn.remap_src = util.clamp(ptn.remap_src + d, 1, NUM_VOICES)
        elseif n == 3 then
          ptn.remap_dst = util.clamp(ptn.remap_dst + d, 1, NUM_VOICES)
        end
      end
    else
      if not (prms.ptn_focus == 1 and ((ptn.rec_mode == "free" and ptn[ptn.focus].endpoint == 0) or ptn[ptn.focus].manual_length)) and n > 1 then
        params:delta(prms.ptn_ids[n - 1][prms.ptn_param]..ptn.focus, d)
      end
    end
  elseif ui.page == 4 then
    if n > 1 then
      local model = drmfm.get_model(ui.kit_focus)
      local mprms = (model == "MIDI" or model == "UW") and model or "DM"
      if ui.shift then
        params:delta("drmfm_"..prms.kitmod[mprms][n - 1][prms.kitmod_param[mprms]].."_"..ui.kit_focus, d)
      else
        params:delta("drmfm_"..prms.kit[mprms][n - 1][prms.kit_param[mprms]].."_"..ui.kit_focus, d)
        if prms.kit_param[mprms] == 1 then
          prms.kit_param["MIDI"] = 1
          prms.kit_param["UW"] = 1
          prms.kit_param["DM"] = 1
        end
      end
    end
  end
  autofocus_timer()
  dirtyscreen = true
end

function redraw()
  screen.clear()
  screen.font_face(2)
  if ui.popup_view then
    screen.clear()
    screen.font_face(2)
    screen.font_size(8)
    screen.level(10)
    screen.move(1, 24)
    screen.line_rel(128, 0)
    screen.move(1, 41)
    screen.line_rel(128, 0)
    screen.stroke()
    screen.level(15)
    screen.move(64, 35)
    screen.text_center(ui.popup_msg)
    screen.level(4)
    screen.move(64, 60)
    screen.text_center("are   you   sure  ?")
    screen.level(15)
    screen.move(20, 60)
    screen.text_center("no   <")
    screen.move(108, 60)
    screen.text_center(">   yes")
    screen.update()
  elseif ui.keyquant_view then
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
  elseif ui.preset_view then
    screen.line_width(1)
    if ui.import_view then
      if ui.shift then
        screen.font_size(16)
        screen.level(15)
        screen.move(64, 39)
        screen.text_center("load   midi   files")
      else
        screen.font_size(8)
        screen.level(15)
        screen.move(64, 12)
        screen.text_center(pset_list[ui.pset_focus].."  -  PATTERN  SLOTS")
        screen.font_size(16)
        screen.level(4)
        screen.move(64, 39)
        screen.text_center(">")
        screen.level(15)
        screen.move(30, 39)
        screen.text_center(ptn.src)
        screen.move(98, 39)
        screen.text_center(ptn.dst)
      end
      -- actions
      screen.font_size(8)
      screen.level(4)
      screen.move(4, 60)
      screen.text("back")
      screen.level(10)
      screen.move(124, 60)
      if ui.shift then
        screen.text_right(">  select")
      else
        screen.text_right(">  import")
      end
    else
      screen.font_size(8)
      screen.level(15)
      screen.move(64, 12)
      screen.text_center(ui.shift and "PATTERNS" or "PRESET")
      -- show pset names
      if #pset_list > 0 then
        local off = get_mid(pset_list[ui.pset_focus])
        screen.level(12)
        screen.rect(64 - off, 28, off * 2 + 2, 10)
        screen.fill()
        screen.level(0)
        screen.move(64, 36)
        screen.text_center(pset_list[ui.pset_focus])
        -- list right
        if ui.pset_focus > 1 then
          screen.level(4)
          screen.move(64 - off - 14, 36)
          screen.text_right(pset_list[ui.pset_focus - 1])
        end
        -- list left
        if ui.pset_focus < #pset_list then
          screen.level(2)
          screen.move(64 + off + 14, 36)
          screen.text(pset_list[ui.pset_focus + 1])
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
      screen.text(ui.shift and "clear   all <" or "import")
      screen.level(10)
      screen.move(124, 60)
      screen.text_right(ui.shift and ">  load   all" or ">  load   pset")
    end
  elseif ui.prgchg_view then
    local launch_options = {{"play", "load"}, {"upbeat", "dnbeat"}}
    local launch_mode = p[ptn.focus].prc_option[ptn.bank]
    local num = p[ptn.focus].prc_num[ptn.bank]
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    local name = ptn.focus < 7 and "voice    "..ptn.focus or (ptn.focus == 7 and "kit" or "drm   mute")
    screen.text_center(name.."      bank   "..ptn.bank)
    -- param list
    screen.level(4)
    screen.move(30, 60)
    if ui.shift and p[ptn.focus].prc_type == 3 then 
      screen.text_center("prg    channel")
    else
      local txt = "prg    msg"
      if p[ptn.focus].prc_type < 3 then
        txt = "polyform   patch"
      elseif p[ptn.focus].prc_type == 4 then
        txt = "drmfm   kit"
      elseif p[ptn.focus].prc_type == 5 then
        txt = "mute   group"
      end
      screen.text_center(txt)
    end
    screen.move(98, 60)
    screen.text_center("launch")
    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    if ui.shift and p[ptn.focus].prc_type == 3 then 
      screen.text_center(p[ptn.focus].prc_ch)
    else
      screen.text_center(num == 0 and "off" or (num == -1 and "clear" or num))
    end
    screen.move(98, 39)
    screen.text_center(launch_options[ptn.focus == 8 and 2 or 1][launch_mode])
  elseif trigs.edit_trig then
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("step    "..trigs.step_focus)
    screen.font_size(16)
    if prms.trigs_param == 1 then
      screen.move(30, 39)
      screen.text_center(util.round(trigs[trigs.focus].prob[trigs.step_focus] * 100, 1).."%")
      screen.move(98, 39)
      screen.text_center(util.round(trigs[trigs.focus].vel[trigs.step_focus] * 100, 1).."%")
    else
      screen.move(30, 39)
      local val = trigs[trigs.focus].ratnum[trigs.step_focus]
      screen.text_center(val == 0 and "rnd" or val.."*")
      screen.move(98, 39)
      screen.text_center(util.round(trigs[trigs.focus].ratvel[trigs.step_focus] * 100, 1).."%")
    end
    screen.font_size(8)
    screen.level(4)
    if prms.trigs_param == 1 then
      screen.move(30, 60)
      screen.text_center("probability")
      screen.move(98, 60)
      screen.text_center("velocity")
    else
      screen.move(30, 60)
      screen.text_center("repeats")
      screen.move(98, 60)
      screen.text_center("fade   curve")
    end
    -- param page
    for i = 1, 2 do
      screen.level(i == prms.trigs_param and 8 or 1)
      screen.pixel(127, 32 - 2 + (i - 1) * 2)
      screen.fill()
    end
  elseif trigs.reset_mode_view then
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("trig   reset")
    screen.font_size(16)
    screen.move(64, 39)
    screen.text_center(params:string("trigs_rst_mode"))
    screen.font_size(8)
    screen.level(4)
    screen.move(64, 60)
    screen.text_center("mode")
  elseif ui.keyedit_view then
    local param1 = prms.keys_ids[1][prms.keys_param].."_"..voice.keys
    local param2 = prms.keys_ids[2][prms.keys_param].."_"..voice.keys
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 12)
    screen.text_center("voice "..ui.voice_focus.." - "..prms.keys_setting[prms.keys_param])
    if param1 == param2 then
      -- param names
      screen.level(4)
      screen.move(64, 60)
      screen.text_center(prms.keys_nms[1][prms.keys_param])
      -- param values
      screen.font_size(16)
      screen.level(15)
      screen.move(64, 39)
      screen.text_center(params:string(param1))
    else
      -- param names
      screen.level(4)
      screen.move(30, 60)
      screen.text_center(prms.keys_nms[1][prms.keys_param])
      screen.move(98, 60)
      screen.text_center(prms.keys_nms[2][prms.keys_param])
      -- param values
      screen.font_size(16)
      screen.level(15)
      screen.move(30, 39)
      screen.text_center(params:string(param1))
      screen.move(98, 39)
      screen.text_center(params:string(param2))
    end
    -- param page
    local nprm = #prms.keys_ids[1]
    if nprm > 1 then
      for i = 1, nprm do
        screen.level(i == prms.keys_param and 8 or 1)
        screen.pixel(127, 32 - nprm + (i - 1) * 2)
        screen.fill()
      end
    end
  elseif ui.kit_options then
    if ui.kit_action == 1 then
      screen.level(15)
      screen.font_size(8)
      screen.move(64, 12)
      screen.text_center("drmFM  action:   morph")
      screen.level(4)
      screen.move(64, 60)
      screen.text_center("morph   time")
      screen.level(15)
      screen.font_size(16)
      screen.move(64, 39)
      screen.text_center(params:string("drmfm_perf_time"))
    elseif ui.kit_action == 2 then
      screen.level(15)
      screen.font_size(8)
      screen.move(64, 12)
      screen.text_center("drmFM  action:   copy")
      screen.level(4)
      screen.move(64, 39)
      if drmfm.get_copy_state() then
        screen.text_center("- ready   to   paste -")
      else
        screen.text_center("- clipboard   empty -")
      end
    elseif ui.kit_action == 3 then
      local kit_txt = drmfm.get_kit()
      local vox_txt = ui.kit_focus
      vox_txt = vox_txt == "" and " - " or vox_txt
      local kit_len = get_mid(kit_txt)
      local vox_len = get_mid(vox_txt) + 5

      screen.level(15)
      screen.font_size(8)
      screen.line_width(1)
      screen.move(64, 12)
      local action = ui.shift and "save" or "load"
      screen.text_center("drmFM  action:   "..action)

      screen.level(4)
      screen.move(64, 29)
      screen.text_center(kit_txt)
      screen.move(22, 52)
      screen.line(22, 27)
      screen.stroke()
      screen.move(21, 27)
      screen.line(64 - kit_len, 27)
      screen.stroke()

      screen.move(64, 43)
      screen.text_center(vox_txt)
      screen.move(109, 52)
      screen.line(109, 41)
      screen.stroke()
      screen.move(64 + vox_len, 41)
      screen.line(109, 41)
      screen.stroke()

      screen.level(10)
      screen.move(64, 60)
      screen.text_center("<  "..action.."  >")
      screen.move(21, 60)
      screen.text_center("kit")
      screen.move(108, 60)
      screen.text_center("voice")
    elseif ui.kit_action == 4 then
      local model = drmfm.get_model(ui.kit_focus)
      screen.level(15)
      screen.font_size(8)
      screen.move(64, 12)
      screen.text_center("drmFM  action:   samples")
      if model == "UW" then
        local info = drmfm.get_file_info(ui.kit_focus)
        screen.level(4)
        if info.name == "" then
          screen.move(64, 39)
          screen.text_center("- no  sample -")
        else
          screen.move(64, 30)
          screen.text_center(ui.kit_focus..":  "..info.name)
          screen.move(64, 42)
          screen.text_center(info.len.."s   /  "..info.ch)
        end
        screen.level(10)
        screen.move(30, 60)
        screen.text_center("clear  sample")
        screen.move(98, 60)
        screen.text_center("load  sample")
      else
        screen.level(4)
        screen.move(64, 39)
        screen.text_center("-")
      end
    end
  else
    if ui.page == 1 then
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
      if hrmy.config or (ui.shift and not seq.active) then
        screen.level(8)
        screen.font_size(8)
        screen.move(8, 58)
        screen.text(params:string("scale"))
        screen.move(110, 58)
        screen.text(params:string("notes_root_scale"))
      elseif seq.collecting and #seq.collected > 0 then
        screen.level(8)
        screen.font_size(16)
        screen.move(64, 58)
        screen.text_center("step: "..#seq.collected)
      elseif seq.active and ui.shift then
        screen.level(4)
        screen.font_size(8)
        screen.move(6, 58)
        screen.text("seq rate")
        screen.level(8)
        screen.move(122, 58)
        screen.text_right(params:string("key_seq_rate"))
      else
        screen.level(15)
        screen.font_size(8)
        screen.move(64, 58)
        screen.text_center(chrd.name)
      end
      local semitone = notes.scale[notes.trsp_int + notes.home] - notes.scale[notes.home]
      if hrmy.config then
        screen.level(15)
        screen.font_size(8)
        screen.move(64, 12)
        screen.text_center("scale   slot   "..hrmy.active)
      elseif notes.trsp_active then
        screen.level(15)
        screen.font_size(8)
        screen.move(64, 12)
        if semitone > 0 then
          screen.text_center("transpose: +"..semitone)
        else
          screen.text_center("transpose: "..semitone)
        end
      end
    elseif ui.page == 2 then
      local out = voice[ui.voice_focus].output
      local i = out == 3 and ui.voice_focus or ""
      screen.level(15)
      screen.font_size(8)
      screen.move(64, 12)
      screen.text_center("voice "..ui.voice_focus.." - "..params:string("voice_out_"..ui.voice_focus))
      if out < NB1 then
        if ui.shift and out < 3 then
          local idx = prms.plymod_param[ui.voice_focus]
          local param1 = prms.voice[out].ids[3][idx]
          local param2 = prms.voice[out].ids[4][idx]
          -- param names
          screen.level(4)
          screen.move(30, 60)
          screen.text_center(prms.voice[out].nms[3][idx])
          screen.move(98, 60)
          screen.text_center(prms.voice[out].nms[4][idx])
          -- param values
          screen.font_size(16)
          screen.level(15)
          screen.move(30, 39)
          screen.text_center(params:string(param1..i))
          screen.move(98, 39)
          screen.text_center(params:string(param2..i))
          -- param page
          local nprm = #prms.voice[out].ids[3]
          if nprm > 1 then
            for i = 1, nprm do
              screen.level(i == idx and 8 or 1)
              screen.pixel(127, 32 - nprm + (i - 1) * 2)
              screen.fill()
            end
          end
        else
          local idx = prms.voice_param[ui.voice_focus]
          local param1 = prms.voice[out].ids[1][idx]
          local param2 = prms.voice[out].ids[2][idx]
          -- param names
          screen.level(4)
          screen.move(30, 60)
          screen.text_center(prms.voice[out].nms[1][idx])
          screen.move(98, 60)
          screen.text_center(prms.voice[out].nms[2][idx])
          -- param values
          screen.font_size(16)
          screen.level(15)
          screen.move(30, 39)
          if param1 == "midi_device_" then
            local dev_id = params:get("midi_device_"..ui.voice_focus)
            screen.text_center(str_format(midi_device_nms[dev_id], 7, ""))
            screen.level(4)
            screen.font_size(8)
            screen.font_face(68)
            screen.move(30, 47)
            screen.text_center("[port:"..dev_id.."]")
            screen.level(15)
            screen.font_size(16)
            screen.font_face(2)
          else
            screen.text_center(params:string(param1..i))
          end
          screen.move(98, 39)
          if param2 == "polyform_saw_shape_1" or param2 == "polyform_saw_shape_2" then
            local width = 40
            local offset = params:get(param2) * (width/2) + (width/2)
            screen.line_width(2)
            screen.move(79, 40)
            screen.line_rel(offset, -16)
            screen.move(79 + width, 40)
            screen.line_rel(-width + offset, -16)
            screen.stroke()
          else
            screen.text_center(params:string(param2..i))
          end
          -- param page
          local nprm = #prms.voice[out].ids[1]
          if nprm > 1 then
            for i = 1, nprm do
              screen.level(i == idx and 8 or 1)
              screen.pixel(127, 32 - nprm + (i - 1) * 2)
              screen.fill()
            end
          end
        end
      else
        --local p = param:lookup_param("nb_"..out - 7)
        screen.font_size(16)
        screen.level(12)
        screen.move(64, 39)
        screen.text_center(params:string("nb_"..out - 7))
        screen.font_size(8)
        screen.level(6)
        screen.move(64, 55)
        screen.text_center("edit in params") -- TODO: populate nb_voices
      end
    elseif ui.page == 3 then
      screen.font_size(8)
      screen.level(15)
      screen.move(64, 12)
      screen.text_center("pattern   "..ptn.focus.."       bank   "..p[ptn.focus].bank)
      if ui.shift then
        if prms.ptn_param == 1 then
          local current_length = ptn[ptn.focus].meter * ptn[ptn.focus].barnum * 4
          screen.level((ptn[ptn.focus].manual_length or current_length ~= ptn[ptn.focus].length) and viz.key_mid or 2)
          screen.move(30, 60)
          screen.text_center("set")
          screen.move(98, 60)
          screen.level(ptn[ptn.focus].endpoint ~= ptn[ptn.focus].endpoint_init and viz.key_mid or 2)
          screen.text_center("reset")
          screen.font_size(16)
          screen.level(10)
          screen.move(64, 39)
          screen.text_center((ptn[ptn.focus].endpoint / 64).."  beats")
        elseif prms.ptn_param == 2 then
          screen.level(2)
          screen.move(64, 60)
          screen.text_center("remap   voice")
          screen.font_size(16)
          screen.move(64, 39)
          screen.text_center(">")
          screen.level(10)
          screen.move(30, 39)
          screen.text_center(ptn.remap_src)
          screen.move(98, 39)
          screen.text_center(ptn.remap_dst)
        elseif prms.ptn_param == 3 then
          screen.level(ptn[ptn.focus].transpose ~= 0 and viz.key_mid or 2)
          screen.move(64, 60)
          screen.text_center("transpose   pattern")
          screen.font_size(16)
          screen.level(10)
          screen.move(64, 39)
          screen.text_center(ptn[ptn.focus].transpose.."  deg")
        else
          screen.font_size(16)
          screen.level(10)
          screen.move(64, 39)
          screen.text_center("-")
        end
      else
        local param1 = prms.ptn_ids[1][prms.ptn_param]..ptn.focus
        local param2 = prms.ptn_ids[2][prms.ptn_param]..ptn.focus
        local txt1 = prms.ptn_nms[1][prms.ptn_param]
        local txt2 = prms.ptn_nms[2][prms.ptn_param]
        if txt1 == txt2 then
          screen.level(2)
          screen.move(64, 60)
          screen.text_center(txt1)
          screen.font_size(16)
          screen.level(10)
          screen.move(64, 39)
          screen.text_center(params:string(param1))
        else
          screen.level(4)
          screen.move(30, 60)
          screen.text_center(txt1)
          screen.move(98, 60)
          screen.text_center(txt2)
          local state = (ptn[ptn.focus].endpoint / 64 == ptn[ptn.focus].meter * ptn[ptn.focus].barnum * 4) and true or false
          screen.level((state or ptn[ptn.focus].manual) and 15 or 4)
          screen.font_size(16)
          screen.move(30, 39)
          if prms.ptn_param == 1 and ((ptn.rec_mode == "free" and ptn[ptn.focus].endpoint == 0) or ptn[ptn.focus].manual_length) then
            screen.text_center("-")
          else
            screen.text_center(params:string(param1))
          end
          screen.move(98, 39)
          if (prms.ptn_param == 1 and ((ptn.rec_mode == "free" and ptn[ptn.focus].endpoint == 0) or ptn[ptn.focus].manual_length)) then
            screen.text_center("-")
          else
            screen.text_center(params:string(param2))
          end
        end
        -- param page
        local nprm = #prms.ptn_ids[1]
        if nprm > 1 then
          for i = 1, nprm do
            screen.level(i == prms.ptn_param and 8 or 1)
            screen.pixel(127, 32 - nprm + (i - 1) * 2)
            screen.fill()
          end
        end
      end
    elseif ui.page == 4 then
      local model = drmfm.get_model(ui.kit_focus)
      local mprms = (model == "MIDI" or model == "UW") and model or "DM"
      local ptab = ui.shift and prms.kitmod or prms.kit
      local pid = ui.shift and prms.kitmod_param or prms.kit_param
      local ktxt = ui.shift and (pid[mprms] == 1 and "drmFM   model   " or "drmFM   morph   ") or "drmFM   voice   "
      local param1 = "drmfm_"..ptab[mprms][1][pid[mprms]].."_"..ui.kit_focus
      local param2 = "drmfm_"..ptab[mprms][2][pid[mprms]].."_"..ui.kit_focus
      screen.font_size(8)
      screen.level(15)
      screen.move(64, 12)
      screen.text_center(ktxt..ui.kit_focus.." :   "..model)
      if param1 == param2 then
        screen.level(4)
        screen.move(64, 60)
        screen.text_center(params:lookup_param(param1).name)
        screen.level(15)
        screen.font_size(16)
        screen.move(64, 39)
        screen.text_center(params:string(param1))
      else
        screen.level(4)
        screen.move(30, 60)
        screen.text_center(params:lookup_param(param1).name)
        screen.move(98, 60)
        screen.text_center(params:lookup_param(param2).name)
        screen.level(15)
        screen.font_size(16)
        screen.move(30, 39)
        screen.text_center(params:string(param1))
        screen.move(98, 39)
        screen.text_center(params:string(param2))
      end
      -- param page
      local nprm = ui.shift and #prms.kitmod[mprms][1] or #prms.kit[mprms][1]
      local idx = ui.shift and prms.kitmod_param[mprms] or prms.kit_param[mprms]
      if nprm > 1 then
        for i = 1, nprm do
          screen.level(i == idx and 8 or 1)
          screen.pixel(127, 32 - nprm + (i - 1) * 2)
          screen.fill()
        end
      end
    end
  end
  -- display messages
  if ui.msg ~= "" then
    screen.clear()
    screen.font_size(8)
    screen.line_width(1)
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(ui.msg)
  end
  screen.update()
end


-------- utilities --------
function r()
  norns.rerun()
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
    grd.redraw()
    dirtygrid = false
  end
  caw.redraw()
end

function screen_redraw()
  if dirtyscreen then
    redraw()
    dirtyscreen = false
  end
end

function page_redraw(page)
  if ui.page == page then
    dirtyscreen = true
  end
end

function grid_add_callback()
  grd.get_size()
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

function popup_set(msg, yes, no)
  ui.popup_msg = msg
  if yes then
    ui.popup_yfunc = yes.func
    ui.popup_yargs = yes.args
  end
  if no then
    ui.popup_nfunc = no.func
    ui.popup_nargs = no.args
  end
  if ui.popup_msg ~= nil then
    ui.popup_view = true
    dirtyscreen = true
  end
end

function popup_exec(choice)
  if choice == "yes" then
    if ui.popup_yfunc then
      ui.popup_yfunc(table.unpack(ui.popup_yargs))
    end
  elseif choice == "no" then
    if ui.popup_nfunc then
      ui.popup_nfunc(table.unpack(ui.popup_nargs))
    end
  end
  ui.popup_yfunc = nil
  ui.popup_nfunc = nil
  ui.popup_yargs = {}
  ui.popup_nargs = {}
  ui.popup_view = false
end

function show_message(message, dur)
  if ui.msg_timer ~= nil then
    clock.cancel(ui.msg_timer)
  end
  ui.msg_timer = clock.run(function()
    ui.msg = message
    dirtyscreen = true
    local dur = dur or string.len(message) > 20 and 1.6 or 0.8
    clock.sleep(dur)
    ui.msg = ""
    dirtyscreen = true
    ui.msg_timer = nil
  end)
end

function cleanup()
  clear_all_notes()
  grd.banner()
  crow.ii.jf[1].mode(0)
  crow.ii.jf[2].mode(0)
  vizclock:destroy()
  clock.cancel(evt_clk)
  clock.cancel(seq_clk)
  clock.cancel(rep_clk)
end
