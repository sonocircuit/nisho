-- moonshine params @danderks
-- adapted for nisho @sonocircuit

local Moonshine = {}
local ControlSpec = require 'controlspec'
local Formatters = require 'formatters'

function round_form(param,quant,form)
  return(util.round(param,quant)..form)
end

local specs = {
  {type = "separator", id = "synthesis", name = "synthesis"},
  {id = 'amp', name = 'level', type = 'control', min = 0, max = 1, warp = 'lin', default = 0.5, formatter = function(param) return (round_form(param:get() * 100, 1, "%")) end},
  {id = 'sub_div', name = 'sub division', type = 'number', min = 1, max = 10, default = 1},
  {id = 'noise_amp', name = 'noise level', type = 'control', min = 0, max = 2, warp = 'lin', default = 0, formatter = function(param) return (round_form(param:get()*100,1,"%")) end},
  {id = 'cutoff', name = 'filter cutoff', type = 'control', min = 20, max = 24000, warp = 'exp', default = 1200, formatter = function(param) return (round_form(param:get(),0.01," hz")) end},
  {id = 'cutoff_env', name = 'filter envelope', type = 'number', min = 0, max = 1, default = 1, formatter = function(param) return (param:get() == 1 and "on" or "off") end},
  {id = 'resonance', name = 'filter q', type = 'control', min = 0, max = 4, warp = 'lin', default = 1, formatter = function(param) return (round_form(util.linlin(0, 4, 0, 100, param:get()), 1, "%")) end},
  {id = 'attack', name = 'attack', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
  {id = 'release', name = 'release', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0.3, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
  {id = 'pan', name = 'pan', type = 'control', min = -1, max = 1, warp = 'lin', default = 0, formatter = Formatters.bipolar_as_pan_widget},
  {type = "separator", id = "slews",name = "slews"},
  {id = 'freq_slew', name = 'frequency slew', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
  {id = 'amp_slew', name = 'level slew', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
  {id = 'noise_slew', name = 'noise level slew', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0.05, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
  {id = 'pan_slew', name = 'pan slew', type = 'control', min = 0.001, max = 10, warp = 'exp', default = 0.5, formatter = function(param) return (round_form(param:get(),0.01," s")) end},
}

-- initialize parameters:
function Moonshine.add_params()
  params:add_separator("moonshine")

  --local voices = {"one", "two", 1, 2, 3, 4, 5, 6, 7, 8}
  local voices = {"all", 1, 2, 3, 4, 5, 6, 7, 8}
  for i = 1, #voices do
    params:add_group("voice ["..voices[i].."]", #specs)
    for j = 1, #specs do 
      local p = specs[j]
      if p.type == 'control' then
        params:add_control(
          voices[i].."_"..p.id,
          p.name,
          ControlSpec.new(p.min, p.max, p.warp, 0, p.default),
          p.formatter
        )
      elseif p.type == 'number' then
        params:add_number(
          voices[i].."_"..p.id,
          p.name,
          p.min,
          p.max,
          p.default,
          p.formatter
        )
      elseif p.type == "option" then
        params:add_option(
          voices[i].."_"..p.id,
          p.name,
          p.options,
          p.default
        )
      elseif p.type == 'separator' then
        params:add_separator(p.id..i, p.name)
      end

      if p.type ~= 'separator' then
        params:set_action(voices[i].."_"..p.id, function(x)
          engine[p.id](voices[i],x)
          if voices[i] == "all" then
            for other_voices = 2, 9 do
              params:set(voices[other_voices].."_"..p.id, x, true)
            end
          end
        end)
      end
    end
  end
  params:bang()
end

return Moonshine
