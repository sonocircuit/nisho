-- moonunit params for nisho @sonocircuit

local Moonunit = {}

local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

local function display_params(i, x)
  if x == 1 then
    params:hide("sustain"..i)
    params:hide("decay"..i)
  else
    params:show("sustain"..i)
    params:show("decay"..i)
  end
  _menu.rebuild_params()
end

local function set_value(i, id, val)
  for j = 1, 4 do
    local voice = j + (i - 1) * 4
    id(voice, val)
  end
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



function Moonunit.add_params()
  -- synth groups 1 and two (voices 1-4 and 5-8)  
  for i = 1, 2 do
    local name = i == 1 and "one" or "two"

    params:add_group("moonunit_synth"..i, "moonunit ["..name.."]", 44)

    params:add_separator("synthesis"..i, "moonunit ["..name.."]")
    -- amp
    params:add_control("main_amp"..i, "main level", controlspec.new(0, 1, "lin", 0, 0.5), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("main_amp"..i, function(val) set_value(i, engine.amp, val) end)
    -- pan
    params:add_control("pan"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0))
    params:set_action("pan"..i, function(x) set_value(i, engine.pan, x) end)

    params:add_separator("oscillator_sine"..i, "sine osc")
    -- sine level
    params:add_control("sine_amp"..i, "sine level", controlspec.new(0, 1, "lin", 0, 1), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("sine_amp"..i, function(x) set_value(i, engine.sine_amp, x) end)
    -- sine level
    params:add_control("sine_gain"..i, "sine gain", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("sine_gain"..i, function(x) set_value(i, engine.sine_gain, x) end)
    -- sine tune
    params:add_control("sine_tune"..i, "sine tune", controlspec.new(-24, 24, "lin", 0, 0), function(param) return (round_form(param:get(), 0.1, "st")) end)
    params:set_action("sine_tune"..i, function(x) set_value(i, engine.sine_tune, x) end)

    params:add_separator("oscillator_saw"..i, "saw osc")
    -- saw level
    params:add_control("saw_amp"..i, "saw level", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("saw_amp"..i, function(x) set_value(i, engine.saw_amp, x) end)
    -- saw tune
    params:add_control("saw_tune"..i, "saw tune", controlspec.new(-12, 12, "lin", 0, 0), function(param) return (round_form(param:get(), 0.1, "st")) end)
    params:set_action("saw_tune"..i, function(x) set_value(i, engine.saw_tune, x) end)
    -- supersaw
    params:add_control("supersaw"..i, "supersaw", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("supersaw"..i, function(x) set_value(i, engine.supersaw, x) end)

    params:add_separator("oscillator_pulse"..i, "pulse osc")
    -- pulse level
    params:add_control("pulse_amp"..i, "pulse level", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("pulse_amp"..i, function(x) set_value(i, engine.pulse_amp, x) end)
     -- pulse tune
    params:add_control("pulse_tune"..i, "pulse tune", controlspec.new(-12, 12, "lin", 0, 0), function(param) return (round_form(param:get(), 0.1, "st")) end)
    params:set_action("pulse_tune"..i, function(x) set_value(i, engine.pulse_tune, x) end)
    -- pulse width
    params:add_control("pulse_width"..i, "pulse width", controlspec.new(0.1, 0.9, "lin", 0, 0.5), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("pulse_width"..i, function(x) set_value(i, engine.pulse_width, x) end)
    -- pwm speed
    params:add_control("pwm_rate"..i, "pwm rate", controlspec.new(0.2, 20, "exp", 0.01, 2.2), function(param) return (round_form(param:get(), 0.01, " hz")) end)
    params:set_action("pwm_rate"..i, function(x) set_value(i, engine.pwm_freq, x) end)
    -- pwm depth
    params:add_control("pwm_depth"..i, "pwm depth", controlspec.new(0, 0.5, "lin", 0, 0), function(param) return (round_form(param:get() * 200, 1, "%")) end)
    params:set_action("pwm_depth"..i, function(x) set_value(i, engine.pwm_depth, x) end)

    params:add_separator("oscillator_noise"..i, "noise")
    -- noise level
    params:add_control("noise_amp"..i, "noise level", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get() * 50, 1, "%")) end)
    params:set_action("noise_amp"..i, function(x) set_value(i, engine.noise_amp, x) end)
    -- noise crackle
    params:add_control("noise_crackle"..i, "noise crackle", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("noise_crackle"..i, function(x) set_value(i, engine.crackle, x) end)
    
    params:add_separator("filter_lpf"..i, "low pass filter")
    -- cutoff lpf
    params:add_control("lpf_cutoff"..i, "cutoff", controlspec.new(20, 18000, "exp", 0, 1200), function(param) return (round_form(param:get(), 0.01, " hz")) end)
    params:set_action("lpf_cutoff"..i, function(x) set_value(i, engine.cutoff_lpf, x) end)
    -- resonance lpf
    params:add_control("lpf_resonance"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0.2), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("lpf_resonance"..i, function(x) set_value(i, engine.res_lpf, x) end)
    -- lpf env depth
    params:add_control("env_lpf_depth"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("env_lpf_depth"..i, function(x) set_value(i, engine.env_depth_lpf, x) end)
    -- lpf env type
    params:add_number("lpf_env_type"..i, "env mode", 0, 1, 0, function(param) return (param:get() == 1 and "[ * ]" or "[ + ]") end)
    params:set_action("lpf_env_type"..i, function(x) set_value(i, engine.env_mod_mode, x) end)
    
    params:add_separator("filter_hpf"..i, "high pass filter")
    -- cutoff hpf
    params:add_control("hpf_cutoff"..i, "cutoff", controlspec.new(20, 18000, "exp", 0, 20), function(param) return (round_form(param:get(), 0.01, " hz")) end)
    params:set_action("hpf_cutoff"..i, function(x) set_value(i, engine.cutoff_hpf, x) end)
    -- resonance hpf
    params:add_control("hpf_resonance"..i, "resonance", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("hpf_resonance"..i, function(x) set_value(i, engine.res_hpf, x) end)
    -- hpf env depth
    params:add_control("env_hpf_depth"..i, "env depth", controlspec.new(-1, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("env_hpf_depth"..i, function(x) set_value(i, engine.env_depth_hpf, x) end)

    params:add_separator("envelope"..i, "envelope")
    -- envelope type
    params:add_option("env_type"..i, "drone", {"off", "on"}, 1)
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

    params:add_separator("vibrato"..i, "vibrato")
    -- vibrato rate
    params:add_control("vib_freq"..i, "vibrato rate", controlspec.new(0.2, 20, "exp", 0, 8), function(param) return (round_form(param:get(), 0.01," hz")) end)
    params:set_action("vib_freq"..i, function(x) set_value(i, engine.vib_rate, x) end)
    -- vibrato depth
    params:add_control("vib_depth"..i, "vibrato depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("vib_depth"..i, function(x) set_value(i, engine.vib_depth, x) end)
    -- vibrato onset
    params:add_control("vib_onset"..i, "vibrato fade in", controlspec.new(0, 2, "lin", 0, 0.2), function(param) return (round_form(param:get(), 0.01, "s")) end)
    params:set_action("vib_onset"..i, function(x) set_value(i, engine.vib_onset, x) end)
    -- vibrato delay
    params:add_control("vib_delay"..i, "vibrato delay", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get(), 0.01," s")) end)
    params:set_action("vib_delay"..i, function(x) set_value(i, engine.vib_delay, x) end)

    params:add_separator("drift"..i, "drift")
    -- lpf cutoff drift
    params:add_control("drift_cutoff"..i, "cutoff drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("drift_cutoff"..i, function(val) cut_drift(i, val) end)
    -- envelope release drift
    params:add_control("drift_env"..i, "env drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("drift_env"..i, function(val) env_drift(i, val) end)
    -- pan drift
    params:add_control("drift_pan"..i, "pan drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("drift_pan"..i, function(val) pan_drift(i, val)  end)
  end
end

return Moonunit
