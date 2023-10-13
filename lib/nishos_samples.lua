local smpls = {}

MAX_SLOT_LEN = 16
CLIP_GAP = 1

smpls.rate_values = {-2, -1, -0.5, -0.25, -0.125, 0.125, 0.25, 0.5, 1, 2}

smpls.bank_focus = 1
smpls.slot_focus = 1

smpls.bank = {}
for i = 1, 5 do
  smpls.bank[i] = {}
  smpls.bank[i].slot = {}
  smpls.bank[i].last_slot = 1
  smpls.bank[i].play = false
  smpls.bank[i].s = CLIP_GAP * i + (i - 1) * MAX_SLOT_LEN
  smpls.bank[i].e = smpls.bank[i].s + 4 * (CLIP_GAP + MAX_SLOT_LEN)
  for j = 1, 4 do
    local count = (i - 1) * 4 + j
    smpls.bank[i].slot[j] = {}
    smpls.bank[i].slot[j].s = CLIP_GAP * count + (count - 1) * MAX_SLOT_LEN
    smpls.bank[i].slot[j].ns = CLIP_GAP * count + (count - 1) * MAX_SLOT_LEN
    smpls.bank[i].slot[j].e = smpls.bank[i].slot[j].s + MAX_SLOT_LEN
    smpls.bank[i].slot[j].ne = smpls.bank[i].slot[j].s + MAX_SLOT_LEN
    smpls.bank[i].slot[j].l = MAX_SLOT_LEN
    smpls.bank[i].slot[j].filename = ""
    smpls.bank[i].slot[j].mode = 0
    smpls.bank[i].slot[j].level = 1
    smpls.bank[i].slot[j].pan = 0
    smpls.bank[i].slot[j].send = 0
    smpls.bank[i].slot[j].fc = 20000
    smpls.bank[i].slot[j].rq = 1
    smpls.bank[i].slot[j].rate = 1
  end
end

function smpls.load(path, bank, slot)
  if path ~= "cancel" and path ~= "" then
    local ch, len = audio.file_info(path)
    if ch > 0 and len > 0 then
      smpls.bank[bank].slot[slot].filename = path
      local s = smpls.bank[bank].slot[slot].s
      local l = math.min(len / 48000, MAX_SLOT_LEN)
      softcut.buffer_clear_region_channel(1, s, MAX_SLOT_LEN)
      softcut.buffer_read_mono(path, 0, s, l, 1, 1, 0, 1)
      smpls.bank[bank].slot[slot].e = s + l
      smpls.bank[bank].slot[slot].ne = s + l
      smpls.bank[bank].slot[slot].l = l
      --print("sample in bank "..bank.." / slot "..slot.." is "..l.."s")
    else
      print("not a sound file")
    end
  end
end

function smpls.play(bank, slot)
  smpls.bank[bank].last_slot = slot
  softcut.play(bank, 1)
  softcut.level(bank, smpls.bank[bank].slot[slot].level)
  softcut.position(bank, smpls.bank[bank].slot[slot].rate > 0 and smpls.bank[bank].slot[slot].ns or smpls.bank[bank].slot[slot].ne)
  softcut.loop_start(bank, smpls.bank[bank].slot[slot].ns)
  softcut.loop_end(bank, smpls.bank[bank].slot[slot].ne)
  softcut.rate(bank, smpls.bank[bank].slot[slot].rate)
  softcut.pan(bank, smpls.bank[bank].slot[slot].pan)
  softcut.level_cut_cut(bank, 6, smpls.bank[bank].slot[slot].send)
  softcut.post_filter_fc(bank, smpls.bank[bank].slot[slot].fc)
  softcut.post_filter_rq(bank, smpls.bank[bank].slot[slot].rq)
end

function smpls.stop(bank, slot)
  softcut.level(bank, 0)
end

function smpls.mode(bank, slot, mode)
  smpls.bank[bank].slot[slot].mode = mode
end

function smpls.gridviz(bank, slot)
  local x = slot + 2 * (bank - 1) - (slot > 2 and 2 or 0) + 3
  local y = (slot > 2 and 2 or 1) + (GRIDSIZE == 128 and 2 or 9)
  gkey[x][y].active = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(1/30)
    gkey[x][y].active = false
    dirtygrid = true
  end)
end

local function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

function smpls.init()
  -- add params
  for i = 1, 5 do
    local bank_names = {"A", "B", "C", "D", "E"}
    local slot_names = {"[one]", "[two]", "[three]", "[four]"}
    params:add_group("sample_bank_"..i, "sample bank "..bank_names[i], 32)
    for j = 1, 4 do
      params:add_separator("bank_"..i.."_slot_"..j.."_sep", "slot "..slot_names[j])

      params:add_file("load_bank_"..i.."_slot_"..j, ">", "")
      params:set_action("load_bank_"..i.."_slot_"..j, function(path) smpls.load(path, i, j) end)

      params:add_control("level_bank_"..i.."_slot_"..j, "level", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
      params:set_action("level_bank_"..i.."_slot_"..j, function(val) smpls.bank[i].slot[j].level = val end)
      
      params:add_control("pan_bank_"..i.."_slot_"..j, "pan", controlspec.new(-1, 1, 'lin', 0, 0, ""), function(param) return pan_display(param:get()) end)
      params:set_action("pan_bank_"..i.."_slot_"..j, function(val) smpls.bank[i].slot[j].pan = val end)
      
      params:add_control("send_bank_"..i.."_slot_"..j, "send", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
      params:set_action("send_bank_"..i.."_slot_"..j, function(val) smpls.bank[i].slot[j].send = val end)
      
      params:add_option("rate_bank_"..i.."_slot_"..j, "rate", {"-200%", "-100%", "-50%", "-12.5%", "12.5%", "12.5%", "25%", "50%", "100%", "200%"}, 9)
      params:set_action("rate_bank_"..i.."_slot_"..j, function(idx) smpls.bank[i].slot[j].rate = smpls.rate_values[idx] end)
      
      params:add_control("cutoff_bank_"..i.."_slot_"..j, "cutoff", controlspec.new(20, 20000, 'exp', 0, 20000, "hz"))
      params:set_action("cutoff_bank_"..i.."_slot_"..j, function(val) smpls.bank[i].slot[j].fc = val end)
      
      params:add_control("reso_bank_"..i.."_slot_"..j, "filter q", controlspec.new(0.1, 4.0, 'exp', 0.01, 2.0, ""))
      params:set_action("reso_bank_"..i.."_slot_"..j, function(val) smpls.bank[i].slot[j].rq = val end)
    end

    -- init softcut
    softcut.enable(i, 1)
    softcut.buffer(i, 1)

    softcut.level_input_cut(1, i, 0)
    softcut.level_input_cut(2, i, 0)
    softcut.level_cut_cut(i, 6, 0)

    softcut.play(i, 1)
    softcut.rec(i, 0)
    
    softcut.level(i, 0)
    softcut.pan(i, 0)

    softcut.pre_level(i, 1)
    softcut.rec_level(i, 0)
    
    softcut.post_filter_dry(i, 0)
    softcut.post_filter_lp(i, 1)
    softcut.post_filter_fc(i, 20000)
    softcut.post_filter_rq(i, 4)

    softcut.fade_time(i, 0.05)
    softcut.level_slew_time(i, 0.1)
    softcut.pan_slew_time(i, 0.1)
    softcut.rate_slew_time(i, 0)
    softcut.rate(i, 1)

    softcut.loop(i, 0)
    softcut.loop_start(i, smpls.bank[i].s)
    softcut.loop_end(i, smpls.bank[i].e)
    softcut.position(i, smpls.bank[i].s)

    --softcut.phase_quant(i, 0.01)
    --softcut.phase_offset(i, 0)
    --softcut.event_phase(smpls.poll_phase)
    --softcut.poll_start_phase()
  end
end

function smpls.poll_phase(i, pos)
  if smpls.bank[i].slot[smpls.bank[i].last_slot].rate > 0 then
    if pos >= smpls.bank[i].slot[smpls.bank[i].last_slot].ne then
      softcut.level(i, 0)
    end
  else
    if pos <= smpls.bank[i].slot[smpls.bank[i].last_slot].ns then
      softcut.level(i, 0)
    end
  end
end

return smpls