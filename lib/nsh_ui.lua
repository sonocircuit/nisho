-- UI for nisho - v2.0

local ui = {}

-- locals
local shift = false
local page = 1
local num_pages = 4
local auto_timer = nil
local msg_timer = nil
local pset_focus = 1

local pop = {}
pop.msg = ""
pop.yfunc = nil
pop.nfunc = nil
pop.yargs = {}
pop.nargs = {}

-- globals
ui.view = 1
ui.prev_view = 1
ui.voice_focus = 1
ui.kit_focus = 1
ui.kit_action = 1
ui.kit_options = false
ui.screen_msg = ""

-- index variables
ui.SCLE = 1  -- main scale/notes
ui.PVOX = 2  -- voice param
ui.PPTN = 3  -- pattern param
ui.PKIT = 4  -- kit param
ui.EVOX = 5  -- voice edit
ui.EKIT = 6  -- kit edit
ui.QKEY = 7  -- key quantize
ui.PTRG = 8  -- trig params
ui.RTRG = 9  -- trig reset
ui.PSET = 10 -- presets
ui.IMPT = 11 -- pattern import
ui.PRCH = 12 -- program change
ui.POPP = 13 -- screen popup
ui.MSGV = 14 -- screen messages

-------------------------- functions --------------------------
local function get_mid(str)
  local len = string.len(str) / 2
  local pix = len * 5
  return pix
end

local function enter_nb_params(i)
  if params:get("nb_player_"..i) > 1 then
    local players = {}
    local names = {}
    for i = 1, 2 do
      players[i] = params:lookup_param("nb_player_"..i):get_player()
      if params:get("nb_player_"..i) > 1 then
        table.insert(names, players[i].name)
      end
    end
    table.sort(names)
    local nb_pos = tab.key(names, players[i].name) + (caw.detected() and 21 or 16)
    _menu.set_mode(true)
    _menu.set_page("PARAMS")
    _menu.m.PARAMS.mode = 1
    if _menu.m.PARAMS.group then
      if _menu.m.PARAMS.groupname ~= params:lookup_param("nb_player_"..i).player.name then
        _menu.key(2, 1)
        _menu.m.PARAMS.pos = nb_pos
        _menu.key(3, 1)
      end
    else
      _menu.m.PARAMS.pos = nb_pos
      _menu.key(3, 1)
    end
     _menu.rebuild_params()
  end
end

function ui.set_view(view)
  if ui.view ~= view then
    ui.prev_view = ui.view
    ui.view = view
  end
  dirtyscreen = true
  dirtygrid = true
  ui.autofocus()
end

function ui.toggle_view(view, alt_view)
  if ui.view ~= view then
    ui.set_view(view)
  else
    ui.set_view(alt_view or ui.prev_view)
  end
end

function ui.draw_view(view)
  if ui.view == view then
    dirtyscreen = true
  end
end

function ui.get_view(view)
  return ui.view == view and true or false
end

function ui.set_voice(i)
  ui.voice_focus = i
  ui.set_view(ui.PVOX)
end

function ui.set_shift(z)
  shift = z == 1 and true or false
end

function ui.reset_pset()
  pset_focus = 1
end

function ui.page_delta(d)
  if ui.view == ui.SCLE and shift then
    hrmy.active = util.clamp(hrmy.active + d, 1, 8)
    set_hrmy_slot(hrmy.active)
  elseif ui.view <= num_pages then
    page = util.clamp(page + d, 1, num_pages)
    ui.set_view(page)
    if page == ui.SCLE then
      for i = 1, 12 do
        nv.viz[i] = false
      end
    end
  end
end

function ui.autofocus()
  if auto_timer ~= nil then
    clock.cancel(auto_timer)
  end
  auto_timer = clock.run(function()
    clock.sleep(20)
    ui.set_view(ui.SCLE)
  end)
end

function ui.show_message(msg, dur)
  ui.screen_msg = msg
  dirtyscreen = true
  if msg_timer ~= nil then
    clock.cancel(msg_timer)
  end
  msg_timer = clock.run(function()
    local dur = dur or string.len(msg) > 20 and 1.6 or 0.8
    clock.sleep(dur)
    ui.screen_msg = ""
    dirtyscreen = true
    msg_timer = nil
  end)
end

function ui.popup_set(msg, yes, no)
  pop.msg = msg
  pop.yfunc = yes and yes.func or nil
  pop.yargs = yes and yes.args or {}
  pop.nfunc = no and no.func or nil
  pop.nargs = no and no.args or {}
  if pop.msg ~= nil then
    ui.set_view(ui.POPP)
  end
end

function ui.popup_exec(choice)
  if choice == "yes" and pop.yfunc then
    pop.yfunc(table.unpack(pop.yargs))
  elseif choice == "no" and pop.nfunc then
    pop.nfunc(table.unpack(pop.nargs))
  end
  pop.yfunc = nil
  pop.nfunc = nil
  pop.yargs = {}
  pop.nargs = {}
  ui.set_view(ui.prev_view)
end

-------------------------- UI --------------------------
ui.key = {}
ui.enc = {}
ui.redraw = {}

-- msg ui ----------------------------------------------
ui.redraw[ui.MSGV] = function()
  screen.font_size(8)
  screen.line_width(1)
  screen.level(10)
  screen.rect(0, 25, 129, 16)
  screen.stroke()
  screen.level(15)
  screen.move(64, 25 + 10)
  screen.text_center(ui.screen_msg)
end

-- popup ui --------------------------------------------

ui.key[ui.POPP] = function(n, z)
  if z == 1 then
    if n == 2 then
      ui.popup_exec("no")
    elseif n == 3 then
      ui.popup_exec("yes")
    end
  end
end

ui.enc[ui.POPP] = function(n, d)
  return
end

ui.redraw[ui.POPP] = function()
  screen.font_size(8)
  screen.level(10)
  screen.move(1, 24)
  screen.line_rel(128, 0)
  screen.move(1, 41)
  screen.line_rel(128, 0)
  screen.stroke()
  screen.level(15)
  screen.move(64, 35)
  screen.text_center(pop.msg)
  screen.level(4)
  screen.move(64, 60)
  screen.text_center("are   you   sure  ?")
  screen.level(15)
  screen.move(20, 60)
  screen.text_center("no   <")
  screen.move(108, 60)
  screen.text_center(">   yes")
  screen.update()
end

-- notes ui --------------------------------------------

ui.key[ui.SCLE] = function(n, z)
  if shift then ui.key[ui.QKEY](n, z) end
end

ui.enc[ui.SCLE] = function(n, d)
  if n == 2 then
    if hrmy.config or (shift and not seq.active) then
      params:delta("scale", d)
    end
  elseif n == 3 then
    if hrmy.config or (shift and not seq.active) then
      params:delta("notes_root_scale", d)
    elseif seq.active and shift then
      params:delta("seq_rate", d)
    end
  end
end

ui.redraw[ui.SCLE] = function()
  for i = 1, 12 do
    local off_x = i > 5 and 8 or 0
    local off_y = (i == 2 or i == 4 or i == 7 or i == 9 or i == 11) and -12 or 0
    screen.level(nv.viz[i] and 15 or (nv.is[i] and 6 or 1))
    if nv.root[i] then
      screen.move(16 + off_x + (i - 1) * 8, 44 + off_y)
      screen.font_size(8)
      screen.text_center(".")
    end
    screen.move(16 + off_x + (i - 1) * 8, 41 + off_y)
    screen.font_size(nv.viz[i] and 16 or 8)
    screen.text_center(nv.name[i])
  end
  if hrmy.config or (shift and not seq.active) then
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 12)
    screen.text_center("scale   slot   "..hrmy.active)
    screen.level(8)
    screen.move(8, 58)
    screen.text(params:string("scale"))
    screen.move(110, 58)
    screen.text(params:string("notes_root_scale"))
  elseif seq.collecting and #seq.collected > 0 then
    screen.level(8)
    screen.font_size(16)
    screen.move(64, 58)
    screen.text_center("step: "..#seq.collected)
  elseif seq.active and shift then
    screen.level(4)
    screen.font_size(8)
    screen.move(6, 58)
    screen.text("seq rate")
    screen.level(8)
    screen.move(122, 58)
    screen.text_right(params:string("seq_rate"))
  else
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 58)
    screen.text_center(chrd.name)
  end
  local semitone = notes.scale[notes.trsp_int + notes.home] - notes.scale[notes.home]
  if notes.trsp_active and not (hrmy.config or shift) then
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 12)
    if semitone > 0 then
      screen.text_center("transpose: +"..semitone)
    else
      screen.text_center("transpose: "..semitone)
    end
  end
end

-- voice ui --------------------------------------------

ui.key[ui.PVOX] = function(n, z)
  if z == 1 then
    local d = n == 2 and -1 or 1
    if voice[ui.voice_focus].output < NB1 then
      if shift then
        if prms.voice[voice[ui.voice_focus].output].ids[3] then
          prms.plymod_param[ui.voice_focus] = util.wrap(prms.plymod_param[ui.voice_focus] + d, 1, #prms.voice[voice[ui.voice_focus].output].ids[3])
        end
      elseif voice[ui.voice_focus].output < NB1 then
        prms.voice_param[ui.voice_focus] = util.wrap(prms.voice_param[ui.voice_focus] + d, 1, #prms.voice[voice[ui.voice_focus].output].ids[1])
      end  
    else
      local player = voice[ui.voice_focus].output - 7
      enter_nb_params(player)
    end
  end 
end

ui.enc[ui.PVOX] = function(n, d)
  if n > 1 then
    local out = voice[ui.voice_focus].output
    if shift and out < MID then
      local idx = prms.plymod_param[ui.voice_focus]
      params:delta(prms.voice[out].ids[n + 1][idx], d)
    elseif out < NB1 then
      local param = prms.voice[out].ids[n - 1][prms.voice_param[ui.voice_focus]]
      local s = out == 3 and ui.voice_focus or ""
      params:delta(param..s, d)
    elseif out == NB1 then
      params:delta("nb_player_1", d)
    elseif out == NB2 then
      params:delta("nb_player_2", d)
    end
  end
end

ui.redraw[ui.PVOX] = function()
  local out = voice[ui.voice_focus].output
  local i = out == 3 and ui.voice_focus or ""
  screen.level(15)
  screen.font_size(8)
  screen.move(64, 12)
  screen.text_center("voice "..ui.voice_focus.." - "..params:string("voice_out_"..ui.voice_focus))
  if out < NB1 then
    if shift and out < 3 then
      local idx = prms.plymod_param[ui.voice_focus]
      local param1 = prms.voice[out].ids[3][idx]
      local param2 = prms.voice[out].ids[4][idx]
      -- param names
      screen.level(4)
      screen.move(30, 60)
      screen.text_center(prms.voice[out].nms[3][idx])
      screen.move(98, 60)
      screen.text_center(prms.voice[out].nms[4][idx])
      -- param values
      screen.font_size(16)
      screen.level(15)
      screen.move(30, 39)
      screen.text_center(params:string(param1..i))
      screen.move(98, 39)
      screen.text_center(params:string(param2..i))
      -- param page
      local nprm = #prms.voice[out].ids[3]
      if nprm > 1 then
        for i = 1, nprm do
          screen.level(i == idx and 8 or 1)
          screen.pixel(127, 32 - nprm + (i - 1) * 2)
          screen.fill()
        end
      end
    else
      local idx = prms.voice_param[ui.voice_focus]
      local param1 = prms.voice[out].ids[1][idx]
      local param2 = prms.voice[out].ids[2][idx]
      -- param names
      screen.level(4)
      screen.move(30, 60)
      screen.text_center(prms.voice[out].nms[1][idx])
      screen.move(98, 60)
      screen.text_center(prms.voice[out].nms[2][idx])
      -- param values
      screen.font_size(16)
      screen.level(15)
      screen.move(30, 39)
      if param1 == "midi_device_" then
        local dev_id = params:get("midi_device_"..ui.voice_focus)
        screen.text_center(m.device_names[dev_id])
        screen.level(4)
        screen.font_size(8)
        screen.font_face(68)
        screen.move(30, 47)
        screen.text_center("[port:"..dev_id.."]")
        screen.level(15)
        screen.font_size(16)
        screen.font_face(2)
      else
        screen.text_center(params:string(param1..i))
      end
      screen.move(98, 39)
      if param2 == "polyform_saw_shape_1" or param2 == "polyform_saw_shape_2" then
        local width = 40
        local offset = params:get(param2) * (width/2) + (width/2)
        screen.line_width(2)
        screen.move(79, 40)
        screen.line_rel(offset, -16)
        screen.move(79 + width, 40)
        screen.line_rel(-width + offset, -16)
        screen.stroke()
      else
        screen.text_center(params:string(param2..i))
      end
      -- param page
      local nprm = #prms.voice[out].ids[1]
      if nprm > 1 then
        for i = 1, nprm do
          screen.level(i == idx and 8 or 1)
          screen.pixel(127, 32 - nprm + (i - 1) * 2)
          screen.fill()
        end
      end
    end
  else
    screen.font_size(16)
    screen.level(12)
    screen.move(64, 39)
    screen.text_center(params:string("nb_player_"..out - 7))
    screen.font_size(8)
    screen.level(6)
    screen.move(64, 55)
    local txt = params:get("nb_player_"..out - 7) > 1 and "goto  params  >  K3" or ""
    screen.text_center(txt)
  end
end

-- pattern ui --------------------------------------------


ui.key[ui.PPTN] = function(n, z)
  if z == 1 then
    if shift then
      if prms.ptn_param == 1 then
        if n == 2 then
          ptn[ptn.focus].manual_length = false
          ptn[ptn.focus].length = ptn[ptn.focus].meter * ptn[ptn.focus].barnum * 4
          ptn[ptn.focus]:set_length(ptn[ptn.focus].length)
          save_pattern_bank(ptn.focus, p[ptn.focus].bank)
        elseif n == 3 then
          reset_pattern_length(ptn.focus, p[ptn.focus].bank)
        end
      elseif prms.ptn_param == 3 then
        remap_pattern_voice(ptn.focus, ptn.remap_src, ptn.remap_dst)
      elseif prms.ptn_param == 4 then
        transpose_pattern(ptn.focus, ptn[ptn.focus].transpose)
      end
    else
      local d = n == 2 and -1 or 1
      prms.ptn_param = util.wrap(prms.ptn_param + d, 1, #prms.ptn_ids[1])
    end
  end
  dirtygrid = true
end

ui.enc[ui.PPTN] = function(n, d)
  if shift then
    if prms.ptn_param == 2 then
      params:delta("patterns_alloc_"..ptn.focus, d)
    elseif prms.ptn_param == 3 then
      if n == 2 then
        ptn.remap_src = util.clamp(ptn.remap_src + d, 1, NUM_VOICES)
      elseif n == 3 then
        ptn.remap_dst = util.clamp(ptn.remap_dst + d, 1, NUM_VOICES)
      end
    end
  else
    if not (prms.ptn_focus == 1 and ((ptn.rec_mode == "free" and ptn[ptn.focus].endpoint == 0) or ptn[ptn.focus].manual_length)) and n > 1 then
      params:delta(prms.ptn_ids[n - 1][prms.ptn_param]..ptn.focus, d)
    end
  end
end

ui.redraw[ui.PPTN] = function()
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center("pattern   "..ptn.focus.."       bank   "..p[ptn.focus].bank)
  if shift then
    if prms.ptn_param == 1 then
      local current_length = ptn[ptn.focus].meter * ptn[ptn.focus].barnum * 4
      screen.level((ptn[ptn.focus].manual_length or current_length ~= ptn[ptn.focus].length) and viz.key_mid or 2)
      screen.move(30, 60)
      screen.text_center("set")
      screen.move(98, 60)
      screen.level(ptn[ptn.focus].endpoint ~= ptn[ptn.focus].endpoint_init and viz.key_mid or 2)
      screen.text_center("reset")
      screen.font_size(16)
      screen.level(10)
      screen.move(64, 39)
      screen.text_center((ptn[ptn.focus].endpoint / 64).."  beats")
    elseif prms.ptn_param == 2 then
      screen.level(10)
      screen.move(64, 60)
      screen.text_center("allocate")
      screen.font_size(16)
      screen.level(10)
      screen.move(64, 39)
      screen.text_center(params:string("patterns_alloc_"..ptn.focus))
    elseif prms.ptn_param == 3 then
      screen.level(2)
      screen.move(64, 60)
      screen.text_center("remap   voice")
      screen.font_size(16)
      screen.move(64, 39)
      screen.text_center(">")
      screen.level(10)
      screen.move(30, 39)
      screen.text_center(ptn.remap_src)
      screen.move(98, 39)
      screen.text_center(ptn.remap_dst)
    elseif prms.ptn_param == 4 then
      screen.level(ptn[ptn.focus].transpose ~= 0 and viz.key_mid or 2)
      screen.move(64, 60)
      screen.text_center("transpose   pattern")
      screen.font_size(16)
      screen.level(10)
      screen.move(64, 39)
      screen.text_center(ptn[ptn.focus].transpose.."  deg")
    end
  else
    local param1 = prms.ptn_ids[1][prms.ptn_param]..ptn.focus
    local param2 = prms.ptn_ids[2][prms.ptn_param]..ptn.focus
    local txt1 = prms.ptn_nms[1][prms.ptn_param]
    local txt2 = prms.ptn_nms[2][prms.ptn_param]
    if txt1 == txt2 then
      screen.level(2)
      screen.move(64, 60)
      screen.text_center(txt1)
      screen.font_size(16)
      screen.level(10)
      screen.move(64, 39)
      screen.text_center(params:string(param1))
    else
      screen.level(4)
      screen.move(30, 60)
      screen.text_center(txt1)
      screen.move(98, 60)
      screen.text_center(txt2)
      local state = (ptn[ptn.focus].endpoint / 64 == ptn[ptn.focus].meter * ptn[ptn.focus].barnum * 4) and true or false
      screen.level((state or ptn[ptn.focus].manual) and 15 or 4)
      screen.font_size(16)
      screen.move(30, 39)
      if prms.ptn_param == 1 and ((ptn.rec_mode == "free" and ptn[ptn.focus].endpoint == 0) or ptn[ptn.focus].manual_length) then
        screen.text_center("-")
      else
        screen.text_center(params:string(param1))
      end
      screen.move(98, 39)
      if (prms.ptn_param == 1 and ((ptn.rec_mode == "free" and ptn[ptn.focus].endpoint == 0) or ptn[ptn.focus].manual_length)) then
        screen.text_center("-")
      else
        screen.text_center(params:string(param2))
      end
    end
    -- param page
    local nprm = #prms.ptn_ids[1]
    if nprm > 1 then
      for i = 1, nprm do
        screen.level(i == prms.ptn_param and 8 or 1)
        screen.pixel(127, 32 - nprm + (i - 1) * 2)
        screen.fill()
      end
    end
  end
end

-- kit ui --------------------------------------------

ui.key[ui.PKIT] = function(n, z)
  if z == 1 then
    local d = n == 2 and -1 or 1
    local model = drmfm.get_model(ui.kit_focus)
    local mprms = (model == "MIDI" or model == "UW") and model or "DM"
    if shift then
      prms.kitmod_param[mprms] = util.wrap(prms.kitmod_param[mprms] + d, 1, #prms.kitmod[mprms][1])
    else
      prms.kit_param[mprms] = util.wrap(prms.kit_param[mprms] + d, 1, #prms.kit[mprms][1])
    end        
  end   
end

ui.enc[ui.PKIT] = function(n, d)
  if n > 1 then
    local model = drmfm.get_model(ui.kit_focus)
    local mprms = (model == "MIDI" or model == "UW") and model or "DM"
    if shift then
      params:delta("drmfm_"..prms.kitmod[mprms][n - 1][prms.kitmod_param[mprms]].."_"..ui.kit_focus, d)
    else
      params:delta("drmfm_"..prms.kit[mprms][n - 1][prms.kit_param[mprms]].."_"..ui.kit_focus, d)
      if prms.kit_param[mprms] == 1 then
        prms.kit_param["MIDI"] = 1
        prms.kit_param["UW"] = 1
        prms.kit_param["DM"] = 1
      end
    end
  end
end

ui.redraw[ui.PKIT] = function()
  local model = drmfm.get_model(ui.kit_focus)
  local mprms = (model == "MIDI" or model == "UW") and model or "DM"
  local ptab = shift and prms.kitmod or prms.kit
  local pid = shift and prms.kitmod_param or prms.kit_param
  local ktxt = shift and (pid[mprms] == 1 and "drmFM   model   " or "drmFM   morph   ") or "drmFM   voice   "
  local param1 = "drmfm_"..ptab[mprms][1][pid[mprms]].."_"..ui.kit_focus
  local param2 = "drmfm_"..ptab[mprms][2][pid[mprms]].."_"..ui.kit_focus
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center(ktxt..ui.kit_focus.." :   "..model)
  if param1 == param2 then
    screen.level(4)
    screen.move(64, 60)
    screen.text_center(params:lookup_param(param1).name)
    screen.level(15)
    screen.font_size(16)
    screen.move(64, 39)
    screen.text_center(params:string(param1))
  else
    screen.level(4)
    screen.move(30, 60)
    screen.text_center(params:lookup_param(param1).name)
    screen.move(98, 60)
    screen.text_center(params:lookup_param(param2).name)
    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    screen.text_center(params:string(param1))
    screen.move(98, 39)
    screen.text_center(params:string(param2))
  end
  -- param page
  local nprm = shift and #prms.kitmod[mprms][1] or #prms.kit[mprms][1]
  local idx = shift and prms.kitmod_param[mprms] or prms.kit_param[mprms]
  if nprm > 1 then
    for i = 1, nprm do
      screen.level(i == idx and 8 or 1)
      screen.pixel(127, 32 - nprm + (i - 1) * 2)
      screen.fill()
    end
  end
end



-- keyquant ui --------------------------------------------

ui.key[ui.QKEY] = function(n, z)
  if n == 2 then
    if params:get("clock_source") == 3 then
      clock.link.stop()
    else
      m[m.tsrp_id]:stop()
    end
    stop_callback()
    ui.show_message("stop")
  elseif n == 3 then
    if params:get("clock_source") == 3 then
      clock.link.start()
      ui.show_message("> start")
      start_callback()
    else
      ui.show_message("starting...", 10)
      clock.run(function()
        clock.sync(quant.bar)
        m[m.tsrp_id]:start()
        ui.show_message("> start")
        start_callback()
      end)
    end
  end
end

ui.enc[ui.QKEY] = function(n, d)
  if n == 2 then
    params:delta("time_signature", d)
  elseif n == 3 then
    params:delta("key_quantization", d)
  end
end

ui.redraw[ui.QKEY] = function()
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center("timing")
  screen.font_size(16)
  screen.move(30, 39)
  screen.text_center(params:string("time_signature"))
  screen.move(98, 39)
  screen.text_center(params:string("key_quantization"))
  screen.font_size(8)
  screen.level(4)
  screen.move(30, 60)
  screen.text_center("time  signature")
  screen.move(98, 60)
  screen.text_center("key  quantization") 
end

-- preset ui --------------------------------------------

ui.key[ui.PSET] = function(n, z)
  if n == 2 and z == 1 then
    if shift then
      local yes = {func = clear_all_patterns, args = {}}
      ui.popup_set("clear   all   patterns", yes)
    else
      ui.set_view(ui.IMPT)
      load_pattern_data(pset_list[pset_focus])
    end
  elseif n == 3 and z == 1 then
    if shift then
      load_patterns(pset_list[pset_focus])
      ui.show_message("patterns    loaded")
    else
      local num = get_pset_num(pset_list[pset_focus])
      params:read(num)
      ui.show_message("pset    loaded")
    end
    ui.set_view(ui.SCLE)
  end      
end

ui.enc[ui.PSET] = function(n, d)
  if n == 2 then
    pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
  elseif n == 3 then
    pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
  end
end

ui.redraw[ui.PSET] = function()
  screen.line_width(1)
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center(shift and "PATTERNS" or "PRESET")
  -- show pset names
  if #pset_list > 0 then
    local off = get_mid(pset_list[pset_focus])
    screen.level(12)
    screen.rect(64 - off, 28, off * 2 + 2, 10)
    screen.fill()
    screen.level(0)
    screen.move(64, 36)
    screen.text_center(pset_list[pset_focus])
    -- list right
    if pset_focus > 1 then
      screen.level(4)
      screen.move(64 - off - 14, 36)
      screen.text_right(pset_list[pset_focus - 1])
    end
    -- list left
    if pset_focus < #pset_list then
      screen.level(2)
      screen.move(64 + off + 14, 36)
      screen.text(pset_list[pset_focus + 1])
    end
  else
    screen.level(2)
    screen.move(64, 36)
    screen.text_center("NO   PSETS")
  end
  -- frame
  screen.level(10)
  screen.move(4, 18)
  screen.line_rel(120, 0)
  screen.move(4, 50)
  screen.line_rel(120, 0)
  screen.stroke()
  -- actions
  screen.level(4)
  screen.move(4, 60)
  screen.text(shift and "clear   all <" or "import")
  screen.level(10)
  screen.move(124, 60)
  screen.text_right(shift and ">  load   all" or ">  load   pset")
end

-- import ui --------------------------------------------

ui.key[ui.IMPT] = function(n, z)
  if n == 2 and z == 1 then
    ui.set_view(ui.PSET)
    ptn.data = nil
  elseif n == 3 and z == 1 then
    if shift then
      screenredrawtimer:stop()
      fs.enter(ptn.midi_path, function(filename)
        if filename ~= 'cancel' then
          local yes = {func = load_midi_files, args = {filename, true}}
          local no = {func = load_midi_files, args = {filename, false}}
          ui.popup_set("map   to   scale", yes, no)
        end
        screenredrawtimer:start()
        dirtyscreen = true
      end)
      shift = false
    else
      load_pattern_slot(ptn.src, ptn.dst)
      ui.show_message("slot    loaded")
    end
  end
end

ui.enc[ui.IMPT] = function(n, d)
  if n == 2 then
    ptn.src = util.clamp(ptn.src + d, 1, 24)
  elseif n == 3 then
    ptn.dst = util.clamp(ptn.dst + d, 1, 24)
  end
end

ui.redraw[ui.IMPT] = function()
  if shift then
    screen.font_size(16)
    screen.level(15)
    screen.move(64, 39)
    screen.text_center("load   midi   files")
  else
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center(pset_list[pset_focus].."  -  PATTERN  SLOTS")
    screen.font_size(16)
    screen.level(4)
    screen.move(64, 39)
    screen.text_center(">")
    screen.level(15)
    screen.move(30, 39)
    screen.text_center(ptn.src)
    screen.move(98, 39)
    screen.text_center(ptn.dst)
  end
  -- actions
  screen.font_size(8)
  screen.level(4)
  screen.move(4, 60)
  screen.text("back")
  screen.level(10)
  screen.move(124, 60)
  if shift then
    screen.text_right(">  select")
  else
    screen.text_right(">  import")
  end
end

-- prgchange ui --------------------------------------------

ui.key[ui.PRCH] = function(n, z)
  return
end

ui.enc[ui.PRCH] = function(n, d)
  if n == 2 then
    if p[ptn.focus].prc_type < 3 then
      p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, 0, 127)
    elseif p[ptn.focus].prc_type == 3 then
      if shift then
        p[ptn.focus].prc_ch = util.clamp(p[ptn.focus].prc_ch + d, 1, 16)
      else
        p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, 0, 127)
      end
    elseif p[ptn.focus].prc_type == 4 then
      p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, 0, 8)
    elseif p[ptn.focus].prc_type == 5 then
        p[ptn.focus].prc_num[ptn.bank] = util.clamp(p[ptn.focus].prc_num[ptn.bank] + d, -1, 6)
    end
  elseif n == 3 then
    p[ptn.focus].prc_option[ptn.bank] = util.clamp(p[ptn.focus].prc_option[ptn.bank] + d, 1, 2)
  end
end

ui.redraw[ui.PRCH] = function()
  local launch_options = {{"play", "load"}, {"upbeat", "dnbeat"}}
  local launch_mode = p[ptn.focus].prc_option[ptn.bank]
  local num = p[ptn.focus].prc_num[ptn.bank]
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  local name = ptn.focus < 7 and "voice    "..ptn.focus or (ptn.focus == 7 and "scale" or "drm   mute")
  screen.text_center(name.."      bank   "..ptn.bank)
  -- param list
  screen.level(4)
  screen.move(30, 60)
  if shift and p[ptn.focus].prc_type == 3 then 
    screen.text_center("prg    channel")
  else
    local txt = "prg    msg"
    if p[ptn.focus].prc_type < 3 then
      txt = "polyform   patch"
    elseif p[ptn.focus].prc_type == 4 then
      txt = "scale   slot"
    elseif p[ptn.focus].prc_type == 5 then
      txt = "mute   group"
    end
    screen.text_center(txt)
  end
  screen.move(98, 60)
  screen.text_center("launch")
  screen.level(15)
  screen.font_size(16)
  screen.move(30, 39)
  if shift and p[ptn.focus].prc_type == 3 then 
    screen.text_center(p[ptn.focus].prc_ch)
  else
    screen.text_center(num == 0 and "off" or (num == -1 and "clear" or num))
  end
  screen.move(98, 39)
  screen.text_center(launch_options[ptn.focus == 8 and 2 or 1][launch_mode])
end

-- trig edit ui --------------------------------------------

ui.key[ui.PTRG] = function(n, z)
  if z == 1 then
    local d = n == 2 and -1 or 1
    prms.trigs_param = util.wrap(prms.trigs_param + d, 1, 2)
  end
end

ui.enc[ui.PTRG] = function(n, d)
  if prms.trigs_param == 1 then
    if n == 2 then
      trigs[trigs.focus].prob[trigs.step_focus] = util.clamp(trigs[trigs.focus].prob[trigs.step_focus] + d/100, 0.01, 1)
    elseif n == 3 then
      trigs[trigs.focus].vel[trigs.step_focus] = util.clamp(trigs[trigs.focus].vel[trigs.step_focus] + d/100, 0.01, 1)
    end
  elseif prms.trigs_param == 2 then
    if n == 2 then
      trigs[trigs.focus].ratnum[trigs.step_focus] = util.clamp(trigs[trigs.focus].ratnum[trigs.step_focus] + d, 0, 8)
    elseif n == 3 then
      trigs[trigs.focus].ratvel[trigs.step_focus] = util.clamp(trigs[trigs.focus].ratvel[trigs.step_focus] + d/100, -1, 1)
    end
  end
  dirtygrid = true
end

ui.redraw[ui.PTRG] = function()
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center("step    "..trigs.step_focus)
  screen.font_size(16)
  if prms.trigs_param == 1 then
    screen.move(30, 39)
    screen.text_center(util.round(trigs[trigs.focus].prob[trigs.step_focus] * 100, 1).."%")
    screen.move(98, 39)
    screen.text_center(util.round(trigs[trigs.focus].vel[trigs.step_focus] * 100, 1).."%")
  else
    screen.move(30, 39)
    local val = trigs[trigs.focus].ratnum[trigs.step_focus]
    screen.text_center(val == 0 and "rnd" or val.."*")
    screen.move(98, 39)
    screen.text_center(util.round(trigs[trigs.focus].ratvel[trigs.step_focus] * 100, 1).."%")
  end
  screen.font_size(8)
  screen.level(4)
  if prms.trigs_param == 1 then
    screen.move(30, 60)
    screen.text_center("probability")
    screen.move(98, 60)
    screen.text_center("velocity")
  else
    screen.move(30, 60)
    screen.text_center("repeats")
    screen.move(98, 60)
    screen.text_center("fade   curve")
  end
  -- param page
  for i = 1, 2 do
    screen.level(i == prms.trigs_param and 8 or 1)
    screen.pixel(127, 32 - 2 + (i - 1) * 2)
    screen.fill()
  end
end

-- trig reset ui --------------------------------------------

ui.key[ui.RTRG] = function(n, z)
  return
end

ui.enc[ui.RTRG] = function(n, d)
  params:delta("trigs_rst_mode", d)
end

ui.redraw[ui.RTRG] = function()
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center("trig   reset")
  screen.font_size(16)
  screen.move(64, 39)
  screen.text_center(params:string("trigs_rst_mode"))
  screen.font_size(8)
  screen.level(4)
  screen.move(64, 60)
  screen.text_center("mode")  
end

-- voice options ui --------------------------------------------

ui.key[ui.EVOX] = function(n, z)
  if z == 1 then
    local d = n == 2 and -1 or 1
    prms.keys_param = util.wrap(prms.keys_param + d, 1, #prms.keys_ids[1])
  end
end

ui.enc[ui.EVOX] = function(n, d)
  params:delta(prms.keys_ids[n - 1][prms.keys_param].."_"..voice.keys, d)
end

ui.redraw[ui.EVOX] = function()
  local param1 = prms.keys_ids[1][prms.keys_param].."_"..voice.keys
  local param2 = prms.keys_ids[2][prms.keys_param].."_"..voice.keys
  screen.level(15)
  screen.font_size(8)
  screen.move(64, 12)
  screen.text_center("voice "..ui.voice_focus.." - "..prms.keys_setting[prms.keys_param])
  if param1 == param2 then
    -- param names
    screen.level(4)
    screen.move(64, 60)
    screen.text_center(prms.keys_nms[1][prms.keys_param])
    -- param values
    screen.font_size(16)
    screen.level(15)
    screen.move(64, 39)
    screen.text_center(params:string(param1))
  else
    -- param names
    screen.level(4)
    screen.move(30, 60)
    screen.text_center(prms.keys_nms[1][prms.keys_param])
    screen.move(98, 60)
    screen.text_center(prms.keys_nms[2][prms.keys_param])
    -- param values
    screen.font_size(16)
    screen.level(15)
    screen.move(30, 39)
    screen.text_center(params:string(param1))
    screen.move(98, 39)
    screen.text_center(params:string(param2))
  end
  -- param page
  local nprm = #prms.keys_ids[1]
  if nprm > 1 then
    for i = 1, nprm do
      screen.level(i == prms.keys_param and 8 or 1)
      screen.pixel(127, 32 - nprm + (i - 1) * 2)
      screen.fill()
    end
  end 
end

-- kit options ui --------------------------------------------

ui.key[ui.EKIT] = function(n, z)
  if ui.kit_action == 3 then
    if z == 0 then
      if shift then
        if n == 2 then
          drmfm.save_kit()
        elseif n == 3 then
          drmfm.save_voice()
        end
        shift = false
      else
        if n == 2 then
          drmfm.load_kit()
        elseif n == 3 then
          drmfm.load_voice()
        end
      end
    end
  elseif ui.kit_action == 4 then
    if drmfm.get_model(ui.kit_focus) == "UW" then
      if n == 2 and z == 1 then
        local msg = "clear   sample"
        local yes = {func = drmfm.clear_sample, args = {ui.kit_focus}}
        ui.popup_set(msg, yes)
      elseif n == 3 and z == 1 then
        drmfm.load_sample(ui.kit_focus)
      end
    end
  end
end

ui.enc[ui.EKIT] = function(n, d)
  if n == 2 then
    ui.kit_action = util.clamp(ui.kit_action + d, 1, 4)
  elseif n == 3 then
    if ui.kit_action == 1 then
      params:delta("drmfm_perf_time", d)
    elseif ui.kit_action == 3 then
      ui.kit_focus = util.clamp(ui.kit_focus + d, 1, 16)
      params:set("drmfm_selected_voice", ui.kit_focus)
    elseif ui.kit_action == 4 then
      params:delta("drmfm_uw_sample_"..ui.kit_focus, d)
    end
  end
end

ui.redraw[ui.EKIT] = function()
  if ui.kit_action == 1 then
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 12)
    screen.text_center("drmFM  action:   morph")
    screen.level(4)
    screen.move(64, 60)
    screen.text_center("morph   time")
    screen.level(15)
    screen.font_size(16)
    screen.move(64, 39)
    screen.text_center(params:string("drmfm_perf_time"))
  elseif ui.kit_action == 2 then
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 12)
    screen.text_center("drmFM  action:   copy")
    screen.level(4)
    screen.move(64, 39)
    if drmfm.get_copy_state() then
      screen.text_center("- ready   to   paste -")
    else
      screen.text_center("- clipboard   empty -")
    end
  elseif ui.kit_action == 3 then
    local kit_txt = drmfm.get_kit()
    local vox_txt = ui.kit_focus
    vox_txt = vox_txt == "" and " - " or vox_txt
    local kit_len = get_mid(kit_txt)
    local vox_len = get_mid(vox_txt) + 5

    screen.level(15)
    screen.font_size(8)
    screen.line_width(1)
    screen.move(64, 12)
    local action = shift and "save" or "load"
    screen.text_center("drmFM  action:   "..action)

    screen.level(4)
    screen.move(64, 29)
    screen.text_center(kit_txt)
    screen.move(22, 52)
    screen.line(22, 27)
    screen.stroke()
    screen.move(21, 27)
    screen.line(64 - kit_len, 27)
    screen.stroke()

    screen.move(64, 43)
    screen.text_center(vox_txt)
    screen.move(109, 52)
    screen.line(109, 41)
    screen.stroke()
    screen.move(64 + vox_len, 41)
    screen.line(109, 41)
    screen.stroke()

    screen.level(10)
    screen.move(64, 60)
    screen.text_center("<  "..action.."  >")
    screen.move(21, 60)
    screen.text_center("kit")
    screen.move(108, 60)
    screen.text_center("voice")
  elseif ui.kit_action == 4 then
    local model = drmfm.get_model(ui.kit_focus)
    screen.level(15)
    screen.font_size(8)
    screen.move(64, 12)
    screen.text_center("drmFM  action:   samples")
    if model == "UW" then
      local info = drmfm.get_file_info(ui.kit_focus)
      screen.level(4)
      if info.name == "" then
        screen.move(64, 39)
        screen.text_center("- no  sample -")
      else
        screen.move(64, 30)
        screen.text_center(ui.kit_focus..":  "..info.name)
        screen.move(64, 42)
        screen.text_center(info.len.."s   /  "..info.ch)
      end
      screen.level(10)
      screen.move(30, 60)
      screen.text_center("clear  sample")
      screen.move(98, 60)
      screen.text_center("load  sample")
    else
      screen.level(4)
      screen.move(64, 39)
      screen.text_center("-")
    end
  end
end

return ui
