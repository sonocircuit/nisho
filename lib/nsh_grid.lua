local drmfm = include 'lib/nsh_drmfm'
local caw = include 'lib/nsh_crow'

local g = grid.connect()

-- local variables
local GRIDSIZE = 0

local mod = {}
mod.a = false
mod.b = false
mod.c = false
mod.d = false
mod.any = false

local gk = {}
for x = 1, 16 do
  gk[x] = {}
  for y = 1, 16 do
    gk[x][y] = {}
    gk[x][y].held = false
    gk[x][y].n_val = 0
    gk[x][y].n_key = 0
  end
end

local held = {} -- track num held keys
held.int = 0
held.key = 0
held.kit = 0
held.cmem = 0
held.ccnf = 0
held.trig = 0
held.ptn = {}
for i = 1, 8 do
  held.ptn[i] = {}
  held.ptn[i].num = 0
  held.ptn[i].max = 0
  held.ptn[i].first = 0
  held.ptn[i].second = 0
end

local rk = {0, 0, 0, 0}


-------------------------- note management functions --------------------------
local function track_num_held(src, z)
  held[src] = held[src] + (z * 2 - 1)
  if held[src] < 0 then held[src] = 0 end
end

local function table_remove(t, note)
  for k = #t, 1, -1 do
    if t[k] == note then
      table.remove(t, k)
      break
    end
  end
end

function add_note(n_key, n_val)
  table.insert(notes.keys, n_key)
  if seq.collecting and not seq.appending then
    table.insert(seq.collected, n_key)
  elseif seq.appending and not seq.collecting then
    table.insert(seq.notes, n_key)
    seq.notes_added = true
  elseif seq.active and not seq.polyseq then
    if seq.hold and (held.key + held.cmem) == 1 then seq.notes = {} end
    table.insert(seq.notes, n_key)
  end
  if seq.active or rep.active then
    reset_trig_step(held.key + held.cmem)
  else
    local e = {t = eSCALE, i = voice.keys, note = n_val, vel = voice[voice.keys].velocity, action = "note_on"} event(e)
  end
  notes.last = n_val + notes.scale_oct * notes.int_oct[voice.int]
end

function remove_note(n_key, n_val)
  local i = voice.keys
  if (voice[i].sustaining and not tab.contains(voice[i].sustained, n_val)) or not voice[i].sustaining then
    if seq.active and not (seq.collecting or seq.appending or seq.hold or seq.polyseq) then
      table_remove(seq.notes, n_key)
    elseif not rep.active then
      local e = {t = eSCALE, i = i, note = n_val, action = "note_off"} event(e)
    end
    table_remove(notes.keys, n_key)
  end
end

function sustain_notes(i, sustain)
  if sustain then
     if i == voice.keys and #notes.keys > 0 and voice[i].keys_option < 4 then
      for idx, note in ipairs(notes.keys) do
        local note = note + notes.trsp_int
        voice[i].sustained[idx] = note
      end
      voice[i].sustaining = true
    end
  else
    for _, note in ipairs(voice[i].sustained) do
      local e = {t = eSCALE, i = i, note = note, action = "note_off"} event(e)
    end
    voice[i].sustained = {}
    voice[i].sustaining = false
  end
end

-------------------------- trig/rep functions --------------------------

function set_trig_start()
  trigs.lock = false
  trigs.step = 0
  if trigs.reset_mode > 2 then
    if not trigs.lock then
      local beat_sync = trigs.reset_mode == 3 and 1 or quant.bar
      clock.run(function()
        clock.sync(beat_sync, -1/8)
        trigs.step = 0
        trigs.lock = true
      end)
    end
  end
end

function reset_trig_step(held_keys)
  local held_keys = held_keys or 0
  if held_keys < 2 then
    if trigs.reset_mode == 1 then
      trigs.step = 0
      if seq.polyseq and not seq.hold then seq.step = 0 end
    elseif trigs.reset_mode == 2 then
      if not trigs.lock then
        trigs.step = 0
        trigs.lock = true
        if seq.polyseq then seq.step = 0 end
      end
    end
  end
end

function set_repeat_rate(t, z)
  if not rep.active then
    set_trig_start()
  end
  local idx = tonumber(tostring(t[4]..t[3]..t[2]..t[1]), 2)
  rep.active = idx > 0 and true or false
  if idx > 0 then
    rep.rate = rep.rate_val[idx] * 4
    if z == 1 then
      show_message("repeat  rate:  "..rep.rate_ids[idx])
    end
  else
    trigs.lock = false
  end
end

-------------------------- chord functions --------------------------
function clear_chord()
  if next(notes.chrd) and not rep.active then
    for _, note in ipairs(notes.chrd) do
      local e = {t = eSCALE, i = voice.keys, note = note, action = "note_off"} event(e)
    end
  end
  notes.chrd = {}
  notes.keys = {}
  chrd.name = ""
  page_redraw(1)
end

function play_chord(i)
  chrd.current = i
  local num = tonumber(tostring(chrd.key[i][3]..chrd.key[i][2]..chrd.key[i][1]), 2)
  local t = chrd.idx[num]
  if next(chrd.nts[i][t]) then
    -- clear notes    
    clear_chord()
    -- reset trig step
    if (rep.active or seq.active) then reset_trig_step() end
    -- set chord and strum notes
    local octave = notes.scale_oct * (notes.key_oct[voice.keys] + 3)
    for _, note in ipairs(chrd.nts[i][t][chrd.inv]) do
      table.insert(notes.chrd, note + octave + notes.trsp_int)
      table.insert(notes.keys, note + octave)
    end
    -- play chord
    if chrd.mode and not rep.active then
      for _, note in ipairs(notes.chrd) do
        local e = {t = eSCALE, i = voice.keys, note = note, vel = voice[voice.keys].velocity, action = "note_on"} event(e)
      end
    end
    chrd.name = notes.names[i].." "..chrd.id[t]
    notes.last = chrd.nts[i][t][1][1] + notes.scale_oct * (notes.int_oct[voice.int] + notes.key_oct[voice.keys] + 3)
    -- strum chord
    if chrd.strm then
      if strum_clock ~= nil then
        clock.cancel(strum_clock)
      end
      strum_clock = clock.run(autostrum, chrd.nts[i][t].strum, octave)
    end
    -- collect or append notes to seq
    if seq.collecting and not seq.appending then
      for _, note in ipairs(notes.keys) do
        table.insert(seq.collected, note)
      end
    elseif seq.appending and not seq.collecting then
      for _, note in ipairs(notes.keys) do
        table.insert(seq.notes, note)
      end
      seq.notes_added = true
    elseif seq.active and not seq.polyseq then
      seq.notes = {}
      for s = chrd.inv, chrd.strm_num + chrd.inv do
        local note = chrd.nts[i][t].strum[s] + octave
        table.insert(seq.notes, note)
      end
      seq.step = 0
    end
  end
end

function autostrum(strum_notes, octave)
  local endpoint = chrd.strm_num + chrd.inv - 1
  -- strum loop
  for i = chrd.inv, endpoint do
    local step = i
    local pos = i - chrd.inv + 1
    -- calc index (step)
    if chrd.strm_mode == 2 then
      if pos % 2 == 0 then
        step = endpoint - pos + 2
      end
    elseif chrd.strm_mode == 3 then
      step = math.random(chrd.inv, endpoint)
    elseif chrd.strm_mode == 4 then
      if pos % 2 ~= 0 then
        step = endpoint - pos
      end
    elseif chrd.strm_mode == 5 then
      step = endpoint - pos + 1
    end
    if step > 15 then step = 15 end
    if step < 1 then step = 1 end
    -- calc rate
    local rate_var = math.random(-12, 12) * chrd.strm_drift
    local rate = chrd.strm_rate + rate_var
    if chrd.strm_skew > 0 then
      rate = chrd.strm_rate + ((endpoint - (i - 1)) * chrd.strm_skew * 0.001)
    elseif chrd.strm_skew < 0 then
      rate = chrd.strm_rate - (i * chrd.strm_skew * 0.001)
    end
    -- play notes
    local vox = voice.strum > 0 and voice.strum or voice.keys
    local note = strum_notes[step] + octave + (notes.scale_oct * chrd.oct_off) + notes.trsp_int
    local e = {t = eSCALE, i = vox, note = note, vel = voice[voice.keys].velocity, action = "note_on"} event(e)
    clock.run(function()
      clock.sleep(rate)
      local e = {t = eSCALE, i = vox, note = note, action = "note_off"} event(e)
    end)
    clock.sleep(rate)
  end
end

-------------------------- pattern functions --------------------------
function set_pattern_loop(i)
  local dur = ptn.loop_set_q == 2 and 1 or (ptn.loop_set_q == 3 and quant.bar or ptn[ptn.focus].quantize)
  clock.sync(dur)
  local first = held.ptn[ptn.focus].first
  local second = ptn.duplicating and held.ptn[ptn.focus].first or held.ptn[ptn.focus].second
  local segment = math.floor(ptn[ptn.focus].endpoint / 16)
  ptn[i].step_min = segment * (math.min(first, second) - 1)
  ptn[i].step_max = segment * math.max(first, second)
  ptn[i].step = ptn[i].step_min
  p[i].step_min_viz[p[i].bank] = math.min(first, second)
  p[i].step_max_viz[p[i].bank] = math.max(first, second)
  p[i].looping = true
  clear_active_notes(i)
end

function clear_pattern_loop(i)
  local dur = ptn.loop_clr_q == 2 and 1 or (ptn.loop_clr_q == 3 and quant.bar or ptn[ptn.focus].quantize)
  clock.sync(dur)
  ptn[i].step = 0
  ptn[i].step_min = 0
  ptn[i].step_max = ptn[i].endpoint
end

function pattern_keys(i)
  if ptn.focus ~= i and num_rec_enabled() == 0 then
    ptn.focus = i
  end
  if not (ptn.pasting or ptn.copying) then
    if ptn.clear or (mod.a and mod.c) or (mod.b and mod.d) then
      if ptn[i].count > 0 then
        clear_pattern_bank(i, p[i].bank)
      end
    else
      if ptn[i].play == 0 then
        local beat_sync = ptn[i].launch == 2 and 1 or (ptn[i].launch == 3 and quant.bar or nil)
        if ptn[i].count == 0 then
          if seq.appending then
            paste_seq_pattern(i)
          else
            if num_rec_enabled() == 0 then
              local mode = ptn.rec_mode == "synced" and 1 or 2
              local dur = ptn.rec_mode ~= "free" and ptn[i].length or nil
              ptn[i]:set_rec(mode, dur, beat_sync)
              ptn.rec_enabled = true
            else
              ptn[i]:set_rec(0)
              ptn[i]:stop()
              ptn.rec_enabled = false
            end
          end
        else
          ptn[i]:start(beat_sync)
        end
      else
        if (ptn.overdub_active or mod.a or mod.b) then
          if ptn[i].rec == 1 then
            ptn[i]:set_rec(0)
            ptn[i]:undo()
            ptn.rec_enabled = false
          else
            if ptn.oneshot_overdub then
              local dur = ptn.rec_mode ~= "free" and ptn[i].length or nil
              ptn[i]:set_rec(2, dur, beat_sync)
            else
              ptn[i]:set_rec(1)
            end   
            ptn.rec_enabled = true          
          end
        else
          if ptn[i].rec == 1 then
            ptn[i]:set_rec(0)
            ptn.rec_enabled = false
            if ptn[i].count == 0 then
              ptn[i]:stop()
            end
          else
            ptn[i]:stop()
            p[i].stop = false
          end
        end
      end
    end
  end
end

function pattern_slots(x, y, z, off) -- grid one: off = 2
  local y = off and (y - off) or y
  local bank = y + ptn.page * 3
  if (x == 4 or x == 13) and y < 4 and z == 1 then
    for i = 1, 8 do
      p[i].load = bank
      if ptn[i].play == 0 then
        update_pattern_bank(i)
        if ptn.overdub_active and p[i].count[bank] > 0 then
          ptn[i]:start(quant.bar)
        end
      else
        clock.run(function()
          clock.sync(quant.bar)
          update_pattern_bank(i)
          ptn[i].step = 0
        end)
      end
    end
  elseif x == 13 and y == 4 and z == 1 then
    stop_all_patterns()
  else
    local i = x - 4
    if ui.prgchg_view then
      if z == 1 then
        if y == 4 then
          p[i].prc_enabled = not p[i].prc_enabled
        else
          ptn.focus = i
          ptn.bank = bank
          if ptn.clear then
            p[i].prc_num[bank] = 0
          end
        end
      end
    else
      if y < 4 then
        -- select active pattern bank, copy/paste/duplicate/append actions
        if z == 1 then
          -- set pattern focus
          if ptn.focus ~= i and num_rec_enabled() == 0 then
            ptn.focus = i
            held.ptn[ptn.focus].num = 0
          end
          -- copy/paste/append/duplicate
          if ptn.pasting and ptn.copy.state then
            copy_pattern(ptn.copy.pattern, ptn.copy.bank, i, bank)
            show_message("pasted  to  pattern  "..i.."  bank  "..bank)
            ptn.copy = {state = false, pattern = nil, bank = nil}
          elseif ptn.appending and ptn.copy.state then
            local src_s = nil
            local src_e = nil
            if p[ptn.copy.pattern].looping then
              src_s = ptn[ptn.copy.pattern].step_min
              src_e = ptn[ptn.copy.pattern].step_max
            end
            append_pattern(ptn.copy.pattern, ptn.copy.bank, i, bank, src_s, src_e)
            show_message("appended  to  pattern  "..i.."  bank  "..bank)
            ptn.copy = {state = false, pattern = nil, bank = nil}
          elseif (ptn.pasting or ptn.appending) and not ptn.copy.state then
            show_message("clipboard   empty")
          elseif ptn.copying and not ptn.copy.state then
            if p[i].count[bank] > 0 then
              ptn.copy.pattern = i
              ptn.copy.bank = bank
              ptn.copy.state = true
              show_message("pattern  "..ptn.copy.pattern.."  bank  "..ptn.copy.bank.."  selected")
            else
              show_message("pattern   empty")
            end
          elseif ptn.duplicating then
            if p[i].count[bank] > 0 then
              append_pattern(i, bank, i, bank)
              show_message("doubled   pattern")
            else
              show_message("pattern   empty")
            end
          elseif ptn.clear or (mod.a and mod.c) or (mod.b and mod.d) then
            clear_pattern_bank(i, bank)
          -- load pattern
          elseif not (ptn.copying or ptn.pasting) then
            if p[i].bank ~= bank then
              if p[i].load ~= nil then
                clock.run(function()
                  clock.sync(1)
                  update_pattern_bank(i)
                  ptn[i].step = 0
                end)
              else
                p[i].load = bank
                if ptn[i].play == 0 then
                  update_pattern_bank(i)
                end
              end
            elseif p[i].load then
              p[i].load = nil
            end
          end
        end
        focus_page(3)
      elseif y == 4 and z == 1 then
        if ptn[i].play == 1 then
          p[i].stop = not p[i].stop
        else
          p[i].stop = false
        end
      end
    end
  end
end

local rec_modes = {"queued", "synced", "free"}
function pattern_options(x, y, z)
  if y == 1 and x == 1 then
    ptn.copying = z == 1 and true or false
    if z == 1 then
      ptn.copy = {state = false, pattern = nil, bank = nil}
    end
  elseif y == 1 and x == 2 then
    ptn.pasting = z == 1 and true or false
  elseif y == 1 and x == 3 then
    ptn.appending = z == 1 and true or false
  elseif y == 1 and x > 13 and z == 1 then
    if ptn.rec_mode == rec_modes[x - 13] then
      ptn.oneshot_overdub = not ptn.oneshot_overdub
    end
    ptn.rec_mode = rec_modes[x - 13]
    page_redraw(3)
  elseif y == 2 and x == 1 then
    ptn.clear = z == 1 and true or false
  elseif y == 2 and x == 2 then
    if not ptn.clear then
      ptn.duplicating = z == 1 and true or false
    end
  elseif y == 2 and x == 15 then
    if z == 1 then
      ui.prgchg_view = not ui.prgchg_view
      if ui.prgchg_view then ui.preset_view = false end
    end
    dirtyscreen = true
  elseif y == 2 and x == 16 then
    if z == 1 then
      ui.preset_view = not ui.preset_view
      if ui.preset_view then ui.prgchg_view = false end
    end
    dirtyscreen = true
  elseif y == 3 and (x == 1 or x == 16) then
    ptn.overdub_active = z == 1 and true or false
  end 
end

function pattern_playhead(x, z)
  if z == 1 and held.ptn[ptn.focus].num then held.ptn[ptn.focus].max = 0 end
  held.ptn[ptn.focus].num = held.ptn[ptn.focus].num + (z * 2 - 1)
  if held.ptn[ptn.focus].num > held.ptn[ptn.focus].max then held.ptn[ptn.focus].max = held.ptn[ptn.focus].num end
  if z == 1 then
    if held.ptn[ptn.focus].num == 1 then
      held.ptn[ptn.focus].first = x
    elseif held.ptn[ptn.focus].num == 2 then
      held.ptn[ptn.focus].second = x
    end
  else
    if ptn.clear then
      for i = 1, 8 do
        if p[i].looping then
          clock.run(clear_pattern_loop, i)
          p[i].looping = false
        end
      end
    elseif held.ptn[ptn.focus].num == 1 and held.ptn[ptn.focus].max == 2 then
      if ptn.overdub_active then
        for i = 1, 8 do
          if ptn[i].play == 1 then
            clock.run(set_pattern_loop, i)
          end
        end
      else
        clock.run(set_pattern_loop, ptn.focus)
      end
    elseif p[ptn.focus].looping and held.ptn[ptn.focus].max < 2 then
      clock.run(clear_pattern_loop, ptn.focus)
      p[ptn.focus].looping = false
    elseif not p[ptn.focus].looping and held.ptn[ptn.focus].max < 2 then
      if ptn.duplicating then
        clock.run(set_pattern_loop, ptn.focus)
      else
        clock.run(function()
          clock.sync(quant.rate)
          local segment = math.floor(ptn[ptn.focus].endpoint / 16)
          ptn[ptn.focus].step = segment * (x - 1)
        end)
      end
    end
  end    
end


-------------------------- trigs functions --------------------------
local function trig_view_logic(z)
  if z == 1 then
    trigs.view_shortpress = true
    if trigs.view_timer ~= nil then
      clock.cancel(trigs.view_timer)
    end
    trigs.view_timer = clock.run(function()
      clock.sleep(1/6)
      trigs.view_shortpress = false
      trigs.view_timer = nil
      trigs.reset_mode_view = ui.trigs_view and true or false
      dirtyscreen = true
    end)
  else
    if trigs.view_shortpress then
      ui.trigs_view = not ui.trigs_view
      trigs.edit_trig = false
      if trigs.view_timer ~= nil then
        clock.cancel(trigs.view_timer)
        trigs.view_timer = nil
      end
      if not ui.trigs_view then
        if #notes.kit > 0 and GRIDSIZE == 128 then
          for _, note in ipairs(notes.kit) do
            drmfm.stop(note)
          end
          notes.kit = {}
          held.kit = 0
        end
      end
    else
      trigs.reset_mode_view = false
    end
    dirtyscreen = true
  end
end

local function nudge_trigs(t, step, size)
  local nt = {table.unpack(t)}
  for i = 1, size do
    local n = util.wrap(i + step, 1, size)
    nt[n] = t[i]
  end
  return nt
end

function reset_trig_pattern(i)
  trigs[i].step_max = 16
  trigs[i].pattern = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].prob = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].vel = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].ratnum = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  trigs[i].ratvel = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

function copy_trig(i)
  if next(trigs.copy_data) then
    trigs[i].step_max = trigs.copy_data.step_max
    trigs[i].pattern = trigs.copy_data.pattern
    trigs[i].prob = trigs.copy_data.prob
    trigs[i].vel = trigs.copy_data.vel
    trigs[i].ratnum = trigs.copy_data.ratnum
    trigs[i].ratvel = trigs.copy_data.ratvel
    trigs.copy_data = {}
  else
    trigs.copy_data = {
      step_max = trigs[i].step_max
      pattern = {table.unpack(trigs[i].pattern)},
      prob = {table.unpack(trigs[i].prob)},
      vel = {table.unpack(trigs[i].vel)},
      ratnum = {table.unpack(trigs[i].ratnum)},
      ratvel = {table.unpack(trigs[i].ratvel)}
    } 
  end
end

function trig_logic(i, z)
  track_num_held("trig", z)
  if z == 1 then
    if trigs.edit_timer ~= nil then
      clock.cancel(trigs.edit_timer)
    end
    trigs.edit_shortpress = true
    trigs.edit_timer = clock.run(function()
      clock.sleep(1/6)
      trigs.edit_trig = true
      trigs.edit_shortpress = false
      dirtyscreen = true
    end)
  else
    if trigs.edit_timer ~= nil then
      clock.cancel(trigs.edit_timer)
      trigs.edit_timer = nil
    end
    if trigs.edit_shortpress then
      trigs[trigs.focus].pattern[i] = 1 - trigs[trigs.focus].pattern[i]
      trigs.edit_shortpress = false
    end
    if held.trig < 1 then trigs.edit_trig = false end
    dirtyscreen = true
  end
end

function trigs_grid(x, y, z, grid)
  if grid == 256 then -- grid zero
    local i = x
    if y == 5 then
      trigs.step_focus = x
      if trigs.set_end then
        if z == 1 then trigs[trigs.focus].step_max = i end
      elseif trigs.nudging then
        if z == 1 then
          local step = x > 8 and (17 - x) or -x
          local size = trigs[trigs.focus].step_max
          trigs[trigs.focus].pattern = nudge_trigs(trigs[trigs.focus].pattern, step, size)
          trigs[trigs.focus].prob = nudge_trigs(trigs[trigs.focus].prob, step, size)
          trigs[trigs.focus].vel = nudge_trigs(trigs[trigs.focus].vel, step, size)
          trigs[trigs.focus].ratnum = nudge_trigs(trigs[trigs.focus].ratnum, step, size)
          trigs[trigs.focus].ratvel = nudge_trigs(trigs[trigs.focus].ratvel, step, size)
        end
      else
        trig_logic(i, z)
      end
    elseif y == 6 then
      if x == 1 then
        trigs.pattern_reset = z == 1 and true or false
      elseif x == 2 then
        trigs.copying = z == 1 and true or false
        if z == 0 then
          trigs.copy_data = {}
        end
      elseif x > 4 and x < 13 and z == 1 then
        local i = x - 4
        if trigs.copying then
          copy_trig(i)
        elseif trigs.pattern_reset then
          reset_trig_pattern(i)
        elseif held.cmem > 0 then
          cmem[cmem.active].trigs = cmem[cmem.active].trigs == i and 0 or i
        end
        trigs.focus = i
      elseif x == 15 then
        trigs.nudging = z == 1 and true or false
      elseif x == 16 then
        trigs.set_end = z == 1 and true or false
      end
    end
  else -- grid one
    if x > 3 and x < 14 and y > 2 and y < 5 then
      if x < 12 then
        local i = (x - 3) + (y - 3) * 8
        trigs.step_focus = i
        if trigs.set_end and z == 1 then
          trigs[trigs.focus].step_max = i
        elseif trigs.pattern_reset and z == 1 then
          reset_trig_pattern(trigs.focus)
        else
          trig_logic(i, z)
        end
      elseif x == 12 then
        if y == 3 then
          trigs.set_end = z == 1 and true or false
        elseif y == 4 then
          trigs.pattern_reset = z == 1 and true or false
        end
      elseif x == 13 and z == 1 then
        if held.cmem > 0 then
          cmem[cmem.active].trigs = cmem[cmem.active].trigs == trigs.focus and 0 or trigs.focus
          local msg = cmem[cmem.active].trigs ~= 0 and ("  >  trig   pattern:  "..trigs.focus) or "   unassigned"
          show_message("mem-slot  "..cmem.active..msg)
        else
          local inc = y == 3 and -1 or 1
          trigs.focus = util.clamp(trigs.focus + inc, 1,  8)
          show_message("trig    pattern:  "..trigs.focus)
        end
      end
    end
  end
end

-------------------------- grid key functions --------------------------
function modifier_keys(x, y, z, off) -- grid one: off = -6
  local y = off and (y - off) or y
  local state = z == 1 and true or false
  mod.any = state
  if y == 7 then
    if x == 4 then
      mod.a = state
    elseif x == 13 then
      mod.b = state
    end
  elseif y == 8 then
    if x == 4 then
      mod.c = state
    elseif x == 13 then
      mod.d = state
    end
  end
end

function voice_settings(x, y, z, off) -- grid one: off = -6
  local y = off and (y - off) or y
  if x < 4 or x > 13 then
    local i = x < 4 and x or x - 10
    if y == 7 then
      if z == 1 then
        if chrd.strm_edit then
          if voice.strum ~= i then
            voice.strum = i
          else
            voice.strum = 0
          end
        elseif (mod.a or mod.b) then
          params:set("voice_mute_"..i, voice[i].mute and 1 or 2)
        elseif not voice[i].mute then
          if held.int > 0 and i ~= voice.int then
            clear_held_notes(voice.int)
          end
          voice.int = i
        end
      end
    elseif y == 8 then
      if z == 1 then
        if ui.shift then
          ui.voice_focus = i
        elseif (mod.a or mod.b) then
          params:set("voice_mute_"..i, voice[i].mute and 1 or 2)
        elseif (mod.c or mod.d) then
          dont_panic(voice[i].output)
          held.key = 0
        elseif not voice[i].mute then
          if held.key > 0 and i ~= voice.keys then
            clear_held_notes(voice.keys)
          end
          voice.keys = i
          ui.voice_focus = i
          dirtyscreen = true
          if keyedit_timer ~= nil then
            clock.cancel(keyedit_timer)
          end
          keyedit_timer = clock.run(function()
            clock.sleep(0.6)
            ui.keyedit_view = true
            dirtyscreen = true
          end)
        end
        focus_page(2)
      else
        if keyedit_timer ~= nil then
          clock.cancel(keyedit_timer)
          keyedit_timer = nil
        end
        ui.keyedit_view = false
        dirtyscreen = true
      end
    elseif y == 9 and z == 1 then
      sustain_notes(i, not voice[i].sustaining)
    end
  end
end

function voice_options(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  if z == 1 then
    if y == 10 then
      if x == 1 then
        params:set("keys_option_"..voice.keys, 1)
      elseif x == 2 then
        params:set("keys_option_"..voice.keys, 3)
      end
    elseif y == 11 then
      if x == 1 then
        params:set("keys_option_"..voice.keys, 2)
      elseif x == 2 then
        params:set("keys_option_"..voice.keys, 4)
      end
    end
  end
end

function grid_options(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  if y == 10 then
    if x == 15 and z == 1 then
      quant.active = not quant.active
    elseif x == 16 then
      ui.keyquant_view = z == 1 and true or false
      dirtyscreen = true
    end
  elseif y == 11 then
    if x == 15 and z == 1 then
      ui.kit_view = not ui.kit_view
      if ui.kit_view then
        focus_page(4)
      end
    elseif x == 16 and z == 1 then
      if rep.active and rep.view and off ~= nil then
        rep.hold = not rep.hold
        if not rep.hold then
          rk = {0, 0, 0, 0}
          set_repeat_rate(rk, z)
        end
      else
        rep.view = not rep.view
        if rep.view then
          seq.active = false
          seq.config = false
        else
          rep.hold = false
          rk = {0, 0, 0, 0}
          set_repeat_rate(rk, z)
        end
      end
    end
  end
end

function kit_grid(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  if x > 3 and x < 12 then
    if y > 9 and y < 12 then
      track_num_held("kit", z)
      --held.kit = held.kit + (z * 2 - 1)
      local i = ((x - 3) + (11 - y) * 8)
      ui.kit_focus = i
      params:set("drmfm_selected_voice", i)
      if z == 1 then
        table.insert(notes.kit, i)
        if mute.edit then
          edit_kit_mutes(i)
        elseif ui.kit_options then
          if ui.kit_action == 1 then
            drmfm.exec_copy(i)
          elseif ui.kit_action == 3 then
            drmfm.init_model(i)
          end
        elseif rep.active then
          if held.kit == 1 then
            reset_trig_step()
          end
        elseif ptn.clear or (mod.a and mod.c) or (mod.b and mod.d) then
          clear_kit_voice(ptn.focus, i)
        else
          local e = {t = eKIT, note = i, vel = 127, action = "note_on"} event(e)
        end
        focus_page(4)
      else
        if not (mute.edit or ui.kit_options or rep.active) then
          local e = {t = eKIT, note = i, action = "note_off"} event(e)
        end
        table_remove(notes.kit, i)
      end       
    elseif y == 9 and mute.edit then
      if x > 5 and x < 12 then
        if z == 1 then
          local mute_group = x - 5
          if mute.focus == mute_group and mute.active then
            clear_mutes()
          else
            set_mutes(mute_group)
          end
        end
      end
    end
  elseif x == 12 then
    if y == 10 then
      ui.kit_options = z == 1 and true or false
      drmfm.init_copy(z)
      autofocus_timer()
      focus_page(4)
    elseif y == 11 then
      mute.edit = z == 1 and true or false
    end
  elseif x == 13 then
    gk[x][y].held = z == 1 and true or false
    if y == 10 then
      if z == 1 then
        drmfm.perf_ramp("run")
      else
        if not mod.any then
          drmfm.perf_ramp("stop")
        end
      end
    elseif y == 11 then
      if mute.edit then
        if z == 1 then
          clear_mutes()
        end
      else
        mute_all(z)
      end
    end
  end
end

function int_grid(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  -- detect key hold
  if ((y == 9 or y == 11) and x > 7 and x < 9) or (y == 10 and ((x > 3 and x < 8) or (x > 9 and x < 14))) then
    track_num_held("int", z)
    --held.int = held.int + (z * 2 - 1)
    --if held.int < 0 then held.int = 0 end
  end
  if z == 1 then
    if y == 9 and x > 7 and x < 10 then
      if notes.trsp_active then
        notes.trsp_int = 0
        page_redraw(1)
      else
        local e = {t = eSCALE, i = voice.int, note = notes.home, vel = voice[voice.int].velocity, action = "note_on"} event(e)
        gk[x][y].n_val = notes.home
        notes.last = notes.home
      end
    elseif y == 10 then
      if ((x > 3 and x < 8) or (x > 9 and x < 14)) then
        local interval = x < 9 and x - 8 or x - 9
        if cmem.rec then
          if #cmem[cmem.focus].notes > 0 then
            local t = cmem[cmem.focus].notes
            for i, note in ipairs(t) do
              cmem[cmem.focus].notes[i] = note + interval
              if held.cmem > 0 then
                local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
                voice_note_off(voice.keys, note_num)
              end
            end
          end
        elseif notes.trsp_active then
          local limit = (2 * notes.scale_oct)
          notes.trsp_int = util.clamp(notes.trsp_int + interval, -limit, limit)
          page_redraw(1)
        else
          local new_note = util.clamp(notes.last + interval, 1, #notes.scale)
          local e = {t = eSCALE, i = voice.int, note = new_note, vel = voice[voice.int].velocity, action = "note_on"} event(e)
          gk[x][y].n_val = new_note
          notes.last = new_note
        end        
      elseif x > 7 and x < 10 then
        if trsp_clk ~= nil then
          clock.cancel(trsp_clk)
        end
        trsp_clk = clock.run(function()
          clock.sleep(0.4)
          notes.trsp_active = not notes.trsp_active
          notes.trsp_int = 0
          page_redraw(1)   
        end)  
      end
    elseif y == 11 then
      if x > 7 and x < 10 then
        if cmem.rec then
          if #cmem[cmem.focus].notes > 0 then
            local t = cmem[cmem.focus].notes
            for i, note in ipairs(t) do
              cmem[cmem.focus].notes[i] = note + (notes.scale_oct * (x - 8 == 0 and -1 or 1))
              if held.cmem > 0 then
                local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
                voice_note_off(voice.keys, note_num)
              end
            end
          end
        elseif notes.trsp_active then
          local limit = (2 * notes.scale_oct)
          local interval = (notes.scale_oct * (x - 8 == 0 and -1 or 1))
          notes.trsp_int = util.clamp(notes.trsp_int + interval, -limit, limit)
          page_redraw(1)
        else
          local e = {t = eSCALE, i = voice.int, note = notes.last, vel = voice[voice.int].velocity, action = "note_on"} event(e)
          gk[x][y].n_val = notes.last
        end
      end
    end
  elseif z == 0 then
    if ((y == 9 or y == 11) and x > 7 and x < 10) or (y == 10 and ((x > 3 and x < 8) or (x > 9 and x < 14))) then
      if not notes.trsp_active then
        local e = {t = eSCALE, i = voice.int, note = gk[x][y].n_val, action = "note_off"} event(e)
      end
    elseif x > 7 and x < 10 then
      if trsp_clk ~= nil then
        clock.cancel(trsp_clk)
        trsp_clk = nil
      end
    end
  end
end

function seq_settings(x, z)
  if x == 1 then
    hrmy.config = z == 1 and true or false
    ui.page = 1
    dirtyscreen = true
  elseif x == 2 then
    -- perfscene = z == 1 and true or false
  elseif x > 4 and x < 13 and z == 1 then
    if hrmy.config then
      hrmy.active = x - 4
      params:set("scale", hrmy.slot[hrmy.active].scale)
      params:set("notes_root_scale", hrmy.slot[hrmy.active].root)
    elseif seq.config then
      params:set("key_seq_rate", x - 4)
      show_message("seq   rate:  "..seq.rate_ids[x - 4])
    end
  elseif x == 15 then
    trig_view_logic(z)
  elseif x == 16 then
    if rep.view and z == 1 then
      rep.hold = not rep.hold
      if not rep.hold then
        rk = {0, 0, 0, 0}
        set_repeat_rate(rk, z)
      end
      seq.config = false
    else
      seq.config = z == 1 and true or false
    end
  end
end

function octave_options(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if x == 1 then
    if mod.any and z == 1 then
      caw.ansi_view = not caw.ansi_view
    else
      if caw.ansi_view then
        local i = y - 12
        if z == 1 then
          table.insert(notes.ansi, i)
          if rep.active then
            if #notes.ansi == 1 then
              reset_trig_step()
            end
          else
            local e = {t = eANSI, i = i} event(e)
          end
        else
          table_remove(notes.ansi, i)
        end
      else
        if (y == 13 or y == 14) and z == 1 then
          local inc = y == 13 and 1 or -1
          if chrd.strm_edit then
            params:delta("strum_octaves", inc)
          else
            params:delta("interval_octaves_"..voice.int, inc)
          end
        elseif (y == 15 or y == 16) and z == 1 then
          local inc = y == 15 and 1 or -1
          params:delta("keys_octaves_"..voice.keys, inc)
        end
      end
    end
  elseif x == 2 then
    if y == 13 then -- channel aftertouch
      local at_coro = z == 1 and at_ramp_up or at_ramp_down
      if at[voice.keys].timer ~= nil then
        clock.cancel(at[voice.keys].timer)
      end
      at[voice.keys].timer = clock.run(at_coro, voice.keys)
    elseif y == 14 then -- modwheel
      local mw_coro = z == 1 and mw_ramp_up or mw_ramp_down
      if mw[voice.keys].timer ~= nil then
        clock.cancel(mw[voice.keys].timer)
      end
      mw[voice.keys].timer = clock.run(mw_coro, voice.keys)
    elseif (y == 15 or y == 16) then -- pitchbend
      local pb_coro = z == 1 and pb_ramp_up or pb_ramp_down
      pb[voice.keys].dir = y == 15 and 1 or -1
      if pb[voice.keys].timer ~= nil then
        clock.cancel(pb[voice.keys].timer)
      end
      pb[voice.keys].timer = clock.run(pb_coro, voice.keys, pb[voice.keys].dir)
    end
  end  
end

function event_options(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if x == 15 then
    if off then
      if y == 13 then
        trig_view_logic(z)
      end
    end
    if y == 14 and z == 1 then
      if seq.collecting and not seq.appending then
        table.insert(seq.collected, 0)
        page_redraw(1)
      elseif seq.appending and not seq.collecting then
        table.insert(seq.notes, 0)
        seq.notes_added = true
      end
    elseif y == 15 and z == 1 then
      vl[voice.keys].baseline = vl[voice.keys].baseline == vl[voice.keys].lo and vl[voice.keys].hi or vl[voice.keys].lo
      voice[voice.keys].velocity = vl[voice.keys].baseline
    elseif y == 16 then
      local vl_coro = z == 1 and vl_ramp_up or vl_ramp_down
      if vl[voice.keys].timer ~= nil then
        clock.cancel(vl[voice.keys].timer)
      end
      vl[voice.keys].timer = clock.run(vl_coro, voice.keys)
    end
  elseif x == 16 then
    if rep.view then
      if y > 12 then
        local slot = y - 12
        if rep.hold then
          if z == 1 then
            rk[slot] = 1 - rk[slot]
          end
        else
          rk[slot] = z
        end
        set_repeat_rate(rk, z)
      end
    else
      if y == 13 then
        if z == 1 then
          seq.mode_shortpress = true
          if seq.mode_timer ~= nil then
            clock.cancel(seq.mode_timer)
          end
          seq.mode_timer = clock.run(function()
            clock.sleep(0.5)
            seq.polyseq = not seq.polyseq
            seq.hold = false
            seq.mode_shortpress = false
          end)
        elseif z == 0 then
          if seq.mode_shortpress then
            clock.cancel(seq.mode_timer)
            seq.mode_timer = nil
            seq.active = not seq.active
            seq.step = 0
            if seq.active then
              set_trig_start()
            else
              seq.notes = {}
              if seq.polyseq and seq.hold then
                seq.hold = false
                sustain_notes(i, false)
              end
            end
          end
        end
      elseif y == 14 then
        seq.collecting = z == 1 and true or false
        if z == 0 then
          if seq.notes_added then
            seq.notes_added = false
          else
            if #seq.collected > 0 then
              seq.step = 0
              reset_trig_step()
              seq.notes = {table.unpack(seq.collected)}              
            end
          end
          seq.collected = {}
        end        
        dirtyscreen = true
      elseif y == 15 then
        seq.appending = z == 1 and true or false
        if z == 1 then
          seq.prev_notes = {table.unpack(seq.notes)}
        elseif seq.notes_added then
          seq.notes = {table.unpack(seq.prev_notes)}
          seq.notes_added = false
          if seq.step >= #seq.prev_notes then
            seq.step = 0
          end
        end
      elseif y == 16 and z == 1 then
        seq.hold = not seq.hold
        if seq.polyseq then
          sustain_notes(voice.keys, seq.hold)
        elseif not seq.hold then
          seq.notes = {table.unpack(notes.keys)}
        end
      end
    end
  end
end

function scale_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  track_num_held("key", z)
  gk[x][y].held = z == 1 and true or false
  if z == 1 then
    local note = (x - 2) + ((16 - y) * ui.iso_y) + (notes.key_oct[voice.keys] + 3) * notes.scale_oct
    gk[x][y].n_val = note + notes.trsp_int
    gk[x][y].n_key = note
    add_note(note, gk[x][y].n_val)
  elseif z == 0 then
    remove_note(gk[x][y].n_key, gk[x][y].n_val)
  end
end

function chord_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if y < 16 then
    track_num_held("key", z)
    gk[x][y].held = z == 1 and true or false
    local i = x - 2
    local s = y - 12
    chrd.key[i][s] = z
    if z == 1 then
      play_chord(i)
    elseif z == 0 then
      if held.key < 1 then
        clear_chord()
        if not (seq.hold or seq.collecting or seq.appending or seq.polyseq) then
          seq.notes = {}
        end
      end
    end
  elseif y == 16 then
    if x == 3 and z == 1 then
      chrd.mode = not chrd.mode
    elseif x == 4 and z == 1 then
      chrd.strm = not chrd.strm
      if not chrd.strm and strum_clock ~= nil then
        clock.cancel(strum_clock)
      end
    elseif x == 5 then
      chrd.strm_len_edit = z == 1 and true or false
      chrd.strm_edit = z == 1 and true or false
    elseif x == 6 then
      chrd.strm_mode_edit = z == 1 and true or false
      chrd.strm_edit = z == 1 and true or false
    elseif x == 7 then
      chrd.strm_skew_edit = z == 1 and true or false
      chrd.strm_edit = z == 1 and true or false
    end
    if chrd.strm_len_edit and z == 1 then
      if x > 5 and x < 15 then
        params:set("strm_length", x - 2)
        if held.key > 0 then
          play_chord(chrd.current)
        end
      end
    elseif chrd.strm_mode_edit and z == 1 then
      if x > 9 and x < 15 then
        params:set("strm_mode", x - 9)
      end
    elseif chrd.strm_skew_edit then
      if (x == 8 or x == 9) then
        gk[x][y].held = z == 1 and true or false
        if z == 1 then
          params:delta("strm_rate", x == 8 and -1 or 1)
          show_message("strum   rate:  ".. params:string("strm_rate"))
        end
      elseif (x == 10 or x == 11) then
        if z == 1 then
          params:delta("strm_drift", x == 10 and -1 or 1)
          show_message("strum   drift:  ".. params:string("strm_drift"))
        end
      elseif x > 11 and x < 15 and z == 1 then
        if x == 13 then
          params:set("strm_skew", 0)
        else
          params:delta("strm_skew", x == 12 and - 1 or 1)
        end
        show_message("strum   skew:  ".. params:string("strm_skew"))
      end
    else
      if (x == 8 or x == 9) then
        local s = x == 8 and 1 or - 1
        local d = z == 1 and (-1 * s) or (1 * s)
        gk[x][y].held = z == 1 and true or false
        params:delta("keys_octaves_"..voice.keys, d)
        if held.key > 0 and chrd.preview and z == 1 then
          play_chord(chrd.current)
        end
      elseif x == 10 then
        if z == 1 then
          if chord_preview_clock ~= nil then
            clock.cancel(chord_preview_clock)
          end
          chord_preview_clock = clock.run(function()
            clock.sleep(0.5)
            chrd.preview = not chrd.preview
          end)
        else
          if chord_preview_clock ~= nil then
            clock.cancel(chord_preview_clock)
          end
        end
      elseif x > 10 and x < 15 then
        track_num_held("ccnf", z)
        if z == 1 then
          if mod.any then
            chrd.prev_inv = x - 10
          end
          chrd.inv = x - 10
          if held.key > 0 and chrd.preview then
            play_chord(chrd.current)
          end
        else
          if held.ccnf < 1 then
            chrd.inv = chrd.prev_inv
          end
        end
      end
    end
  end
end

function cmem_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if x < 7 then
    track_num_held("cmem", z)
    local i = (x - 2) + (y - 13) * 4
    if cmem.copying and z == 1 then
      if cmem.copy_src == 0 then
        cmem.copy_src = i
      else
        cmem[i].notes = {table.unpack(cmem[cmem.copy_src].notes)}
        cmem.copy_src = 0
      end
    elseif cmem.clear and z == 1 then
      cmem[i].notes = {}
    else
      if cmem.rec then
        if z == 1 then
          if held.cmem > 1 and next(cmem[i].notes) then
            for _, note in ipairs(cmem[cmem.focus].notes) do
              local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
              voice_note_off(voice.keys, note_num)
            end
          end
          if next(cmem[i].notes) then
            for _, note in ipairs(cmem[i].notes) do
              local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
              voice_note_on(voice.keys, note_num, voice[voice.keys].velocity)
            end
          end
          cmem.focus = i
        elseif z == 0 then
          if held.cmem < 1 and next(cmem[cmem.focus].notes) then
            for _, note in ipairs(cmem[cmem.focus].notes) do
              local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
              voice_note_off(voice.keys, note_num)
            end
          end
        end
      else
        if z == 1 then
          -- reset trigs / clear current notes
          if (held.cmem > 1 or seq.hold or seq.polyseq) and next(cmem[i].notes) then
            for _, note in ipairs(cmem[cmem.active].notes) do
              if seq.active or seq.polyseq then table_remove(seq.notes, note) end
              if not seq.polyseq then table_remove(notes.keys, note) end
            end
            if not (seq.active or rep.active) then
              for _, note in ipairs(cmem.mem) do
                if not tab.contains(notes.keys, note) then
                  local e = {t = eSCALE, i = voice.keys, note = note, action = "note_off"} event(e)
                end
              end
            end
          end
          -- play cmem
          if next(cmem[i].notes) then
            cmem.active = i
            -- add seq/rep notes
            if held.key < 1 then seq.notes = {} end
            for _, note in ipairs(cmem[cmem.active].notes) do
              if seq.active or seq.polyseq then table.insert(seq.notes, note) end
              if not seq.polyseq then table.insert(notes.keys, note) end
            end
            if (rep.active or seq.active) then
              reset_trig_step()
              seq.step = 0
              if cmem[i].trigs > 0 then
                trigs.focus = cmem[i].trigs
              end
            else
              cmem.mem = {}
              for _, note in ipairs(cmem[i].notes) do
                local note = note + notes.trsp_int
                local e = {t = eSCALE, i = voice.keys, note = note, vel = voice[voice.keys].velocity, action = "note_on"} event(e)
                table.insert(cmem.mem, note)
              end
            end
            notes.last = cmem[i].notes[1] + notes.scale_oct * (notes.int_oct[voice.int])
          end
        elseif z == 0 then
          if held.cmem < 1 and next(cmem[cmem.active].notes) then
            for _, note in ipairs(cmem[cmem.active].notes) do
              if seq.active and not (seq.hold or seq.polyseq) then table_remove(seq.notes, note) end
              if not seq.polyseq then table_remove(notes.keys, note) end
            end
            if not (seq.active or rep.active) then
              for _, note in ipairs(cmem.mem) do
                if not tab.contains(notes.keys, note) then
                  local e = {t = eSCALE, i = voice.keys, note = note, action = "note_off"} event(e)
                end
              end
            end
          end      
        end
      end
    end
  elseif x == 7 then
    if y == 13 and z == 1 then
      cmem.rec = not cmem.rec
    elseif y == 14 and cmem.rec then
      cmem.copying = z == 1 and true or false
      if z == 0 then cmem.copy_src = 0 end
    elseif y == 15 and cmem.rec then
      cmem.clear = z == 1 and true or false
    elseif y == 16 and z == 1 then
      cmem.link = not cmem.link
    end
  elseif x > 7 then
    track_num_held("key", z)
    gk[x][y].held = z == 1 and true or false
    local note = (x - 7) + ((16 - y) * ui.iso_y) + (notes.key_oct[voice.keys] + 3) * notes.scale_oct
    if cmem.rec then
      local note_num = notes.scale[util.clamp(note, 1, #notes.scale)]
      if z == 1 then
        if tab.contains(cmem[cmem.focus].notes, note) then
          voice_note_off(voice.keys, note_num)
          table_remove(cmem[cmem.focus].notes, note)
        else
          voice_note_on(voice.keys, note_num, voice[voice.keys].velocity)
          table.insert(cmem[cmem.focus].notes, note)
        end
      elseif z == 0 then
        if held.cmem < 1 then
          voice_note_off(voice.keys, note_num)
        end
      end
    else
      if z == 1 then
        gk[x][y].n_val = note + notes.trsp_int
        gk[x][y].n_key = note
        if cmem.link then
          add_note(note, gk[x][y].n_val)
        else
          local e = {t = eSCALE, i = voice.int, note = gk[x][y].n_val, vel = voice[voice.keys].velocity, action = "note_on"} event(e)
        end
      elseif z == 0 then
        if cmem.link then
          remove_note(gk[x][y].n_key, gk[x][y].n_val)
        else
          local e = {t = eSCALE, i = voice.int, note = gk[x][y].n_val, action = "note_off"} event(e)
        end
      end
    end
  end
end

function drum_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if y > 13 and x > 2 and x < 15 then
    track_num_held("key", z)
    local note = (x - 3) + drm.root + 12 * notes.key_oct[voice.keys]
    drm.vel = y == 16 and drm.vel_hi or (y == 15 and drm.vel_mid or drm.vel_lo)
    gk[x][y].held = z == 1 and true or false
    if z == 1 then
      gk[x][y].n_val = note
      table.insert(notes.keys, note)
      if rep.active then
        if held.key == 1 then
          reset_trig_step()
        end
      else
        local e = {t = eDRUMS, i = voice.keys, note = note, vel = drm.vel} event(e)
      end
    elseif z == 0 then
      table_remove(notes.keys, gk[x][y].n_val)
    end
  elseif y == 13 and z == 1 and mute.edit then
    local i = x - 2
    edit_drum_mutes(i)
  end
end

-------------------------- grid draw functions --------------------------

function pattern_key_draw(off)
  local off = off and off or 0
  for i = 1, 8 do
    if ptn[i].rec == 1 and ptn[i].play == 1 then
      g:led(i + 4, 7 + off, viz.key_fast)
    elseif ptn[i].rec_enabled == 1 then
      g:led(i + 4, 7 + off, 15)
    elseif ptn[i].play == 1 then
      g:led(i + 4, 7 + off, ptn[i].pulse_key and 15 or 12)
    elseif ptn[i].count > 0 then
      g:led(i + 4, 7 + off, 6)
    else
      g:led(i + 4, 7 + off, 2)
    end
    if off == 0 then
      g:led(i + 4, 8, ptn.page + 1 == i and 1 or 0)
    elseif ui.pattern_view then
      g:led(i + 4, 8 + off, ptn.page + 1 == i and 1 or 0)
    end
  end
end

function mod_key_draw(off)
  local off = off and off or 0
  g:led(4, 7 + off, mod.a and 15 or 0) 
  g:led(13, 7 + off, mod.b and 15 or 0)
  g:led(4, 8 + off, mod.c and 15 or 0) 
  g:led(13, 8 + off, mod.d and 15 or 0)
end

function grid_options_draw(off)
  local off = off and off or 0
  if viz.metro then
    g:led(16, 10 + off, viz.bar and 15 or (viz.beat and 8 or 3)) -- Q flash
  else
    g:led(16, 10 + off, 3)
  end
  g:led(15, 10 + off, quant.active and 8 or 4)
  g:led(15, 11 + off, ui.kit_view and 10 or 4)
  g:led(16, 11 + off, rep.view and ((rep.hold and off ~= 0) and viz.key_slow or 10) or 4)
end

function pattern_options_draw(grid)
  g:led(1, 1, ptn.copying and viz.key_slow or (ptn.copy.state and 10 or 4))
  g:led(2, 1, ptn.pasting and 15 or ((ptn.copy.state and not ptn.appending) and viz.key_slow or 4))
  g:led(3, 1, ptn.appending and 15 or ((ptn.copy.state and not ptn.pasting) and viz.key_slow - 3 or 4))
  g:led(1, 2, ptn.clear and viz.key_mid or 4)
  g:led(2, 2, ptn.clear and viz.key_mid or (ptn.duplicating and 15 or 4))
  g:led(1, 3, ptn.overdub_active and 15 or 4)
  local osod = ptn.oneshot_overdub and 5 or 0
  g:led(14, 1, ptn.rec_mode == "queued" and (10 + osod) or 4)
  g:led(15, 1, ptn.rec_mode == "synced" and (10 + osod) or 4)
  g:led(16, 1, ptn.rec_mode == "free" and (10 + osod) or 4)
  g:led(15, 2, ui.prgchg_view and 15 or 4)
  g:led(16, 2, ui.preset_view and viz.key_mid or 4)
  if grid == 128 then
    if viz.metro then
      g:led(16, 3, viz.bar and 15 or (viz.beat and 8 or 3)) -- Q flash
    else
      g:led(16, 3, 3)
    end
  else
    g:led(16, 3, ptn.overdub_active and 15 or 4)
  end
end

function pattern_slot_draw(off)
  local off = off and off or 0
  local page = ptn.page * 3
  if ui.prgchg_view then
    for i = 1, 8 do
      for j = 1, 3 do
        local bank = j + page
        local led = 0
        if ptn.bank == bank and ptn.focus == i then
          led = math.ceil(viz.key_slow / 2)
        elseif p[i].prc_num[bank] > 0 then
          if p[i].count[bank] > 0 then
            led = 10
          else
            led = 5
          end
        elseif p[i].prc_num[bank] == 0 then
          if p[i].count[bank] > 0 then
            led = 1
          end
        end
        g:led(i + 4, j + off, led)
      end
      g:led(i + 4, 4 + off, p[i].prc_enabled and 8 or 3)
    end
  else
    -- pattern slots
    for i = 1, 8 do
      local dim = ptn.focus == i and 0 or -1
      for j = 1, 3 do
        g:led(i + 4, j + off, p[i].load == j + page and viz.key_slow or (p[i].bank == j + page and (p[i].count[j + page] > 0 and 15 + dim or 4 + dim) or (p[i].count[j + page] > 0 and 8 + dim or 2 + dim)))
        if p[i].prc_pulse and p[i].bank == j + page then
          g:led(i + 4, j + off, 15)
        end
      end
      g:led(i + 4, 4 + off, p[i].stop and viz.key_mid or 0)
    end
    -- stop all key
    g:led(13, 4 + off, ptn.stop_all and viz.key_fast or 0)
  end
end

function trigs_draw(grid)
  local cmemviz = (held.cmem > 0 and cmem[cmem.active].trigs == trigs.focus) and true or false
  if grid == 256 then
    for x = 1, 16 do
      if x <= trigs[trigs.focus].step_max then
        g:led(x, 5, (trigs.step == x and (seq.active or rep.active)) and 14 or (trigs[trigs.focus].pattern[x] == 1 and (math.ceil(trigs[trigs.focus].prob[x] * 5) + 1) or 1))
      end
    end
    for i = 1, 8 do
      g:led(i + 4, 6, trigs.focus == i and (cmemviz and viz.key_slow or 4) or 0)
    end
    g:led(1, 6, trigs.pattern_reset and viz.key_mid or 3)
    g:led(2, 6, trigs.copying and viz.key_slow or 1)
    g:led(15, 6, trigs.nudging and 15 or 1)
    g:led(16, 6, trigs.set_end and 15 or 3)
    g:led(15, 12, viz.key_mid)
  elseif grid == 128 then
    for x = 1, 8 do
      if x <= trigs[trigs.focus].step_max then
        g:led(x + 3, 3, (trigs.step == x and (seq.active or rep.active)) and 12 or (trigs[trigs.focus].pattern[x] == 1 and 6 or 2))
      end
      if x + 8 <= trigs[trigs.focus].step_max then
        g:led(x + 3, 4, (trigs.step == x + 8 and (seq.active or rep.active)) and 12 or (trigs[trigs.focus].pattern[x + 8] == 1 and 6 or 2))
      end
    end
    g:led(13, 3, trigs.focus > 4 and 3 or (cmemviz and viz.key_slow or (15 - trigs.focus * 2)))
    g:led(13, 4, trigs.focus < 5 and 3 or (cmemviz and viz.key_slow or (trigs.focus * 2 - 3)))
    g:led(12, 3, trigs.set_end and 15 or 1)
    g:led(12, 4, trigs.pattern_reset and 15 or 1)
    g:led(15, 5, viz.key_mid)
  end
end

function pattern_playhead_draw(off)
  local off = off and off or 0
  if p[ptn.focus].looping then
    local min = p[ptn.focus].step_min_viz[p[ptn.focus].bank]
    local max = p[ptn.focus].step_max_viz[p[ptn.focus].bank]
    for i = min, max do
      g:led(i, 5 + off, 4)
    end
  end
  if ptn[ptn.focus].play == 1 and ptn[ptn.focus].endpoint > 0 then
    g:led(ptn[ptn.focus].position, 5 + off, ptn[ptn.focus].play == 1 and 10 or 0)
  end
end

function voice_settings_draw(off)
  local off = off and off or 0
  for i = 1, 3 do
    if chrd.strm_edit then
      g:led(i, 7 + off, (voice.strum > 0 and voice.strum == i) and 12 or 1)
      g:led(i + 13, 7 + off, (voice.strum > 0 and voice.strum == i + 3) and 12 or 1)
    else
      g:led(i, 7 + off, voice[i].mute and 2 or (voice.int == i and 10 or 4))
      g:led(i + 13, 7 + off, voice[i + 3].mute and 2 or (voice.int == i + 3 and 10 or 4))
    end
    g:led(i, 8 + off, voice[i].mute and 2 or (voice.keys == i and 10 or 4))
    g:led(i + 13, 8 + off, voice[i + 3].mute and 2 or (voice.keys == i + 3 and 10 or 4))
    if off == 0 then
      g:led(i, 9, voice[i].sustaining and viz.key_slow or 0)
      g:led(i + 13, 9, voice[i + 3].sustaining and viz.key_slow or 0)
    end
  end
end

function voice_options_draw(off)
  local off = off and off or 0
  g:led(1, 10 + off, voice[voice.keys].keys_option == 1 and 8 or 4)
  g:led(2, 10 + off, voice[voice.keys].keys_option == 3 and 8 or 4)
  g:led(1, 11 + off, voice[voice.keys].keys_option == 2 and 8 or 4)
  g:led(2, 11 + off, voice[voice.keys].keys_option == 4 and 8 or 4)
end

function kit_grid_draw(off)
  local off = off and off or 0
  for x = 1, 2 do
    for y = 10, 11 do
      local i = (x + (11 - y) * 8)
      g:led(x + 3, y + off, drmfm.viz[i + 0] and 15 or (mute.kit_key[i + 0] and 0 or 2))
      g:led(x + 5, y + off, drmfm.viz[i + 2] and 15 or (mute.kit_key[i + 2] and 0 or 4))
      g:led(x + 7, y + off, drmfm.viz[i + 4] and 15 or (mute.kit_key[i + 4] and 0 or 2))
      g:led(x + 9, y + off, drmfm.viz[i + 6] and 15 or (mute.kit_key[i + 6] and 0 or 4))
    end
    g:led(13, x + 9 + off, gk[13][x + 9].held and 15 or 8)
  end
  g:led(12, 10 + off, drmfm.copy_data and viz.key_mid or 1)
  g:led(12, 11 + off, gk[12][11].held and 15 or (mute.active and viz.key_mid or 1))
  if mute.edit then
    for i = 1, 6 do
      g:led(i + 5, 9 + off, (mute.active and mute.focus == i) and 15 or 6)
    end
  end
end

function int_grid_draw(off)
  local off = off and off or 0
  for i = 8, 9 do
    g:led(i, 9 + off, 6) -- home
    g:led(i, 10 + off, notes.trsp_active and viz.key_mid or 2) -- transpose
    g:led(i, 11 + off, 10) -- interval 0
  end
  for i = 1, 4 do
    g:led(i + 3, 10 + off, 12 - i * 2) -- intervals dec
    g:led(i + 9, 10 + off, 2 + i * 2) -- intervals inc
  end
end

function octave_options_draw(off)
  local off = off and off or 0
  if caw.ansi_view then
    for i = 1, 4 do
      g:led(1, i + 12 + off, caw.viz_ansi_trig[i] and 15 or 2)
    end
  else
    -- int/key octave
    if chrd.strm_edit then
      g:led(1, 13 + off, 8 + chrd.oct_off * 2)
      g:led(1, 14 + off, 8 - chrd.oct_off * 2)
    else
      g:led(1, 13 + off, 8 + notes.int_oct[voice.int] * 2)
      g:led(1, 14 + off, 8 - notes.int_oct[voice.int] * 2)
    end
    -- key octave
    g:led(1, 15 + off, 8 + notes.key_oct[voice.keys] * 2)
    g:led(1, 16 + off, 8 - notes.key_oct[voice.keys] * 2)
    -- afterfouch, modwheel, pitchbend
    g:led(2, 13 + off, math.floor(at[voice.keys].value * 15))
    g:led(2, 14 + off, math.floor(mw[voice.keys].value * 15))
    g:led(2, 15 + off, pb[voice.keys].dir == 1 and math.floor(pb[voice.keys].value * 15) or 0) -- pitchbend up
    g:led(2, 16 + off, pb[voice.keys].dir == -1 and math.floor(pb[voice.keys].value * 15) or 0) -- ptichbend down
  end
end

function event_options_draw(off)
  local off = off and off or 0
  if rep.view then
    for i = 1, 4 do
      g:led(16, i + 12 + off, rk[i] == 1 and 15 or i * 2)
    end
    if off == 0 then
      g:led(16, 12, rep.hold and viz.key_slow or 0)     
    end
  else
    if off == 0 then
      g:led(1, 12, hrmy.config and viz.key_mid or 0)
      g:led(16, 12, seq.config and viz.key_slow or 0)
      if hrmy.config then
        for x = 1, 8 do
          g:led(x + 4, 12, hrmy.active == x and viz.key_mid or 2)
        end
      elseif seq.config then
        for x = 1, 8 do
          g:led(x + 4, 12, params:get("key_seq_rate") == x and 6 or 1)
        end
      end
    end
    g:led(16, 13 + off, seq.active and (seq.polyseq and viz.key_slow or 12) or 6)
    g:led(16, 14 + off, seq.collecting and 10 or (seq.polyseq and 4 or 2))
    g:led(16, 15 + off, seq.appending and 10 or (seq.polyseq and 0 or 2))
    g:led(16, 16 + off, seq.hold and 15 or 2)
  end
  g:led(15, 15 + off, vl[voice.keys].baseline == vl[voice.keys].hi and 2 or 0)
  g:led(15, 16 + off, math.floor(vl[voice.keys].value * 14) + 1)
end

function keyboard_draw(off)
  local off = off and off or 0
  if voice[voice.keys].keys_option == 1 then
    for i = 1, 12 do
      for y = 13, 16 do
        local key = i + ui.iso_y * (16 - y)
        local note = key + (notes.key_oct[voice.keys] + 3) * notes.scale_oct
        g:led(i + 2, y + off, tab.contains(notes.keys, note) and 12 or ((key % notes.scale_oct) == 1 and 8 or 2))
      end
    end
  elseif voice[voice.keys].keys_option == 2 then
    for x = 3, 6 do
      for y = 13, 16 do
        local i = (x - 2) + (y - 13) * 4
        if cmem.rec then
          g:led(x, y + off, cmem.focus == i and viz.key_slow or (#cmem[i].notes > 0 and 8 or 2))
        else          
          g:led(x, y + off, #cmem[i].notes > 0 and (cmem.active == i and 12 or 8) or 2)
        end
      end
    end
    g:led(7, 13 + off, cmem.rec and 12 or 0)
    g:led(7, 14 + off, cmem.copy_src > 0 and viz.key_mid or (cmem.copying and 15 or 0))
    g:led(7, 15 + off, cmem.clear and 15 or 0)
    g:led(7, 16 + off, cmem.link and 0 or viz.key_slow)
    for i = 1, 7 do
      for y = 13, 16 do
        local key = i + ui.iso_y * (16 - y)
        local note = key + (notes.key_oct[voice.keys] + 3) * notes.scale_oct
        local check = cmem.rec and cmem[cmem.focus].notes or notes.keys
        g:led(i + 7, y + off, tab.contains(check, note) and 12 or ((key % notes.scale_oct) == 1 and 8 or 2))
      end
    end
  elseif voice[voice.keys].keys_option == 3 then
    for x = 3, 14 do
      for y = 13, 15 do
        g:led(x, y + off, gk[x][y].held and 15 or chrd.viz[x - 2][y - 12])
      end
    end
    g:led(3, 16 + off, chrd.mode and 14 or 2)
    g:led(4, 16 + off, chrd.strm and 10 or 2)
    g:led(5, 16 + off, chrd.strm_len_edit and 15 or 0)
    g:led(6, 16 + off, chrd.strm_mode_edit and 15 or 0)
    g:led(7, 16 + off, chrd.strm_skew_edit and 15 or 0)
    if chrd.strm_len_edit then
      for i = 4, 12 do
        g:led(i + 2, 16 + off, chrd.strm_num == i and 10 or 1)
      end
    elseif chrd.strm_mode_edit then
      for i = 1, 5 do
        g:led(i + 9, 16 + off, chrd.strm_mode == i and 10 or 2)
      end
    elseif chrd.strm_skew_edit then
      g:led(8, 16 + off, gk[8][16].held and 15 or (chrd.strm_rate == 0.5 and 10 or 4))
      g:led(9, 16 + off, gk[9][16].held and 15 or (chrd.strm_rate == 0.02 and 10 or 4))
      g:led(10, 16 + off, gk[10][16].held and 15 or 1)
      g:led(11, 16 + off, gk[11][16].held and 15 or 1)
      local val = util.clamp(math.floor(math.abs((chrd.strm_skew) / 2) + 4), 3, 15)
      g:led(12, 16 + off, chrd.strm_skew < 0 and val or 3)
      g:led(13, 16 + off, chrd.strm_skew == 0 and 10 or 3)
      g:led(14, 16 + off, chrd.strm_skew > 0 and val or 3)
    else
      g:led(8, 16 + off, gk[8][16].held and 15 or 2)
      g:led(9, 16 + off, gk[9][16].held and 15 or 2)
      g:led(10, 16 + off, chrd.preview and (viz.key_slow - 4) or 0)
      for i = 1, 4 do
        g:led(i + 10, 16 + off, chrd.inv == i and 8 or 2)
      end
    end
  elseif voice[voice.keys].keys_option == 4 then
    for x = 3, 14 do
      for y = 14, 16 do
        g:led(x, y + off, gk[x][y].held and 15 or 2 * (y - 14) + 2)
      end
    end
    for i = 1, 12 do
      if mute.edit then
        g:led(i + 2, 13 + off, mute.drm_key[i] and 0 or 6)
      else
        g:led(i + 2, 13 + off, mute.drm_key[i] and viz.key_mid - 4 or 0)
      end
    end
  end 
end


-------------------------- grid module --------------------------

grd = {}

-- grid keys and redraw
function zero_keys(x, y, z)
  if (x < 4 or x > 13) and y < 4 then
    pattern_options(x, y, z)
  elseif x > 3 and x < 14 and y < 5 then
    pattern_slots(x, y, z)
  elseif (y == 5 or y == 6) then
    if ui.trigs_view then
      trigs_grid(x, y, z, 256)
    elseif y == 5 then
      pattern_playhead(x, z)
    end
  elseif x > 4 and x < 13 and y == 7 and z == 1 then
    pattern_keys(x - 4)
  elseif x > 4 and x < 13 and y == 8 and z == 1 then
    ptn.page = x - 5
  elseif (x == 4 or x == 13) and (y == 7 or y == 8) then
    modifier_keys(x, y, z)
  elseif (x < 4 or x > 13) and y > 6 and y < 10 then
    voice_settings(x, y, z)
  elseif x < 3 and y > 9 and y < 12 then
    voice_options(x, y, z)
  elseif x > 14 and y > 9 and y < 12 then
    grid_options(x, y, z)
  elseif x > 3 and x < 14 and y > 8 and y < 12 then
    if ui.kit_view then
      kit_grid(x, y, z)
    else
      int_grid(x, y, z)
    end
  elseif y == 12 then
    seq_settings(x, z)
  elseif x < 3 and y > 12 then
    octave_options(x, y, z)
  elseif x > 14 and y > 12 then
    event_options(x, y, z)
  elseif x > 2 and x < 15 and y > 12 then
    if voice[voice.keys].keys_option == 1 then
      scale_grid(x, y, z)
    elseif voice[voice.keys].keys_option == 2 then
      cmem_grid(x, y, z)
    elseif voice[voice.keys].keys_option == 3 then
      chord_grid(x, y, z)
    elseif voice[voice.keys].keys_option == 4 then
      drum_grid(x, y, z)  
    end
  end
  dirtygrid = true
  screen.ping()
end

function one_keys(x, y, z)
  if x > 4 and x < 13 and y == 1 and z == 1 then
    pattern_keys(x - 4)
  end
  if (x == 4 or x == 13) and y < 3 then
    modifier_keys(x, y, z, -6)
  end
  if x == 16 and y == 3 and z == 1 then
    ui.pattern_view = not ui.pattern_view
    dirtyscreen = true
  end
  if ui.pattern_view then
    if (x < 4 or x > 13) and y < 4 then
      pattern_options(x, y, z)
    elseif x > 4 and x < 13 and y == 2 and z == 1 then
      ptn.page = x - 5
    elseif x > 3 and x < 14 and y > 2 and y < 7 then
      pattern_slots(x, y, z, 2)
    elseif y == 8 then
      pattern_playhead(x, z)
    end
  else
    if (x < 4 or x > 13) and y < 3 then
      voice_settings(x, y, z, -6)
    elseif x > 3 and x < 14 and y > 1 and y < 5 then
      if ui.trigs_view then
        trigs_grid(x, y, z, 128)
      elseif ui.kit_view then
        kit_grid(x, y, z, -7)
      else
        int_grid(x, y, z, -7)
      end
    elseif x < 3 and y > 2 and y < 5 then
      voice_options(x, y, z, -7)
    elseif x > 14 and y > 2 and y < 5 then
      grid_options(x, y, z, -7)
    elseif x < 3 and y > 4 then
      octave_options(x, y, z, -8)
    elseif x > 14 and y > 4 then
      event_options(x, y, z, -8)
    elseif x > 2 and x < 15 and y > 4 then
      if voice[voice.keys].keys_option == 1 then
        scale_grid(x, y, z, -8)
      elseif voice[voice.keys].keys_option == 2 then
        cmem_grid(x, y, z, -8)
      elseif voice[voice.keys].keys_option == 3 then
        chord_grid(x, y, z, -8)
      elseif voice[voice.keys].keys_option == 4 then
        drum_grid(x, y, z, -8)  
      end
    end
  end
  dirtygrid = true
  screen.ping()
end

function zero_draw()
  g:all(0)
  pattern_options_draw()
  pattern_slot_draw()
  pattern_key_draw()
  mod_key_draw()
  if ui.trigs_view then
    trigs_draw(256)
  else
    pattern_playhead_draw()
  end
  if ui.kit_view then
    kit_grid_draw()
  else
    int_grid_draw()
  end
  voice_settings_draw()
  voice_options_draw()
  grid_options_draw()
  octave_options_draw()
  event_options_draw()
  keyboard_draw()  
  g:refresh()
end

function one_draw()
  g:all(0)
  pattern_key_draw(-6)
  mod_key_draw(-6)
  if ui.pattern_view then
    pattern_options_draw(128)
    pattern_slot_draw(2)
    pattern_playhead_draw(3)
  else
    if ui.trigs_view then
      trigs_draw(128)
    elseif ui.kit_view then
      kit_grid_draw(-7)
    else
      int_grid_draw(-7)
    end
    voice_settings_draw(-6)
    voice_options_draw(-7)
    grid_options_draw(-7)
    octave_options_draw(-8)
    event_options_draw(-8)
    keyboard_draw(-8)  
  end
  g:refresh()
end

-- grid key/draw
function g.key(x, y, z)
  if GRIDSIZE == 256 then
    zero_keys(x, y, z)
  elseif GRIDSIZE == 128 then
    one_keys(x, y, z)
  end
  dirtygrid = true
end 

function grd.redraw()
  if GRIDSIZE == 256 then
    zero_draw()
  elseif GRIDSIZE == 128 then
    one_draw()
  end
end

-- get grid size
function grd.get_size()
  if g then
    GRIDSIZE = g.cols * g.rows
  end
  if GRIDSIZE == 256 and rotate_grid then
    g:rotation(1) -- 1 is 90°
  end
  dirtygrid = true
end

-- banner
function grd.banner()
  local banner = {
    {1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1},
    {1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1},
    {1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1},
    {1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1},
  }
  local hi = GRIDSIZE == 256 and 7 or 3
  local lo = GRIDSIZE == 256 and 10 or 6
  g:all(0)
  for x = 1, 16 do
    for y = hi, lo do
      g:led(x, y, banner[y - hi + 1][x] * 5)
    end
  end
  g:refresh()
end

return grd
