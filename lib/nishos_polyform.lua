local polyForm = {}

local tx = require 'textentry'
local mu = require 'musicutil'
local vx = require 'voice'
local md = require 'core/mods'

local preset_path = norns.state.data.."polyform_patches"
local default_patch = norns.state.data.."polyform_patches/default.patch"

local active_ch = 1

local current_patch = {}
for i = 1, 2 do
  current_patch[i] = ""
end

local polyform_params = {
  main_amp = 0,
  pan = 0, 
  mix = 0,
  send_A = 0,
  send_B = 0,
  unison_mode = 0,
  unison_detune = 0,
  saw_tune = 0,
  saw_shape = 0,
  swm_rate = 0,
  swm_depth = 0,
  pulse_tune = 0,
  pulse_width = 0,
  pwm_rate = 0,
  pwm_depth = 0,
  noise_mix = 0,
  noise_crackle = 0,
  lpf_cutoff = 0,
  lpf_resonance = 0,
  env_lpf_depth = 0,
  hpf_cutoff = 0,
  hpf_resonance = 0,
  env_hpf_depth = 0,
  env_type = 0,
  env_curve = 0,
  attack = 0,
  decay = 0,
  sustain = 0,
  release = 0,
  mod_source = 0,
  env_mod_curve = 0,
  mod_delay = 0,
  mod_attack = 0,
  mod_decay = 0,
  mod_sustain = 0,
  mod_release = 0,
  mod_cutoff_lpf = 0,
  mod_cutoff_hpf = 0,
  mod_saw_shape = 0,
  mod_pulse_width = 0,
  mod_noise_level = 0,
  vib_freq = 0,
  vib_depth = 0,
  vib_onset = 0,
  vib_delay = 0,
  drift_freq = 0,
  drift_cutoff = 0,
  drift_env = 0,
  drift_pan = 0
}

local synthvoice = {}
for i = 1, 2 do
  local alloc_num = i == 1 and 1 or 6
  synthvoice[i] = {}
  synthvoice[i].vox = 1
  synthvoice[i].env = 1
  synthvoice[i].unison = false
  synthvoice[i].detune = 1
  synthvoice[i].count = 0
  synthvoice[i].alloc = vx.new(alloc_num, 2) -- 2 is LRU
  synthvoice[i].notes = {}
end

-- JP800 supersaw emulation based on adam szbao's thesis,
-- ported to supercollider by eric skogan and adapted by zack scholl
-- ported to lua and adapted for nisho by @sonocircuit
local function get_detune_val(x)
  local detune_val = 
  (10028.7312891634 * math.pow(11, x)) -
  (50818.8652045924 * math.pow(10, x)) +
  (111363.4808729368 * math.pow(9, x)) -
  (138150.6761080548 * math.pow(8, x)) +
  (106649.6679158292 * math.pow(7, x)) -
  (53046.9642751875 * math.pow(6, x)) +
  (17019.9518580080 * math.pow(5, x)) -
  (3425.0836591318 * math.pow(4, x)) +
  (404.2703938388 * math.pow(3, x)) -
  (24.1878824391 * math.pow(2, x)) +
  (0.6717417634 * x) +
  0.0030115596
  return detune_val
end

-- don't think it's good to call detune_curve() each time a note is triggered so we'll populate a table at init with 101 values (0 - 1).
local detune_curve = {}
local function build_detune_values()
  for i = 1, 100 do
    table.insert(detune_curve, get_detune_val(i / 100))
  end
end

-- detune array for six voices
local detune_array = {-0.11002313, -0.06288439, -0.01952356, 0.01991221, 0.06216538, 0.10745242}

local function detune_freq(voice, freq, depth)
  return freq + (freq * detune_curve[depth] * detune_array[voice] * 0.1)
end

-- display utilities
local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

local function display_params(i)
  if synthvoice[i].env == 1 then
    params:hide("polyform_sustain_"..i)
    params:hide("polyform_release_"..i)
  else
    params:show("polyform_sustain_"..i)
    params:show("polyform_release_"..i)
  end
  if params:get("polyform_mod_source_"..i) == 1 then -- mod env
    params:show("polyform_env_mod_curve_"..i)
    params:show("polyform_mod_delay_"..i)
    params:show("polyform_mod_attack_"..i)
    params:show("polyform_mod_decay_"..i)
    if synthvoice[i].env == 1 then
      params:hide("polyform_mod_sustain_"..i)
      params:hide("polyform_mod_release_"..i)
    else
      params:show("polyform_mod_sustain_"..i)
      params:show("polyform_mod_release_"..i)
    end
  else
    params:hide("polyform_env_mod_curve_"..i)
    params:hide("polyform_mod_delay_"..i)
    params:hide("polyform_mod_attack_"..i)
    params:hide("polyform_mod_decay_"..i)
    params:hide("polyform_mod_sustain_"..i)
    params:hide("polyform_mod_release_"..i)
  end
  if synthvoice[i].unison then
    params:show("polyform_unison_detune_"..i)
  else
    params:hide("polyform_unison_detune_"..i)
  end
  _menu.rebuild_params()
end

local function pan_display(param)
  local pos_right = ""
  local pos_left = ""
  if param < -0.01 then
    pos_right = ""
    pos_left = "L< "
  elseif param > 0.01 then
    pos_right = " >R"
    pos_left = ""
  else
    pos_right = "<"
    pos_left = ">"
  end
  return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
end

local function shape_display(param)
  if param < -0.01 then
    return ("ramp  "..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1)).."%")
  elseif param > 0.01 then
    return ("saw  "..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1)).."%")
  else
    return "tri"
  end
end

local function curve_display(param)
  if param < -0.01 then
    return ("exp  "..math.abs(util.round(util.linlin(-5, 5, -100, 100, param), 1)).."%")
  elseif param > 0.01 then
    return ("log  "..math.abs(util.round(util.linlin(-5, 5, -100, 100, param), 1)).."%")
  else
    return "lin"
  end
end

local function width_display(param)
  if param < 1 then
    return (util.round(1/(param), 0.01).."/1")
  elseif param > 1 then
    return ("1/"..util.round(param, 0.01))
  else
    return "1/1"
  end
end

local function mix_display(param)
  local saw = util.round(util.linlin(-1, 1, 100, 0, param), 1)
  local pulse = util.round(util.linlin(-1, 1, 0, 100, param), 1)
  return saw.."/"..pulse
end

-- load save and set
local function load_synth_patch(path, i)
  polyForm.panic(i)
  if util.file_exists(path) then
    local patch = tab.load(path)
    for k, v in pairs(patch) do
      params:set("polyform_"..k.."_"..i, v)
    end
    display_params(i)
    local name = path:match("[^/]*$")
    current_patch[active_ch] = name:gsub(".patch", "")
    print("loaded patch: "..path)
  else
    print("patch file "..path.." does not exist yet")
  end
end

local function save_synth_patch(txt)
  if txt then
    local patch = {}
    for k, v in pairs(polyform_params) do
      patch[k] = params:get("polyform_"..k.."_"..active_ch)
    end
    tab.save(patch, preset_path.."/"..txt..".patch")
    current_patch[active_ch] = txt
    params:set("polyform_load_patch_"..active_ch, preset_path.."/"..txt..".patch", true)
    print("saved patch "..preset_path.."/"..txt..".patch")
  end
end

local function set_value(i, id, val)
  local min = i == 1 and 1 or 3
  local max = i == 1 and 2 or 8
  for voice = min, max do
    id(voice, val)
  end
  page_redraw(2)
end

-- play and mute
function polyForm.note_on(synth, note_num)
  local freq = mu.note_num_to_freq(note_num)
  local offset = synth == 1 and 0 or 2
  if synthvoice[synth].unison then
    local min = synth == 1 and 1 or 3
    local max = synth == 1 and 2 or 8
    local off = synth == 1 and 2 or -2
    for voice = min, max do
      engine.trig(voice, detune_freq(voice + off, freq, synthvoice[synth].detune))
    end
    if synthvoice[synth].env == 2 then
      synthvoice[synth].count = synthvoice[synth].count + 1
    end
  elseif synthvoice[synth].env == 1 then
    synthvoice[synth].vox = util.wrap(synthvoice[synth].vox + 1, 1, (synth == 1 and 1 or 6))
    engine.trig(synthvoice[synth].vox + offset, freq)
  else
    local slot = synthvoice[synth].notes[note_num]
    if slot == nil then
      slot = synthvoice[synth].alloc:get()
      slot.count = 1
    end
    slot.on_release = function()
      engine.stop(slot.id + offset)
    end
    synthvoice[synth].notes[note_num] = slot
    engine.trig(slot.id + offset, freq)
  end
end

function polyForm.note_off(synth, note_num)
  if synthvoice[synth].env == 2 then
    if synthvoice[synth].unison then
      synthvoice[synth].count = synthvoice[synth].count - 1
      if synthvoice[synth].count <= 0 then
        polyForm.panic(synth)
      end
    else
      local slot = synthvoice[synth].notes[note_num]
      if slot ~= nil then
        synthvoice[synth].alloc:release(slot)
      end
      synthvoice[synth].notes[note_num] = nil
    end
  end
end

function polyForm.panic(synth)
  local min = synth == 1 and 1 or 3
  local max = synth == 1 and 2 or 8
  for n = min, max do
    engine.stop(n)
  end
  synthvoice[synth].count = 0
end

-- initialize
function polyForm.init()
  -- make directory and copy files
  if util.file_exists(preset_path) == false then
    util.make_dir(preset_path)
    os.execute('cp '.. norns.state.path .. 'lib/polyform_patches/*.patch '.. preset_path)
  end
  -- populate detune table
  build_detune_values()
  -- synth groups one and six (voices 1-2 and 3-8)  
  for i = 1, 2 do
    local name = i == 1 and "mono" or "poly"

    params:add_group("polyform_synth_"..i, "polyform ["..name.."]", 65)

    params:add_separator("polyform_patches_"..i, "polyform ["..name.."]")

    params:add_file("polyform_load_patch_"..i, ">> load", default_patch)
    params:set_action("polyform_load_patch_"..i, function(path) load_synth_patch(path, i) end)

    params:add_trigger("polyform_save_patch_"..i, "<< save")
    params:set_action("polyform_save_patch_"..i, function() active_ch = i tx.enter(save_synth_patch, current_patch[i]) end)

    params:add_separator("polyform_levels_"..i, "levels")
    -- main amp
    params:add_control("polyform_main_amp_"..i, "main level", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_main_amp_"..i, function(x) set_value(i, engine.main_amp, x) end)
    -- pan
    params:add_control("polyform_pan_"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0), function(param) return pan_display(param:get()) end)
    params:set_action("polyform_pan_"..i, function(x) set_value(i, engine.pan, x) end)
    -- send a
    params:add_control("polyform_send_A_"..i, "send a", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_send_A_"..i, function(x) set_value(i, engine.sendA, x) end)
    if not md.is_loaded("fx") then params:hide("polyform_send_A_"..i) end
    -- send b
    params:add_control("polyform_send_B_"..i, "send b", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_send_B_"..i, function(x) set_value(i, engine.sendB, x) end)
    if not md.is_loaded("fx") then params:hide("polyform_send_B_"..i) end

    params:add_separator("polyform_voice_"..i, "voice")
    -- unison mode
    params:add_option("polyform_unison_mode_"..i, "unison", {"off", "on"}, 1)
    params:set_action("polyform_unison_mode_"..i, function(mode) synthvoice[i].unison = mode == 2 and true or false display_params(i) polyForm.panic(i) end)
    -- detune amt
    params:add_number("polyform_unison_detune_"..i, "detune", 1, 100, 1, function(param) return round_form(param:get(), 1, "%") end)
    params:set_action("polyform_unison_detune_"..i, function(x) synthvoice[i].detune = x end)
    -- pitchbend range
    params:add_number("polyform_ptichbend_range_"..i, "pitchbend", 0, 24, 7, function(param) return param:get().."st" end)
    params:set_action("polyform_ptichbend_range_"..i, function(x) set_value(i, engine.pb_range, x) end)
    -- osc mix
    params:add_control("polyform_mix_"..i, "mix [saw/pulse]", controlspec.new(-1, 1, "lin", 0, -0.75), function(param) return mix_display(param:get()) end)
    params:set_action("polyform_mix_"..i, function(x) set_value(i, engine.mix_osc_level, x) end)

    params:add_separator("polyform_saw_"..i, "saw osc")
    -- saw tune
    params:add_control("polyform_saw_tune_"..i, "tune", controlspec.new(-24, 24, "lin", 0, 0, "", 1/480), function(param) return (round_form(param:get(), 0.01, "st")) end)
    params:set_action("polyform_saw_tune_"..i, function(x) set_value(i, engine.saw_tune, x) end)
    -- saw shape
    params:add_control("polyform_saw_shape_"..i, "wave shape", controlspec.new(-1, 1, "lin", 0, -0.8), function(param) return shape_display(param:get()) end)
    params:set_action("polyform_saw_shape_"..i, function(x) set_value(i, engine.saw_shape, util.linlin(-1, 1, 0, 1, x)) end)
    -- swm speed
    params:add_control("polyform_swm_rate_"..i, "shape mod rate", controlspec.new(0.2, 20, "exp", 0.01, 2.2), function(param) return round_form(param:get(), 0.01, " hz") end)
    params:set_action("polyform_swm_rate_"..i, function(x) set_value(i, engine.saw_mod_freq, x) end)
    -- swm depth
    params:add_control("polyform_swm_depth_"..i, "shape mod depth", controlspec.new(0, 0.5, "lin", 0, 0), function(param) return round_form(param:get() * 200, 1, "%") end)
    params:set_action("polyform_swm_depth_"..i, function(x) set_value(i, engine.saw_mod_depth, x) end)
    
    params:add_separator("polyform_polyform_pulse_"..i, "pulse osc")
     -- pulse tune
    params:add_control("polyform_pulse_tune_"..i, "tune", controlspec.new(-24, 24, "lin", 0, 0, "", 1/480), function(param) return round_form(param:get(), 0.01, "st") end)
    params:set_action("polyform_pulse_tune_"..i, function(x) set_value(i, engine.pulse_tune, x) end)
    -- pulse width
    params:add_control("polyform_pulse_width_"..i, "pulse width", controlspec.new(0.1, 0.9, "lin", 0, 0.5), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_pulse_width_"..i, function(x) set_value(i, engine.pulse_width, x) end)
    -- pwm speed
    params:add_control("polyform_pwm_rate_"..i, "pwm rate", controlspec.new(0.2, 20, "exp", 0.01, 2.2), function(param) return round_form(param:get(), 0.01, " hz") end)
    params:set_action("polyform_pwm_rate_"..i, function(x) set_value(i, engine.pulse_mod_freq, x) end)
    -- pwm depth
    params:add_control("polyform_pwm_depth_"..i, "pwm depth", controlspec.new(0, 0.5, "lin", 0, 0), function(param) return round_form(param:get() * 200, 1, "%") end)
    params:set_action("polyform_pwm_depth_"..i, function(x) set_value(i, engine.pulse_mod_depth, x) end)

    params:add_separator("polyform_noise_"..i, "noise")
    -- noise level
    params:add_control("polyform_noise_mix_"..i, "noise level", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_noise_mix_"..i, function(x) set_value(i, engine.mix_noise_level, x) end)
    -- noise crackle
    params:add_control("polyform_noise_crackle_"..i, "noise crackle", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_noise_crackle_"..i, function(x) set_value(i, engine.noise_crackle, x) end)
    
    params:add_separator("polyform_filter_lpf_"..i, "low pass filter")
    -- cutoff lpf
    params:add_control("polyform_lpf_cutoff_"..i, "cutoff", controlspec.new(20, 18000, "exp", 0, 1200), function(param) return round_form(param:get(), 1, " hz") end)
    params:set_action("polyform_lpf_cutoff_"..i, function(x) set_value(i, engine.cutoff_lpf, x) end)
    -- resonance lpf
    params:add_control("polyform_lpf_resonance_"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0.2), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_lpf_resonance_"..i, function(x) set_value(i, engine.res_lpf, x) end)
    -- lpf env depth
    params:add_control("polyform_env_lpf_depth_"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0.1), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_env_lpf_depth_"..i, function(x) set_value(i, engine.env_lpf_depth, x) end)
    
    params:add_separator("polyform_polyform_filter_hpf_"..i, "high pass filter")
    -- cutoff hpf
    params:add_control("polyform_hpf_cutoff_"..i, "cutoff", controlspec.new(20, 8000, "exp", 0, 20), function(param) return round_form(param:get(), 1, " hz") end)
    params:set_action("polyform_hpf_cutoff_"..i, function(x) set_value(i, engine.cutoff_hpf, x) end)
    -- resonance hpf
    params:add_control("polyform_hpf_resonance_"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_hpf_resonance_"..i, function(x) set_value(i, engine.res_hpf, x) end)
    -- hpf env depth
    params:add_control("polyform_env_hpf_depth_"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_env_hpf_depth_"..i, function(x) set_value(i, engine.env_hpf_depth, x) end)

    params:add_separator("polyform_envelope_"..i, "envelope")
    -- envelope type
    params:add_option("polyform_env_type_"..i, "env type", {"ad", "adsr"}, 1)
    params:set_action("polyform_env_type_"..i, function(mode) set_value(i, engine.env_type, mode - 1) synthvoice[i].env = mode display_params(i) polyForm.panic(i) end)
    -- curve
    params:add_control("polyform_env_curve_"..i, "curve", controlspec.new(-5, 5, "lin", 0, -4), function(param) return curve_display(param:get()) end)
    params:set_action("polyform_env_curve_"..i, function(x) set_value(i, engine.env_curve, x) end)
    -- attack
    params:add_control("polyform_attack_"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0.001), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("polyform_attack_"..i, function(x) set_value(i, engine.env_a, x) end)
    -- decay
    params:add_control("polyform_decay_"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.4), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("polyform_decay_"..i, function(x) set_value(i, engine.env_d, x) end)
    -- sustain
    params:add_control("polyform_sustain_"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.5), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_sustain_"..i, function(x) set_value(i, engine.env_s, x) end)
    -- release
    params:add_control("polyform_release_"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.8), function(param) return (round_form(param:get(), 0.01, " s")) end)
    params:set_action("polyform_release_"..i, function(x) set_value(i, engine.env_r, x) end)

    params:add_separator("polyform_mod_src_"..i, "mod source")
    -- source
    params:add_option("polyform_mod_source_"..i, "mod src", {"mod env", "aftertouch"}, 1)
    params:set_action("polyform_mod_source_"..i, function(x) set_value(i, engine.mod_source, x - 1) display_params(i) end)
    -- curve
    params:add_control("polyform_env_mod_curve_"..i, "curve", controlspec.new(-5, 5, "lin", 0, 0), function(param) return curve_display(param:get()) end)
    params:set_action("polyform_env_mod_curve_"..i, function(x) set_value(i, engine.env_mod_curve, x) end)
    -- delay
    params:add_control("polyform_mod_delay_"..i, "delay", controlspec.new(0, 5, "lin", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("polyform_mod_delay_"..i, function(x) set_value(i, engine.envmod_h, x) end)
    -- attack
    params:add_control("polyform_mod_attack_"..i, "attack", controlspec.new(0.1, 10, "exp", 0, 0.1), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("polyform_mod_attack_"..i, function(x) set_value(i, engine.envmod_a, x) end)
    -- decay
    params:add_control("polyform_mod_decay_"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.2), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("polyform_mod_decay_"..i, function(x) set_value(i, engine.envmod_d, x) end)
    -- sustain
    params:add_control("polyform_mod_sustain_"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_mod_sustain_"..i, function(x) set_value(i, engine.envmod_s, x) end)
    -- release
    params:add_control("polyform_mod_release_"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.4), function(param) return (round_form(param:get(), 0.01, " s")) end)
    params:set_action("polyform_mod_release_"..i, function(x) set_value(i, engine.envmod_r, x) end)

    params:add_separator("polyform_mod_dst_"..i, "mod destination")
    -- cutoff lpf mod
    params:add_control("polyform_mod_cutoff_lpf_"..i, "cutoff lpf mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_mod_cutoff_lpf_"..i, function(x) set_value(i, engine.env_lpf_mod, x) end)
    -- cutoff hpf mod
    params:add_control("polyform_mod_cutoff_hpf_"..i, "cutoff hpf mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_mod_cutoff_hpf_"..i, function(x) set_value(i, engine.env_hpf_mod, x) end)
    -- saw shape mod
    params:add_control("polyform_mod_saw_shape_"..i, "saw shape mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_mod_saw_shape_"..i, function(x) set_value(i, engine.saw_shape_mod, x) end)
    -- pulse width mod
    params:add_control("polyform_mod_pulse_width_"..i, "pulse width mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_mod_pulse_width_"..i, function(x) set_value(i, engine.pulse_width_mod, x) end)
    -- noise amp mod
    params:add_control("polyform_mod_noise_level_"..i, "noise level mod", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_mod_noise_level_"..i, function(x) set_value(i, engine.noise_amp_mod, x) end)

    params:add_separator("polyform_vibrato_"..i, "vibrato")
    -- vibrato rate
    params:add_control("polyform_vib_freq_"..i, "vibrato rate", controlspec.new(0.2, 20, "exp", 0, 8), function(param) return (round_form(param:get(), 0.01," hz")) end)
    params:set_action("polyform_vib_freq_"..i, function(x) set_value(i, engine.vibrato_rate, x) end)
    -- vibrato depth
    params:add_control("polyform_vib_depth_"..i, "vibrato depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_vib_depth_"..i, function(x) set_value(i, engine.vibrato_depth, x) end)
    -- vibrato onset
    params:add_control("polyform_vib_onset_"..i, "vibrato fade in", controlspec.new(0, 2, "lin", 0, 0.2), function(param) return (round_form(param:get(), 0.01, "s")) end)
    params:set_action("polyform_vib_onset_"..i, function(x) set_value(i, engine.vibrato_onset, x) end)
    -- vibrato delay
    params:add_control("polyform_vib_delay_"..i, "vibrato delay", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get(), 0.01," s")) end)
    params:set_action("polyform_vib_delay_"..i, function(x) set_value(i, engine.vibrato_delay, x) end)

    params:add_separator("polyform_drift_"..i, "drift")
    -- freq drift
    params:add_control("polyform_drift_freq_"..i, "freq drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_drift_freq_"..i, function(x) set_value(i, engine.freq_slop, x) end)
    -- lpf cutoff drift
    params:add_control("polyform_drift_cutoff_"..i, "cutoff drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_drift_cutoff_"..i, function(x) set_value(i, engine.cut_slop, x) end)
    -- envelope release drift
    params:add_control("polyform_drift_env_"..i, "env drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_drift_env_"..i, function(x) set_value(i, engine.env_slop, x) end)
    -- pan drift
    params:add_control("polyform_drift_pan_"..i, "pan drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("polyform_drift_pan_"..i, function(x) set_value(i, engine.pan_slop, x)  end)
  end
end

return polyForm
