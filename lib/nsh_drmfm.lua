-- drmfm for nisho - v2.0.0

local fs = require 'fileselect'
local tx = require 'textentry'
local mu = require 'musicutil'
local md = require 'core/mods'

local NUM_VOICES = 16
local MAX_LENGTH = math.pow(2, 24)

local perf_clk = nil

local kit = {}
kit.preset_path = norns.state.data.."drmfm_kits"
kit.voice_path = norns.state.data.."drmfm_voices"
kit.default = norns.state.data.."drmfm_kits/default.kit"
kit.failsafe = norns.state.path.."data/drmfm_kits/default.kit"
kit.loaded = ""
kit.clipboard = {}
kit.list = {}

local vox = {}
vox.models = {"BD", "SD", "XT", "CP", "RS", "CB", "HH", "CY", "OC", "UW", "MIDI"}
vox.selected = 1
for i = 1, NUM_VOICES do
  vox[i] = {}
  vox[i].model = "UW"
  vox[i].uw_mode = 1
  vox[i].sample_name = ""
  vox[i].sample_len = 0
  vox[i].sample_ch = ""
  vox[i].midi_dev = 0
  vox[i].midi_ch = 1
  vox[i].midi_note = 48
  vox[i].midi_vel = 100
  vox[i].midi_rise = 4
  vox[i].midi_fall = 0.5
  vox[i].midi_ccA_num = 0
  vox[i].midi_ccB_num = 0
  vox[i].midi_ccA_min = 0
  vox[i].midi_ccA_max = 127
  vox[i].midi_ccB_min = 0
  vox[i].midi_ccB_max = 127
  vox[i].midi_ccA_mod = 0
  vox[i].midi_ccB_mod = 0
end

local prms = {}
prms.kit = {
  "model", "uw_sample", "uw_mode", "uw_pitch", "level", "dist", "pan", "pan_drift", "send_a", "send_b", "pitch", "tune", "decay", "decay_drift",
  "mod1", "mod2", "mod3", "mod4", "mod5", "mod6", "lpf_cutoff", "lpf_resonance", "hpf_cutoff", "hpf_resonance",
  "midi_device", "midi_channel", "midi_note", "midi_vel", "midi_ccA_num", "midi_ccB_num", "dist_pmc", "send_a_pmc", "send_b_pmc", "decay_pmc",
  "mod1_pmc", "mod2_pmc", "mod3_pmc", "mod4_pmc", "mod5_pmc", "mod6_pmc", "lpf_cutoff_pmc", "hpf_cutoff_pmc", "midi_ccA_pmc", "midi_ccB_pmc"
}

prms.hide = {
  "model", "uw_params", "uw_sample", "uw_clear", "uw_mode", "uw_pitch", "levels", "level", "dist", "pan", "pan_drift", "send_a", "send_b", "synthesis",
  "pitch", "tune", "decay", "decay_drift", "sample_params", "mod1", "mod2", "mod3", "mod4", "mod5", "mod6", "filters", "lpf_cutoff", "lpf_resonance",
  "hpf_cutoff", "hpf_resonance", "midi", "midi_device", "midi_note", "midi_channel", "midi_ccA_num", "midi_ccB_num", "dist_pmc",
  "send_a_pmc", "send_b_pmc", "decay_pmc", "mod1_pmc", "mod2_pmc", "mod3_pmc", "mod4_pmc", "mod5_pmc", "mod6_pmc", "lpf_cutoff_pmc", "hpf_cutoff_pmc",
  "midi_ccA_pmc", "midi_ccB_pmc"
}

prms.vox = {
  "model", "levels", "level", "dist", "pan", "pan_drift", "send_a", "send_b", "synthesis", "pitch", "tune", "decay", "decay_drift",
  "mod1", "mod2", "mod3", "mod4", "mod5", "mod6", "filters", "lpf_cutoff", "lpf_resonance", "hpf_cutoff", "hpf_resonance",
  "dist_pmc", "send_a_pmc", "send_b_pmc", "decay_pmc", "mod1_pmc", "mod2_pmc", "mod3_pmc", "mod4_pmc", "mod5_pmc", "mod6_pmc", "lpf_cutoff_pmc", "hpf_cutoff_pmc"
}

prms.uw = {
  "model", "uw_params", "uw_sample", "uw_clear", "uw_mode", "levels", "level", "dist", "pan", "pan_drift", "send_a", "send_b", "sample_params", "uw_pitch",
  "mod1", "mod2", "mod3", "mod4", "mod5", "mod6", "filters", "lpf_cutoff", "lpf_resonance", "hpf_cutoff", "hpf_resonance", "dist_pmc",
  "send_a_pmc", "send_b_pmc", "mod1_pmc", "mod2_pmc", "mod3_pmc", "mod4_pmc", "lpf_cutoff_pmc", "hpf_cutoff_pmc"
}

prms.midi = {
  "model", "midi", "midi_device", "midi_note", "midi_vel", "midi_channel", "midi_ccA_num", "midi_ccB_num", "midi_ccA_pmc", "midi_ccB_pmc"
}

prms.specs = {
  BD = {
    names = {"sweep depth", "sweep decay", "mod depth", "mod ratio", "mod decay", "mod feedback"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 1, 5, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
    },
    default = {pitch = 24, decay = 0.1, mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  SD = {
    names = {"noise level", "noise decay", "noise colour", "mod depth", "mod ratio", "mod decay"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 1, 10, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  XT = {
    names = {"sweep depth", "sweep decay", "transients", "mod depth", "mod ratio", "mod decay"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, -100, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 1, 6, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  CP = {
    names = {"num claps", "clap decay", "noise level", "mod depth", "mod ratio", "mod decay"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 1, 12, param:get()), 1, "") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 1, 10, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  RS = {
    names = {"rim mod", "rim ratio", "snr level", "snr decay", "snr mod", "snr ratio"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 1, 5, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 40, 600, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 10, param:get()), 0.1, "*") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  CB = {
    names = {"snap", "feedback", "detune", "mod depth", "mod ratio", "mod decay"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 10, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  CY = {
    names = {"hold", "noise level", "tone", "mod depth", "mod ratio", "mod decay"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 2200, 8800, param:get()), 1, "hz") end,
      function(param) return round_form(util.linlin(0, 1, 10, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 1.8, 2.2, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 100, 400, param:get()), 1, "%") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  HH = {
    names = {"hold", "feedback", "tone", "mod depth", "mod ratio", "mod decay"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 2200, 8800, param:get()), 1, "hz") end,
      function(param) return round_form(util.linlin(0, 1, 20, 200, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 2, 12, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 240, param:get()), 1, "%") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  OC = {
    names = {"noise level", "wave fold", "dest [car/mod]", "mod depth", "mod ratio", "mod decay"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param)  val = math.floor(param:get() * 100) return ((100 - val).."/"..val) end,
      function(param) return round_form(util.linlin(0, 1, -100, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 1, 10, param:get()), 0.1, "*") end,
      function(param) return round_form(util.linlin(0, 1, 0, 200, param:get()), 1, "%") end
    },
    default = {mod1 = 0, mod2 = 0, mod3 = 0, mod4 = 0.7, mod5 = 0.1, mod6 = 0.05}
  },
  UW = {
    names = {"tune", "direction", "start", "end", "fade in", "fade out"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, -100, 100, param:get()), 1, "ct") end,
      function(param) return param:get() > 0.5 and "fwd" or "rev" end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linexp(0, 1, 0.01, 2, param:get()), 0.01, "s") end,
      function(param) return round_form(util.linexp(0, 1, 0.01, 2, param:get()), 0.01, "s") end
    },
    default = {mod1 = 0.5, mod2 = 1, mod3 = 0, mod4 = 1, mod5 = 0, mod6 = 0}
  },
  MIDI = {
    names = {"-", "-", "-", "-", "-", "-"},
    formatters = {
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end,
      function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end
    },
    default = {}
  },
}
  
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

local function build_menu()
  for i = 1, NUM_VOICES do
    for _, v in ipairs(prms.hide) do
      params:hide("drmfm_"..v.."_"..i)
    end
    if vox.selected == i then
      if vox[i].model == "UW" then
        for _, v in ipairs(prms.uw) do
          params:show("drmfm_"..v.."_"..i)
        end
      elseif vox[i].model == "MIDI" then
        for _, v in ipairs(prms.midi) do
          params:show("drmfm_"..v.."_"..i)
        end
      else
        for _, v in ipairs(prms.vox) do
          params:show("drmfm_"..v.."_"..i)
        end
      end
    end
  end
  _menu.rebuild_params()
end

local function update_modparams(i)
  local t = prms.specs[vox[i].model]
  for n = 1, 6 do
    local p = params:lookup_param("drmfm_mod"..n.."_"..i)
    p.name = t.names[n]
    p.formatter = t.formatters[n]
    p:bang()
    local m = params:lookup_param("drmfm_mod"..n.."_pmc_"..i)
    m.name = t.names[n]
    m:bang()
  end
  build_menu()
end

local function set_default(i)
  local t = prms.specs[vox[i].model]
  if next(t.default) then
    for k, v in pairs(t.default) do
      params:set("drmfm_"..k.."_"..i, v)
    end
  end
end

local function set_model(i, idx)
  vox[i].model = vox.models[idx]
  update_modparams(i)
  engine.drmfm_set_def(i - 1, vox[i].model)
end

local function set_param(i, key, val)
  engine.set_drmfm(i - 1, key, val)
  page_redraw(2)
end

local function set_perf_macros(val)
  engine.drmfm_perf(val)
  for i = 1, NUM_VOICES do
    if vox[i].model == "MIDI" then
      if vox[i].midi_ccA_mod ~= 0 and vox[i].midi_ccA_num > 0 then
        local cc_val = math.floor(vox[i].midi_ccA_mod * val)
        vox[i].midi_dev:cc(vox[i].midi_ccA_num, cc_val)
      end
      if vox[i].midi_ccB_mod ~= 0 and vox[i].midi_ccB_num > 0 then
        local cc_val = math.floor(vox[i].midi_ccB_mod * val)
        vox[i].midi_dev:cc(vox[i].midi_ccB_num, cc_val)
      end
    end
  end
end

local function build_kit_list()
  local files = util.scandir(kit.preset_path)
  kit.list = {}
  for i = 1, #files do
    if files[i]:match("^.+(%..+)$") == ".kit" then
      local num = tonumber(files[i]:match(".-%d+"))
      if num ~= nil then
        kit.list[num] = files[i]
      end
    end
  end
end

local function save_drmfm_kit(txt)
  if txt then
    local t = {}
    t["main_level"] = params:get("drmfm_main_level")
    t["perf_time"] = params:get("drmfm_perf_time")
    for n = 1, NUM_VOICES do
      t[n] = {}
      for _, v in ipairs(prms.kit) do
        t[n][v] = params:get("drmfm_"..v.."_"..n)
      end
    end
    tab.save(t, kit.preset_path.."/"..txt..".kit")
    kit.loaded = txt
    build_kit_list()
    print("saved drmfm kit: "..txt)
  end
end

local function load_drmfm_kit(path)
  if path ~= "cancel" and path ~= "" and path ~= kit.preset_path then
    if path:match("^.+(%..+)$") == ".kit" then
      local t = tab.load(path)
      if t ~= nil then
        params:set("drmfm_main_level", t["main_level"])
        params:set("drmfm_perf_time", t["perf_time"])
        for n = 1, NUM_VOICES do
          for _, v in ipairs(prms.kit) do
            if t[n][v] ~= nil then
              params:set("drmfm_"..v.."_"..n, t[n][v])
            end
          end
        end
        local name = path:match("[^/]*$")
        kit.loaded = name:gsub(".kit", "")
        print("loaded drmfm kit: "..kit.loaded)
      else
        if util.file_exists(kit.failsafe) then
          load_drmfm_kit(kit.failsafe)
        end
        print("error: could not find kit", path)
      end
    else
      print("error: not a kit file")
    end
  end
  screenredrawtimer:start()
end

local function save_drmfm_voice(txt)
  if txt then
    local t = {}
    for _, v in ipairs(prms.kit) do
      t[v] = params:get("drmfm_"..v.."_"..vox.selected)
    end
    tab.save(t, kit.voice_path.."/"..txt..".kvox")
    print("saved drmfm voice: "..txt)
  end
end

local function load_drmfm_voice(path)
  if path ~= "cancel" and path ~= "" and path ~= kit.voice_path then
    if path:match("^.+(%..+)$") == ".kvox" then
      local t = tab.load(path)
      if t ~= nil then
        for _, v in ipairs(prms.kit) do
          if t[v] ~= nil then
            params:set("drmfm_"..v.."_"..vox.selected, t[v])
          end
        end
        local name = path:match("[^/]*$"):gsub(".kvox", "")
        print("loaded drmfm voice: "..name)
      else
        print("error: could not find voice", path)
      end
    else
      print("error: not a voice file")
    end
  end
  screenredrawtimer:start()
end

local function load_sample(i, path)
  if (path ~= "cancel" and path ~= "" and path ~= _path.audio) then
    local ch, samples = audio.file_info(path)
    if ch > 0 and ch < 3 and samples > 1 then
      if samples < MAX_LENGTH then
        engine.load_sample(i - 1, path)
        vox[i].sample_name = path:match("[^/]*$")
        vox[i].sample_len = util.round(samples/48000, 0.01)
        vox[i].sample_ch = ch == 2 and "stereo" or "mono"
        params:set("drmfm_uw_sample_"..i, path, true)
      else
        print("max length exceeded: "..path)
      end
    else
      print("file not supported: "..path)
    end
  end
  screenredrawtimer:start()
end

local function clear_sample(i)
  engine.clear_sample(i - 1)
  params:set("drmfm_uw_sample_"..i, "", true)
  vox[i].sample_name = ""
  vox[i].sample_len = 0
  vox[i].sample_ch = ""
end

local function viz_pulse(i)
  drmfm.viz[i] = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(1/30)
    drmfm.viz[i] = false
    dirtygrid = true
  end)
end

local function add_params()
  local send_a_name = md.is_loaded("fx") and "send a" or "delay send"
  local send_b_name = md.is_loaded("fx") and "send b" or "reverb send" 

  params:add_group("drmfm_params", "drmFM [kit]", ((NUM_VOICES * 51) + 14))

  params:add_separator("drmfm_kits", "drmFM kit")

  params:add_trigger("drmfm_load_kit", ">> load", "")
  params:set_action("drmfm_load_kit", function(path) fs.enter(kit.preset_path, function(path) load_drmfm_kit(path) end) screenredrawtimer:stop() end)

  params:add_trigger("drmfm_save_kit", "<< save")
  params:set_action("drmfm_save_kit", function() tx.enter(save_drmfm_kit, kit.loaded)  end)
   
  params:add_separator("drmfm_settings", "drmFM settings")

  params:add_control("drmfm_main_level", "main level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("drmfm_main_level", function(val) engine.set_drmfm_level(val) end)

  params:add_trigger("drmfm_load_voice", "> load voice")
  params:set_action("drmfm_load_voice", function() fs.enter(kit.voice_path, function(path) load_drmfm_voice(path) end) screenredrawtimer:stop() end)

  params:add_trigger("drmfm_save_voice", "< save voice")
  params:set_action("drmfm_save_voice", function() tx.enter(save_drmfm_voice, vox[vox.selected].model.."_") end)

  params:add_separator("drmfm_voice", "drmFM voice")

  params:add_number("drmfm_selected_voice", "selected voice", 1, NUM_VOICES, 1)
  params:set_action("drmfm_selected_voice", function(val) vox.selected = val build_menu() end)
   
  for i = 1, NUM_VOICES do
    params:add_option("drmfm_model_"..i, "model", vox.models, tab.key(vox.models, "UW"))
    params:set_action("drmfm_model_"..i, function(idx) set_model(i, idx) end)
  end

  params:add_trigger("drmfm_set_defaults", "set default >>")
  params:set_action("drmfm_set_defaults", function() set_default(vox.selected) end)

  for i = 1, NUM_VOICES do
    ----- UW model params -----
    params:add_separator("drmfm_uw_params_"..i, "sample")
    params:add_file("drmfm_uw_sample_"..i, "load sample", _path.audio)
    params:set_action("drmfm_uw_sample_"..i, function(path) load_sample(i, path) end)

    params:add_binary("drmfm_uw_clear_"..i, "clear sample", "trigger")
    params:set_action("drmfm_uw_clear_"..i, function() clear_sample(i) end)

    params:add_option("drmfm_uw_mode_"..i, "mode", {"oneshot", "hold"}, 1)
    params:set_action("drmfm_uw_mode_"..i, function(val) vox[i].uw_mode = val set_param(i, "mode", val - 1) end)

    ----- DRM model params -----
    params:add_separator("drmfm_levels_"..i, "levels")
    params:add_control("drmfm_level_"..i, "level", controlspec.new(0, 2, "lin", 0, 1, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_level_"..i, function(val) set_param(i, "amp", val) end)

    params:add_control("drmfm_dist_"..i, "distortion", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_dist_"..i, function(val) set_param(i, "dist", val) end)

    params:add_control("drmfm_pan_"..i, "pan", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return pan_display(param:get()) end)
    params:set_action("drmfm_pan_"..i, function(val) set_param(i, "pan", val) end)

    params:add_control("drmfm_pan_drift_"..i, "pan drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_pan_drift_"..i, function(val) set_param(i, "panRnd", val) end)
    
    params:add_control("drmfm_send_a_"..i, send_a_name, controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_send_a_"..i, function(val) set_param(i, "sendA", val) end)
    
    params:add_control("drmfm_send_b_"..i, send_b_name, controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_send_b_"..i, function(val) set_param(i, "sendB", val) end)

    params:add_separator("drmfm_synthesis_"..i, "synthesis")
    params:add_number("drmfm_pitch_"..i, "pitch", 12, 95, 24, function(param) return mu.note_num_to_name(param:get(), true) end)
    params:set_action("drmfm_pitch_"..i, function(val) set_param(i, "note", val) end)

    params:add_number("drmfm_tune_"..i, "tune", -100, 100, 0, function(param) return round_form(param:get(), 1, "ct") end)
    params:set_action("drmfm_tune_"..i, function(val) set_param(i, "tune", math.floor(val / 100)) end)

    params:add_control("drmfm_decay_"..i, "decay", controlspec.new(0.01, 4, "exp", 0, 0.1, "", 1/200), function(param) return round_form(param:get(), 0.01, "s") end)
    params:set_action("drmfm_decay_"..i, function(val) set_param(i, "decay", val) end)

    params:add_control("drmfm_decay_drift_"..i, "decay drift", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_decay_drift_"..i, function(val) set_param(i, "decRnd", val) end)

    params:add_separator("drmfm_sample_params_"..i, "sample settings")
    params:add_number("drmfm_uw_pitch_"..i, "pitch", -24, 24, 0, function(param) return param:get().."st" end)
    params:set_action("drmfm_uw_pitch_"..i, function(val) set_param(i, "pitch", val) end)

    for n = 1, 6 do
      params:add_control("drmfm_mod"..n.."_"..i, "mod"..n, controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
      params:set_action("drmfm_mod"..n.."_"..i, function(val) set_param(i, "mod"..n, val) end)
    end

    params:add_separator("drmfm_filters_"..i, "filters")
    params:add_control("drmfm_lpf_cutoff_"..i, "lpf cutoff", controlspec.new(20, 18000, "exp", 0, 18000, "", 1/200), function(param) return round_form(param:get(), 1, " hz") end)
    params:set_action("drmfm_lpf_cutoff_"..i, function(val) set_param(i, "lpfHz", val)  end)

    params:add_control("drmfm_lpf_resonance_"..i, "lpf resonance", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_lpf_resonance_"..i, function(val) set_param(i, "lpfRz", val) end)
    
    params:add_control("drmfm_hpf_cutoff_"..i, "hpf cutoff", controlspec.new(20, 18000, "exp", 0, 20, "", 1/200), function(param) return round_form(param:get(), 1, " hz") end)
    params:set_action("drmfm_hpf_cutoff_"..i, function(val) set_param(i, "hpfHz", val) end)

    params:add_control("drmfm_hpf_resonance_"..i, "hpf resonance", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_hpf_resonance_"..i, function(val) set_param(i, "hpfRz", val) end)

    ----- MIDI model params -----
    params:add_separator("drmfm_midi_"..i, "midi")
    params:add_option("drmfm_midi_device_"..i, "midi device", midi_devices, 1)
    params:set_action("drmfm_midi_device_"..i, function(val) vox[i].midi_dev = midi.connect(val) end)

    params:add_number("drmfm_midi_channel_"..i, "midi channel", 1, 16, 1)
    params:set_action("drmfm_midi_channel_"..i, function(val) vox[i].midi_ch = val end)

    params:add_number("drmfm_midi_note_"..i, "midi note", 0, 127, 60 + i, function(param) return mu.note_num_to_name(param:get(), true) end)
    params:set_action("drmfm_midi_note_"..i, function(val) vox[i].midi_note = val end)

    params:add_number("drmfm_midi_vel_"..i, "velocity", 0, 127, 100)
    params:set_action("drmfm_midi_vel_"..i, function(val) vox[i].midi_vel = val end)

    params:add_number("drmfm_midi_ccA_num_"..i, "cc A number", 0, 127, 0, function(param) return param:get() == 0 and "off" or param:get() end)
    params:set_action("drmfm_midi_ccA_num_"..i, function(val) vox[i].midi_ccA_num = val end)

    params:add_number("drmfm_midi_ccB_num_"..i, "cc B number", 0, 127, 0, function(param) return param:get() == 0 and "off" or param:get() end)
    params:set_action("drmfm_midi_ccB_num_"..i, function(val) vox[i].midi_ccB_num = val end)
  end

  params:add_separator("drmfm_modulation_settings", "mod settings")

  params:add_control("drmfm_perf_depth", "mod depth", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get() * 100, 1, "%") end)
  params:set_action("drmfm_perf_depth", function(val) set_perf_macros(val) end)

  params:add_number("drmfm_perf_time", "mod duration", 2, 32, 8, function(param) return param:get().." beats" end)

  params:add_separator("drmfm_modulation_depth", "mod dest")

  for i = 1, NUM_VOICES do
    params:add_control("drmfm_dist_pmc_"..i, "distortion", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_dist_pmc_"..i, function(val) set_param(i, "distM", val)  end)

    params:add_control("drmfm_send_a_pmc_"..i, send_a_name, controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_send_a_pmc_"..i, function(val) set_param(i, "sendAM", val) end)

    params:add_control("drmfm_send_b_pmc_"..i, send_b_name, controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_send_b_pmc_"..i, function(val) set_param(i, "sendBM", val) end)
    
    params:add_control("drmfm_decay_pmc_"..i, "decay", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_decay_pmc_"..i, function(val) set_param(i, "decayM", val) end)

    for n = 1, 6 do
      params:add_control("drmfm_mod"..n.."_pmc_"..i, "mod"..n, controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
      params:set_action("drmfm_mod"..n.."_pmc_"..i, function(val) local key = ("mod"..n.."M") set_param(i, key, val)  end)
    end

    params:add_control("drmfm_lpf_cutoff_pmc_"..i, "lpf cutoff", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_lpf_cutoff_pmc_"..i, function(val) set_param(i, "lpfM", val) end)

    params:add_control("drmfm_hpf_cutoff_pmc_"..i, "hpf cutoff", controlspec.new(-1, 1, "lin", 0, 0, "", 1/200), function(param) return round_form(param:get() * 100, 1, "%") end)
    params:set_action("drmfm_hpf_cutoff_pmc_"..i, function(val) set_param(i, "hpfM", val) end)

    ----- MIDI model params -----
    params:add_number("drmfm_midi_ccA_pmc_"..i, "cc A depth", -127, 127, 0)
    params:set_action("drmfm_midi_ccA_pmc_"..i, function(val) vox[i].midi_ccA_mod = val end)

    params:add_number("drmfm_midi_ccB_pmc_"..i, "cc B depth", -127, 127, 0)
    params:set_action("drmfm_midi_ccB_pmc_"..i, function(val) vox[i].midi_ccB_mod = val end)
  end
end


------------------- drmfm -------------------

drmfm = {}
drmfm.copy_data = false
drmfm.viz = {}
drmfm.model = {}
for i = 1, NUM_VOICES do
  drmfm.viz[i] = false
  drmfm.model[i] = ""
end

function drmfm.init()
  if util.file_exists(kit.preset_path) == false then
    util.make_dir(kit.preset_path)
    os.execute('cp '.. norns.state.path .. 'data/drmfm_kits/*.kit '.. kit.preset_path)
  end
  if util.file_exists(kit.voice_path) == false then
    util.make_dir(kit.voice_path)
    os.execute('cp '.. norns.state.path .. 'data/drmfm_voices/*.kitvox '.. kit.voice_path)
  end
  build_kit_list()
  add_params()
end

function drmfm.get_model(i)
  return vox[i].model
end

function drmfm.get_file_info(i)
  local info = {}
  info.name = vox[i].sample_name
  info.len = vox[i].sample_len
  info.ch = vox[i].sample_ch
  return info
end

function drmfm.print_params(i) -- 4 debug
  for _, v in ipairs(prms.kit) do
    print(v, params:get("drmfm_"..v.."_"..i))
  end
end

function drmfm.init_model(i)
  set_default(i)
  show_message(i..":  set  to  default")
end

function drmfm.load_default()
  if kit.default ~= nil then
    load_drmfm_kit(kit.default)
  else
    if util.file_exists(kit.failsafe) then
      load_drmfm_kit(kit.failsafe)
    end
  end
end

function drmfm.load_kit()
  fs.enter(kit.preset_path, function(path) load_drmfm_kit(path) end)
  screenredrawtimer:stop()
end

function drmfm.load_voice()
  fs.enter(kit.voice_path, function(path) load_drmfm_voice(path) end)
  screenredrawtimer:stop()
end

function drmfm.load_sample(i)
  fs.enter(_path.audio, function(path) load_sample(i, path) end)
  screenredrawtimer:stop()
end

function drmfm.clear_sample(i)
  clear_sample(i)
end

function drmfm.prc_load(num)
  if kit.list[num] ~= nil then
    load_drmfm_kit(kit.preset_path.."/"..kit.list[num])
  else
    print("error: unvalid kit number: "..num)
  end
end

function drmfm.init_copy(z)
  if z == 0 then
    kit.clipboard = {}
    drmfm.copy_data = false
  end
end

function drmfm.exec_copy(i)
  if next(kit.clipboard) then
    for _,v in ipairs(prms.kit) do
      params:set("drmfm_"..v.."_"..i , kit.clipboard[v])
    end
    show_message("pasted   drmFM   voice")
  else
    for _,v in ipairs(prms.kit) do 
      kit.clipboard[v] = params:get("drmfm_"..v.."_"..i)
    end
    drmfm.copy_data = true
    show_message("copied   drmFM   voice   "..i)
  end
end

function drmfm.perf_ramp(action)
  if action == "run" then
    if perf_clk ~= nil then
      clock.cancel(perf_clk)
    end
    perf_clk = clock.run(function()
      local counter = 0
      local num_beats = params:get("drmfm_perf_time")
      local d = 100 / (num_beats * 4)
      while counter < num_beats do
        params:delta("drmfm_perf_depth", d)
        counter = counter + 1/4
        clock.sync(1/4)
      end 
    end)
  else
    if perf_clk ~= nil then
      clock.cancel(perf_clk)
    end
    params:set("drmfm_perf_depth", 0)
  end
end

function drmfm.trig(i, vel)
  if not (mute.all or mute.kit_key[i]) then
    local vel = vel and util.linlin(0, 127, 0, 1, vel) or 1
    if vox[i].model == "MIDI" then
      vox[i].midi_dev:note_on(vox[i].midi_note, math.floor(vox[i].midi_vel * vel), vox[i].midi_ch)
      drmfm.viz[i] = true
      dirtygrid = true
    elseif vox[i].model == "UW" then
      engine.drmfm_trig(i - 1, vel)
      if vox[i].uw_mode == 1 then
        viz_pulse(i)
      else
        drmfm.viz[i] = true
        dirtygrid = true
      end
    else
      engine.drmfm_trig(i - 1, vel)
      viz_pulse(i)
    end
  end
end

function drmfm.stop(i)
  if vox[i].model == "MIDI" then
    vox[i].midi_dev:note_off(vox[i].midi_note, 0, vox[i].midi_ch)
    drmfm.viz[i] = false
  elseif vox[i].model == "UW" then
    if vox[i].uw_mode == 2 then
      engine.drmfm_stop(i - 1)
      drmfm.viz[i] = false
    end
  end
  dirtygrid = true
end

return drmfm
