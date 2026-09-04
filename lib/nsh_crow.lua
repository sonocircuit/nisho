-- crow/ii & arc for nisho - v2.0

local vx = require 'voice'
local lo = include 'lib/nsh_lfo'

local a = arc.connect()
local crow_detected = false
local arc_detected = false

local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

---------------------- crow out ----------------------
local cw = {}
cw.env_shapes = {'logarithmic', 'linear', 'exponential'}
for i = 1, 2 do
  cw[i] = {}
  cw[i].active = false
  cw[i].v8_std = 12
  cw[i].v8 = 0
  cw[i].pb_depth = 7
  cw[i].at_depth = 5
  cw[i].mw_depth = 5
  cw[i].pb_v8 = 0
  cw[i].slew = 0
  cw[i].legato = false
  cw[i].env_amp = 8
  cw[i].env_a = 0
  cw[i].env_d = 0.4
  cw[i].env_s = 0.8
  cw[i].env_r = 0.6
  cw[i].env_curve = 'linear'
  cw[i].count = 0
end

cw.note_on = function(i, note_num, velocity)
  local vel = util.linlin(0, 127, 0, 1, (velocity or 127))
  local cv = i == 1 and 1 or 3
  local env = i == 1 and 2 or 4
  local v = ((note_num - 60) / cw[i].v8_std)
  local v8 = v + cw[i].pb_v8
  cw[i].v8 = v
  if cw[i].count > 0 then
    crow.output[cv].action = string.format("{ to(%f,%f,sine) }", v8, cw[i].slew)
    crow.output[cv]()
  else
    crow.output[cv].volts = v8
  end
  if cw[i].count > 0 and cw[i].legato then
    crow.output[env].action = string.format("{ to(%f,%f,'%s') }", cw[i].env_amp * cw[i].env_s * vel, cw[i].env_d, cw[i].env_curve)
  else
    crow.output[env].action = string.format("{ to(%f,%f,'%s'), to(%f,%f,'%s') }", cw[i].env_amp * vel, cw[i].env_a, cw[i].env_curve, cw[i].env_amp * cw[i].env_s * vel, cw[i].env_d, cw[i].env_curve)
  end
  crow.output[env]()
  cw[i].count = cw[i].count + 1
end

cw.note_off = function(i)
  local env = i == 1 and 2 or 4
  cw[i].count = cw[i].count - 1
  if cw[i].count < 0 then cw[i].count = 0 end
  if cw[i].count == 0 then
    crow.output[env].action = string.format("{ to(%f,%f,'%s') }", 0, cw[i].env_r, cw[i].env_curve)
    crow.output[env]()
  end
end

cw.panic = function(i)
  local env = i == 1 and 2 or 4
  crow.output[env].action = string.format("{ to(%f,%f) }", 0, 0)
  crow.output[env]()
  cw[i].count = 0
end

cw.pitchbend = function(n, val, dir)
  local pb = (cw[n].pb_depth / cw[n].v8_std) * val * dir
  local v8 = cw[n].v8 + pb
  cw[n].pb_v8 = pb
  if cw[n].count > 0 then
    crow.output[(n == 1 and 1 or 3)].volts = v8
  end
end

cw.modwheel = function(n, val)
  local u = n == 1 and 2 or 1
  if not cw[u].active then
    local out = n == 1 and 4 or 2
    crow.output[out].volts = cw[n].mw_depth * val
  end
end

cw.aftertouch = function(n, val)
  local u = n == 1 and 2 or 1
  if not cw[u].active then
    local out = n == 1 and 3 or 1
    crow.output[out].volts = cw[n].at_depth * val
  end
end

cw.add_params = function()
  local crow_options = {"crow [out 1+2]", "crow [out 3+4]"}
  for i = 1, 2 do
    params:add_group("crow_out_"..i, crow_options[i], 15)
    if not crow_detected then params:hide("crow_out_"..i) end

    params:add_separator("crow_pitch_params_"..i, "pitch")

    params:add_option("crow_v8_type_"..i, "v/oct type", {"1 v/oct", "1.2 v/oct"}, 1)
    params:set_action("crow_v8_type_"..i, function(mode) cw[i].v8_std = mode == 1 and 12 or 10 end)

    params:add_option("crow_legato_"..i, "legato", {"off", "on"}, 1)
    params:set_action("crow_legato_"..i, function(mode) cw[i].legato = mode == 2 and true or false end)

    params:add_control("crow_v8_slew_"..i, "slew rate", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_v8_slew_"..i, function(value) cw[i].slew = value end)

    params:add_number("crow_pitchbend_"..i, "pitchbend", 1, 12, 7, function(param) return param:get().."st" end)
    params:set_action("crow_pitchbend_"..i, function(value) cw[i].pb_depth = value end)

    params:add_separator("crow_env_params_"..i, "envelope")

    params:add_control("crow_env_amp_"..i, "env amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8), function(param) return round_form(param:get(), 0.01, "v") end)
    params:set_action("crow_env_amp_"..i, function(value) cw[i].env_amp = value end)

    params:add_option("crow_env_shape_"..i, "env curve", {"exp", "lin", "log"}, 1)
    params:set_action("crow_env_shape_"..i, function(idx) cw[i].env_curve = cw.env_shapes[idx] end)

    params:add_control("crow_env_attack_"..i, "attack", controlspec.new(0.001, 10, "exp", 0, 0.001), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_env_attack_"..i, function(value) cw[i].env_a = value end)

    params:add_control("crow_env_decay_"..i, "decay", controlspec.new(0.01, 10, "exp", 0, 0.4), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_env_decay_"..i, function(value) cw[i].env_d = value end)

    params:add_control("crow_env_sustain_"..i, "sustain", controlspec.new(0, 1, "lin", 0, 0.8), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("crow_env_sustain_"..i, function(value) cw[i].env_s = value end)

    params:add_control("crow_env_release_"..i, "release", controlspec.new(0.01, 10, "exp", 0, 0.8), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("crow_env_release_"..i, function(value) cw[i].env_r = value end)

    params:add_separator("crow_mod_params_"..i, "modulation")
    local atout = {"[out 3]", "[out 1]"}
    local mwout = {"[out 4]", "[out 2]"}

    params:add_control("crow_at_depth_"..i, "aftertouch "..atout[i], controlspec.new(-5, 10, "lin", 0.1, 5), function(param) return round_form(param:get(), 0.01, "v") end)
    params:set_action("crow_at_depth_"..i, function(value) cw[i].at_depth = value end)

    params:add_control("crow_mw_depth_"..i, "modwheel "..mwout[i], controlspec.new(-5, 10, "lin", 0.1, 5), function(param) return round_form(param:get(), 0.01, "v") end)
    params:set_action("crow_mw_depth_"..i, function(value) cw[i].mw_depth = value end)
  end
end


---------------------- just friends ----------------------
local jf = {}
jf.addr = 1
jf.mode = 1
jf.vox_mono = 1
jf.num_poly = 6
jf.poly_alloc = vx.new(6, 2)
jf.poly_notes = {}
jf.count = 0
jf.amp = 5
jf.detune = 0
jf.detune_array = {-0.11002313, -0.06288439, -0.01952356, 0.01991221, 0.06216538, 0.10745242}
jf.pb_depth = 7
for i = 1, 6 do
  jf[i] = {}
  jf[i].pb_v8 = 0
  jf[i].v8 = 0
end

jf.note_on = function(note_num, velocity)
  local vel = util.linlin(0, 127, 0, 1, (velocity or 127)) * jf.amp
  local v = (note_num - 60) / 12
  if jf.mode == 1 then
    local v8 = v + jf[jf.vox_mono].pb_v8
    jf[jf.vox_mono].v8 = v
    crow.ii.jf[jf.addr].play_voice(jf.vox_mono, v8, vel)
    jf.count = jf.count + 1
  elseif jf.mode == 2 then
    local slot = jf.poly_notes[note_num]
    if slot == nil then
      slot = jf.poly_alloc:get()
      slot.count = 1
    end
    slot.on_release = function()
      crow.ii.jf[jf.addr].trigger(slot.id, 0)
    end
    jf.poly_notes[note_num] = slot
    local v8 = v + jf[slot.id].pb_v8
    jf[slot.id].v8 = v
    crow.ii.jf[jf.addr].play_voice(slot.id, v8, vel)
  elseif jf.mode == 3 then
    for n = 1, 6 do
      local v8 = v + jf[n].pb_v8 + (jf.detune_array[n] * (jf.detune/120))
      jf[n].v8 = v
      crow.ii.jf[jf.addr].play_voice(n, v8, vel * 0.707)
    end
    jf.count = jf.count + 1
  end
end

jf.note_off = function(note_num)
  if jf.mode == 1 then
    jf.count = jf.count - 1
    if jf.count < 0 then jf.count = 0 end
    if jf.count == 0 then
      crow.ii.jf[jf.addr].trigger(jf.vox_mono, 0)
    end
  elseif jf.mode == 2 then
    local slot = jf.poly_notes[note_num]
    if slot ~= nil then
      jf.poly_alloc:release(slot)
    end
    jf.poly_notes[note_num] = nil
  elseif jf.mode == 3 then
    jf.count = jf.count - 1
    if jf.count < 0 then jf.count = 0 end
    if jf.count == 0 then
      for n = 1, 6 do
        crow.ii.jf[jf.addr].trigger(n, 0)
      end
    end
  end
end

jf.panic = function()
  for n = 1, 6 do
    crow.ii.jf[jf.addr].trigger(n, 0)
    jf.count = 0
  end
end

jf.pitchbend = function(n, val, dir)
  local pb = (jf.pb_depth / 12) * val * dir
  if jf.mode == 1 then
    local v8 = jf[jf.vox_mono].v8 + pb
    jf[jf.vox_mono].pb_v8 = pb
    crow.ii.jf[jf.addr].pitch(jf.vox_mono, v8)
  else
    for n = 1, jf.num_poly do
      local v8 = jf[n].v8 + pb
      jf[n].pb_v8 = pb
      crow.ii.jf[jf.addr].pitch(n, v8)
    end
  end
end

jf.add_params = function()
  params:add_group("jf_params", "crow [jf]", 9)
  if not crow_detected then params:hide("jf_params") end

  params:add_option("jf_address", "address", {"jf[one]", "jf[two]"}, 1)
  params:set_action("jf_address", function(selected) jf.addr = selected
    local other = selected == 1 and 2 or 1
    caw.jf_panic(other)
    crow.ii.jf[selected].mode(1)
    crow.ii.jf[other].mode(0)
  end)

  params:add_option("jf_mode", "mode", {"mono", "poly", "unison"}, 1)
  params:set_action("jf_mode", function(val) jf.mode = val caw.jf_panic() end)

  params:add_number("jf_mono_voice", "voice", 1, 6, 1, function(param) return jf.mode == 1 and param:get() or "-" end)
  params:set_action("jf_mono_voice", function(val) jf.vox_mono = val caw.jf_panic() end)

  params:add_number("jf_poly_voices", "polyphony", 2, 6, 6, function(param) return jf.mode == 2 and param:get() or "-" end)
  params:set_action("jf_poly_voices", function(val)
    caw.jf_panic()
    jf.num_poly = val
    jf.poly_alloc = nil
    jf.poly_alloc = vx.new(val, 2)
  end)

  params:add_number("jf_detune", "detune", 1, 100, 12, function(param) return jf.mode == 3 and param:get().."%" or "-" end)
  params:set_action("jf_detune", function(val) jf.detune = val end)

  params:add_number("jf_pitchbend", "pitchbend", 1, 12, 7, function(param) return param:get().."st" end)
  params:set_action("jf_pitchbend", function(val) jf.pb_depth = val end)

  params:add_control("jf_level", "level", controlspec.new(0.1, 10, "lin", 0.1, 8.0), function(param) return round_form(param:get(), 0.1, "vpp") end)
  params:set_action("jf_level", function(val) jf.amp = val end)

  params:add_option("jf_run_mode", "run mode", {"off", "on"}, 1)
  params:set_action("jf_run_mode", function(mode) crow.ii.jf[jf.addr].run_mode(mode - 1) end)

  params:add_control("jf_run_voltage", "run voltage", controlspec.new(-5, 5, "lin", 0, 0), function(param) return round_form(param:get(), 0.1, "v") end)
  params:set_action("jf_run_voltage", function(v) crow.ii.jf[jf.addr].run(v) end)
end

---------------------- w/ syn ----------------------
local wsyn = {}
wsyn.jack = {"ramp", "curve", "fm env", "fm index", "lpg time", "lpg symmetry", "gate", "pitch", "fm ratio num", "fm ratio denom"}
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

wsyn.note_on = function(note_num, velocity)
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

wsyn.note_off = function(note_num)
  local slot = wsyn.notes[note_num]
  if slot ~= nil then
    wsyn.alloc:release(slot)
  end
  wsyn.notes[note_num] = nil
end

wsyn.panic = function()
  for i = 1, 4 do
    crow.ii.wsyn.velocity(i, 0)
  end
end

wsyn.pitchbend = function(n, val, dir)
  local pb = (wsyn.pb_depth / 12) * val * dir
  wsyn.pb_v8 = pb
  for n = 1, 4 do
    local v8 = wsyn[n].v8 + pb
    crow.ii.wsyn.pitch(n, v8)
  end
end

wsyn.add_params = function()
  params:add_group("wsyn_params", "crow [wsyn]", 14)
  if not crow_detected then params:hide("wsyn_params") end

  params:add_option("wysn_mode", "wsyn mode", {"hold", "lpg"}, 2)
  params:set_action("wysn_mode", function(mode)
    crow.ii.wsyn.ar_mode(mode - 1)
    params[mode == 2 and "show" or "hide"](params, "wsyn_lpg_time")
    params[mode == 2 and "show" or "hide"](params, "wsyn_lpg_sym")
    _menu.rebuild_params()
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

  params:add_number("wsyn_pitchbend", "pitchbend", 1, 12, 7, function(param) return param:get().."st" end)
  params:set_action("wsyn_pitchbend", function(value) wsyn.pb_depth = value end)

  params:add_separator("wysn_modulation", "modulation")

  params:add_option("wsyn_this", "this jack", wsyn.jack, 1)
  params:set_action("wsyn_this", function(dest) crow.ii.wsyn.patch(1, dest) end)

  params:add_option("wsyn_that", "that jack", wsyn.jack, 2)
  params:set_action("wsyn_that", function(dest) crow.ii.wsyn.patch(2, dest) end)
end


---------------------- w/ del ----------------------

local wdel = {}
wdel.mode = 1
wdel.time = 1
wdel.rate = 3/8
wdel.sync = true
wdel.rate_names = {"1/16", "1/12", "3/32", "1/8", "1/6", "3/16", "1/4","1/3", "3/8", "1/2", "2/3", "3/4", "1"}
wdel.rate_values = {1/16, 1/12, 3/32, 1/8, 1/6, 3/16, 1/4, 1/3, 3/8, 1/2, 2/3, 3/4, 1}

wdel.set_time = function()
  if wdel.mode == 1 then
    local time = clock.get_beat_sec() * wdel.rate
    params:set("wdel_time", time)
  end
end

wdel.set_rate = function()
  if wdel.sync then
    params:set("wdel_time", wdel.rate * clock.get_beat_sec() * 4)
  end
end

wdel.add_params = function()

  crow.ii.wdel.rate(1)
  crow.ii.wdel.length(1, 1)
  crow.ii.wdel.clock_ratio(1, 1)
  
  params:add_group("wdel_params", "crow [wdel]", 8)
  if not crow_detected then params:hide("wdel_params") end

  params:add_control("wdel_mix", "mix", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wdel_mix", function(v) crow.ii.wdel.mix(v) end)

  params:add_option("wdel_mode", "mode", {"free", "clocked"}, 2)
  params:set_action("wdel_mode", function(mode)
    wdel.sync = mode == 2 and true or false
    wdel.set_rate()
    params[mode == 1 and "show" or "hide"](params, "wdel_time")
    params[mode == 2 and "show" or "hide"](params, "wdel_rate")
    _menu.rebuild_params()
  end)

  params:add_control("wdel_time", "time", controlspec.new(0.1, 4, "lin", 0, 0), function(param) return round_form(param:get(), 0.01, "s") end)
  params:set_action("wdel_time", function(x) crow.ii.wdel.time(x)  end)

  params:add_option("wdel_rate", "rate", wdel.rate_names, 6)
  params:set_action("wdel_rate", function(x) wdel.rate = wdel.rate_values[x] wdel.set_rate() end)

  params:add_control("wdel_feedback", "feedback", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wdel_feedback", function(v) crow.ii.wdel.feedback(v) end)

  params:add_control("wdel_filter", "filter", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wdel_filter", function(v) crow.ii.wdel.filter(v) end)

  params:add_control("wdel_mod_rate", "mod rate", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wdel_mod_rate", function(v) crow.ii.wdel.mod_rate(v) end)

  params:add_control("wdel_mod_amount", "mod amount", controlspec.new(-5, 5, "lin", 0, 0, "v"))
  params:set_action("wdel_mod_amount", function(v) crow.ii.wdel.mod_amount(v) end)
end


---------------------- ansible ----------------------
local ansi = {}
for i = 1, 4 do
  ansi[i] = {}
  ansi[i].lvl = 0
  ansi[i].min = 0
  ansi[i].max = 10
  ansi[i].viz = 0
  ansi[i].prev_val = nil
  ansi[i].lfo = {}
end

ansi.arc_lfos = false
ansi.arc_spress = false
ansi.arc_lpress = false
ansi.arc_ktimer = nil

ansi.trig = function(i)
  crow.ii.ansible.trigger_pulse(i)
  if caw.ansi_view then
    clock.run(function()
      caw.viz_ansi_trig[i] = true
      dirtygrid = true
      clock.sleep(1/30)
      caw.viz_ansi_trig[i] = false
      dirtygrid = true
    end)
  end  
end

ansi.volt_display = function(i)
  local volts = util.linlin(0, 1, ansi[i].min, ansi[i].max, ansi[i].lvl)
  return round_form(volts, 0.1, "v")
end

ansi.clamp_range = function(i)
  if ansi[i].min >= ansi[i].max then
    params:set("ansi_cv_"..i.."_min", ansi[i].max - 0.1)
  end
  if ansi[i].max <= ansi[i].min then
    params:set("ansi_cv_"..i.."_max", ansi[i].min + 0.1)
  end
end

ansi.set_volt = function(i)
  local volts = util.linlin(0, 1, ansi[i].min, ansi[i].max, ansi[i].lvl)
  crow.ii.ansible.cv(i, volts)
end

ansi.add_params = function()
  params:add_group("ansi_params", "crow [ansible]", (4 + 11) * 4)
  if not crow_detected then params:hide("ansi_params") end

  for i = 1, 4 do
    params:add_separator("ansi_cv_"..i, "ansible cv "..i)

    params:add_control("ansi_cv_"..i.."_level", "level", controlspec.new(0, 1, "lin", 0, 0), function() return ansi.volt_display(i) end)
    params:set_action("ansi_cv_"..i.."_level", function(val) ansi[i].lvl = val ansi.set_volt(i) end)

    params:add_control("ansi_cv_"..i.."_min", "min", controlspec.new(0, 10, "lin", 0, 0), function(param) return round_form(param:get(), 0.1, "v") end)
    params:set_action("ansi_cv_"..i.."_min", function(val) ansi[i].min = val ansi.clamp_range(i) ansi.set_volt(i) end)
    
    params:add_control("ansi_cv_"..i.."_max", "max", controlspec.new(0, 10, "lin", 0, 10), function(param) return round_form(param:get(), 0.1, "v") end)
    params:set_action("ansi_cv_"..i.."_max", function(val) ansi[i].max = val ansi.clamp_range(i) ansi.set_volt(i) end)

    ansi[i].lfo = lo:add{min = 0, max = 1, baseline = 'min'}
    ansi[i].lfo:add_params("ansi_"..i, "cv out "..i.." lfo")
    ansi[i].lfo:set("action", function(scaled, raw)
      params:set("ansi_cv_"..i.."_level", scaled)
      ansi[i].viz = math.floor(raw * 12) + 3
    end)
    ansi[i].lfo:set("state_callback", function(enabled)
      if not enabled and ansi[i].prev_val ~= nil then
        params:set("ansi_cv_"..i.."_level", ansi[i].prev_val)
      elseif enabled then
        ansi[i].prev_val = params:get("ansi_cv_"..i.."_level")
      end
      ansi[i].viz = enabled and 3 or 0
    end)
  end
end


---------------------- arc ----------------------

function a.key(n, z)
  if z == 1 then
    ansi.arc_ktimer = clock.run(function()
      ansi.arc_spress = true
      clock.sleep(0.2)
      ansi.arc_spress = false
      ansi.arc_lpress = true
      ansi.arc_ktimer = nil
    end)
  else
    if ansi.arc_ktimer ~= nil then
      clock.cancel(ansi.arc_ktimer)
    end
    if ansi.arc_spress then
      ansi.arc_lfos = not ansi.arc_lfos
    end
    ansi.arc_lpress = false
  end
end

function a.delta(n, d)
  if ansi.arc_lfos then
    if ansi.arc_lpress then
      if params:get("lfo_mode_ansi_"..n) == 1 then
        params:delta("lfo_clocked_ansi_"..n, d / 16)
      elseif params:get("lfo_mode_ansi_"..n) == 2 then
        params:delta("lfo_free_ansi_"..n, d / 16)
      end
    else
      params:delta("lfo_depth_ansi_"..n, d / 16)
      if ansi[n].lfo.depth == 0 then
        if ansi[n].lfo.enabled == 1 then
          params:set("lfo_ansi_"..n, 1)
        end
      else
        if ansi[n].lfo.enabled == 0 then
          params:set("lfo_ansi_"..n, 2)
        end
      end
    end
  else
    if ansi[n].lfo.enabled == 1 then
      if ansi.arc_lpress then
        params:delta("lfo_depth_ansi_"..n, d / 16)
      else
        params:delta("lfo_offset_ansi_"..n, d / 16)
      end
    else
      params:delta("ansi_cv_"..n.."_level", d / 10)
    end
  end
end

function arc_redraw()
  local off = -16
  a:all(0)
  for n = 1, 4 do
    local level = math.ceil(ansi[n].lvl * 56) - 27
    a:led(n, 29 + off, 8)
    a:led(n, -27 + off, 8)
    for i = -26, 28 do
      if i < level then
        a:led(n, i + off, 4)
      end
    end
    a:led(n, level + off, 15)
    a:led(n, 32 + off, ansi.arc_lfos and 15 or 0)
    a:led(n, 33 + off, ansi[n].viz)
    a:led(n, 34 + off, ansi.arc_lfos and 15 or 0)
  end
  a:refresh()
end

---------------------- caw caw caw ----------------------

local caw = {}

caw.ansi_view = false
caw.viz_ansi_trig = {false, false, false, false}

function caw.init()
  cw.add_params()
  jf.add_params()
  wsyn.add_params()
  wdel.add_params()
  ansi.add_params()
end

function caw.detect()
  if norns.crow.connected() then
    crow_detected = true
  end
  if a.device then
    arc_detected = true
  end
  if crow_detected and arc_detected then
    arcredrawtimer = metro.init(arc_redraw, 1/20, -1)
    arcredrawtimer:start()
  end
end

function caw.detected()
  return crow_detected
end

function caw.manage_ii()
  local ii, crow_1, crow_2 = 0, 0, 0
  for i = 1, 6 do
    if voice[i].output == 4 then
      crow_1 = crow_1 + 1
    elseif voice[i].output == 5 then
      crow_2 = crow_2 + 1
    elseif voice[i].output == 6 then
      ii = ii + 1
    elseif voice[i].output == 7 then
      crow.ii.wsyn.voices(4)
    end
  end
  crow.ii.jf[jf.addr].mode(ii > 0 and 1 or 0)
  cw[1].active = crow_1 > 0 and true or false
  cw[2].active = crow_2 > 0 and true or false
end

function caw.crow_note_on(i, note_num, velocity)
  cw.note_on(i, note_num, velocity)
end

function caw.crow_note_off(i)
  cw.note_off(i)
end

function caw.crow_panic(i)
  cw.panic(i)
end

function caw.crow_pitchbend(n, val, dir)
  cw.pitchbend(n, val, dir)
end

function caw.crow_modwheel(n, val)
  cw.modwheel(n, val)
end

function caw.crow_aftertouch(n, val)
  cw.aftertouch(n, val)
end

function caw.jf_note_on(note_num, velocity)
  jf.note_on(note_num, velocity)
end

function caw.jf_note_off(note_num)
  jf.note_off(note_num)
end

function caw.jf_panic()
  jf.panic()
end

function caw.jf_pitchbend(i, val, dir)
  jf.pitchbend(n, val, dir)
end

function caw.wsyn_note_on(note_num, velocity)
  wsyn.note_on(note_num, velocity)
end

function caw.wsyn_note_off(note_num)
  wsyn.note_off(note_num)
end

function caw.wsyn_panic()
  wysn.panic()
end

function caw.wsyn_pitchbend(val, dir)
  wysn.pitchbend(n, val, dir)
end

function caw.ansi_trigger(i)
  ansi.trig(i)
end

return caw
