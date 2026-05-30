-- crow/ii & arc for nisho v.2.0

local vx = require 'voice'
local lo = include 'lib/nsh_lfo'

local a = arc.connect()

local crow_detected = false
local arc_detected = false
local wsyn_jack = {"ramp", "curve", "fm env", "fm index", "lpg time", "lpg symmetry", "gate", "pitch", "fm ratio num", "fm ratio denom"}

caw = {}

caw.ansi_view = false
caw.viz_ansi_trig = {false, false, false, false}

-- crow
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

-- jf
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
local ansi_cv = {}
for i = 1, 4 do
  ansi_cv[i] = {}
  ansi_cv[i].lvl = 0
  ansi_cv[i].min = 0
  ansi_cv[i].max = 10
  ansi_cv[i].viz = 0
  ansi_cv[i].prev_val = nil
  ansi_cv[i].lfo = {}
end


-------- ansible cv out --------
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

-------- arc interface --------
local arc_lfo_view = false
local arc_shortpress = false
local arc_keypresstimer = nil

function a.key(n, z)
  if z == 1 then
    arc_keypresstimer = clock.run(function()
      arc_shortpress = true
      clock.sleep(0.2)
      arc_shortpress = false
      arc_longpress = true
      arc_keypresstimer = nil
    end)
  else
    if arc_keypresstimer ~= nil then
      clock.cancel(arc_keypresstimer)
    end
    if arc_shortpress then
      arc_lfo_view = not arc_lfo_view
    end
    arc_longpress = false
  end
end

function a.delta(n, d)
  if arc_lfo_view then
    if arc_longpress then
      params:delta("lfo_rate_ansi_cv_"..n, d / 16)
    else
      params:delta("lfo_depth_ansi_cv_"..n, d / 16)
      if ansi_cv[n].lfo.depth == 0 then
        if ansi_cv[n].lfo.enabled == 1 then
          params:set("lfo_ansi_cv_"..n, 1)
        end
      else
        if ansi_cv[n].lfo.enabled == 0 then
          params:set("lfo_ansi_cv_"..n, 2)
        end
      end
    end
  else
    if ansi_cv[n].lfo.enabled == 1 then
      if arc_longpress then
        params:delta("lfo_depth_ansi_cv_"..n, d / 16)
      else
        params:delta("lfo_offset_ansi_cv_"..n, d / 16)
      end
    else
      params:delta("ansible_cv_"..n.."_level", d / 10)
    end
  end
end

function arc_redraw()
  a:all(0)
  for n = 1, 4 do
    local level = math.ceil(ansi_cv[n].lvl * 56) - 27
    a:led(n, 29, 8)
    a:led(n, -27, 8)
    for i = -26, 28 do
      if i < level then
        a:led(n, i, 4)
      end
    end
    a:led(n, level, 15)
    a:led(n, 32, arc_lfo_view and 15 or 0)
    a:led(n, 33, ansi_cv[n].viz)
    a:led(n, 34, arc_lfo_view and 15 or 0)
  end
  a:refresh()
end

----------------------------------- caw --------------------------------------------

function caw.crow_note_on(i, note_num, velocity)
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

function caw.crow_note_off(i)
  local env = i == 1 and 2 or 4
  cw[i].count = cw[i].count - 1
  if cw[i].count < 0 then cw[i].count = 0 end
  if cw[i].count == 0 then
    crow.output[env].action = string.format("{ to(%f,%f,'%s') }", 0, cw[i].env_r, cw[i].env_curve)
    crow.output[env]()
  end
end

function caw.crow_panic(i)
  local env = i == 1 and 2 or 4
  crow.output[env].action = string.format("{ to(%f,%f) }", 0, 0)
  crow.output[env]()
  cw[i].count = 0
end

function caw.jf_note_on(note_num, velocity)
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

function caw.jf_note_off(i, note_num)
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

function caw.jf_panic(i)
  local addr = i or jf.addr
  for n = 1, 6 do
    crow.ii.jf[jf.addr][addr].trigger(n, 0)
    jf.count = 0
  end
end

function caw.wsyn_note_on(note_num, velocity)
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

function caw.wsyn_note_off(note_num)
  local slot = wsyn.notes[note_num]
  if slot ~= nil then
    wsyn.alloc:release(slot)
  end
  wsyn.notes[note_num] = nil
end

function caw.wsyn_panic()
  for i = 1, 4 do
    crow.ii.wsyn.velocity(i, 0)
  end
end

function caw.ansi_trigger(i)
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

function caw.crow_pitchbend(n, val, dir)
  local pb = (cw[n].pb_depth / cw[n].v8_std) * val * dir
  local v8 = cw[n].v8 + pb
  cw[n].pb_v8 = pb
  if cw[n].count > 0 then
    crow.output[(n == 1 and 1 or 3)].volts = v8
  end
end

function caw.jf_pitchbend(i, val, dir)
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

function caw.wsyn_pitchbend(val, dir)
  local pb = (wsyn.pb_depth / 12) * val * dir
  wsyn.pb_v8 = pb
  for n = 1, 4 do
    local v8 = wsyn[n].v8 + pb
    crow.ii.wsyn.pitch(n, v8)
  end
end

function caw.crow_modwheel(n, val)
  local u = n == 1 and 2 or 1
  if not cw[u].active then
    local out = n == 1 and 4 or 2
    crow.output[out].volts = cw[n].mw_depth * val
  end
end

function caw.crow_aftertouch(n, val)
  local u = n == 1 and 2 or 1
  if not cw[u].active then
    local out = n == 1 and 3 or 1
    crow.output[out].volts = cw[n].at_depth * val
  end
end

function caw.detect()
  if norns.crow.connected() then
    crow_detected = true
  end
  if a.device then
    arc_detected = true
  end
end

function caw.detected()
  return crow_detected
end

function caw.manage_ii()
  local ii, crow_1, crow_2 = 0, 0, 0
  for i = 1, NUM_VOICES do
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

function caw.redraw()
  if arc_detected and crow_detected then arc_redraw() end
end

function caw.init()
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

  -- jf params
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

  params:add_control("jf_amp", "level", controlspec.new(0.1, 10, "lin", 0.1, 8.0), function(param) return round_form(param:get(), 0.1, "vpp") end)
  params:set_action("jf_amp", function(val) jf.amp = val end)

  params:add_option("jf_run_mode", "run mode", {"off", "on"}, 1)
  params:set_action("jf_run_mode", function(mode) crow.ii.jf[jf.addr].run_mode(mode - 1) end)

  params:add_control("jf_run_voltage", "run voltage", controlspec.new(-5, 5, "lin", 0, 0), function(param) return round_form(param:get(), 0.1, "v") end)
  params:set_action("jf_run_voltage", function(v) crow.ii.jf[jf.addr].run(v) end)

  -- wsyn params
  params:add_group("wsyn_params", "crow [wsyn]", 15)
  if not crow_detected then params:hide("wsyn_params") end

  params:add_separator("wysn_synth", "synth")

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

  params:add_option("wsyn_this", "this jack", wsyn_jack, 1)
  params:set_action("wsyn_this", function(dest) crow.ii.wsyn.patch(1, dest) end)

  params:add_option("wsyn_that", "that jack", wsyn_jack, 2)
  params:set_action("wsyn_that", function(dest) crow.ii.wsyn.patch(2, dest) end)
  
  params:add_group("ansible_params", "crow [ansible]", (4 + 11) * 4)
  if not crow_detected then params:hide("ansible_params") end

  for i = 1, 4 do
    params:add_separator("ansible_cv_"..i, "ansible cv "..i)

    params:add_control("ansible_cv_"..i.."_level", "level", controlspec.new(0, 1, "lin", 0, 0), function() return display_output_volt(i) end)
    params:set_action("ansible_cv_"..i.."_level", function(val) ansi_cv[i].lvl = val set_output_volt(i) end)

    params:add_control("ansible_cv_"..i.."_min", "min", controlspec.new(0, 10, "lin", 0, 0), function(param) return round_form(param:get(), 0.1, "v") end)
    params:set_action("ansible_cv_"..i.."_min", function(val) ansi_cv[i].min = val clamp_range(i) set_output_volt(i) end)
    
    params:add_control("ansible_cv_"..i.."_max", "max", controlspec.new(0, 10, "lin", 0, 10), function(param) return round_form(param:get(), 0.1, "v") end)
    params:set_action("ansible_cv_"..i.."_max", function(val) ansi_cv[i].max = val clamp_range(i) set_output_volt(i) end)

    ansi_cv[i].lfo = lo:add{min = 0, max = 1, baseline = 'min'}
    ansi_cv[i].lfo:add_params("ansi_cv_"..i, "cv out "..i.." lfo")
    ansi_cv[i].lfo:set("action", function(scaled, raw)
      params:set("ansible_cv_"..i.."_level", scaled)
      ansi_cv[i].viz = math.floor(raw * 12) + 3
    end)
    ansi_cv[i].lfo:set("state_callback", function(enabled)
      if not enabled and ansi_cv[i].prev_val ~= nil then
        params:set("ansible_cv_"..i.."_level", ansi_cv[i].prev_val)
      elseif enabled then
        ansi_cv[i].prev_val = params:get("ansible_cv_"..i.."_level")
      end
      ansi_cv[i].viz = enabled and 3 or 0
    end)
  end
end

return caw
