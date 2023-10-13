grd_one = {}

function grd_one.func_keys(x, y, z)
  -- pattern mod_a
  if y == 2 and x == 6 and not pattern_view then
    mod_a = z == 1 and true or false
    dirtyscreen = true
  end
  -- pattern mod_b
  if y == 2 and x == 11 and not pattern_view then
    mod_b = z == 1 and true or false
    dirtyscreen = true
  end
  -- detect key hold last key and root
  if (y == 2 or y == 4) and x > 7 and x < 9 and not sample_view then
    heldkey = heldkey + (z * 2 - 1)
  end
  -- detect key hold intervals
  if y == 3 and ((x > 3 and x < 8) or (x > 9 and x < 14)) and not sample_view then
    heldkey = heldkey + (z * 2 - 1)
  end
  -- play samples grid
  if (y == 3 or y == 4) and (x > 3 and x < 14) and sample_view and not pattern_view then
    grd_one.sampl_grid(x, y, z)
  end
  -- detect key hold for keyboard
  if y > 4 and x > 2 and x < 15 and not pattern_view then
    heldkey = heldkey + (z * 2 - 1)
  end
  -- change to pattern edit view
  if y == 3 and x == 16 and z == 1 then
    pattern_view = not pattern_view
    dirtyscreen = true
  end
  -- key repeat and sequener
  if not pattern_view then
    if y == 5 and x == 16 and retrig_mode then
      gkey[x][y].active = z == 1 and true or false
      get_repeat_rate()
    end
    if y == 6 and x == 16 then
      if retrig_mode then
        gkey[x][y].active = z == 1 and true or false
        get_repeat_rate()
      else
        collecting_notes = z == 1 and true or false
        if z == 0 and #collected_notes > 0 then
          seq_step = 0
          seq_notes = {table.unpack(collected_notes)}
        else
          collected_notes = {}
        end
        dirtyscreen = true
      end
    end
    if y == 7 and x == 16 then
      if retrig_mode then
        gkey[x][y].active = z == 1 and true or false
        get_repeat_rate()
      else
        appending_notes = z == 1 and true or false
      end
    end
    if y == 8 and x == 16 and retrig_mode then
      gkey[x][y].active = z == 1 and true or false
      get_repeat_rate()
    end
  end
  -- pattern play head
  if y == 8 and pattern_view then
    if z == 1 and held[pattern_focus].num then held[pattern_focus].max = 0 end
    held[pattern_focus].num = held[pattern_focus].num + (z * 2 - 1)
    if held[pattern_focus].num > held[pattern_focus].max then held[pattern_focus].max = held[pattern_focus].num end
    if z == 1 then
      if pattern[pattern_focus].rec == 0 then
        if held[pattern_focus].num == 1 then
          held[pattern_focus].first = x
        elseif held[pattern_focus].num == 2 then
          held[pattern_focus].second = x
        end
      end
      if pattern_reset then
        clear_pattern_loops()
      elseif not p[pattern_focus].looping and held[pattern_focus].max < 2 then -- parameterize this? add as option only?
        clock.run(function()
          clock.sync(quant_rate)
          local segment = util.round(pattern[pattern_focus].endpoint / 16, 1)
          pattern[pattern_focus].step = segment * (x - 1)
        end)
      end
    else
      if held[pattern_focus].num == 1 and held[pattern_focus].max == 2 then
        local pf = pattern_focus
        clock.run(function()
          clock.sync(1)
          local segment = util.round(pattern[pf].endpoint / 16, 1)
          pattern[pf].step_min = segment * (math.min(held[pf].first, held[pf].second) - 1)
          pattern[pf].step_max = segment * math.max(held[pf].first, held[pf].second)
          pattern[pf].step = pattern[pf].step_min
          p[pf].step_min_viz[p[pf].bank] = math.min(held[pf].first, held[pf].second)
          p[pf].step_max_viz[p[pf].bank] = math.max(held[pf].first, held[pf].second)
          p[pf].looping = true
          -- store these in case you wanna add a "copy section function"
          p[pf].step_min[p[pf].bank] = pattern[pf].step_min
          p[pf].step_max[p[pf].bank] = pattern[pf].step_max
        end)
      elseif p[pattern_focus].looping and held[pattern_focus].max < 2 then
        local pf = pattern_focus
        p[pf].looping = false
        clock.run(function()
          local sync = params:get("patterns_countin"..pf) == 2 and 1 or (params:get("patterns_countin"..pf) == 3 and 4 or pattern[pf].quantize)
          clock.sync(sync)
          pattern[pf].step = 0
          pattern[pf].step_min = 0
          pattern[pf].step_max = pattern[pf].endpoint
          -- restore these so the loop points aren't saveed to the pattern bank
          p[pf].step_min[p[pf].bank] = 0
          p[pf].step_max[p[pf].bank] = pattern[pf].endpoint
        end)
      end
    end
  end
end

function grd_one.main_grid(x, y, z)
  if z == 1 then
    if y == 1 then
      -- set interval_focus
      if x < 4 or x > 13 then
        local i = x < 4 and x or x - 10
        if (mod_a or mod_b) then
          params:set("voice_mute"..i, voice[i].mute and 1 or 2)
        elseif not voice[i].mute then
          int_focus = i
        end
      end
    elseif y == 2 then
      -- set key focus
      if x < 4 or x > 13 then
        local i = x < 4 and x or x - 10
        if (mod_a or mod_b) then
          params:set("voice_mute"..i, voice[i].mute and 1 or 2)
        elseif not voice[i].mute then
          key_focus = i
          voice_focus = i
          notes.held = {}
          dirtyscreen = true
        end
      end
      -- home key
      if not sample_view and x > 7 and x < 10 then
        local home_note = tab.key(scale_notes, params:get("root_note"))
        if not transposing then
          local e = {t = eSCALE, p = pattern_focus, i = int_focus, root = root_oct, note = home_note, action = "note_on"} event(e)
          gkey[x][y].note = home_note
        else
          local e = {t = eTRSP_SCALE, interval = 0} event(e)
        end
        notes.last = home_note
      end
    elseif y == 3 then
      if x == 1 then
        params:set("keys_option"..key_focus, 1) -- set keys to scale
      elseif x == 2 then
        params:set("keys_option"..key_focus, 2) -- set keys to chromatic
      elseif x == 15 then
        key_quantize = not key_quantize -- toggle quantization
      end
      if not sample_view then
        -- interval decrease
        if x > 3 and x < 8 then
          local interval = x - 8
          local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
          if not transposing then
            local e = {t = eSCALE, p = pattern_focus, i = int_focus, root = root_oct, note = new_note, action = "note_on"} event(e)
            gkey[x][y].note = new_note
          else
            local e = {t = eTRSP_SCALE, interval = interval} event(e)
          end
          notes.last = new_note
        -- interval increase
        elseif x > 9 and x < 14 then
          local interval = x - 9
          local new_note = util.clamp(notes.last + interval, 1, #scale_notes)
          if not transposing then
            local e = {t = eSCALE, p = pattern_focus, i = int_focus, root = root_oct, note = new_note, action = "note_on"} event(e)
            gkey[x][y].note = new_note
          else
            local e = {t = eTRSP_SCALE, interval = interval} event(e)
          end
          notes.last = new_note
        -- toggle key link
        elseif x > 7 and x < 10 then
          link_clock = clock.run(function()
            clock.sleep(1)
            key_link = not key_link
          end)
        end
      end
    elseif y == 4 then
      if x == 1 then
        params:set("keys_option"..key_focus , 3) -- set keys to chords
      elseif x == 2 then
        params:set("keys_option"..key_focus, 4) -- set keys to drums
      elseif x == 15 then
        sample_view = not sample_view
      elseif x == 16 then
        retrig_mode = not retrig_mode
        if retrig_mode and seq_active then
          seq_active = false
        end
      end
      if not sample_view then
        if x > 7 and x < 10 then
          if not transposing then
            if collecting_notes and not appending_notes then
              table.insert(collected_notes, 0)
              dirtyscreen = true
            elseif appending_notes and not collecting_notes then
              table.insert(seq_notes, 0)
            else
              local e = {t = eSCALE, p = pattern_focus, i = int_focus, root = root_oct, note = notes.last, action = "note_on"} event(e)
              gkey[x][y].note = notes.last
            end
          else
            local octave = (#scale_intervals[params:get("scale")] - 1) * (x - 8 == 0 and -1 or 1)
            local e = {t = eTRSP_SCALE, interval = octave} event(e)
          end
        end
      end
    elseif y == 5 then
      if x == 1 then
        notes.oct_int = util.clamp(notes.oct_int + 1, -3, 3) -- interval octave up
      elseif x == 16 then
        if not retrig_mode then
          toggle_seq()
        end
      end
    elseif y == 6 then
      if x == 1 then
        notes.oct_int = util.clamp(notes.oct_int - 1, -3, 3) -- interval octave down
      end
    elseif y == 7 then
      if x == 1 then
        notes.oct_key = util.clamp(notes.oct_key + 1, -3, 3) -- key octave up        
      end
    elseif y == 8 then
      if x == 1 then
        notes.oct_key = util.clamp(notes.oct_key - 1, -3, 3) -- key octave down
      elseif x == 16 then
        if not retrig_mode then
          seq_hold = not seq_hold
          if not seq_hold then
            seq_notes = {table.unpack(notes.held)}
          end
        end
      end
    end
  elseif z == 0 then
    if not pattern_view then
      if y == 2 and x > 7 and x < 10 then
        local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      elseif y == 3 then
        if x > 3 and x < 8 then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
        elseif x > 7 and x < 10 then
          if link_clock ~= nil then clock.cancel(link_clock) end
        elseif x > 9 and x < 14 then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
        end
      elseif y == 4 and x > 7 and x < 10 then
        local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      end
    end
  end
end

function grd_one.pattern_keys(i)
  if pattern_focus ~= i then
    pattern_focus = i
  end
  if duplicating_pattern then
    if pattern[i].count > 0 then
      append_pattern(i, p[i].bank, i, p[i].bank)
      show_message("doubled pattern")
    end
  elseif appending_pattern and copy_src.state then
    append_pattern(copy_src.pattern, copy_src.bank, i, p[i].bank)
    show_message("appended to pattern "..i.." bank ".. p[i].bank)
    copying_pattern = false
    copy_src = {state = false, pattern = nil, bank = nil}
  elseif pattern_reset then
    reset_pattern_length(i, p[i].bank)
  elseif not pasting_pattern and not copying_pattern then
    -- stop and clear
    if pattern_clear or (mod_a and mod_b) then
      if pattern[i].count > 0 then
        kill_active_notes(i)
        pattern[i]:clear()
        save_pattern_bank(i, p[i].bank)
      end
    else
      if pattern[i].play == 0 then -- if pattern is not playing
        local count_in = params:get("patterns_countin"..i) == 2 and 1 or (params:get("patterns_countin"..i) == 3 and 4 or nil)
        -- if pattern is empty
        if pattern[i].count == 0 then
          -- if rec not enabled press key to enable recording
          if appending_notes then
            paste_seq_pattern(i)
          else
            if pattern[i].rec_enabled == 0 then
              local mode = pattern_rec_mode == "synced" and 1 or 2
              local dur = pattern_rec_mode ~= "free" and pattern[i].length or nil
              pattern[i]:set_rec(mode, dur, 4)
            -- if recording and no data then press key to abort
            else
              pattern[i]:set_rec(0)
              pattern[i]:stop()
            end
          end
        -- if a pattern contains data then
        else
          pattern[i]:start(count_in)
        end
      else -- if pattern is playing
        if (pattern_overdub or mod_a or mod_b) then -- if holding overdub key
          -- if recording then discard the recording and replace with prev event table
          if pattern[i].rec == 1 then
            pattern[i]:set_rec(0)
            pattern[i]:undo()
          -- if not recording start recording
          else
            pattern[i]:set_rec(1)               
          end
        else
          if pattern[i].rec == 1 then
            pattern[i]:set_rec(0)
          else
            pattern[i]:stop()
          end
        end
      end
    end
  end
end

function grd_one.pattern_grid(x, y, z)
  -- left and right function keys
  if y == 1 and x == 1 and z == 1 then
    copying_pattern = not copying_pattern
    if not copying_pattern then
      copy_src = {state = false, pattern = nil, bank = nil}
    end
  elseif y == 1 and x == 2 then
    pasting_pattern = z == 1 and true or false
  elseif y == 1 and x == 3 then
    appending_pattern = z == 1 and true or false
  elseif y == 1 and x == 14 and z == 1 then
    pattern_rec_mode = "queued"
  elseif y == 1 and x == 15 and z == 1  then
    pattern_rec_mode = "synced"
  elseif y == 1 and x == 16 and z == 1  then
    pattern_rec_mode = "free"
  elseif y == 2 and x == 1 then
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      if gkey[1][2].active and not gkey[2][2].active then
        pattern_reset = true
      end
    else
      pattern_clear = false
      pattern_reset = false
    end
  elseif y == 2 and x == 2 then
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      if gkey[1][2].active and gkey[2][2].active then
        pattern_clear = true
        duplicating_pattern = false
        pattern_reset = false
      elseif not gkey[1][2].active and gkey[2][2].active then
        pattern_clear = false
        duplicating_pattern = true
      end
    else
      duplicating_pattern = false
    end
  elseif y == 2 and x == 15 then
    pattern_length_config = z == 1 and true or false
    dirtyscreen = true
  elseif y == 2 and x == 16 then
    pattern_options_config = z == 1 and true or false
    dirtyscreen = true
  elseif y == 3 and x == 1 then
    pattern_overdub = z == 1 and true or false
  end

  --main body
  if y > 1 and y < 7 and x > 4 and x < 13 then
    local i = x - 4
    local bank = y - 2
    if pattern_length_config and z == 1 then
      -- set meter and bar num
      if y == 3 then
        params:set("patterns_meter"..pattern_focus, i)
        if pattern[pattern_focus].manual_length then
          pattern[pattern_focus].manual_length = false
        end
      elseif y > 3 and y < 6 then
        params:set("patterns_beatnum"..pattern_focus, i + 8 * (y - 4))
        if pattern[pattern_focus].manual_length then
          pattern[pattern_focus].manual_length = false
        end
      elseif y > 5 and y < 8 then
        if pattern_focus ~= i then
          pattern_focus = i
          held[pattern_focus].num = 0
        end
      end
      save_pattern_bank(pattern_focus, p[pattern_focus].bank)
    elseif pattern_options_config and z == 1 then
      if y == 4 then
        local val = params:get("patterns_countin"..i)
        val = util.wrap(val + 1, 1, 3)
        params:set("patterns_countin"..i, val)
      elseif y == 5 then
        params:set("patterns_playback"..i, pattern[i].loop == 0 and 1 or 2)
      end
    else
      -- select active pattern bank, copy/paste/duplicate/append actions
      if y > 2 and y < 6 and z == 1 then
        -- set pattern focus
        if pattern_focus ~= i then
          pattern_focus = i
          held[pattern_focus].num = 0
        end
        -- copy/paste/append/duplicate
        if pasting_pattern and copy_src.state then
          copy_pattern(copy_src.pattern, copy_src.bank, i, bank)
          show_message("pasted to pattern "..i.." bank "..bank)
          copying_pattern = false
          copy_src = {state = false, pattern = nil, bank = nil}
        elseif appending_pattern and copy_src.state then
          append_pattern(copy_src.pattern, copy_src.bank, i, bank)
          show_message("appended to pattern "..i.." bank "..bank)
          copying_pattern = false
          copy_src = {state = false, pattern = nil, bank = nil}
        elseif (pasting_pattern or appending_pattern) and not copy_src.state then
          show_message("clipboard empty")
        elseif copying_pattern and not copy_src.state then
          copy_src.pattern = i
          copy_src.bank = bank
          copy_src.state = true
          show_message("pattern "..copy_src.pattern.." bank "..copy_src.bank.." selected")
        elseif duplicating_pattern then
          if p[i].count[bank] > 0 then
            append_pattern(i, bank, i, bank)
            show_message("doubled pattern")
          end
        -- reset pattern
        elseif pattern_reset then
          reset_pattern_length(i, bank)
        -- clear pattern
        elseif pattern_clear then
          clear_pattern_bank(i, bank)
          if pattern[i].count > 0 and p[i].bank == bank then
            kill_active_notes(i)
            pattern[i]:clear()
          end
        -- load pattern
        elseif not copying_pattern and not pasting_pattern then
          if p[i].bank ~= bank then
            p[i].load = bank
            if pattern[i].play == 0 then
              set_pattern_bank(i)
            end
          elseif p[i].load then
            p[i].load = nil
          end
        end
      end
    end
  end
  dirtyscreen = true
end

function grd_one.sampl_grid(x, y, z)
  if y > 2 and y < 5 and x > 3 and x < 14 then
    local bank = math.ceil((x - 3) / 2)
    local slot = (x - 3) - (bank - 1) * 2 + (y - 3) * 2
    --local smpl_num = (math.ceil((x - 3) / 2) - 1) * 4 + ((x - 3) - (math.ceil((x - 3) / 2) - 1) * 2 + (y - 3) * 2)
    if z == 1 then
      smpls.bank_focus = bank
      smpls.slot_focus = slot
      if not key_repeat then
        local e = {t = eSMPL, action = "play", bank = bank, slot = slot} event(e)
      end
      held_sample[bank] = slot
      render_sample()
    elseif z == 0 then
      if held_sample[bank] == slot then
        held_sample[bank] = 0
      end
    end
  end
end

function grd_one.scale_grid(x, y, z)
  if y > 4 and x > 2 and x < 15 then
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      local octave = #scale_intervals[params:get("scale")] - 1
      local note = (x - 2) + ((8 - y) * sc_iy) + (notes.oct_key + 3) * octave
      -- keep track of held notes
      gkey[x][y].note = note
      table.insert(notes.held, note)
      -- collect or append notes
      if collecting_notes and not appending_notes then
        table.insert(collected_notes, note)
      elseif appending_notes and not collecting_notes then
        table.insert(seq_notes, note)
      end
      -- insert notes
      if seq_active and not (collecting_notes or appending_notes) then
        if heldkey == 1 and seq_hold then seq_notes = {} end
        table.insert(seq_notes, note)
      end
      -- play notes
      if (not seq_active or #seq_notes == 0) then
        if not key_repeat then
          local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = note, action = "note_on"} event(e)
        end
      end
      -- set last note
      if key_link and not transposing then
        notes.last = note + octave * notes.oct_int
      end
    elseif z == 0 then
      -- remove notes
      if seq_active and not (collecting_notes or appending_notes or seq_hold) then
        table.remove(seq_notes, tab.key(notes.held, gkey[x][y].note))
      end
      if (not seq_active or #seq_notes == 0) then
        local e = {t = eSCALE, p = pattern_focus, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      end
      table.remove(notes.held, tab.key(notes.held, gkey[x][y].note))
    end
  end
end

function grd_one.chrom_grid(x, y, z)
  if y > 4 and x > 2 and x < 15 then
    local root = (60 - 3) + 12 * notes.oct_key
    local note = (root + x * ch_ix) + ch_iy * (8 - y)
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      -- keep track of held notes
      gkey[x][y].note = note
      table.insert(notes.held, note)
      -- collec or append notes
      if collecting_notes and not appending_notes then
        table.insert(collected_notes, note)
      elseif appending_notes and not collecting_notes then
        table.insert(seq_notes, note)
      end
      -- insert notes
      if seq_active and not (collecting_notes or appending_notes) then
        if heldkey == 1 and seq_hold then seq_notes = {} end
        table.insert(seq_notes, note)
      end
      if (not seq_active or #seq_notes == 0) then
        if not key_repeat then
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = note, action = "note_on"} event(e)
        end
      end
    elseif z == 0 then
      if seq_active and not (collecting_notes or appending_notes or seq_hold) then
        table.remove(seq_notes, tab.key(notes.held, gkey[x][y].note))
      end
      if (not seq_active or #seq_notes == 0) then
        local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = gkey[x][y].note, action = "note_off"} event(e)
      end
      table.remove(notes.held, tab.key(notes.held, gkey[x][y].note))
    end
  end
end

function grd_one.chord_grid(x, y, z)
  if y > 4 and y < 8 and x > 2 and x < 15 then
    local i = x - 2
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      local note = (60 + (x - 3)) + 12 * notes.oct_key
      -- kill any playing chords
      notes.held = {}
      for i = 1, 12 do
        if #chord[i] > 0 then
          for index, value in ipairs(chord[i]) do
            local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = value, action = "note_off"} event(e)
          end
          chord[i] = {}
        end
      end
      -- build new chord
      local chord_type = get_chord_type(x)
      chord[i] = mu.generate_chord(note, chord_type, chord_inversion)
      build_strum(chord[i])
      notes.held = {table.unpack(chord[i])}
      notes.chord = {table.unpack(chord[i])}
      -- play chord
      if chord_play and #chord[i] > 0 and not key_repeat then
        for index, value in ipairs(chord[i]) do
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = value, action = "note_on"} event(e)
        end
      end
      if chord_harp and not chord_strum then
        if harp_clock ~= nil then
          clock.cancel(harp_clock)
        end
        harp_clock = clock.run(autoharp)
      end
      if collecting_notes and not appending_notes then
        for i, v in ipairs(chord_arp) do
          table.insert(collected_notes, v)
        end
      elseif appending_notes and not collecting_notes then
        for i, v in ipairs(chord[i]) do
          table.insert(seq_notes, v)
        end
      end
      if seq_active and not (collecting_notes or appending_notes) then
        if #chord_arp > 0 then
          seq_notes = {table.unpack(chord_arp)}
          seq_step = 0
        end
      end
    elseif z == 0 then
      if #chord[i] > 0 and not (gkey[x][5].active or gkey[x][6].active or gkey[x][7].active) then
        for index, value in ipairs(chord[i]) do
          local e = {t = eKEYS, p = pattern_focus, i = key_focus, note = value, action = "note_off"} event(e)
          notes.held = {}
        end
      end
      if not seq_hold and heldkey == 0 then
        seq_notes = {}
      end
    end
    elseif y == 8 then
    if x == 3 and z == 1 then
      chord_play = not chord_play
    elseif x == 4 and z == 1 then
      chord_harp = not chord_harp
    elseif x == 5 then
      strum_options = z == 1 and true or false
    end
    if strum_options then
      if x > 5 and x < 14 and z == 1 then
        params:set("arp_length", x - 2)
      end
    else
      if x == 6 and z == 1 then
        strum_direction = strum_direction == 1 and - 1 or 1
      elseif x == 8 and z == 1  then
        strum_rate = util.clamp(strum_rate + 0.005, 0.02, 0.5)
      elseif x == 9 and z == 1  then
        strum_rate = util.clamp(strum_rate - 0.005, 0.02, 0.5)
      elseif x > 10 and x < 15 and z == 1 then
        chord_inversion = x - 11
      end
    end
  end
end

function grd_one.drum_grid(x, y, z)
  if y > 5 and x > 2 and x < 15 then
    local note = (params:get("drum_root_note") + 12 * notes.oct_key) + (x - 3)
    local vel = y == 8 and params:get("drum_vel_hi") or ( y == 7 and params:get("drum_vel_mid") or params:get("drum_vel_lo"))
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      last_velocity = vel
      if not key_repeat then
        local e = {t = eDRUMS, i = key_focus, note = note, vel = vel} event(e)
      end
      gkey[x][y].note = note
      table.insert(notes.held, note)
    elseif z == 0 then
      table.remove(notes.held, tab.key(notes.held, gkey[x][y].note))
    end
  end
end

function grd_one.draw()
  g:all(0)
  -- patterns
  for i = 1, 8 do
    if pattern[i].rec == 1 and pattern[i].play == 1 then
      g:led(i + 4, 1, ledfast)
    elseif pattern[i].rec_enabled == 1 then
      g:led(i + 4, 1, 15)
    elseif pattern[i].play == 1 then
      g:led(i + 4, 1, p[i].key_flash and 15 or 12)
    elseif pattern[i].count > 0 then
      g:led(i + 4, 1, 6)
    else
      g:led(i + 4, 1, 2)
    end
  end
  if params:get("metronome_viz") == 2 then
    g:led(16, 3, flash_bar and 15 or (flash_beat and 8 or 5)) -- Q flash
  end
    
  if pattern_view then
    -- pattern edit
    g:led(1, 1, (copying_pattern and not copy_src.state) and ledslow or (copy_src.state and 10 or 4))
    g:led(2, 1, pasting_pattern and ledslow or 4)
    g:led(3, 1, appending_pattern and 15 or 4)
    g:led(1, 2, pattern_clear and ledslow or (pattern_reset and 15 or 4))
    g:led(2, 2, pattern_clear and ledslow or (duplicating_pattern and 15 or 4))
    g:led(1, 3, pattern_overdub and 15 or 4)

    g:led(14, 1, pattern_rec_mode == "queued" and 10 or 4)
    g:led(15, 1, pattern_rec_mode == "synced" and 10 or 4)
    g:led(16, 1, pattern_rec_mode == "free" and 10 or 4)
    g:led(15, 2, pattern_length_config and 15 or 4)
    g:led(16, 2, pattern_options_config and 15 or 4)

    if pattern_length_config then
      for i = 1, 8 do
        g:led(i + 4, 3, params:get("patterns_meter"..pattern_focus) == i and 8 or 2)
        g:led(i + 4, 4, params:get("patterns_beatnum"..pattern_focus) == i and 12 or 4)
        g:led(i + 4, 5, params:get("patterns_beatnum"..pattern_focus) == i + 8 and 15 or 4)
        g:led(i + 4, 6, pattern_focus == i and 10 or 1)
      end
    elseif pattern_options_config then
      for i = 1, 8 do
        g:led(i + 4, 4, params:get("patterns_countin"..i) == 1 and 2 or (params:get("patterns_countin"..i) == 2 and 6 or 12))
        g:led(i + 4, 5, pattern[i].loop == 0 and 1 or 4)
      end
    else
      for i = 1, 8 do
        for j = 1, 3 do
          g:led(i + 4, j + 2, p[i].load == j and ledslow or (p[i].bank == j and (p[i].count[j] > 0 and 15 or 10) or (p[i].count[j] > 0 and 6 or 2)))
        end
      end
    end
    -- pattern position
    if p[pattern_focus].looping then
      local min = p[pattern_focus].step_min_viz[p[pattern_focus].bank]
      local max = p[pattern_focus].step_max_viz[p[pattern_focus].bank]
      for i = min, max do
        g:led(i, 8, 4)
      end
    end
    if pattern[pattern_focus].play == 1 and pattern[pattern_focus].endpoint > 0 then
      g:led(pattern[pattern_focus].position, 8, pattern[pattern_focus].play == 1 and 10 or 0)
    end
  else
    g:led(6, 2, mod_a and 15 or 8) 
    g:led(11, 2, mod_b and 15 or 8)
    -- focus
    for i = 1, 3 do
      g:led(i, 1, voice[i].mute and 2 or (int_focus == i and 10 or 4))
      g:led(i + 13, 1, voice[i + 3].mute and 2 or (int_focus == i + 3 and 10 or 4))
      g:led(i, 2, voice[i].mute and 2 or (key_focus == i and 10 or 4))
      g:led(i + 13, 2, voice[i + 3].mute and 2 or (key_focus == i + 3 and 10 or 4))
    end
    -- keyboard options
    g:led(1, 3, params:get("keys_option"..key_focus) == 1 and 6 or 2)
    g:led(2, 3, params:get("keys_option"..key_focus) == 2 and 6 or 2)
    g:led(1, 4, params:get("keys_option"..key_focus) == 3 and 6 or 2)
    g:led(2, 4, params:get("keys_option"..key_focus) == 4 and 6 or 2)

    g:led(15, 3, key_quantize and 6 or 2)
    g:led(15, 4, sample_view and 8 or 2)
    g:led(16, 4, retrig_mode and 8 or 2)

    if sample_view then
      for i = 1, 2 do
        for y = 3, 4 do
          g:led(i + 3, y, gkey[i + 3][y].active and 15 or 2)
          g:led(i + 5, y, gkey[i + 5][y].active and 15 or 4)
          g:led(i + 7, y, gkey[i + 7][y].active and 15 or 2)
          g:led(i + 9, y, gkey[i + 9][y].active and 15 or 4)
          g:led(i + 11, y, gkey[i + 11][y].active and 15 or 2)
        end
      end
    else
      -- interval
      for i = 8, 9 do
        g:led(i, 2, 6) -- home
        g:led(i, 3, key_link and 2 or 0) -- key link
        g:led(i, 4, 10) -- interval 0
      end
      for i = 1, 4 do
        g:led(i + 3, 3, 12 - i * 2) -- intervals dec
        g:led(i + 9, 3, 2 + i * 2) -- intervals inc
      end
    end
    -- int octave
    g:led(1, 5, 8 + notes.oct_int * 2)
    g:led(1, 6, 8 - notes.oct_int * 2)
    -- key octave
    g:led(1, 7, 8 + notes.oct_key * 2)
    g:led(1, 8, 8 - notes.oct_key * 2)
    -- sequencer
    if retrig_mode then
      for i = 1, 4 do
        g:led(16, i + 4, gkey[16][i + 4].active and 15 or i * 2)
      end
    else
      g:led(16, 5, seq_active and 10 or 4)
      g:led(16, 6, collecting_notes and 10 or 2)
      g:led(16, 7, appending_notes and 10 or 2)
      g:led(16, 8, seq_hold and 15 or 2)
    end
    -- keyboard
    if params:get("keys_option"..key_focus) == 1 then
      for i = 1, 12 do
        local octave = #scale_intervals[params:get("scale")] - 1
        g:led(i + 2, 5, gkey[i + 2][5].active and 15 or (((i + sc_iy * 3) % octave) == 1 and 10 or 2))
        g:led(i + 2, 6, gkey[i + 2][6].active and 15 or (((i + sc_iy * 2) % octave) == 1 and 10 or 2))
        g:led(i + 2, 7, gkey[i + 2][7].active and 15 or (((i + sc_iy) % octave) == 1 and 10 or 2))
        g:led(i + 2, 8, gkey[i + 2][8].active and 15 or ((i % octave) == 1 and 10 or 2))
      end
    elseif params:get("keys_option"..key_focus) == 2 then
      for x = 3, 14 do
        for y = 5, 8 do
          local note = (x * ch_ix - 3) + ch_iy * (8 - y)
          local st = note % 12
          if st == 0 or st == 2 or st == 4 or st == 5 or st == 7 or st == 9 or st == 11 then -- white keys
            g:led(x, y, gkey[x][y].active and 15 or 6)
          else
            g:led(x, y, gkey[x][y].active and 15 or 1)  -- black keys
          end
        end
      end
    elseif params:get("keys_option"..key_focus) == 3 then
      for x = 3, 14 do
        for y = 5, 8 do
          g:led(x, y, gkey[x][y].active and 15 or (gkey[x][y].chord and 4 or 0))
        end
      end
      g:led(3, 8, chord_play and 14 or 2)
      g:led(4, 8, chord_harp and 10 or 2)
      g:led(5, 8, strum_options and 15 or 2)
      if strum_options then
        g:led(params:get("arp_length") + 2, 8, 10)
      else
        g:led(6, 8, strum_direction == 1 and 4 or 1)
        g:led(8, 8, strum_rate == 0.5 and 8 or 2)
        g:led(9, 8, strum_rate == 0.02 and 8 or 2)
        for i = 1, 4 do
          g:led(i + 10, 8, chord_inversion == i - 1 and 6 or 2)
        end
      end
    elseif params:get("keys_option"..key_focus) == 4 then
      for x = 3, 14 do
        for y = 6, 8 do
          g:led(x, y, gkey[x][y].active and 15 or 2 * (y - 6) + 2)
        end
      end
    end
  end
  g:refresh()
end

return grd_one