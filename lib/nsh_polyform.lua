-- polyform for nisho v2.0

local tx = require 'textentry'
local mu = require 'musicutil'
local md = require 'core/mods'
local vx = require 'voice'

local ptch = {}
ptch.preset_path = norns.state.data.."polyform_patches"
ptch.default = norns.state.data.."polyform_patches/default.patch"
ptch.failsafe = norns.state.path.."data/polyform_patches/default.patch"
ptch.loaded = {"", ""}
ptch.synth = 1
ptch.list = {}
ptch.prms = {
  "main_amp", "pan", "send_a", "send_b", "unison_mode", "unison_detune", "ptichbend_range", "mix",
  "saw_tune","saw_shape", "saw_fm_index", "saw_fm_ratio", "swm_rate", "swm_depth", "pulse_tune", "pulse_width", "pwm_rate", 
  "pwm_depth", "noise_mix", "noise_type", "lpf_cutoff", "lpf_resonance", "lpf_env_depth", "lpf_keytrack", "hpf_cutoff",
  "hpf_resonance", "hpf_env_depth", "hpf_keytrack", "env_curve", "attack", "decay", "sustain", "release",
  "mod_env_amp", "mod_env_curve", "mod_delay", "mod_attack", "mod_decay", "mod_sustain", "mod_release", "mod_osc_mix",
  "mod_noise_level", "mod_send_a", "mod_send_b", "mod_saw_shape", "mod_swm_depth","mod_fm_ratio", "mod_fm_index",
  "mod_pulse_width", "mod_pwm_depth", "mod_cutoff_lpf", "mod_cutoff_hpf", "vib_freqmod", "vib_depthmod",
  "vib_freq", "vib_depth", "vib_delay", "vib_onset", "drift_freq", "drift_cutoff", "drift_env", "drift_pan"
}

local syn = {}
for i = 1, 2 do
  local alloc_num = i == 1 and 1 or 6
  syn[i] = {}
  syn[i].vox = 1
  syn[i].unison = false
  syn[i].detune = 1
  syn[i].count = 0
  syn[i].alloc = vx.new(alloc_num, 2) -- 2 is LRU
  syn[i].slot = {}
  syn[i].prev_note = 0
  syn[i].modwheel = 0
  syn[i].vib_rate_mod = 0
  syn[i].vib_depth_mod = 0
  syn[i].noise_type = 0
end

-- JP800 supersaw emulation based on adam szbao's thesis,
-- ported to supercollider by eric skogan and adapted by zack scholl
-- ported to lua and adapted for nisho by sonocircuit
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

-- bad idea to call get_detune_val() each time a note is triggered so we'll populate a table at init with 100 values (depth).
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

local function pan_display(param)
  if param < -0.01 then
    return ("L < "..math.abs(util.round(param * 100, 1)))
  elseif param > 0.01 then
    return (math.abs(util.round(param * 100, 1)).." > R")
  else
    return "> <"
  end
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

local function mix_display(param)
  local saw = util.round(util.linlin(-1, 1, 100, 0, param), 1)
  local pulse = util.round(util.linlin(-1, 1, 0, 100, param), 1)
  return saw.."/"..pulse
end

local function set_value(i, key, val)
  local t = {"mono", "poly"}
  engine.set_polyform(t[i], key, val)
  page_redraw(2)
end

local function dont_panic(i)
  local t = {"mono", "poly"}
  engine.polyform_panic(t[i])
  syn[i].count = 0
end

local function build_patch_list()
  local files = util.scandir(ptch.preset_path)
  ptch.list = {}
  for i = 1, #files do
    if files[i]:match("^.+(%..+)$") == ".patch" then
      local num = tonumber(files[i]:match(".-%d+"))
      if num ~= nil then
        ptch.list[num] = files[i]
      end
    end
  end
end

local function save_synth_patch(txt)
  if txt then
    local t = {}
    for _, v in ipairs(ptch.prms) do
      t[v] = params:get("polyform_"..v.."_"..ptch.synth)
    end
    tab.save(t, ptch.preset_path.."/"..txt..".patch")
    ptch.loaded[ptch.synth] = txt
    params:set("polyform_load_patch_"..ptch.synth, ptch.preset_path.."/"..txt..".patch", true)
    build_patch_list()
    print("saved polyform patch "..txt)
  end
end

local function load_synth_patch(path, i)
  if path ~= "cancel" and path ~= "" then
    dont_panic(i)
    if path:match("^.+(%..+)$") == ".patch" then
      local t = tab.load(path)
      if t ~= nil then
        for _, v in ipairs(ptch.prms) do
          if t[v] ~= nil then
            params:set("polyform_"..v.."_"..i, t[v])
          end
        end
        local name = path:match("[^/]*$")
        ptch.loaded[i] = name:gsub(".patch", "")
        local syn_name = {"polyform[mono]", "polyform[poly]"}
        print("loaded "..syn_name[i]..": "..ptch.loaded[i])
      else
        if util.file_exists(ptch.failsafe) then
          load_synth_patch(ptch.failsafe, i)
        end
        print("error: could not find patch", path)
      end
    else
      print("error: not a polyform patch file")
    end
  end
end

local function add_params()
   for i = 1, 2 do
    local name = i == 1 and "mono" or "poly"
    params:add_group("polyform_synth_"..i, "polyform ["..name.."]", 79)

    params:add_separator("polyform_patches_"..i, "polyform ["..name.."]")

    params:add_file("polyform_load_patch_"..i, ">> load", ptch.default)
    params:set_action("polyform_load_patch_"..i, function(path) load_synth_patch(path, i) end)

    params:add_trigger("polyform_save_patch_"..i, "<< save")
    params:set_action("polyform_save_patch_"..i, function() ptch.synth = i tx.enter(save_synth_patch, ptch.loaded[i]) end)

    params:add_separator("polyform_levels_"..i, "levels")
    -- main amp
    params:add_control("polyform_main_amp_"..i, "main level", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_main_amp_"..i, function(x) set_value(i, "level", x) end)
    -- pan
    params:add_control("polyform_pan_"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return pan_display(param:get()) end)
    params:set_action("polyform_pan_"..i, function(x) set_value(i, "pan", x) end)
    -- send a
    local send_a_name = md.is_loaded("fx") and "send a" or "delay send"
    params:add_control("polyform_send_a_"..i, send_a_name, controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_send_a_"..i, function(x) set_value(i, "sendA", x) end)
    -- send b
    local send_b_name = md.is_loaded("fx") and "send b" or "reverb send"
    params:add_control("polyform_send_b_"..i, send_b_name, controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_send_b_"..i, function(x) set_value(i, "sendB", x) end)

    params:add_separator("polyform_voice_"..i, "voice")
    -- unison mode
    params:add_option("polyform_unison_mode_"..i, "unison", {"off", "on"}, 1)
    params:set_action("polyform_unison_mode_"..i, function(mode) syn[i].unison = mode == 2 and true or false dont_panic(i) end)
    -- detune amt
    params:add_number("polyform_unison_detune_"..i, "detune", 1, 100, 10, function(param) return round_form(param:get(), 1, "%") end)
    params:set_action("polyform_unison_detune_"..i, function(x) syn[i].detune = x end)
    -- pitchbend range
    params:add_number("polyform_ptichbend_range_"..i, "pitchbend", 1, 12, 7, function(param) return param:get().."st" end)
    params:set_action("polyform_ptichbend_range_"..i, function(x) set_value(i, "pb_range", x) end)
    -- osc mix
    params:add_control("polyform_mix_"..i, "mix [saw/pulse]", controlspec.new(-1, 1, "lin", 0, -0.75), function(param) return mix_display(param:get()) end)
    params:set_action("polyform_mix_"..i, function(x) set_value(i, "osc_mix", x) end)

    params:add_separator("polyform_saw_"..i, "saw osc")
    -- saw tune
    params:add_control("polyform_saw_tune_"..i, "tune", controlspec.new(-24, 24, "lin", 0, 0, "", 1/480), function(param) return (round_form(param:get(), 0.01, "st")) end)
    params:set_action("polyform_saw_tune_"..i, function(x) set_value(i, "saw_tune", x) end)
    -- saw shape
    params:add_control("polyform_saw_shape_"..i, "wave shape", controlspec.new(-1, 1, "lin", 0, -0.8, "", 1/200), function(param) return shape_display(param:get()) end)
    params:set_action("polyform_saw_shape_"..i, function(x) set_value(i, "saw_shape", util.linlin(-1, 1, 0, 1, x)) end)
    -- swm speed
    params:add_control("polyform_swm_rate_"..i, "shape mod rate", controlspec.new(0.2, 20, "exp", 0.01, 2.2, "", 1/200), function(param) return round_form(param:get(), 0.01, " hz") end)
    params:set_action("polyform_swm_rate_"..i, function(x) set_value(i, "saw_lfo_freq", x) end)
    -- swm depth
    params:add_control("polyform_swm_depth_"..i, "shape mod depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_swm_depth_"..i, function(x) set_value(i, "saw_lfo_depth", x * 0.5) end)
    -- fm ratio
    params:add_control("polyform_saw_fm_ratio_"..i, "fm ratio", controlspec.new(1, 5, "lin", 0, 1.5, "", 1/400), function(param) return round_form(param:get(), 0.01, "") end)
    params:set_action("polyform_saw_fm_ratio_"..i, function(x) set_value(i, "fm_ratio", x) end)
    -- fm depth
    params:add_control("polyform_saw_fm_index_"..i, "fm depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_saw_fm_index_"..i, function(x) set_value(i, "fm_index", x) end)
    
    params:add_separator("polyform_polyform_pulse_"..i, "pulse osc")
     -- pulse tune
    params:add_control("polyform_pulse_tune_"..i, "tune", controlspec.new(-24, 24, "lin", 0, 0, "", 1/480), function(param) return round_form(param:get(), 0.01, "st") end)
    params:set_action("polyform_pulse_tune_"..i, function(x) set_value(i, "pulse_tune", x) end)
    -- pulse width
    params:add_control("polyform_pulse_width_"..i, "pulse width", controlspec.new(0.1, 0.9, "lin", 0, 0.5), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_pulse_width_"..i, function(x) set_value(i, "pulse_width", x) end)
    -- pwm speed
    params:add_control("polyform_pwm_rate_"..i, "pwm rate", controlspec.new(0.2, 20, "exp", 0.01, 2.2), function(param) return round_form(param:get(), 0.01, " hz") end)
    params:set_action("polyform_pwm_rate_"..i, function(x) set_value(i, "pulse_lfo_freq", x) end)
    -- pwm depth
    params:add_control("polyform_pwm_depth_"..i, "pwm depth", controlspec.new(0, 0.5, "lin", 0, 0), function(param) return round_form(param:get() * 200, 1, "%") end)
    params:set_action("polyform_pwm_depth_"..i, function(x) set_value(i, "pulse_lfo_depth", x) end)

    params:add_separator("polyform_noise_"..i, "noise")
    -- noise level
    params:add_control("polyform_noise_mix_"..i, "noise level", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_noise_mix_"..i, function(x) set_value(i, "noise_amp", x) end)
    -- noise crackle
    params:add_option("polyform_noise_type_"..i, "noise type", {"white", "static", "redux", "brown"}, 1)
    params:set_action("polyform_noise_type_"..i, function(x) syn[i].noise_type = x - 1 end)
    
    params:add_separator("polyform_filter_lpf_"..i, "low pass filter")
    -- cutoff lpf
    params:add_control("polyform_lpf_cutoff_"..i, "cutoff", controlspec.new(20, 18000, "exp", 0, 1200), function(param) return round_form(param:get(), 1, " hz") end)
    params:set_action("polyform_lpf_cutoff_"..i, function(x) set_value(i, "cutoff_lpf", x) end)
    -- resonance lpf
    params:add_control("polyform_lpf_resonance_"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0.2), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_lpf_resonance_"..i, function(x) set_value(i, "res_lpf", x) end)
    -- lpf env depth
    params:add_control("polyform_lpf_env_depth_"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0.1, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_lpf_env_depth_"..i, function(x) set_value(i, "env_depth_lpf", x) end)
    -- lpf key tracking
    params:add_control("polyform_lpf_keytrack_"..i, "key tracking", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_lpf_keytrack_"..i, function(x) set_value(i, "keytrack_lpf", x) end)
    
    params:add_separator("polyform_polyform_filter_hpf_"..i, "high pass filter")
    -- cutoff hpf
    params:add_control("polyform_hpf_cutoff_"..i, "cutoff", controlspec.new(20, 8000, "exp", 0, 20), function(param) return round_form(param:get(), 1, " hz") end)
    params:set_action("polyform_hpf_cutoff_"..i, function(x) set_value(i, "cutoff_hpf", x) end)
    -- resonance hpf
    params:add_control("polyform_hpf_resonance_"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_hpf_resonance_"..i, function(x) set_value(i, "res_hpf", x) end)
    -- hpf env depth
    params:add_control("polyform_hpf_env_depth_"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_hpf_env_depth_"..i, function(x) set_value(i, "env_depth_hpf", x) end)
    -- hpf key tracking
    params:add_control("polyform_hpf_keytrack_"..i, "key tracking", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_hpf_keytrack_"..i, function(x) set_value(i, "keytrack_hpf", x) end)

    params:add_separator("polyform_envelope_"..i, "envelope")
    -- curve
    params:add_control("polyform_env_curve_"..i, "curve", controlspec.new(-5, 5, "lin", 0, -4, "", 1/400), function(param) return curve_display(param:get()) end)
    params:set_action("polyform_env_curve_"..i, function(x) set_value(i, "env_curve", x) end)
    -- attack
    params:add_control("polyform_attack_"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0.001, "", 1/200), function(param) return round_form(param:get(),0.01," s") end)
    params:set_action("polyform_attack_"..i, function(x) set_value(i, "env_a", x) end)
    -- decay
    params:add_control("polyform_decay_"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.4, "", 1/200), function(param) return round_form(param:get(),0.01," s") end)
    params:set_action("polyform_decay_"..i, function(x) set_value(i, "env_d", x) end)
    -- sustain
    params:add_control("polyform_sustain_"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.5), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_sustain_"..i, function(x) set_value(i, "env_s", x) end)
    -- release
    params:add_control("polyform_release_"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.8, "", 1/200), function(param) return round_form(param:get(), 0.01, " s") end)
    params:set_action("polyform_release_"..i, function(x) set_value(i, "env_r", x) end)

    params:add_separator("polyform_mod_src_"..i, "mod source")
    -- depth
    params:add_control("polyform_modwheel_amt_"..i, "modwheel amt", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_modwheel_amt_"..i, function(x) set_value(i, "mod_wheel", x) syn[i].modwheel = x end)
    -- mod env level
    params:add_control("polyform_mod_env_amp_"..i, "mod env amt", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_env_amp_"..i, function(x) set_value(i, "menv_amp", x) end)
    -- curve
    params:add_control("polyform_mod_env_curve_"..i, "curve", controlspec.new(-5, 5, "lin", 0, 0, "", 1/400), function(param) return curve_display(param:get()) end)
    params:set_action("polyform_mod_env_curve_"..i, function(x) set_value(i, "menv_curve", x) end)
    -- delay
    params:add_control("polyform_mod_delay_"..i, "delay", controlspec.new(0, 5, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get(),0.01," s") end)
    params:set_action("polyform_mod_delay_"..i, function(x) set_value(i, "menv_h", x) end)
    -- attack
    params:add_control("polyform_mod_attack_"..i, "attack", controlspec.new(0.1, 10, "exp", 0, 0.1, "", 1/200), function(param) return round_form(param:get(),0.01," s") end)
    params:set_action("polyform_mod_attack_"..i, function(x) set_value(i, "menv_a", x) end)
    -- decay
    params:add_control("polyform_mod_decay_"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.2, "", 1/200), function(param) return round_form(param:get(),0.01," s") end)
    params:set_action("polyform_mod_decay_"..i, function(x) set_value(i, "menv_d", x) end)
    -- sustain
    params:add_control("polyform_mod_sustain_"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_sustain_"..i, function(x) set_value(i, "menv_s", x) end)
    -- release
    params:add_control("polyform_mod_release_"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.4, "", 1/200), function(param) return round_form(param:get(), 0.01, " s") end)
    params:set_action("polyform_mod_release_"..i, function(x) set_value(i, "menv_r", x) end)

    params:add_separator("polyform_mod_dst_"..i, "mod dest")
    -- osc mix mod
    params:add_control("polyform_mod_osc_mix_"..i, "osc mix", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_osc_mix_"..i, function(x) set_value(i, "mod_oscmix", x) end)
    -- noise amp mod
    params:add_control("polyform_mod_noise_level_"..i, "noise level", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_noise_level_"..i, function(x) set_value(i, "mod_noiseamp", x) end)
    -- send A mod
    params:add_control("polyform_mod_send_a_"..i, send_a_name, controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_send_a_"..i, function(x) set_value(i, "mod_sendA", x) end)
    -- send B mod
    params:add_control("polyform_mod_send_b_"..i, send_b_name, controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_send_b_"..i, function(x) set_value(i, "mod_sendB", x) end)
    -- saw shape mod
    params:add_control("polyform_mod_saw_shape_"..i, "saw shape", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_saw_shape_"..i, function(x) set_value(i, "mod_sawshape", x) end)
    -- saw lfo mod
    params:add_control("polyform_mod_swm_depth_"..i, "saw lfo depth", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_swm_depth_"..i, function(x) set_value(i, "mod_saw_lfo_depth", x) end)
    -- saw fm mod
    params:add_control("polyform_mod_fm_ratio_"..i, "fm ratio", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_fm_ratio_"..i, function(x) set_value(i, "mod_fm_ratio", x) end)
    -- saw fm mod
    params:add_control("polyform_mod_fm_index_"..i, "fm index", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_fm_index_"..i, function(x) set_value(i, "mod_fm_index", x) end)
    -- pulse width mod
    params:add_control("polyform_mod_pulse_width_"..i, "pulse width", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_pulse_width_"..i, function(x) set_value(i, "mod_pulsewidth", x) end)
    -- pulse width mod
    params:add_control("polyform_mod_pwm_depth_"..i, "pwm depth", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_pwm_depth_"..i, function(x) set_value(i, "mod_pwm_depth", x) end)
    -- cutoff lpf mod
    params:add_control("polyform_mod_cutoff_lpf_"..i, "cutoff lpf", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_cutoff_lpf_"..i, function(x) set_value(i, "mod_lpfcut", x) end)
    -- cutoff hpf mod
    params:add_control("polyform_mod_cutoff_hpf_"..i, "cutoff hpf", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_mod_cutoff_hpf_"..i, function(x) set_value(i, "mod_hpfcut", x) end)

    params:add_separator("polyform_at_dst_"..i, "aftertouch dest")
    -- vibrato rate mod
    params:add_control("polyform_vib_freqmod_"..i, "vibrato rate", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_vib_freqmod_"..i, function(x) syn[i].vib_rate_mod = x end)
    -- vibrato depth mod
    params:add_control("polyform_vib_depthmod_"..i, "vibrato depth", controlspec.new(0, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_vib_depthmod_"..i, function(x) syn[i].vib_depth_mod = x end)

    params:add_separator("polyform_vibrato_"..i, "vibrato")
    -- vibrato rate
    params:add_control("polyform_vib_freq_"..i, "vibrato rate", controlspec.new(0.2, 20, "exp", 0, 8), function(param) return round_form(param:get(), 0.01," hz") end)
    params:set_action("polyform_vib_freq_"..i, function(x) set_value(i, "vib_rate", x) end)
    -- vibrato depth
    params:add_control("polyform_vib_depth_"..i, "vibrato depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_vib_depth_"..i, function(x) set_value(i, "vib_depth", x) end)
    -- vibrato delay
    params:add_control("polyform_vib_delay_"..i, "vibrato delay", controlspec.new(0, 2, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get(), 0.01," s") end)
    params:set_action("polyform_vib_delay_"..i, function(x) set_value(i, "vib_delay", x) end)
    -- vibrato onset
    params:add_control("polyform_vib_onset_"..i, "vibrato fade in", controlspec.new(0, 2, "lin", 0, 0.2, "", 1/200), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("polyform_vib_onset_"..i, function(x) set_value(i, "vib_onset", x) end)

    params:add_separator("polyform_drift_"..i, "drift")
    -- freq drift
    params:add_control("polyform_drift_freq_"..i, "freq drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_drift_freq_"..i, function(x) set_value(i, "freq_drift", x) end)
    -- lpf cutoff drift
    params:add_control("polyform_drift_cutoff_"..i, "lpf drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_drift_cutoff_"..i, function(x) set_value(i, "cut_drift", x) end)
    -- envelope release drift
    params:add_control("polyform_drift_env_"..i, "env drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_drift_env_"..i, function(x) set_value(i, "env_drift", x) end)
    -- pan drift
    params:add_control("polyform_drift_pan_"..i, "pan drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("polyform_drift_pan_"..i, function(x) set_value(i, "pan_drift", x)  end)
  end
end


------------------- polyform -------------------

local polyform = {}

function polyform.init()
  if util.file_exists(ptch.preset_path) == false then
    util.make_dir(ptch.preset_path)
    os.execute('cp '.. norns.state.path .. 'data/polyform_patches/*.patch '.. ptch.preset_path)
  end
  build_detune_values()
  build_patch_list()
  add_params()
end

function polyform.prc_load(num, i)
  if ptch.list[num] ~= nil then
    params:set("polyform_load_patch_"..i, ptch.preset_path.."/"..ptch.list[num])
  else
    print("error: unvalid patch number: "..num)
  end
end

function polyform.panic(i)
  dont_panic(i)
end

function polyform.note_on(i, note_num, vel)
  local t = {"mono", "poly"}
  local freq = mu.note_num_to_freq(note_num)
  local vel = vel and util.linlin(0, 127, 0, 1, vel) or 1
  if syn[i].unison then
    -- unsion on
    local max = i == 1 and 2 or 6
    local off = i == 1 and 2 or 0
    local att = i == 1 and 0.704 or 0.501
    for vox = 1, max do
      engine.polyform_on(t[i], vox - 1, detune_freq(vox + off, freq, syn[i].detune), vel * att, syn[i].noise_type)
    end
    syn[i].count = syn[i].count + 1
  else
    local slot = syn[i].slot[note_num]
    if slot == nil then
      if i == 1 then
        syn[i].slot[syn[i].prev_note] = nil
        syn[i].prev_note = note_num
      end
      slot = syn[i].alloc:get()
      slot.count = 1
    end
    slot.on_release = function()
      engine.polyform_off(t[i], slot.id - 1)
    end
    syn[i].slot[note_num] = slot
    engine.polyform_on(t[i], slot.id - 1, freq, vel, syn[i].noise_type)
  end
end

function polyform.note_off(i, note_num)
  if syn[i].unison then
    syn[i].count = syn[i].count - 1
    if syn[i].count <= 0 then
      dont_panic(i) -- unison off
    end
  else
    local slot = syn[i].slot[note_num]
    if slot ~= nil then
      syn[i].alloc:release(slot)
    end
    syn[i].slot[note_num] = nil
  end
end

function polyform.set_pitchbend(i, val)
  local t = {"mono", "poly"}
  engine.set_polyform(t[i], "pb_depth", val)
end

function polyform.set_modwheel(i, val)
  local t = {"mono", "poly"}
  local amt = util.clamp(0, 1, syn[i].modwheel + val)
  engine.set_polyform(t[i], "mod_wheel", amt)
end

function polyform.set_aftertouch(i, val)
  local t = {"mono", "poly"}
  engine.set_polyform(t[i], "mod_vibrate", syn[i].vib_rate_mod * val)
  engine.set_polyform(t[i], "mod_vibdepth", syn[i].vib_depth_mod * val)
end

return polyform
