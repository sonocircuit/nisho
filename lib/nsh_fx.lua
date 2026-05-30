-- fx for nisho v.2.0

local del = {}
del.mode = 0
del.sync = true
del.rate_l = 1/4
del.rate_r = 1/4
del.rate_names = {"1/16", "1/12", "3/32", "1/8", "1/6", "3/16", "1/4","1/3", "3/8", "1/2", "2/3", "3/4", "1"}
del.rate_values = {1/16, 1/12, 3/32, 1/8, 1/6, 3/16, 1/4, 1/3, 3/8, 1/2, 2/3, 3/4, 1}

-- display utilities
local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

local function update_delay_params()
  if del.mode == 1 then
    params:hide("ledelay_rate_l")
    params:hide("ledelay_rate_r")
    params:hide("ledelay_time_l")
    params:hide("ledelay_time_r")
    if del.sync then
      params:show("ledelay_rate")
      params:hide("ledelay_time")
    else
      params:hide("ledelay_rate")
      params:show("ledelay_time")
    end
    params:set("ledelay_rate", params:get("ledelay_rate_l"), true)
    params:set("ledelay_time", params:get("ledelay_time_l"), true)
  else
    params:hide("ledelay_time")
    params:hide("ledelay_rate")
    if del.sync then
      params:show("ledelay_rate_l")
      params:show("ledelay_rate_r")
      params:hide("ledelay_time_l")
      params:hide("ledelay_time_r")
    else
      params:hide("ledelay_rate_l")
      params:hide("ledelay_rate_r")
      params:show("ledelay_time_l")
      params:show("ledelay_time_r")
    end
  end
  _menu.rebuild_params()
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

local function set_rates()
  if del.sync then
    local beat_sec = clock.get_beat_sec()
    params:set("ledelay_time_l", del.rate_l * beat_sec * 4)
    params:set("ledelay_time_r", del.rate_r * beat_sec * 4)
  end
end

local function add_params()
  params:add_group("nisho_ledelay", "fx [delay]", 14)

  params:add_control("ledelay_level", "level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("ledelay_level", function(x) engine.fx_set_param("delay", "amp", x) end)

  params:add_control("ledelay_send", "send [reverb]", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("ledelay_send", function(x) engine.fx_set_param("delay", "send", x) end)

  params:add_option("ledelay_type", "type", {"stereo", "dual mono", "ping pong"}, 1)
  params:set_action("ledelay_type", function(x) del.mode = x engine.fx_set_param("delay", "mode", x - 1) update_delay_params() end)

  params:add_option("ledelay_mode", "mode", {"free", "clocked"}, 2)
  params:set_action("ledelay_mode", function(x) del.sync = x == 2 and true or false set_rates() update_delay_params() end)

  params:add_control("ledelay_time_l", "time L", controlspec.new(0.1, 4, "lin", 0, 1.2), function(param) return round_form(param:get(), 0.01, "s") end)
  params:set_action("ledelay_time_l", function(x) engine.fx_set_param("delay", "timeL", x) end)

  params:add_control("ledelay_time_r", "time R", controlspec.new(0.1, 4, "lin", 0, 6), function(param) return round_form(param:get(), 0.01, "s") end)
  params:set_action("ledelay_time_r", function(x) engine.fx_set_param("delay", "timeR", x) end)

  params:add_option("ledelay_rate_l", "rate L", del.rate_names, 6)
  params:set_action("ledelay_rate_l", function(x) del.rate_l = del.rate_values[x] set_rates() end)

  params:add_option("ledelay_rate_r", "rate R", del.rate_names, 4)
  params:set_action("ledelay_rate_r", function(x) del.rate_r = del.rate_values[x] set_rates() end)

  params:add_control("ledelay_time", "time", controlspec.new(0.1, 4, "lin", 0, 0), function(param) return round_form(param:get(), 0.01, "s") end)
  params:set_action("ledelay_time", function(x) params:set("ledelay_time_l", x) end)

  params:add_option("ledelay_rate", "rate", del.rate_names, 6)
  params:set_action("ledelay_rate", function(x) params:set("ledelay_rate_l", x) end)

  params:add_control("ledelay_feedback", "feedback", controlspec.new(0, 1, "lin", 0, 0.6), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("ledelay_feedback", function(x) engine.fx_set_param("delay", "fb", x) end)

  params:add_control("ledelay_lpf_cutoff", "lowpass", controlspec.new(20, 18000, "exp", 0, 1600), function(param) return round_form(param:get(), 1, " hz") end)
  params:set_action("ledelay_lpf_cutoff", function(x) engine.fx_set_param("delay", "hzLpf", x) end)

  params:add_control("ledelay_hpf_cutoff", "highpass", controlspec.new(20, 18000, "exp", 0, 80), function(param) return round_form(param:get(), 1, " hz") end)
  params:set_action("ledelay_hpf_cutoff", function(x) engine.fx_set_param("delay", "hzHpf", x) end)

  params:add_control("ledelay_modulation", "mod depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("ledelay_modulation", function(x) engine.fx_set_param("delay","mod", x) end)

  
  params:add_group("fx_leverb", "fx [plate]", 7)

  params:add_control("leverb_level", "level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("leverb_level", function(x) engine.fx_set_param("reverb", "amp", x) end)

  params:add_control("leverb_pre_filter", "pre filter", controlspec.new(0, 1, "lin", 0, 0.12), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("leverb_pre_filter", function(x) engine.fx_set_param("reverb", "preFilter", x) end)

  params:add_number("leverb_pre_delay", "pre delay", 0, 500, 30, function(param) return param:get().."ms" end)
  params:set_action("leverb_pre_delay", function(x) engine.fx_set_param("reverb", "preDelay", x * 0.001) end)

  params:add_control("leverb_decay", "decay time", controlspec.new(0, 1, "lin", 0, 0.72), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("leverb_decay", function(x) engine.fx_set_param("reverb", "decayRate", x) end)

  params:add_control("leverb_damp", "damping", controlspec.new(0, 1, "lin", 0, 0.40), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("leverb_damp", function(x) engine.fx_set_param("reverb", "damping", x) end)

  params:add_control("leverb_mod_rate", "mod rate", controlspec.new(0.1, 3.6, "exp", 0, 1.2), function(param) return round_form(param:get(), 0.01, " hz") end)
  params:set_action("leverb_mod_rate", function(x) engine.fx_set_param("reverb", "modRate", x) end)

  params:add_control("leverb_mod_depth", "mod depth", controlspec.new(0, 1, "lin", 0, 0.32), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("leverb_mod_depth", function(x) engine.fx_set_param("reverb", "modDepth", x) end)

  params:add_group("sum_stage", "fx [sum]", 3)

  params:add_control("sum_level", "level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("sum_level", function(x) engine.sum_set_param("level", x) end)

  params:add_control("sum_hz_lo", "cutoff lpf", controlspec.new(80, 20000, "exp", 0, 20000), function(param) return round_form(param:get(), 1, "hz") end)
  params:set_action("sum_hz_lo", function(x) engine.sum_set_param("loHz", x) end)

  params:add_control("sum_hz_hi", "cutoff hpf", controlspec.new(20, 8000, "exp", 0, 20), function(param) return round_form(param:get(), 1, "hz") end)
  params:set_action("sum_hz_hi", function(x) engine.sum_set_param("hiHz", x) end)

end

------------------- fx -------------------

local fx = {}

function fx.update_rates()
  set_rates()
end

-- initialize
function fx.init()
  add_params()
end

return fx
