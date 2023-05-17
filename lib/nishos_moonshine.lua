-- moonshine params @danderks
-- adapted for nisho @sonocircuit

local Moonshine = {}
local ControlSpec = require 'controlspec'
local Formatters = require 'formatters'

function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

local function display_voices(i, x)
  for j = 1, 4 do
    if x == 1 then
      params:hide("moonshine_voice"..j + (i - 1) * 4)
    else
      params:show("moonshine_voice"..j + (i - 1) * 4)
    end
  end
  _menu.rebuild_params()
end

local function set_value(i, id, val)
  for j = 1, 4 do
    local num = j + (i - 1) * 4
    params:set(id..num, val)
  end
end

function Moonshine.add_params()
  -- synth groups 1 and two (voices 1-4 and 5-8)  
  for i = 1, 2 do
    local name = i == 1 and "one" or "two"

    params:add_group("moonshine_synth"..i, "synth["..name.."]", 17)

    params:add_separator("synthesis_synth"..i, "moonshine["..name.."]")
    -- amp
    params:add_control("amp_synth"..i, "level", controlspec.new(0, 1, "lin", 0, 0.5), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("amp_synth"..i, function(val) set_value(i, "amp", val) end)
    -- sub division
    params:add_number("sub_div_synth"..i, "sub division", 1, 10, 1)
    params:set_action("sub_div_synth"..i, function(x) set_value(i, "sub_div", x) end)
    -- noise level
    params:add_control("noise_amp_synth"..i, "noise level", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get() * 50, 1, "%")) end)
    params:set_action("noise_amp_synth"..i, function(x) set_value(i, "noise_amp", x) end)
    -- cutoff
    params:add_control("cutoff_synth"..i, "cutoff", controlspec.new(20, 20000, "exp", 0, 1200), function(param) return (round_form(param:get(), 0.01, " hz")) end)
    params:set_action("cutoff_synth"..i, function(x) set_value(i, "cutoff", x) end)
    -- filter env
    params:add_number("cutoff_env_synth"..i, "filter env", 0, 1, 0, function(param) return (param:get() == 1 and "on" or "off") end)
    params:set_action("cutoff_env_synth"..i, function(x) set_value(i, "cutoff_env", x) end)
    -- resonance
    params:add_control("resonance_synth"..i, "filter q", controlspec.new(0, 4, "lin", 0, 1), function(param) return (round_form(util.linlin(0, 4, 0, 100, param:get()), 1, "%")) end)
    params:set_action("resonance_synth"..i, function(x) set_value(i, "resonance", x) end)
    -- attack
    params:add_control("attack_synth"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("attack_synth"..i, function(x) set_value(i, "attack", x) end)
    -- release
    params:add_control("release_synth"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.3), function(param) return (round_form(param:get(), 0.01, " s")) end)
    params:set_action("release_synth"..i, function(x) set_value(i, "release", x) end)
    -- pan
    params:add_control("pan_synth"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0), Formatters.bipolar_as_pan_widget)
    params:set_action("pan_synth"..i, function(x) set_value(i, "pan", x) end)

    params:add_separator("slews_synth"..i, "slews")
    params:hide("slews_synth"..i)
    -- freq slew
    params:add_control("freq_slew_synth"..i, "frequency slew", controlspec.new(0.001, 10, "exp", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("freq_slew_synth"..i, function(x) set_value(i, "freq_slew", x) end)
    params:hide("freq_slew_synth"..i)
    -- amp slew
    params:add_control("amp_slew_synth"..i, "level slew", controlspec.new(0.001, 10, "exp", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("amp_slew_synth"..i, function(x) set_value(i, "amp_slew", x) end)
    params:hide("amp_slew_synth"..i)
    -- noise slew
    params:add_control("noise_slew_synth"..i, "noise slew", controlspec.new(0.001, 10, "exp", 0, 0.5), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("noise_slew_synth"..i, function(x) set_value(i, "noise_slew", x) end)
    params:hide("noise_slew_synth"..i)
    -- pan slew
    params:add_control("pan_slew_synth"..i, "pan slew", controlspec.new(0.001, 10, "exp", 0, 0.5), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("pan_slew_synth"..i, function(x) set_value(i, "pan_slew", x) end)
    params:hide("pan_slew_synth"..i)

    params:add_separator("voices"..i, "voices")
    params:add_option("display_voices"..i, "individual voices", {"hide", "show"}, 1)
    params:set_action("display_voices"..i, function(x) display_voices(i, x) end)
  end

  -- voices 1 - 8
  for i = 1, 8 do
    local name = i < 5 and "one" or "two"
    local voicenum = i < 5 and i or i - 4

    params:add_group("moonshine_voice"..i, "synth["..name.."] ["..voicenum.."]", 15)
    params:hide("moonshine_voice"..i)

    params:add_separator("synthesis"..i, "moonshine voice ["..voicenum.."]")
    -- amp
    params:add_control("amp"..i, "level", controlspec.new(0, 1, "lin", 0, 0.5), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("amp"..i, function(x) engine.amp(i, x / 2) end) 
    -- sub division
    params:add_number("sub_div"..i, "sub division", 1, 10, 1)
    params:set_action("sub_div"..i, function(x) engine.sub_div(i, x) end)
    -- noise level
    params:add_control("noise_amp"..i, "noise level", controlspec.new(0, 2, "lin", 0, 0), function(param) return (round_form(param:get() * 50, 1, "%")) end)
    params:set_action("noise_amp"..i, function(x) engine.noise_amp(i, x) end)
    -- cutoff
    params:add_control("cutoff"..i, "cutoff", controlspec.new(20, 20000, "exp", 0, 1200), function(param) return (round_form(param:get(), 0.01, " hz")) end)
    params:set_action("cutoff"..i, function(x) engine.cutoff(i, x) end)
    -- filter env
    params:add_number("cutoff_env"..i, "filter env", 0, 1, 0, function(param) return (param:get() == 1 and "on" or "off") end)
    params:set_action("cutoff_env"..i, function(x) engine.cutoff_env(i, x) end)
    -- resonance
    params:add_control("resonance"..i, "filter q", controlspec.new(0, 4, "lin", 0, 0.8), function(param) return (round_form(util.linlin(0, 4, 0, 100, param:get()), 1, "%")) end)
    params:set_action("resonance"..i, function(x) engine.resonance(i, x) end)
    -- attack
    params:add_control("attack"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("attack"..i, function(x) engine.attack(i, x) end)
    -- release
    params:add_control("release"..i, "release", controlspec.new(0.001, 10, "exp", 0, 0.3), function(param) return (round_form(param:get(), 0.01, " s")) end)
    params:set_action("release"..i, function(x) engine.release(i, x) end)
    -- pan
    params:add_control("pan"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0), Formatters.bipolar_as_pan_widget)
    params:set_action("pan"..i, function(x) engine.pan(i, x) end)

    params:add_separator("slews"..i, "slews")
    params:hide("slews"..i)
    -- freq slew
    params:add_control("freq_slew"..i, "frequency slew", controlspec.new(0.001, 10, "exp", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("freq_slew"..i, function(x) engine.freq_slew(i, x) end)
    params:hide("freq_slew"..i)
    -- amp slew
    params:add_control("amp_slew"..i, "level slew", controlspec.new(0.001, 10, "exp", 0, 0), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("amp_slew"..i, function(x) engine.amp_slew(i, x) end)
    params:hide("amp_slew"..i)
    -- noise slew
    params:add_control("noise_slew"..i, "noise slew", controlspec.new(0.001, 10, "exp", 0, 0.5), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("noise_slew"..i, function(x) engine.noise_slew(i, x) end)
    params:hide("noise_slew"..i)
    -- pan slew
    params:add_control("pan_slew"..i, "pan slew", controlspec.new(0.001, 10, "exp", 0, 0.5), function(param) return (round_form(param:get(),0.01," s")) end)
    params:set_action("pan_slew"..i, function(x) engine.pan_slew(i, x) end)
    params:hide("pan_slew"..i)
  end
end

return Moonshine
