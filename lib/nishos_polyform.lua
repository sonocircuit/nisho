-- Formantpulse params for nisho @sonocircuit

local polyForm = {}

local tx = require 'textentry'

local preset_path = norns.state.path.."/polyform_presets"

local polyform_params = {
  "main_amp",
  "pan"
}

local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

local function display_params(i, x)
  if x == 1 then
    params:hide("sustain"..i)
    params:hide("release"..i)
    params:hide("mod_sustain"..i)
    params:hide("mod_release"..i)
  else
    params:show("sustain"..i)
    params:show("release"..i)
    params:show("mod_sustain"..i)
    params:show("mod_release"..i)
  end
  _menu.rebuild_params()
end

local function set_value(i, id, val)
  for j = 1, 4 do
    local voice = j + (i - 1) * 4
    id(voice, val)
  end
  page_redraw(2)
end

local function cut_drift(synth, val)
  if synth == 1 then
    engine.cut_slop(2, val)
    engine.cut_slop(3, val)
    engine.cut_slop(4, val)
  elseif synth == 2 then
    engine.cut_slop(6, val)
    engine.cut_slop(7, val)
    engine.cut_slop(8, val)
  end
end

local function env_drift(synth, val)
  if synth == 1 then
    engine.env_slop(2, 0.2 * val)
    engine.env_slop(3, 1.1 * val)
    engine.env_slop(4, 0.8 * val)
  elseif synth == 2 then
    engine.env_slop(6, 0.4 * val)
    engine.env_slop(7, 1.2 * val)
    engine.env_slop(8, 1.6 * val)
  end
end

local function pan_drift(synth, val)
  if synth == 1 then
    engine.pan_slop(2, 0.2 * val)
    engine.pan_slop(3, -0.6 * val)
    engine.pan_slop(4, 0.4 * val)
  elseif synth == 2 then
    engine.pan_slop(6, 0.1 * val)
    engine.pan_slop(7, -0.5 * val)
    engine.pan_slop(8, 0.4 * val)
  end
end

local function pan_display(param)
  local pos_right = ""
  local pos_left = ""
  if param == 0 then
    pos_right = ""
    pos_left = ""
  elseif param < -0.01 then
    pos_right = ""
    pos_left = "L< "
  elseif param > 0.01 then
    pos_right = " >R"
    pos_left = ""
  end
  return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
end

local function shape_display(param)
  if param < -0.01 then
    return ("saw  "..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1)))
  elseif param > 0.01 then
    return (math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1)).."  was")
  else
    return "tri"
  end
end

local function curve_display(param)
  if param < -0.01 then
    return ("exp  "..math.abs(util.round(util.linlin(-5, 5, -100, 100, param), 1)))
  elseif param > 0.01 then
    return ("log  "..math.abs(util.round(util.linlin(-5, 5, -100, 100, param), 1)))
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

local function load_synth_patch(path)
  if path then
    print(txt)
  end
end

local function save_synth_patch(txt, i)
  if txt then
    local patch = {}
    for _, v in ipairs(polyform_params) do
      patch.v = params:get(v..i)
    end
    tab.save(patch, preset_path..txt..".patch")
  end
end

function polyForm.add_params()
  -- synth groups 1 and two (voices 1-4 and 5-8)  
  for i = 1, 2 do
    local name = i == 1 and "one" or "two"

    params:add_group("polyform_synth"..i, "polyform ["..name.."]", 56)

    params:add_separator("synthesis"..i, "polyform ["..name.."]")
    -- main amp
    params:add_control("main_amp"..i, "main level", controlspec.new(0, 1, "lin", 0, 0.4), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("main_amp"..i, function(x) set_value(i, engine.main_amp, x) end)
    -- pan
    params:add_control("pan"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0), function(param) return pan_display(param:get()) end)
    params:set_action("pan"..i, function(x) set_value(i, engine.pan, x) end)

    params:add_separator("oscillator_formant"..i, "formant osc")
    -- formant level
    params:add_control("formant_amp"..i, "level", controlspec.new(0, 1, "lin", 0, 1), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("formant_amp"..i, function(x) set_value(i, engine.formant_amp, x) end)
    -- formant tune
    params:add_control("formant_tune"..i, "tune", controlspec.new(-12, 12, "lin", 0, 0, "", 1/480), function(param) return (round_form(param:get(), 0.01, "st")) end)
    params:set_action("formant_tune"..i, function(x) set_value(i, engine.formant_tune, x) end)
    -- formant mode
    params:add_option("formant_type"..i, "type", {"constant", "formant"}, 1)
    params:set_action("formant_type"..i, function(x) set_value(i, engine.formant_type, x - 1) end)
    -- formant shape
    params:add_control("formant_shape"..i, "wave shape", controlspec.new(-1, 1, "lin", 0, 0), function(param) return shape_display(param:get()) end)
    params:set_action("formant_shape"..i, function(x) set_value(i, engine.formant_shape, util.linlin(-1, 1, 0, 1, x)) end)
    -- formant width
    params:add_control("formant_curve"..i, "wave curve", controlspec.new(-5, 5, "lin", 0, 0), function(param) return curve_display(param:get()) end)
    params:set_action("formant_curve"..i, function(x) set_value(i, engine.formant_curve, x) end)
    -- formant width
    params:add_control("formant_width"..i, "formant width", controlspec.new(0.01, 10, "lin", 0.01, 1, "", 0.001), function(param) return width_display(param:get()) end)
    params:set_action("formant_width"..i, function(x) set_value(i, engine.formant_width, x + 0.11) end)
    
    params:add_separator("oscillator_pulse"..i, "pulse osc")
    -- pulse level
    params:add_control("pulse_amp"..i, "level", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("pulse_amp"..i, function(x) set_value(i, engine.pulse_amp, x) end)
     -- pulse tune
    params:add_control("pulse_tune"..i, "tune", controlspec.new(-12, 12, "lin", 0, 0, "", 1/480), function(param) return (round_form(param:get(), 0.01, "st")) end)
    params:set_action("pulse_tune"..i, function(x) set_value(i, engine.pulse_tune, x) end)
    -- pulse width
    params:add_control("pulse_width"..i, "pulse width", controlspec.new(0.1, 0.9, "lin", 0, 0.5), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("pulse_width"..i, function(x) set_value(i, engine.pulse_width, x) end)
    -- pwm speed
    params:add_control("pwm_rate"..i, "pwm rate", controlspec.new(0.2, 20, "exp", 0.01, 2.2), function(param) return (round_form(param:get(), 0.01, " hz")) end)
    params:set_action("pwm_rate"..i, function(x) set_value(i, engine.pulse_mod_freq, x) end)
    -- pwm depth
    params:add_control("pwm_depth"..i, "pwm depth", controlspec.new(0, 0.5, "lin", 0, 0), function(param) return (round_form(param:get() * 200, 1, "%")) end)
    params:set_action("pwm_depth"..i, function(x) set_value(i, engine.pulse_mod_depth, x) end)

    params:add_separator("oscillator_noise"..i, "noise")
    -- noise level
    params:add_control("noise_amp"..i, "noise level", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get() * 50, 1, "%")) end)
    params:set_action("noise_amp"..i, function(x) set_value(i, engine.noise_amp, x) end)
    -- noise crackle
    params:add_control("noise_crackle"..i, "noise crackle", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("noise_crackle"..i, function(x) set_value(i, engine.noise_crackle, x) end)
    
    params:add_separator("filter_lpf"..i, "low pass filter")
    -- cutoff lpf
    params:add_control("lpf_cutoff"..i, "cutoff", controlspec.new(20, 18000, "exp", 0, 1200), function(param) return (round_form(param:get(), 1, " hz")) end)
    params:set_action("lpf_cutoff"..i, function(x) set_value(i, engine.cutoff_lpf, x) end)
    -- resonance lpf
    params:add_control("lpf_resonance"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0.2), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("lpf_resonance"..i, function(x) set_value(i, engine.res_lpf, x) end)
    -- lpf env depth
    params:add_control("env_lpf_depth"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("env_lpf_depth"..i, function(x) set_value(i, engine.env_lpf_depth, x) end)
    
    params:add_separator("filter_hpf"..i, "high pass filter")
    -- cutoff hpf
    params:add_control("hpf_cutoff"..i, "cutoff", controlspec.new(20, 8000, "exp", 0, 20), function(param) return (round_form(param:get(), 1, " hz")) end)
    params:set_action("hpf_cutoff"..i, function(x) set_value(i, engine.cutoff_hpf, x) end)
    -- resonance hpf
    params:add_control("hpf_resonance"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("hpf_resonance"..i, function(x) set_value(i, engine.res_hpf, x) end)
    -- hpf env depth
    params:add_control("env_hpf_depth"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("env_hpf_depth"..i, function(x) set_value(i, engine.env_hpf_depth, x) end)

    params:add_separator("envelope"..i, "envelope")
    -- envelope type
    params:add_option("env_type"..i, "env type", {"ar", "adsr"}, 1)
    params:set_action("env_type"..i, function(x)
      set_value(i, engine.env_type, x - 1)
      display_params(i, x)
      if x == 1 then
        for j = 1, 4 do
          local voice = j + (i - 1) * 4
          engine.stop(voice)
        end
      end
    end)

    -- curve
    params:add_control("env_curve"..i, "curve", controlspec.new(-5, 5, "lin", 0, -4), function(param) return curve_display(param:get()) end)
    params:set_action("env_curve"..i, function(x) set_value(i, engine.env_curve, x) end)
    -- attack
    params:add_control("attack"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0.001), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("attack"..i, function(x) set_value(i, engine.env_a, x) end)
    -- decay
    params:add_control("decay"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.2), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("decay"..i, function(x) set_value(i, engine.env_d, x) end)
    -- sustain
    params:add_control("sustain"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("sustain"..i, function(x) set_value(i, engine.env_s, x) end)
    -- release
    params:add_control("release"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.4), function(param) return (round_form(param:get(), 0.01, " s")) end)
    params:set_action("release"..i, function(x) set_value(i, engine.env_r, x) end)

    params:add_separator("mod_envelope"..i, "mod envelope")

    -- curve
    params:add_control("env_mod_curve"..i, "curve", controlspec.new(-5, 5, "lin", 0, 0), function(param) return curve_display(param:get()) end)
    params:set_action("env_mod_curve"..i, function(x) set_value(i, engine.env_mod_curve, x) end)
    -- delay
    params:add_control("mod_delay"..i, "delay", controlspec.new(0, 5, "lin", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("mod_delay"..i, function(x) set_value(i, engine.envmod_h, x) end)
    -- attack
    params:add_control("mod_attack"..i, "attack", controlspec.new(0.1, 10, "exp", 0, 0.1), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("mod_attack"..i, function(x) set_value(i, engine.envmod_a, x) end)
    -- decay
    params:add_control("mod_decay"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.2), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("mod_decay"..i, function(x) set_value(i, engine.envmod_d, x) end)
    -- sustain
    params:add_control("mod_sustain"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("mod_sustain"..i, function(x) set_value(i, engine.envmod_s, x) end)
    -- release
    params:add_control("mod_release"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.4), function(param) return (round_form(param:get(), 0.01, " s")) end)
    params:set_action("mod_release"..i, function(x) set_value(i, engine.envmod_r, x) end)

    -- cutoff lpf mod
    params:add_control("mod_cutoff_lpf"..i, "cutoff lpf mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("mod_cutoff_lpf"..i, function(x) set_value(i, engine.env_lpf_mod, x) end)
    -- cutoff hpf mod
    params:add_control("mod_cutoff_hpf"..i, "cutoff hpf mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("mod_cutoff_hpf"..i, function(x) set_value(i, engine.env_hpf_mod, x) end)
    -- formant shape mod
    params:add_control("mod_formant_shape"..i, "formant shape mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("mod_formant_shape"..i, function(x) set_value(i, engine.formant_shape_mod, x) end)
    -- pulse width mod
    params:add_control("mod_pulse_width"..i, "pulse width mod", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("mod_pulse_width"..i, function(x) set_value(i, engine.pulse_width_mod, x) end)
    -- noise amp mod
    params:add_control("mod_noise_level"..i, "noise level mod", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("mod_noise_level"..i, function(x) set_value(i, engine.noise_amp_mod, x) end)

    params:add_separator("vibrato"..i, "vibrato")
    -- vibrato rate
    params:add_control("vib_freq"..i, "vibrato rate", controlspec.new(0.2, 20, "exp", 0, 8), function(param) return (round_form(param:get(), 0.01," hz")) end)
    params:set_action("vib_freq"..i, function(x) set_value(i, engine.vibrato_rate, x) end)
    -- vibrato depth
    params:add_control("vib_depth"..i, "vibrato depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("vib_depth"..i, function(x) set_value(i, engine.vibrato_depth, x) end)
    -- vibrato onset
    params:add_control("vib_onset"..i, "vibrato fade in", controlspec.new(0, 2, "lin", 0, 0.2), function(param) return (round_form(param:get(), 0.01, "s")) end)
    params:set_action("vib_onset"..i, function(x) set_value(i, engine.vibrato_onset, x) end)
    -- vibrato delay
    params:add_control("vib_delay"..i, "vibrato delay", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get(), 0.01," s")) end)
    params:set_action("vib_delay"..i, function(x) set_value(i, engine.vibrato_delay, x) end)

    params:add_separator("drift"..i, "drift")
    -- freq drift
    params:add_control("drift_freq"..i, "freq drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("drift_freq"..i, function(x) set_value(i, engine.freq_slop, x) end)
    -- lpf cutoff drift
    params:add_control("drift_cutoff"..i, "cutoff drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("drift_cutoff"..i, function(x) set_value(i, engine.cut_slop, x) end)
    -- envelope release drift
    params:add_control("drift_env"..i, "env drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("drift_env"..i, function(x) set_value(i, engine.env_slop, x) end)
    -- pan drift
    params:add_control("drift_pan"..i, "pan drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("drift_pan"..i, function(x) set_value(i, engine.pan_slop, x)  end)
  end
end

return polyForm
