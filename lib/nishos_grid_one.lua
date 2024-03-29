grd_one = {}

function grd_one.keys(x, y, z)
  if x > 4 and x < 13 and y == 1 and z == 1 then
    grd_one.pattern_keys(x - 4)
  end
  if (x == 4 or x == 13) and y < 3 then
    grd_one.modifier_keys(x, y, z)
  end
  if x == 16 and y == 3 and z == 1 then
    pattern_view = not pattern_view
    dirtyscreen = true
  end
  if pattern_view then
    if (x < 5 or x > 12) and y < 6 then
      grd_one.pattern_options(x, y, z)
    elseif x > 4 and x < 13 and y == 2 and z == 1 then
      pattern_bank_page = x - 5
    end
    if prgchange_view then
      if x > 4 and x < 13 and y > 2 and y < 7 then
        grd_one.prg_change(x, y, z)
      end
    else
      if x > 4 and x < 13 and y > 2 and y < 7 then
        grd_one.pattern_slots(x, y, z)
      elseif x == 13 and y == 6 and z == 1 then
          stop_all_patterns() 
      elseif y == 8 then
        grd_one.pattern_trigs(x, z)
      end
    end
  else
    if (x < 4 or x > 13) and y < 3 then
      grd_one.voice_settings(x, y, z)
    elseif x > 3 and x < 14 and y > 1 and y < 5 then
      grd_one.center_grid(x, y, z)
    elseif x < 3 and y > 2 and y < 5 then
      grd_one.voice_options(x, y, z)
    elseif x > 14 and y > 2 and y < 5 then
      grd_one.grid_options(x, y, z)
    elseif x < 3 and y > 4 then
      grd_one.octave_options(x, y, z)
    elseif x > 14 and y > 4 then
      grd_one.event_options(x, y, z)
    elseif x > 2 and x < 15 and y > 4 then
      grd_one.keyboard_grid(x, y, z)
    end
  end
  dirtygrid = true
end

function grd_one.pattern_options(x, y, z)
  if (x < 4 or x > 13) then
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
      dirtyscreen = true
    elseif y == 1 and x == 15 and z == 1  then
      pattern_rec_mode = "synced"
      dirtyscreen = true
    elseif y == 1 and x == 16 and z == 1  then
      pattern_rec_mode = "free"
      dirtyscreen = true
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
      pattern_len_edit = z == 1 and true or false
      dirtyscreen = true
    elseif y == 2 and x == 16 then
      if z == 1 then
        prgchange_view = not prgchange_view
        if prgchange_view then loading_page = false end
      end
      dirtyscreen = true
    elseif y == 3 and x == 1 then
      pattern_overdub = z == 1 and true or false
    elseif y == 4 and x == 16 and z == 1 then
      loading_page = not loading_page
      if loading_page then prgchange_view = false end
      dirtyscreen = true
    end
  elseif x == 4 and z == 1 then
    if y == 2 then
      pattern_bank_page = util.clamp(pattern_bank_page - 1, 0, 7)
    elseif y == 3 then
      pattern_bank_page = util.clamp(pattern_bank_page + 1, 0, 7)
    end
  elseif x == 13 and z == 1 then
    local bank = y - 2 + pattern_bank_page * 3
    for i = 1, 8 do
      p[i].load = bank
      if pattern[i].play == 0 then
        update_pattern_bank(i)
      else
        clock.run(function()
          clock.sync(4)
          update_pattern_bank(i)
          pattern[i].step = 0
        end)
      end
      if pattern_overdub and pattern[i].play == 0 and p[i].count[bank] > 0 then
        pattern[i]:start(4)
      end
    end
  end
end

function grd_one.pattern_keys(i)
  if pattern_focus ~= i and num_rec_enabled() == 0 then
    pattern_focus = i
  end
  if not (pasting_pattern or copying_pattern) then
    -- stop and clear
    if pattern_clear or (mod_a and mod_c) or (mod_b and mod_d) then
      if pattern[i].count > 0 then
        kill_active_notes(i)
        pattern[i]:clear()
        save_pattern_bank(i, p[i].bank)
      end
    else
      if pattern[i].play == 0 then -- if pattern is not playing
        local count_in = params:get("patterns_launch_"..i) == 2 and 1 or (params:get("patterns_launch_"..i) == 3 and 4 or nil)
        -- if pattern is empty
        if pattern[i].count == 0 then
          -- if rec not enabled press key to enable recording
          if appending_notes then
            paste_seq_pattern(i)
          else
            if num_rec_enabled() == 0 then
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
            if pattern[i].count == 0 then
              pattern[i]:stop()
            end
          else
            pattern[i]:stop()
            p[i].stop = false
          end
        end
      end
    end
  end
end

function grd_one.pattern_slots(x, y, z)
  local i = x - 4
  local bank = y - 2 + pattern_bank_page * 3
  if y < 6 then
    -- select active pattern bank, copy/paste/duplicate/append actions
    if z == 1 then
      -- set pattern focus
      if pattern_focus ~= i and num_rec_enabled() == 0 then
        pattern_focus = i
        held[pattern_focus].num = 0
      end
      -- copy/paste/append/duplicate
      if pasting_pattern and copy_src.state then
        copy_pattern(copy_src.pattern, copy_src.bank, i, bank)
        show_message("pasted  to  pattern  "..i.."  bank  "..bank)
        copying_pattern = false
        copy_src = {state = false, pattern = nil, bank = nil}
      elseif appending_pattern and copy_src.state then
        local src_s = nil
        local src_e = nil
        if p[copy_src.pattern].looping then
          src_s = pattern[copy_src.pattern].step_min
          src_e = pattern[copy_src.pattern].step_max
        end
        append_pattern(copy_src.pattern, copy_src.bank, i, bank, src_s, src_e)
        show_message("appended  to  pattern  "..i.."  bank  "..bank)
        copying_pattern = false
        copy_src = {state = false, pattern = nil, bank = nil}
      elseif (pasting_pattern or appending_pattern) and not copy_src.state then
        show_message("clipboard  empty")
      elseif copying_pattern and not copy_src.state then
        copy_src.pattern = i
        copy_src.bank = bank
        copy_src.state = true
        show_message("pattern  "..copy_src.pattern.."  bank  "..copy_src.bank.."  selected")
      elseif duplicating_pattern then
        if p[i].count[bank] > 0 then
          append_pattern(i, bank, i, bank)
          show_message("doubled  pattern")
        end
      elseif pattern_reset then
        reset_pattern_length(i, bank)
        show_message("pattern  reset")
      elseif pattern_len_edit then
        p[i].manual_length[bank] = false
        pattern[i].manual_length = false
        --pattern[i].length = pattern[i].meter * pattern[i].barnum * 4
        --pattern[i]:set_length(pattern[i].length)
      elseif pattern_clear or (mod_a and mod_c) or (mod_b and mod_d) then
        clear_pattern_bank(i, bank)
        if pattern[i].count > 0 and p[i].bank == bank then
          kill_active_notes(i)
          pattern[i]:clear()
        end
      -- load pattern
      elseif not (copying_pattern or pasting_pattern) then
        if p[i].bank ~= bank then
          p[i].load = bank
          if pattern[i].play == 0 then
            update_pattern_bank(i)
          end
        elseif p[i].load then
          p[i].load = nil
        end
      end
    end
  elseif y == 6 and z == 1 then
    if pattern[i].play == 1 then
      p[i].stop = not p[i].stop
    else
      p[i].stop = false
    end
  end
  dirtyscreen = true
end

function grd_one.prg_change(x, y, z)
  local i = x - 4
  local bank = y - 2 + pattern_bank_page * 3
  if z == 1 then
    if y == 6 then
      p[i].prc_enabled = not p[i].prc_enabled
    else
      pattern_focus = i
      bank_focus = bank
      if pattern_clear then
        p[i].prc_num[bank] = 0
      end
    end
  end
  dirtyscreen = true
end

function grd_one.pattern_trigs(x, z)
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
      if pattern_reset then
        clear_pattern_loops()
      end
    end
  else
    if held[pattern_focus].num == 1 and held[pattern_focus].max == 2 then
      local pf = pattern_focus
      if pattern_overdub then
        for i = 1, 8 do
          if pattern[i].play == 1 then
            clock.run(function()
              clock.sync(1)
              local segment = math.floor(pattern[pf].endpoint / 16) --util.round(pattern[pf].endpoint / 16, 1)
              pattern[i].step_min = segment * (math.min(held[pf].first, held[pf].second) - 1)
              pattern[i].step_max = segment * math.max(held[pf].first, held[pf].second)
              pattern[i].step = pattern[i].step_min
              p[i].step_min_viz[p[i].bank] = math.min(held[pf].first, held[pf].second)
              p[i].step_max_viz[p[i].bank] = math.max(held[pf].first, held[pf].second)
              p[i].looping = true
              -- store these in case you wanna add a "copy section function"
              p[i].step_min[p[i].bank] = pattern[i].step_min
              p[i].step_max[p[i].bank] = pattern[i].step_max
            end)
          end
        end
      else
        clock.run(function()
          clock.sync(1)
          local segment = math.floor(pattern[pf].endpoint / 16)
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
      end
    elseif p[pattern_focus].looping and held[pattern_focus].max < 2 then
      p[pattern_focus].looping = false
      clock.run(function()
        local wait = params:get("patterns_launch_"..pattern_focus) == 2 and 1 or (params:get("patterns_launch_"..pattern_focus) == 3 and 4 or pattern[pattern_focus].quantize)
        clock.sync(wait)
        pattern[pattern_focus].step = 0
        pattern[pattern_focus].step_min = 0
        pattern[pattern_focus].step_max = pattern[pattern_focus].endpoint
        -- restore these so the loop points aren't saveed to the pattern bank
        p[pattern_focus].step_min[p[pattern_focus].bank] = 0
        p[pattern_focus].step_max[p[pattern_focus].bank] = pattern[pattern_focus].endpoint
      end)
    elseif not (p[pattern_focus].looping or pattern_reset) and held[pattern_focus].max < 2 then
      clock.run(function()
        clock.sync(quant_rate)
        local segment = math.floor(pattern[pattern_focus].endpoint / 16)
        pattern[pattern_focus].step = segment * (x - 1)
      end)
    end
  end
end

function grd_one.modifier_keys(x, y, z)
  if y == 1 then
    if x == 4 then
      mod_a = z == 1 and true or false
    elseif x == 13 then
      mod_b = z == 1 and true or false
    end
  elseif y == 2 then
    if x == 4 then
      mod_c = z == 1 and true or false
    elseif x == 13 then
      mod_d = z == 1 and true or false
    end
  end
end

function grd_one.octave_options(x, y, z)
  if y == 5 and z == 1 then
    if x == 1 then
      if kit_view then
        params:delta("kit_octaves", 1)
      else
        params:delta("interval_octaves_"..int_focus, 1)
      end
    end
  elseif y == 6 and z == 1 then
    if x == 1 then
      if kit_view then
        params:delta("kit_octaves", -1)
      else
        params:delta("interval_octaves_"..int_focus, -1)
      end
    end
  elseif y == 7 and z == 1 then
    if x == 1 then
      if (strum_count_options or strum_mode_options or strum_skew_options) then
        params:delta("strum_octaves", 1)
      else
        params:delta("keys_octaves_"..key_focus, 1)
      end
    end
  elseif y == 8 and z == 1 then
    if x == 1 then
      if (strum_count_options or strum_mode_options or strum_skew_options) then
        params:delta("strum_octaves", -1)
      else
        params:delta("keys_octaves_"..key_focus, -1)
      end
    end
  end
end

function grd_one.trigs_grid(x, y, z)
  if x > 3 and x < 14 and y > 2 and y < 5 then
    if x < 12 and z == 1 then
      local i = (x - 3) + (y - 3) * 8
      if set_trigs_end then
        trigs[trigs_focus].step_max = i
      else
        trigs[trigs_focus].pattern[i] = 1 - trigs[trigs_focus].pattern[i]
      end
    elseif x == 12 then
      if y == 3 then
        set_trigs_end = z == 1 and true or false
      elseif y == 4 then
        trigs_reset = z == 1 and true or false
      end
    elseif x == 13 and z == 1 then
      if trigs_reset then
        trigs[y - 2].pattern = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
        trigs[y - 2].step_max = 16
      else
        trigs_focus = y - 2
      end
    end
  end
end

function grd_one.center_grid(x, y, z)
  if trigs_config_view then
    grd_one.trigs_grid(x, y, z)
  elseif kit_view and y > 2 and y < 5 then
    grd_one.kit_grid(x, y, z)
  else
    grd_one.int_grid(x, y, z)
  end
end

function grd_one.voice_settings(x, y, z)
  if y == 1 and z == 1 then
    -- set interval_focus
    if x < 4 or x > 13 then
      local i = x < 4 and x or x - 10
      if (strum_count_options or strum_mode_options or strum_skew_options) then
        strum_focus = i
      elseif (mod_a or mod_b) then
        params:set("voice_mute"..i, voice[i].mute and 1 or 2)
      elseif not voice[i].mute then
        int_focus = i
      end
    end
  elseif y == 2 and z == 1 then
    -- set key focus
    if x < 4 or x > 13 then
      local i = x < 4 and x or x - 10
      if (mod_a or mod_b) then
        params:set("voice_mute"..i, voice[i].mute and 1 or 2)
      elseif (mod_c or mod_d) then
        if voice[i].output < 3 then
          --for _, value in ipairs(voicenotes[voice[i].output]) do
            --free_voice(voice[i].output, value)
          --end
        elseif voice[i].output == 3 or voice[i].output > 6 then
          notes_off(i)
        end
      elseif not voice[i].mute then
        key_focus = i
        voice_focus = i
        notes_held = {}
        dirtyscreen = true
      end
    end
  end
end

function grd_one.voice_options(x, y, z)
  if y == 3 and z == 1 then
    if x == 1 then
      params:set("keys_option"..key_focus, 1) -- set keys to scale
    elseif x == 2 then
      params:set("keys_option"..key_focus, 2) -- set keys to chromatic
    end
  elseif y == 4 and z == 1 then
    if x == 1 then
      params:set("keys_option"..key_focus , 3) -- set keys to chords
    elseif x == 2 then
      params:set("keys_option"..key_focus, 4) -- set keys to drums
    end
  end
end

function grd_one.grid_options(x, y, z)
  if y == 3 then
    if x == 15 and z == 1 then
      key_quantize = not key_quantize -- toggle quantization
    end
  elseif y == 4 and z == 1 then
    if x == 15 then
      kit_view = not kit_view
    elseif x == 16 then
      key_repeat_view = not key_repeat_view
      if key_repeat_view then
        if seq_active then
          seq_active = false
        end
        sequencer_config = false
      else
        latch_key_repeat = false
        for i = 5, 8 do
          gkey[16][i].active = false
        end
        set_repeat_rate()
      end
    end
  end
end


function grd_one.event_options(x, y, z)
  if y == 5 and x == 15 and z == 1 then
    trigs_config_view = not trigs_config_view
  end
  -- key repeat and sequener
  if key_repeat_view then
    if y > 4 and x == 16 then
      if latch_key_repeat then
        if z == 1 then
          gkey[x][y].active = not gkey[x][y].active
        end
      else
        gkey[x][y].active = z == 1 and true or false
      end
      set_repeat_rate()
    elseif y == 8 and x == 15 and z == 1 then
      latch_key_repeat = not latch_key_repeat
      if not latch_key_repeat then
        for i = 5, 8 do
          gkey[16][i].active = false
        end
        set_repeat_rate()
      end
    end
  else
    if y == 5 and x == 16 and z == 1 then
      seq_active = not seq_active
      seq_step = 0
      trig_step = 0
      if not seq_active then
        seq_notes = {}
      end
    elseif y == 6 and x == 16 then
      collecting_notes = z == 1 and true or false
      if z == 1 and notes_added then
        notes_added = false
        prev_seq_notes = {table.unpack(seq_notes)}
      end
      if z == 0 and #collected_notes > 0 then
        seq_step = 0
        trig_step = 0
        seq_notes = {table.unpack(collected_notes)}
        prev_seq_notes = {table.unpack(collected_notes)}
      else
        collected_notes = {}
      end
      dirtyscreen = true
    elseif y == 7 and x == 16 then
      appending_notes = z == 1 and true or false
      if z == 0 and notes_added then
        seq_notes = {table.unpack(prev_seq_notes)}
        notes_added = false
        if seq_step >= #prev_seq_notes then
          seq_step = 0
        end
      end
    elseif y == 8 and x == 16 and z == 1 then
      seq_hold = not seq_hold
      if not seq_hold then
        seq_notes = {table.unpack(notes_held)}
      end
    end
  end
end

function grd_one.keyboard_grid(x, y, z)
  if voice[key_focus].keys_option == 1 then
    grd_one.scale_grid(x, y, z)
  elseif voice[key_focus].keys_option == 2 then
    grd_one.chrom_grid(x, y, z)
  elseif voice[key_focus].keys_option == 3 then
    grd_one.chord_grid(x, y, z)
  elseif voice[key_focus].keys_option == 4 then
    grd_one.drum_grid(x, y, z)
  end
end

function grd_one.int_grid(x, y, z)
  -- detect key hold last key and root
  if (y == 2 or y == 4) and x > 7 and x < 9 and not kit_view then
    heldkey_int = heldkey_int + (z * 2 - 1)
  end
  -- detect key hold intervals
  if y == 3 and ((x > 3 and x < 8) or (x > 9 and x < 14)) and not kit_view then
    heldkey_int = heldkey_int + (z * 2 - 1)
  end
  -- interval keys
  if z == 1 then
    if y == 2 and x > 7 and x < 10 then
      if not kit_view then
        if not transposing then
          local p = pattern[pattern_focus].rec_enabled == 1 and pattern_focus or nil
          local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = notes_home, action = "note_on"} event(e)
          gkey[x][y].note = notes_home
        else
          local e = {t = eTRSP_SCALE, interval = 0} event(e)
        end
        notes_last = notes_home
      end
    elseif y == 3 then
      -- interval decrease
      if x > 3 and x < 8 then
        local interval = x - 8
        local new_note = util.clamp(notes_last + interval, 1, #scale_notes)
        if not transposing then
          local p = pattern[pattern_focus].rec_enabled == 1 and pattern_focus or nil
          local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = new_note, action = "note_on"} event(e)
          gkey[x][y].note = new_note
        else
          local e = {t = eTRSP_SCALE, interval = interval} event(e)
        end
        notes_last = new_note
      -- interval increase
      elseif x > 9 and x < 14 then
        local interval = x - 9
        local new_note = util.clamp(notes_last + interval, 1, #scale_notes)
        if not transposing then
          local p = pattern[pattern_focus].rec_enabled == 1 and pattern_focus or nil
          local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = new_note, action = "note_on"} event(e)
          gkey[x][y].note = new_note
        else
          local e = {t = eTRSP_SCALE, interval = interval} event(e)
        end
        notes_last = new_note
      -- toggle key link
      elseif x > 7 and x < 10 then
        if (mod_a or mod_b or mod_c or mod_d) then
          transposing = not transposing
        else
          link_clock = clock.run(function()
            clock.sleep(1)
            key_link = not key_link
          end)
        end
      end
    elseif y == 4 then
      if x > 7 and x < 10 then
        if not transposing then
          if collecting_notes and not appending_notes then
            table.insert(collected_notes, 0)
            dirtyscreen = true
          elseif appending_notes and not collecting_notes then
            table.insert(seq_notes, 0)
            notes_added = true
          else
            local p = pattern[pattern_focus].rec_enabled == 1 and pattern_focus or nil
            local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = notes_last, action = "note_on"} event(e)
            gkey[x][y].note = notes_last
          end
        else
          local octave = (#scale_intervals[current_scale] - 1) * (x - 8 == 0 and -1 or 1)
          local e = {t = eTRSP_SCALE, interval = octave} event(e)
        end
      end
    end
  elseif z == 0 then
    if not (kit_view or trigs_config_view) then
      local p = pattern[pattern_focus].rec_enabled == 1 and pattern_focus or nil
      if y == 2 and x > 7 and x < 10 then
        local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      elseif y == 3 then
        if x > 3 and x < 8 then
          local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
        elseif x > 7 and x < 10 then
          if link_clock ~= nil then clock.cancel(link_clock) end
        elseif x > 9 and x < 14 then
          local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
        end
      elseif y == 4 and x > 7 and x < 10 then
        local e = {t = eSCALE, p = p, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      end
    end
  end
end

function grd_one.kit_grid(x, y, z)
  if x > 3 and x < 12 then 
    local note = ((x - 3) + (4 - y) * 8) + (kit_oct * 16) + 47
    heldkey_kit = heldkey_kit + (z * 2 - 1)
    if z == 1 then
      if key_repeat then
        if heldkey_kit == 1 then
          trig_step = 0
        end
      else
        local e = {t = eKIT, note = note} event(e)
      end
      gkey[x][y].note = note
      table.insert(kit_held, note)
    else
      table.remove(kit_held, tab.key(kit_held, gkey[x][y].note))
    end
  elseif x == 12 then
    if y > 2 and y < 5 then
      gkey[x][y].active = z == 1 and true or false
      held_bank = held_bank + (z * 2 - 1)
      if held_bank < 1 then
        midi_bank = 0
      elseif held_bank == 1 then
        if y == 3 then
          midi_bank = z == 1 and 2 or 4
        elseif y == 4 then
          midi_bank = z == 1 and 4 or 2
        end
      elseif held_bank == 2 then
        midi_bank = 6
      end
    end
  elseif x == 13 then
    gkey[x][y].active = z == 1 and true or false
    local n = y - 2 + midi_bank
    m[kit_midi_dev]:cc(mcc[n].num, z == 1 and mcc[n].max or mcc[n].min, kit_midi_ch)
  end
end

function grd_one.scale_grid(x, y, z)
  if y > 4 and x > 2 and x < 15 then
    heldkey_key = heldkey_key + (z * 2 - 1)
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      local octave = #scale_intervals[current_scale] - 1
      local note = (x - 2) + ((8 - y) * scalekeys_y) + (notes_oct_key[key_focus] + 3) * octave
      -- keep track of held notes
      gkey[x][y].note = note
      table.insert(notes_held, note)
      -- collect or append notes
      if collecting_notes and not appending_notes then
        table.insert(collected_notes, note)
      elseif appending_notes and not collecting_notes then
        table.insert(seq_notes, note)
        notes_added = true
      end
      -- insert notes
      if seq_active and not (collecting_notes or appending_notes) then
        if heldkey_key == 1 then
          trig_step = 0
          if seq_hold then seq_notes = {} end
        end
        table.insert(seq_notes, note)
        prev_seq_notes = {table.unpack(seq_notes)}
      end
      -- play notes
      if (not seq_active or #seq_notes == 0) then
        if key_repeat then
          if heldkey_key == 1 then
            trig_step = 0
          end
        else
          local e = {t = eSCALE, i = key_focus, root = root_oct, note = note, action = "note_on"} event(e)
        end
      end
      -- set last note
      if key_link and not transposing then
        notes_last = note + octave * notes_oct_int[int_focus]
      end
    elseif z == 0 then
      -- remove notes
      if seq_active and not (collecting_notes or appending_notes or seq_hold) then
        table.remove(seq_notes, tab.key(notes_held, gkey[x][y].note))
      end
      if (not seq_active or #seq_notes == 0 or not key_repeat) then
        local e = {t = eSCALE, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      end
      table.remove(notes_held, tab.key(notes_held, gkey[x][y].note))
    end
  end
end

function grd_one.chrom_grid(x, y, z)
  if y > 4 and x > 2 and x < 15 then
    heldkey_key = heldkey_key + (z * 2 - 1)
    local root = (60 - 3) + 12 * notes_oct_key[key_focus]
    local note = (root + x * chromakeys_x) + chromakeys_y * (8 - y)
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      -- keep track of held notes
      gkey[x][y].note = note
      table.insert(notes_held, note)
      -- collec or append notes
      if collecting_notes and not appending_notes then
        table.insert(collected_notes, note)
      elseif appending_notes and not collecting_notes then
        table.insert(seq_notes, note)
        notes_added = true
      end
      -- insert notes
      if seq_active and not (collecting_notes or appending_notes) then
        if heldkey_key == 1 then
          trig_step = 0
          if seq_hold then seq_notes = {} end
        end
        table.insert(seq_notes, note)
        prev_seq_notes = {table.unpack(seq_notes)}
      end
      -- play notes
      if (not seq_active or #seq_notes == 0) then
        if key_repeat then
          if heldkey_key == 1 then
            trig_step = 0
          end
        else
          local e = {t = eKEYS, i = key_focus, note = note, action = "note_on"} event(e)
        end
      end
    elseif z == 0 then
      if seq_active and not (collecting_notes or appending_notes or seq_hold) then
        table.remove(seq_notes, tab.key(notes_held, gkey[x][y].note))
      end
      if (not seq_active or #seq_notes == 0) then
        local e = {t = eKEYS, i = key_focus, note = gkey[x][y].note, action = "note_off"} event(e)
      end
      table.remove(notes_held, tab.key(notes_held, gkey[x][y].note))
    end
  end
end

function grd_one.chord_grid(x, y, z)
  if y > 4 and y < 8 and x > 2 and x < 15 then
    heldkey_key = heldkey_key + (z * 2 - 1)
    gkey[x][y].active = z == 1 and true or false
    local i = x - 2
    if z == 1 then
      last_chord_root = i
      if key_repeat and #current_chord == 0 then
        trig_step = 0
      end
      play_chord(i)
    elseif z == 0 then
      if heldkey_key == 0 then
        kill_chord()
        if not (seq_hold or appending_notes) then
          seq_notes = {}
        end
      end
    end
  elseif y == 8 then
    if x == 3 and z == 1 then
      chord_play = not chord_play
    elseif x == 4 and z == 1 then
      chord_strum = not chord_strum
      if not chord_strum and strum_clock ~= nil then
        clock.cancel(strum_clock)
      end
    elseif x == 5 then
      strum_count_options = z == 1 and true or false
    elseif x == 6 then
      strum_mode_options = z == 1 and true or false
    elseif x == 7 then
      strum_skew_options = z == 1 and true or false
    end
    if strum_count_options and z == 1 then
      if x > 5 and x < 15 then
        params:set("strm_length", x - 2)
        if heldkey_key > 0 then
          play_chord()
        end
      end
    elseif strum_mode_options and z == 1 then
      if x > 9 and x < 15 then
        params:set("strm_mode", x - 9)
      end
    elseif strum_skew_options and z == 1 then
      if x == 11 then
        params:delta("strm_skew", -1)
      elseif x == 12 then
        params:set("strm_skew", 0)
      elseif x == 13 then
        params:delta("strm_skew", 1)
      end
    else
      if (x == 8 or x == 9) then
        gkey[x][y].active = z == 1 and true or false
        if z == 1 then
          params:delta("strm_rate", x == 8 and 1 or -1)
        end
      elseif x > 10 and x < 15 and z == 1 then
        chord_inversion = x - 10
        if heldkey_key > 0 then
          play_chord()
        end
      end
    end
  end
end

function grd_one.drum_grid(x, y, z)
  if y > 5 and x > 2 and x < 15 then
    heldkey_key = heldkey_key + (z * 2 - 1)
    local note = (drum_root_note + 12 * notes_oct_key[key_focus]) + (x - 3)
    local vel = y == 8 and drum_vel_hi or (y == 7 and drum_vel_mid or drum_vel_lo)
    gkey[x][y].active = z == 1 and true or false
    if z == 1 then
      drum_vel_last = vel
      if key_repeat then
        if heldkey_key == 1 then
          trig_step = 0
        end
      else
        local e = {t = eDRUMS, i = key_focus, note = note, vel = vel} event(e)
      end
      gkey[x][y].note = note
      table.insert(notes_held, note)
    elseif z == 0 then
      table.remove(notes_held, tab.key(notes_held, gkey[x][y].note))
    end
  end
end

function grd_one.draw()
  g:all(0)
  -- patterns keys
  for i = 1, 8 do
    if pattern[i].rec == 1 and pattern[i].play == 1 then
      g:led(i + 4, 1, pulse_key_fast)
    elseif pattern[i].rec_enabled == 1 then
      g:led(i + 4, 1, 15)
    elseif pattern[i].play == 1 then
      g:led(i + 4, 1, pattern[i].pulse_key and 15 or 12)
    elseif pattern[i].count > 0 then
      g:led(i + 4, 1, 6)
    else
      g:led(i + 4, 1, 2)
    end
  end
  -- mod keys
  g:led(4, 1, mod_a and 15 or 0) 
  g:led(13, 1, mod_b and 15 or 0)
  g:led(4, 2, mod_c and 15 or 0) 
  g:led(13, 2, mod_d and 15 or 0)

  if hide_metronome then
    g:led(16, 3, 3)
  else
    g:led(16, 3, pulse_bar and 15 or (pulse_beat and 8 or 3)) -- Q flash
  end

  if pattern_view then
    -- pattern edit
    g:led(1, 1, (copying_pattern and not copy_src.state) and pulse_key_slow or (copy_src.state and 10 or 4))
    g:led(2, 1, pasting_pattern and pulse_key_slow or 4)
    g:led(3, 1, appending_pattern and 15 or 4)
    g:led(1, 2, pattern_clear and pulse_key_slow or (pattern_reset and 15 or 4))
    g:led(2, 2, pattern_clear and pulse_key_slow or (duplicating_pattern and 15 or 4))
    g:led(1, 3, pattern_overdub and 15 or 4)

    g:led(14, 1, pattern_rec_mode == "queued" and 10 or 4)
    g:led(15, 1, pattern_rec_mode == "synced" and 10 or 4)
    g:led(16, 1, pattern_rec_mode == "free" and 10 or 4)
    g:led(15, 2, pattern_len_edit and 15 or 4)
    g:led(16, 2, prgchange_view and 15 or 4)
    g:led(16, 4, loading_page and pulse_key_mid or 0)
    -- patten bank page
    for i = 1, 8 do
      g:led(i + 4, 2, pattern_bank_page + 1 == i and 2 or 0)
    end
    
    if prgchange_view then
      local bank_off = pattern_bank_page * 3
      for i = 1, 8 do
        for j = 1, 3 do
          local bank = j + bank_off
          local led = 0
          if bank_focus == bank and pattern_focus == i then
            led = math.ceil(pulse_key_slow / 2)
          elseif p[i].prc_num[bank] > 0 then
            if p[i].count[bank] > 0 then
              led = 10
            else
              led = 5
            end
          elseif p[i].prc_num[bank] == 0 then
            if p[i].count[bank] > 0 then
              led = 2
            end
          end
          g:led(i + 4, j + 2, led)
        end
        g:led(i + 4, 6, p[i].prc_enabled and 8 or 3)
      end
    else
      -- pattern slots
      local bank_off = pattern_bank_page * 3
      for i = 1, 8 do
        local dim = pattern_focus == i and 0 or -1
        for j = 1, 3 do
          g:led(i + 4, j + 2, p[i].load == j + bank_off and pulse_key_slow or (p[i].bank == j + bank_off and (p[i].count[j + bank_off] > 0 and 15 + dim or 10 + dim) or (p[i].count[j + bank_off] > 0 and 6 + dim or 3 + dim)))
        end
        g:led(i + 4, 6, p[i].stop and pulse_key_mid or 1)
      end
      -- stop all key
      g:led(13, 6, stop_all and pulse_key_fast or 0)
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
    end
  else
    -- focus
    for i = 1, 3 do
      if (strum_count_options or strum_mode_options or strum_skew_options) then
        g:led(i, 1, strum_focus == i and 12 or 1)
        g:led(i + 13, 1, int_focus == i + 3 and 12 or 1)
      else
        g:led(i, 1, voice[i].mute and 2 or (int_focus == i and 10 or 4))
        g:led(i + 13, 1, voice[i + 3].mute and 2 or (int_focus == i + 3 and 10 or 4))
      end
      g:led(i, 2, voice[i].mute and 2 or (key_focus == i and 10 or 4))
      g:led(i + 13, 2, voice[i + 3].mute and 2 or (key_focus == i + 3 and 10 or 4))
    end

    -- keyboard options
    g:led(1, 3, voice[key_focus].keys_option == 1 and 8 or 4)
    g:led(2, 3, voice[key_focus].keys_option == 2 and 8 or 4)
    g:led(1, 4, voice[key_focus].keys_option == 3 and 8 or 4)
    g:led(2, 4, voice[key_focus].keys_option == 4 and 8 or 4)

    g:led(15, 3, key_quantize and 8 or 4)
    g:led(15, 4, kit_view and 10 or 4)
    g:led(16, 4, key_repeat_view and 10 or 4)

    if trigs_config_view then
      for x = 1, 8 do
        if x <= trigs[trigs_focus].step_max then
          g:led(x + 3, 3, (trig_step == x and (seq_active or key_repeat)) and 12 or (trigs[trigs_focus].pattern[x] == 1 and 6 or 2))
        end
        if x + 8 <= trigs[trigs_focus].step_max then
          g:led(x + 3, 4, (trig_step == x + 8 and (seq_active or key_repeat)) and 12 or (trigs[trigs_focus].pattern[x + 8] == 1 and 6 or 2))
        end
      end
      for i = 1, 2 do
        g:led(13, i + 2, trigs_focus == i and 12 or 4)
      end
      g:led(12, 3, set_trigs_end and 15 or 1)
      g:led(12, 4, trigs_reset and 15 or 1)
      g:led(15, 5, pulse_key_mid)

    elseif kit_view then
      for x = 1, 2 do
        for y = 3, 4 do
          g:led(x + 3, y, gkey[x + 3][y].active and 15 or 2)
          g:led(x + 5, y, gkey[x + 5][y].active and 15 or 4)
          g:led(x + 7, y, gkey[x + 7][y].active and 15 or 2)
          g:led(x + 9, y, gkey[x + 9][y].active and 15 or 4)
        end
        g:led(12, x + 2, gkey[12][x + 2].active and 15 or 1)
        g:led(13, x + 2, gkey[13][x + 2].active and 15 or 8)
      end
    else
    -- interval
      for i = 8, 9 do
        g:led(i, 2, 6) -- home
        g:led(i, 3, transposing and pulse_key_mid or (key_link and 2 or 0)) -- key link/transpose
        g:led(i, 4, 10) -- interval 0
      end
      for i = 1, 4 do
        g:led(i + 3, 3, 12 - i * 2) -- intervals dec
        g:led(i + 9, 3, 2 + i * 2) -- intervals inc
      end
    end

    -- int/key octave
    if kit_view then
      g:led(1, 5, 8 + kit_oct * 2)
      g:led(1, 6, 8 - kit_oct * 2)
    else
      g:led(1, 5, 8 + notes_oct_int[int_focus] * 2)
      g:led(1, 6, 8 - notes_oct_int[int_focus] * 2)
    end

    -- key octave
    if (strum_count_options or strum_mode_options or strum_skew_options) then
      g:led(1, 7, 8 + chord_oct_shift * 2)
      g:led(1, 8, 8 - chord_oct_shift * 2)
    else
      g:led(1, 7, 8 + notes_oct_key[key_focus] * 2)
      g:led(1, 8, 8 - notes_oct_key[key_focus] * 2)
    end

    -- sequencer
    if key_repeat_view then
      for i = 1, 4 do
        g:led(16, i + 4, gkey[16][i + 4].active and 15 or i * 2)
      end
      g:led(15, 8, latch_key_repeat and pulse_key_slow or 0)
    else
      g:led(16, 5, seq_active and 10 or 4)
      g:led(16, 6, collecting_notes and 10 or 2)
      g:led(16, 7, appending_notes and 10 or 2)
      g:led(16, 8, seq_hold and 15 or 2)
    end

    -- keyboard/mute pattern view
    if voice[key_focus].keys_option == 1 then
      local octave = #scale_intervals[current_scale] - 1
      for i = 1, 12 do
        g:led(i + 2, 5, gkey[i + 2][5].active and 15 or (((i + scalekeys_y * 3) % octave) == 1 and 10 or 2))
        g:led(i + 2, 6, gkey[i + 2][6].active and 15 or (((i + scalekeys_y * 2) % octave) == 1 and 10 or 2))
        g:led(i + 2, 7, gkey[i + 2][7].active and 15 or (((i + scalekeys_y) % octave) == 1 and 10 or 2))
        g:led(i + 2, 8, gkey[i + 2][8].active and 15 or ((i % octave) == 1 and 10 or 2))
      end
    elseif voice[key_focus].keys_option == 2 then
      for x = 3, 14 do
        for y = 5, 8 do
          local note = (x * chromakeys_x - 3) + chromakeys_y * (8 - y)
          local st = note % 12
          if st == 0 or st == 2 or st == 4 or st == 5 or st == 7 or st == 9 or st == 11 then -- white keys
            g:led(x, y, gkey[x][y].active and 15 or 6)
          else
            g:led(x, y, gkey[x][y].active and 15 or 1)  -- black keys 
          end
        end
      end
    elseif voice[key_focus].keys_option == 3 then
      for x = 3, 14 do
        for y = 5, 7 do
          g:led(x, y, gkey[x][y].active and 15 or (gkey[x][y].chord_viz))
        end
      end
      g:led(3, 8, chord_play and 14 or 2)
      g:led(4, 8, chord_strum and 10 or 2)
      g:led(5, 8, strum_count_options and 15 or 0)
      g:led(6, 8, strum_mode_options and 15 or 0)
      g:led(7, 8, strum_skew_options and 15 or 0)
      if strum_count_options then
        for i = 4, 12 do
          g:led(i + 2, 8, strum_count == i and 10 or 1)
        end
      elseif strum_mode_options then
        for i = 1, 5 do
          g:led(i + 9, 8, strum_mode == i and 10 or 2)
        end
      elseif strum_skew_options then
        local val = math.floor(math.abs(strum_skew / 2)) + 2
        g:led(11, 8, strum_skew < 0 and val or 2)
        g:led(12, 8, strum_skew == 0 and 10 or 2)
        g:led(13, 8, strum_skew > 0 and val or 2)
      else
        g:led(8, 8, gkey[8][8].active and 15 or (strum_rate == 0.5 and 8 or 2))
        g:led(9, 8, gkey[9][8].active and 15 or (strum_rate == 0.02 and 8 or 2))
        for i = 1, 4 do
          g:led(i + 10, 8, chord_inversion == i and 6 or 2)
        end
      end
    elseif voice[key_focus].keys_option == 4 then
      for x = 3, 14 do
        for y = 6, 8 do
          g:led(x, y, gkey[x][y].active and 15 or 2 * (y - 6) + 2)
        end
      end
    end
  end
  g:refresh()
end

function grd_one.end_msg()
  g:all(0)
    --n i
  for y = 3, 6 do
    for i = 0, 2 do
      g:led(1 + i * 2, y, 4)
    end
  end
  g:led(2, 3, 4)
  --s
  for x = 7, 10 do
    for i = 0, 1 do
      g:led(x, 3 + i * 3, 4)
    end
  end
  g:led(8, 4, 4)
  g:led(9, 5, 4)
  -- h o
  for y = 3, 6 do
    for i = 0, 1 do
      g:led(12 + i * 2, y, 4)
    end
    g:led(16, y, 4)
  end
  for x = 1, 2 do
    for i = 0, 1 do
      g:led(x + 13, 3 + i * 3, 4)
    end
  end
  g:led(13, 4, 4)

  g:refresh()
end

return grd_one
