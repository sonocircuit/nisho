grd = {}

-- local variables
local trig_shortpress = false
local held_chord_edit = 0
local seq_hold = false
local set_trigs_end = false
local trigs_reset = false
local drmfm_copying = false
local drmfm_clipboard_contains = false
local chord_preview = false
local prev_chord_inversion = 1
local chordkeys_options = false
local strum_count_options = false
local strum_mode_options = false
local strum_skew_options = false
local copying_pattern = false
local pasting_pattern = false
local duplicating_pattern = false
local appending_pattern = false

-- grid keys and redraw
function grd.zero_keys(x, y, z)
  if (x < 4 or x > 13) and y < 4 then
    pattern_options(x, y, z)
  elseif x > 3 and x < 14 and y < 5 then
    pattern_slots(x, y, z)
  elseif (y == 5 or y == 6) then
    if trigs_config_view then
      event_trigs(x, y, z, 256)
    elseif y == 5 then
      pattern_trigs(x, z)
    end
  elseif x > 4 and x < 13 and y == 7 and z == 1 then
    pattern_keys(x - 4)
  elseif x > 4 and x < 13 and y == 8 and z == 1 then
    pattern_bank_page = x - 5
  elseif (x == 4 or x == 13) and (y == 7 or y == 8) then
    modifier_keys(x, y, z)
  elseif (x < 4 or x > 13) and y > 6 and y < 10 then
    voice_settings(x, y, z)
  elseif x < 3 and y > 9 and y < 12 then
    voice_options(x, y, z)
  elseif x > 14 and y > 9 and y < 12 then
    grid_options(x, y, z)
  elseif x > 3 and x < 14 and y > 8 and y < 12 then
    if kit_view then
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
    if voice[key_focus].keys_option == 1 then
      scale_grid(x, y, z)
    elseif voice[key_focus].keys_option == 2 then
      chrom_grid(x, y, z)
    elseif voice[key_focus].keys_option == 3 then
      chord_grid(x, y, z)
    elseif voice[key_focus].keys_option == 4 then
      drum_grid(x, y, z)
    end
  end
  dirtygrid = true
  screen.ping()
end

function grd.one_keys(x, y, z)
  if x > 4 and x < 13 and y == 1 and z == 1 then
    pattern_keys(x - 4)
  end
  if (x == 4 or x == 13) and y < 3 then
    modifier_keys(x, y, z, -6)
  end
  if x == 16 and y == 3 and z == 1 then
    pattern_view = not pattern_view
    dirtyscreen = true
  end
  if pattern_view then
    if (x < 4 or x > 13) and y < 4 then
      pattern_options(x, y, z)
    elseif x > 4 and x < 13 and y == 2 and z == 1 then
      pattern_bank_page = x - 5
    elseif x > 3 and x < 14 and y > 2 and y < 7 then
      pattern_slots(x, y, z, 2)
    elseif y == 8 then
      pattern_trigs(x, z)
    end
  else
    if (x < 4 or x > 13) and y < 3 then
      voice_settings(x, y, z, -6)
    elseif x > 3 and x < 14 and y > 1 and y < 5 then
      if trigs_config_view then
        event_trigs(x, y, z, 128)
      elseif kit_view then
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
      if voice[key_focus].keys_option == 1 then
        scale_grid(x, y, z, -8)
      elseif voice[key_focus].keys_option == 2 then
        chrom_grid(x, y, z, -8)
      elseif voice[key_focus].keys_option == 3 then
        chord_grid(x, y, z, -8)
      elseif voice[key_focus].keys_option == 4 then
        drum_grid(x, y, z, -8)
      end
    end
  end
  dirtygrid = true
  screen.ping()
end

function grd.zero_draw()
  g:all(0)
  pattern_options_draw()
  pattern_slot_draw()
  pattern_key_draw()
  mod_key_draw()
  if trigs_config_view then
    event_trigs_draw(256)
  else
    pattern_trigs_draw()
  end
  if kit_view then
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

function grd.one_draw()
  g:all(0)
  pattern_key_draw(-6)
  mod_key_draw(-6)
  if pattern_view then
    pattern_options_draw(128)
    pattern_slot_draw(2)
    pattern_trigs_draw(3)
  else
    if trigs_config_view then
      event_trigs_draw(128)
    elseif kit_view then
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

-------------------------- grid key functions --------------------------

function pattern_keys(i)
  if pattern_focus ~= i and num_rec_enabled() == 0 then
    pattern_focus = i
  end
  if not (pasting_pattern or copying_pattern) then
    if pattern_clear or (mod_a and mod_c) or (mod_b and mod_d) then
      if pattern[i].count > 0 then
        clear_active_notes(i)
        pattern[i]:clear()
        save_pattern_bank(i, p[i].bank)
      end
    else
      if pattern[i].play == 0 then
        local beat_sync = pattern[i].launch == 2 and 1 or (pattern[i].launch == 3 and bar_val or nil)
        if pattern[i].count == 0 then
          if appending_notes then
            paste_seq_pattern(i)
          else
            if num_rec_enabled() == 0 then
              local mode = pattern_rec_mode == "synced" and 1 or 2
              local dur = pattern_rec_mode ~= "free" and pattern[i].length or nil
              pattern[i]:set_rec(mode, dur, beat_sync)
              rec_enabled = true
            else
              pattern[i]:set_rec(0)
              pattern[i]:stop()
              rec_enabled = false
            end
          end
        else
          pattern[i]:start(beat_sync)
        end
      else
        if (pattern_overdub or mod_a or mod_b) then
          if pattern[i].rec == 1 then
            pattern[i]:set_rec(0)
            pattern[i]:undo()
            rec_enabled = false
          else
            pattern[i]:set_rec(1)     
            rec_enabled = true          
          end
        else
          if pattern[i].rec == 1 then
            pattern[i]:set_rec(0)
            rec_enabled = false
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

function pattern_slots(x, y, z, off) -- grid one: off = 2
  local y = off and (y - off) or y
  local bank = y + pattern_bank_page * 3
  if (x == 4 or x == 13) and y < 4 and z == 1 then
    for i = 1, 8 do
      p[i].load = bank
      if pattern[i].play == 0 then
        update_pattern_bank(i)
        if pattern_overdub and p[i].count[bank] > 0 then
          pattern[i]:start(bar_val)
        end
      else
        clock.run(function()
          clock.sync(bar_val)
          update_pattern_bank(i)
          pattern[i].step = 0
        end)
      end
    end
  elseif x == 13 and y == 4 and z == 1 then
    stop_all_patterns()
  else
    local i = x - 4
    if prgchange_view then
      if z == 1 then
        if y == 4 then
          p[i].prc_enabled = not p[i].prc_enabled
        else
          pattern_focus = i
          bank_focus = bank
          if pattern_clear then
            p[i].prc_num[bank] = 0
          end
        end
      end
    else
      if y < 4 then
        if autofocus then pageNum = 3 end
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
            show_message("clipboard   empty")
          elseif copying_pattern and not copy_src.state then
            copy_src.pattern = i
            copy_src.bank = bank
            copy_src.state = true
            show_message("pattern  "..copy_src.pattern.."  bank  "..copy_src.bank.."  selected")
          elseif duplicating_pattern then
            if p[i].count[bank] > 0 then
              append_pattern(i, bank, i, bank)
              show_message("doubled   pattern")
            else
              show_message("pattern   empty")
            end
          elseif pattern_clear or (mod_a and mod_c) or (mod_b and mod_d) then
            clear_pattern_bank(i, bank)
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
      elseif y == 4 and z == 1 then
        if pattern[i].play == 1 then
          p[i].stop = not p[i].stop
        else
          p[i].stop = false
        end
      end
    end
  end
  dirtyscreen = true
end

function pattern_options(x, y, z)
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
    page_redraw(3)
  elseif y == 1 and x == 15 and z == 1  then
    pattern_rec_mode = "synced"
    page_redraw(3)
  elseif y == 1 and x == 16 and z == 1  then
    pattern_rec_mode = "free"
    page_redraw(3)
  elseif y == 2 and x == 1 then
    pattern_clear = z == 1 and true or false
  elseif y == 2 and x == 2 then
    if not pattern_clear then
      duplicating_pattern = z == 1 and true or false
    end
  elseif y == 2 and x == 15 then
    if z == 1 then
      prgchange_view = not prgchange_view
      if prgchange_view then loading_page = false end
    end
    dirtyscreen = true
  elseif y == 2 and x == 16 then
    if z == 1 then
      loading_page = not loading_page
      if loading_page then prgchange_view = false end
    end
    dirtyscreen = true
  elseif y == 3 and (x == 1 or x == 16) then
    pattern_overdub = z == 1 and true or false
  end 
end

function pattern_trigs(x, z)
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
      if pattern_clear then
        for i = 1, 8 do
          if p[i].looping then
            clock.run(clear_pattern_loop, i, bar_val)
            p[i].looping = false
          end
        end
      end
    end
  else
    if held[pattern_focus].num == 1 and held[pattern_focus].max == 2 then
      if pattern_overdub then
        for i = 1, 8 do
          if pattern[i].play == 1 then
            clock.run(set_pattern_loop, i, pattern_focus)
          end
        end
      else
        clock.run(set_pattern_loop, pattern_focus, pattern_focus)
      end
    elseif p[pattern_focus].looping and held[pattern_focus].max < 2 then
      local dur = pattern[pattern_focus].launch == 2 and 1 or (pattern[pattern_focus].launch == 3 and bar_val or pattern[pattern_focus].quantize)
      clock.run(clear_pattern_loop, pattern_focus, dur)
      p[pattern_focus].looping = false
    elseif not (p[pattern_focus].looping or pattern_reset) and held[pattern_focus].max < 2 then
      clock.run(function()
        clock.sync(quant_rate)
        local segment = math.floor(pattern[pattern_focus].endpoint / 16)
        pattern[pattern_focus].step = segment * (x - 1)
      end)
    end
  end    
end

function event_trigs(x, y, z, grid)
  if grid == 256 then -- grid zero
    local i = x
    if y == 5 then
      trig_step_focus = x
      if set_trigs_end then
        if z == 1 then trigs[trigs_focus].step_max = i end
      else
        if z == 1 then
          if t_edit_clock ~= nil then
            clock.cancel(t_edit_clock)
          end
          trig_shortpress = true
          t_edit_clock = clock.run(function()
            clock.sleep(0.15)
            trigs_edit = true
            trig_shortpress = false
            dirtyscreen = true
          end)
        else
          if t_edit_clock ~= nil then
            clock.cancel(t_edit_clock)
          end
          if trig_shortpress then
            trigs[trigs_focus].pattern[i] = 1 - trigs[trigs_focus].pattern[i]
            trig_shortpress = false
          end
          trigs_edit = false
          dirtyscreen = true
        end
      end
    elseif y == 6 then
      if x == 1 then
        trigs_reset = z == 1 and true or false
      elseif x > 4 and x < 13 and z == 1 then
        trigs_focus = x - 4
        if trigs_reset then
          trigs[trigs_focus].pattern = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
          trigs[trigs_focus].prob = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
          trigs[trigs_focus].step_max = 16
        end
      elseif x == 16 then
        set_trigs_end = z == 1 and true or false
      end
    end
  else -- grid one
    if x > 3 and x < 14 and y > 2 and y < 5 then
      if x < 12 then
        local i = (x - 3) + (y - 3) * 8
        trig_step_focus = i
        if set_trigs_end then
          if z == 1 then trigs[trigs_focus].step_max = i end
        else
          if z == 1 then
            if t_edit_clock ~= nil then
              clock.cancel(t_edit_clock)
            end
            trig_shortpress = true
            t_edit_clock = clock.run(function()
              clock.sleep(0.15)
              trigs_edit = true
              trig_shortpress = false
              dirtyscreen = true
            end)
          else
            if t_edit_clock ~= nil then
              clock.cancel(t_edit_clock)
            end
            if trig_shortpress then
              trigs[trigs_focus].pattern[i] = 1 - trigs[trigs_focus].pattern[i]
              trig_shortpress = false
            end
            trigs_edit = false
            dirtyscreen = true
          end
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
          trigs[y - 2].prob = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
          trigs[y - 2].step_max = 16
        else
          trigs_focus = y - 2
        end
      end
    end
  end
end

function modifier_keys(x, y, z, off) -- grid one: off = -6
  local y = off and (y - off) or y
  if y == 7 then
    if x == 4 then
      mod_a = z == 1 and true or false
    elseif x == 13 then
      mod_b = z == 1 and true or false
    end
  elseif y == 8 then
    if x == 4 then
      mod_c = z == 1 and true or false
    elseif x == 13 then
      mod_d = z == 1 and true or false
    end
  end
  mod_chord = z == 1 and true or false
end

function voice_settings(x, y, z, off) -- grid one: off = -6
  local y = off and (y - off) or y
  if x < 4 or x > 13 then
    local i = x < 4 and x or x - 10
    if y == 7 and z == 1 then
      -- set interval_focus
      if chordkeys_options then
        if strum_focus ~= i then
          strum_focus = i
        else
          strum_focus = 0
        end
      elseif (mod_a or mod_b) then
        params:set("voice_mute_"..i, voice[i].mute and 1 or 2)
      elseif not voice[i].mute then
        if heldkey_int > 0 and i ~= int_focus then
          dont_panic(voice[int_focus].output)
        end
        int_focus = i
      end
    elseif y == 8 and z == 1 then
      -- set key focus
      if (mod_a or mod_b) then
        params:set("voice_mute_"..i, voice[i].mute and 1 or 2)
      elseif (mod_c or mod_d) then
        dont_panic(voice[i].output)
      elseif not voice[i].mute then
        if heldkey_key > 0 and i ~= key_focus then
          dont_panic(voice[key_focus].output)
        end
        key_focus = i
        voice_focus = i
        notes_held = {}
        dirtyscreen = true
      end
      if autofocus then pageNum = 2 end
    elseif y == 9 and z == 1 then
      if voice[i].keys_option < 3 then
        -- sustain notes
        if voice[i].sustain then
          for _, note in ipairs(voice[i].held_notes) do
            if voice[i].keys_option == 1 then
              local e = {t = eSCALE, i = i, root = root_oct, note = note, action = "note_off"} event(e)
            else
              local e = {t = eKEYS, i = i, note = note, action = "note_off"} event(e)
            end
          end
          voice[i].held_notes = {}
          voice[i].sustain = false
        else
          if i == key_focus and #notes_held > 0 then
            for idx, note in ipairs(notes_held) do
              voice[i].held_notes[idx] = note
            end
            voice[i].sustain = true
          end
        end
      end
    end
  end
end

function voice_options(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  if y == 10 and z == 1 then
    if x == 1 then
      params:set("keys_option_"..key_focus, 1)
    elseif x == 2 then
      params:set("keys_option_"..key_focus, 2)
    end
  elseif y == 11 and z == 1 then
    if x == 1 then
      params:set("keys_option_"..key_focus , 3)
    elseif x == 2 then
      params:set("keys_option_"..key_focus, 4)
    end
  end
end

function grid_options(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  if y == 10 then
    if x == 15 and z == 1 then
      key_quantize = not key_quantize
    elseif x == 16 then
      keyquant_edit = z == 1 and true or false
      dirtyscreen = true
    end
  elseif y == 11 then
    if x == 15 then
      if z == 1 then
        if kitmode_clock ~= nil then
          clock.cancel(kitmode_clock)
        end
        kitmode_clock = clock.run(function()
          clock.sleep(0.5)
          kit_view = not kit_view
        end)
      else
        if kitmode_clock ~= nil then
          clock.cancel(kitmode_clock)
        end
        if kit_view and kit_mode == 1 and autofocus then
          pageNum = 4
        end
        dirtyscreen = true
      end
    elseif x == 16 and z == 1 then
      key_repeat_view = not key_repeat_view
      if key_repeat_view then
        if seq_active then
          seq_active = false
        end
        sequencer_config = false
      else
        latch_key_repeat = false
        for i = 1, 4 do
          rk[i] = 0
        end
        set_repeat_rate(rk[1], rk[2], rk[3], rk[4])
      end
    end
  end
end

function kit_grid(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  --print("kitgrid", x, y, z)
  if x > 3 and x < 12 then
    if y > 9 and y < 12 then
      local note = ((x - 3) + (11 - y) * 8) + (kit_oct * 16) + 47 + kit_root_note
      local kit_voice = (note % 16) + 1
      drmfm_voice_focus = kit_voice
      heldkey_kit = heldkey_kit + (z * 2 - 1)
      if z == 1 then
        gkey[x][y].note = note
        table.insert(kit_held, note)
        if kit_edit_mutes then
          kit_mute.key[kit_voice] = not kit_mute.key[kit_voice]
          if kit_mute.active then
            local state = kit_mute.key[kit_voice] and 2 or 1
            params:set("kit_mute_key_"..kit_voice.."_group_"..kit_mute.focus, state)
          end
        elseif drmfm_copying then
          if drmfm_clipboard_contains then
            drmfm.paste_voice(kit_voice)
            show_message("pasted   drmFM   voice")
            drmfm_clipboard_contains = false
          else
            drmfm.copy_voice(kit_voice)
            show_message("copied   drmFM   voice   "..kit_voice)
            drmfm_clipboard_contains = true
          end
        elseif key_repeat then
          if heldkey_kit == 1 then
            trig_step = 0
          end
        else
          local e = {t = eKIT, i = 7, note = note} event(e)
        end
        page_redraw(4)
      else
        table.remove(kit_held, tab.key(kit_held, gkey[x][y].note))
      end
    elseif y == 9 and kit_edit_mutes then
      if x > 5 and x < 12 then
        if z == 1 then
          local group = x - 5
          if kit_mute.focus == group and kit_mute.active then
            clear_kit_mutes()
          else
            set_kit_mutes(group)
          end
        end
      end
    end
  elseif x == 12 then
    if y > 9 and y < 12 then
      gkey[x][y].active = z == 1 and true or false
      held_bank = held_bank + (z * 2 - 1)
      if held_bank < 1 then
        midi_bank = 0
        kit_edit_mutes = false
        drmfm_copying = false
        drmfm_clipboard_contains = false
      elseif held_bank == 1 then
        if y == 10 then
          midi_bank = z == 1 and 2 or 4
          if kit_mode == 1 then
            drmfm_copying = true
          end
        elseif y == 11 then
          midi_bank = z == 1 and 4 or 2
          if kit_mod_keys == 1 then
            kit_edit_mutes = true
          end
        end
      elseif held_bank == 2 then
        midi_bank = 6
      end
    end
  elseif x == 13 then
    gkey[x][y].active = z == 1 and true or false
    if kit_mod_keys == 2 then
      local n = y - 9 + midi_bank
      m[kit_midi_dev]:cc(mcc[n].num, z == 1 and mcc[n].max or mcc[n].min, kit_midi_ch)
    else
      if y == 10 then
        if z == 1 then
          run_drmf_perf()
        else
          cancel_drmf_perf()
        end
      elseif y == 11 then
        if kit_edit_mutes then
          clear_kit_mutes()
        else
          local state = z == 1 and true or false
          kit_mute_all = state
          if state then
            rytm_mute_all()
          else
            if kit_mute.active then
              set_kit_mutes(kit_mute.focus)
            else
              clear_kit_mutes()
            end
          end
        end
      end
    end
  end
end

function int_grid(x, y, z, off) -- grid one: off = -7
  local y = off and (y - off) or y
  -- detect key hold last key and root
  if (y == 9 or y == 11) and x > 7 and x < 9 and not kit_view then
    heldkey_int = heldkey_int + (z * 2 - 1)
  end
  -- detect key hold intervals
  if y == 10 and ((x > 3 and x < 8) or (x > 9 and x < 14)) and not kit_view then
    heldkey_int = heldkey_int + (z * 2 - 1)
  end
  -- interval keys
  if z == 1 then
    if y == 9 and x > 7 and x < 10 then
      if not kit_view then
        if not transposing then
          local e = {t = eSCALE, i = int_focus, root = root_oct, note = notes_home, action = "note_on"} event(e)
          gkey[x][y].note = notes_home
        else
          local e = {t = eTRSP_SCALE, interval = 0} event(e)
        end
        notes_last = notes_home
      end
    elseif y == 10 then
      -- interval decrease
      if x > 3 and x < 8 then
        local interval = x - 8
        local new_note = util.clamp(notes_last + interval, 1, #scale_notes)
        if not transposing then
          local e = {t = eSCALE, i = int_focus, root = root_oct, note = new_note, action = "note_on"} event(e)
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
          local e = {t = eSCALE, i = int_focus, root = root_oct, note = new_note, action = "note_on"} event(e)
          gkey[x][y].note = new_note
        else
          local e = {t = eTRSP_SCALE, interval = interval} event(e)
        end
        notes_last = new_note
      -- toggle key link
      elseif x > 7 and x < 10 then
        if (mod_a or mod_b or mod_c or mod_d) then
          transposing = not transposing
          page_redraw(1)
        else
          link_clock = clock.run(function()
            clock.sleep(1)
            key_link = not key_link
          end)
        end
      end
    elseif y == 11 then
      if x > 7 and x < 10 then
        if not transposing then
          if collecting_notes and not appending_notes then
            table.insert(collected_notes, 0)
            page_redraw(1)
          elseif appending_notes and not collecting_notes then
            table.insert(seq_notes, 0)
            notes_added = true
          else
            local e = {t = eSCALE, i = int_focus, root = root_oct, note = notes_last, action = "note_on"} event(e)
            gkey[x][y].note = notes_last
          end
        else
          local octave = (#scale_intervals[current_scale] - 1) * (x - 8 == 0 and -1 or 1)
          local e = {t = eTRSP_SCALE, interval = octave} event(e)
        end
      end
    end
  elseif z == 0 then
    if not (kit_view or trigs_config_view or transposing) then
      if y == 9 and x > 7 and x < 10 then
        local e = {t = eSCALE, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      elseif y == 10 then
        if x > 3 and x < 8 then
          local e = {t = eSCALE, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
        elseif x > 7 and x < 10 then
          if link_clock ~= nil then clock.cancel(link_clock) end
        elseif x > 9 and x < 14 then
          local e = {t = eSCALE, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
        end
      elseif y == 11 and x > 7 and x < 10 then
        local e = {t = eSCALE, i = int_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      end
    end
  end
end

function seq_settings(x, z)
  if x > 4 and x < 13 and z == 1 then
    if not key_repeat_view then
      params:set("key_seq_rate", x - 4)
    end
  elseif x > 12 then
    if x == 15 and z == 1 then
      trigs_config_view = not trigs_config_view
    elseif x == 16 and z == 1 then
      if key_repeat_view then
        latch_key_repeat = not latch_key_repeat
        if not latch_key_repeat then
          for i = 1, 4 do
            rk[i] = 0
          end
          set_repeat_rate(rk[1], rk[2], rk[3], rk[4])
        end
        sequencer_config = false
      else
        sequencer_config = not sequencer_config
      end
    end
  end
end

function octave_options(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  --("octave options", x, y, z)
  if (mod_a or mod_b or mod_c or mod_d) and x == 1 and z == 1 then
    ansi_view = not ansi_view
  elseif y == 13 and x == 2 then
    -- channel aftertouch
    local at_coro = z == 1 and at_ramp_up or at_ramp_down
    if at[key_focus].timer ~= nil then
      clock.cancel(at[key_focus].timer)
    end
    at[key_focus].timer = clock.run(at_coro, key_focus)
  elseif y == 14 and x == 2 then
    -- modwheel aftertouch
    local mw_coro = z == 1 and mw_ramp_up or mw_ramp_down
    if mw[key_focus].timer ~= nil then
      clock.cancel(mw[key_focus].timer)
    end
    mw[key_focus].timer = clock.run(mw_coro, key_focus)
  elseif (y == 15 or y == 16) and x == 2 then
    -- pitchbend
    local pb_coro = z == 1 and pb_ramp_up or pb_ramp_down
    pb[key_focus].dir = y == 15 and 1 or -1
    if pb[key_focus].timer ~= nil then
      clock.cancel(pb[key_focus].timer)
    end
    pb[key_focus].timer = clock.run(pb_coro, key_focus, pb[key_focus].dir)
  end
  if ansi_view then
    local i = y - 12
    if x == 1 then
      gkey[x][y].active = z == 1 and true or false
      if z == 1 then
        table.insert(ansi_held, i)
        if key_repeat then
          if #ansi_held == 1 then
            trig_step = 0
          end
        else
          local e = {t = eANSI, i = i} event(e)
        end
      else
        table.remove(ansi_held, tab.key(ansi_held, i))
      end
    end
  else
    if x == 1 then
      if y == 13 and z == 1 then
        if kit_view then
          params:delta("kit_octaves", 1)
        else
          params:delta("interval_octaves_"..int_focus, 1)
        end
      elseif y == 14 and z == 1 then
        if kit_view then
          params:delta("kit_octaves", -1)
        else
          params:delta("interval_octaves_"..int_focus, -1)
        end
      elseif y == 15 and z == 1 then
        if chordkeys_options then
          params:delta("strum_octaves", 1)
        else
          params:delta("keys_octaves_"..key_focus, 1)
        end
      elseif y == 16 and z == 1 then
        if chordkeys_options then
          params:delta("strum_octaves", -1)
        else
          params:delta("keys_octaves_"..key_focus, -1)
        end
      end
    end
  end
end

function event_options(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if x == 15 then
    if off then
      if y == 13 and z == 1 then
        trigs_config_view = not trigs_config_view
      elseif y == 16 and z == 1 then
        if key_repeat_view then
          latch_key_repeat = not latch_key_repeat
          if not latch_key_repeat then
            for i = 1, 4 do
              rk[i] = 0
            end
            set_repeat_rate(rk[1], rk[2], rk[3], rk[4])
          end
        end
      end
    else
      if voice[key_focus].keys_option == 3 and y == 16 then
        mod_chord = z == 1 and true or false
      end
    end
  elseif x == 16 then
    if key_repeat_view then
      if y > 12 then
        local slot = y - 12
        if latch_key_repeat then
          if z == 1 then
            rk[slot] = 1 - rk[slot]
          end
        else
          rk[slot] = z
        end
        set_repeat_rate(rk[1], rk[2], rk[3], rk[4])
      end
    else
      if y == 13 and z == 1 then
        seq_active = not seq_active
        seq_step = 0
        trig_step = 0
        if not seq_active then
          seq_notes = {}
        end
      elseif y == 14 then
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
      elseif y == 15 then
        appending_notes = z == 1 and true or false
        if z == 0 and notes_added then
          seq_notes = {table.unpack(prev_seq_notes)}
          notes_added = false
          if seq_step >= #prev_seq_notes then
            seq_step = 0
          end
        end
      elseif y == 16 and z == 1 then
        seq_hold = not seq_hold
        if not seq_hold then
          seq_notes = {table.unpack(notes_held)}
        end
      end
    end
  end
end

function scale_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  heldkey_key = heldkey_key + (z * 2 - 1)
  gkey[x][y].active = z == 1 and true or false
  if z == 1 then
    local octave = #scale_intervals[current_scale] - 1
    local note = (x - 2) + ((16 - y) * scalekeys_y) + (notes_oct_key[key_focus] + 3) * octave
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
    if voice[key_focus].sustain then
      if not tab.contains(voice[key_focus].held_notes, gkey[x][y].note) then
        -- remove notes
        if seq_active and not (collecting_notes or appending_notes or seq_hold) then
          table.remove(seq_notes, tab.key(notes_held, gkey[x][y].note))
        end
        if not (seq_active or key_repeat) or #seq_notes == 0 then
          local e = {t = eSCALE, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
        end
      end
    else
      -- remove notes
      if seq_active and not (collecting_notes or appending_notes or seq_hold) then
        table.remove(seq_notes, tab.key(notes_held, gkey[x][y].note))
      end
      if not (seq_active or key_repeat) or #seq_notes == 0 then
        local e = {t = eSCALE, i = key_focus, root = root_oct, note = gkey[x][y].note, action = "note_off"} event(e)
      end
    end
    table.remove(notes_held, tab.key(notes_held, gkey[x][y].note))
  end
end

function chrom_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  heldkey_key = heldkey_key + (z * 2 - 1)
  local root = (60 - 3) + 12 * notes_oct_key[key_focus]
  local note = (root + x * chromakeys_x) + chromakeys_y * (16 - y)
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
    if voice[key_focus].sustain then
      if not tab.contains(voice[key_focus].held_notes, gkey[x][y].note) then
        -- remove notes
        if seq_active and not (collecting_notes or appending_notes or seq_hold) then
          table.remove(seq_notes, tab.key(notes_held, gkey[x][y].note))
        end
        if not (seq_active or key_repeat) or #seq_notes == 0 then
          local e = {t = eKEYS, i = key_focus, note = gkey[x][y].note, action = "note_off"} event(e)
        end
      end
    else
      -- remove notes
      if seq_active and not (collecting_notes or appending_notes or seq_hold) then
        table.remove(seq_notes, tab.key(notes_held, gkey[x][y].note))
      end
      if not (seq_active or key_repeat) or #seq_notes == 0 then
        local e = {t = eKEYS, i = key_focus, note = gkey[x][y].note, action = "note_off"} event(e)
      end
    end
    table.remove(notes_held, tab.key(notes_held, gkey[x][y].note))
  end
end

function chord_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if y < 16 then
    heldkey_key = heldkey_key + (z * 2 - 1)
    gkey[x][y].active = z == 1 and true or false
    local i = x - 2
    local s = y - 12
    crd[i][s].key = z
    if z == 1 then
      last_chord_root = i
      play_chord(i)
    elseif z == 0 then
      if heldkey_key == 0 then
        clear_chord()
        if not (seq_hold or appending_notes) then
          seq_notes = {}
        end
      end
    end
  elseif y == 16 then
    if x == 3 and z == 1 then
      chord_play = not chord_play
    elseif x == 4 and z == 1 then
      chord_strum = not chord_strum
      if not chord_strum and strum_clock ~= nil then
        clock.cancel(strum_clock)
      end
    elseif x == 5 then
      strum_count_options = z == 1 and true or false
      chordkeys_options = z == 1 and true or false
    elseif x == 6 then
      strum_mode_options = z == 1 and true or false
      chordkeys_options = z == 1 and true or false
    elseif x == 7 then
      strum_skew_options = z == 1 and true or false
      chordkeys_options = z == 1 and true or false
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
    elseif strum_skew_options then
      if (x == 9 or x == 10) then
        gkey[x][y].active = z == 1 and true or false
        if z == 1 then
          params:delta("strm_rate", x == 9 and 1 or -1)
        end
      elseif x == 12 and z == 1 then
        params:delta("strm_skew", -1)
      elseif x == 13 and z == 1 then
        params:set("strm_skew", 0)
      elseif x == 14 and z == 1 then
        params:delta("strm_skew", 1)
      end
    else
      if (x == 8 or x == 9) then
        local s = x == 8 and 1 or - 1
        local d = z == 1 and (-1 * s) or (1 * s)
        gkey[x][y].active = z == 1 and true or false
        params:delta("keys_octaves_"..key_focus, d)
        if heldkey_key > 0 and chord_preview and z == 1 then
          play_chord()
        end
      elseif x == 10 then
        if z == 1 then
          if chord_preview_clock ~= nil then
            clock.cancel(chord_preview_clock)
          end
          chord_preview_clock = clock.run(function()
            clock.sleep(0.5)
            chord_preview = not chord_preview
          end)
        else
          if chord_preview_clock ~= nil then
            clock.cancel(chord_preview_clock)
          end
        end
      elseif x > 10 and x < 15 then
        held_chord_edit = held_chord_edit + (z * 2 - 1)
        if z == 1 then
          if held_chord_edit < 1 then held_chord_edit = 1 end
          if mod_chord then
            prev_chord_inversion = x - 10
          end
          chord_inversion = x - 10
          if heldkey_key > 0 and chord_preview then
            play_chord()
          end
        else
          if held_chord_edit < 1 then
            chord_inversion = prev_chord_inversion
          end
        end
      end
    end
  end
end

function drum_grid(x, y, z, off) -- off -8 for grid one
  local y = off and (y - off) or y
  if y > 13 and x > 2 and x < 15 then
    heldkey_key = heldkey_key + (z * 2 - 1)
    local note = (drum_root_note + 12 * notes_oct_key[key_focus]) + (x - 3)
    local vel = y == 16 and drum_vel_hi or (y == 15 and drum_vel_mid or drum_vel_lo)
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
  elseif y == 13 and z == 1 then
    if kit_edit_mutes then
      local drm_voice = x - 2
      drm_mute.key[drm_voice] = not drm_mute.key[drm_voice]
      if kit_mute.active then
        local state = drm_mute.key[drm_voice] and 2 or 1
        params:set("drm_mute_key_"..drm_voice.."_group_"..kit_mute.focus, state)
      end
      if rytm_mode then
        local state = drm_mute.key[drm_voice] and 127 or 0
        m[midi_rytm_dev]:cc(94, state, drm_voice)
      end
    end
  end
end

-------------------------- grid draw functions --------------------------

function pattern_key_draw(off)
  local off = off and off or 0
  for i = 1, 8 do
    if pattern[i].rec == 1 and pattern[i].play == 1 then
      g:led(i + 4, 7 + off, pulse_key_fast)
    elseif pattern[i].rec_enabled == 1 then
      g:led(i + 4, 7 + off, 15)
    elseif pattern[i].play == 1 then
      g:led(i + 4, 7 + off, pattern[i].pulse_key and 15 or 12)
    elseif pattern[i].count > 0 then
      g:led(i + 4, 7 + off, 6)
    else
      g:led(i + 4, 7 + off, 2)
    end
    if off ~= 0 or pattern_view then
      g:led(i + 4, 8 + off , pattern_bank_page + 1 == i and 1 or 0)
    end
  end
end

function mod_key_draw(off)
  local off = off and off or 0
  g:led(4, 7 + off, mod_a and 15 or 0) 
  g:led(13, 7 + off, mod_b and 15 or 0)
  g:led(4, 8 + off, mod_c and 15 or 0) 
  g:led(13, 8 + off, mod_d and 15 or 0)
end

function grid_options_draw(off)
  local off = off and off or 0
  if hide_metronome then
    g:led(16, 10 + off, 3)
  else
    g:led(16, 10 + off, pulse_bar and 15 or (pulse_beat and 8 or 3)) -- Q flash
  end
  g:led(15, 10 + off, key_quantize and 8 or 4)
  g:led(15, 11 + off, kit_view and 10 or 4)
  g:led(16, 11 + off, key_repeat_view and 10 or 4)
end

function pattern_options_draw(grid)
  g:led(1, 1, (copying_pattern and not copy_src.state) and pulse_key_slow or (copy_src.state and 10 or 4))
  g:led(2, 1, pasting_pattern and 15 or 4)
  g:led(3, 1, appending_pattern and 15 or 4)
  g:led(1, 2, pattern_clear and pulse_key_slow or 4)
  g:led(2, 2, pattern_clear and pulse_key_slow or (duplicating_pattern and 15 or 4))
  g:led(1, 3, pattern_overdub and 15 or 4)

  g:led(14, 1, pattern_rec_mode == "queued" and 10 or 4)
  g:led(15, 1, pattern_rec_mode == "synced" and 10 or 4)
  g:led(16, 1, pattern_rec_mode == "free" and 10 or 4)
  g:led(15, 2, prgchange_view and 15 or 4)
  g:led(16, 2, loading_page and pulse_key_mid or 4)
  if grid == 128 then
    if hide_metronome then
      g:led(16, 3, 3)
    else
      g:led(16, 3, pulse_bar and 15 or (pulse_beat and 8 or 3)) -- Q flash
    end
  else
    g:led(16, 3, pattern_overdub and 15 or 4)
  end
end

function pattern_slot_draw(off)
  local off = off and off or 0
  local page = pattern_bank_page * 3
  if prgchange_view then
    for i = 1, 8 do
      for j = 1, 3 do
        local bank = j + page
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
      local dim = pattern_focus == i and 0 or -1
      for j = 1, 3 do
        g:led(i + 4, j + off, p[i].load == j + page and pulse_key_slow or (p[i].bank == j + page and (p[i].count[j + page] > 0 and 15 + dim or 4 + dim) or (p[i].count[j + page] > 0 and 8 + dim or 2 + dim)))
        if p[i].prc_pulse and p[i].bank == j + page then
          g:led(i + 4, j + off, 15)
        end
      end
      g:led(i + 4, 4 + off, p[i].stop and pulse_key_mid or 0)
    end
    -- stop all key
    g:led(13, 4 + off, stop_all and pulse_key_fast or 0)
  end
end

function event_trigs_draw(grid)
  if grid == 256 then
    for x = 1, 16 do
      if x <= trigs[trigs_focus].step_max then
        g:led(x, 5, (trig_step == x and (seq_active or key_repeat)) and 14 or (trigs[trigs_focus].pattern[x] == 1 and (math.ceil(trigs[trigs_focus].prob[x] * 5) + 1) or 1))
      end
    end
    for i = 1, 8 do
      g:led(i + 4, 6, trigs_focus == i and 4 or 0)
    end
    g:led(1, 6, trigs_reset and 15 or 1)
    g:led(16, 6, set_trigs_end and 15 or 1)
    g:led(15, 12, pulse_key_mid)
  elseif grid == 128 then
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
  end
end

function pattern_trigs_draw(off)
  local off = off and off or 0
  if p[pattern_focus].looping then
    local min = p[pattern_focus].step_min_viz[p[pattern_focus].bank]
    local max = p[pattern_focus].step_max_viz[p[pattern_focus].bank]
    for i = min, max do
      g:led(i, 5 + off, 4)
    end
  end
  if pattern[pattern_focus].play == 1 and pattern[pattern_focus].endpoint > 0 then
    g:led(pattern[pattern_focus].position, 5 + off, pattern[pattern_focus].play == 1 and 10 or 0)
  end
end

function voice_settings_draw(off)
  local off = off and off or 0
  for i = 1, 3 do
    if chordkeys_options then
      g:led(i, 7 + off, (strum_focus > 0 and strum_focus == i) and 12 or 1)
      g:led(i + 13, 7 + off, (strum_focus > 0 and strum_focus == i + 3) and 12 or 1)
    else
      g:led(i, 7 + off, voice[i].mute and 2 or (int_focus == i and 10 or 4))
      g:led(i + 13, 7 + off, voice[i + 3].mute and 2 or (int_focus == i + 3 and 10 or 4))
    end
    g:led(i, 8 + off, voice[i].mute and 2 or (key_focus == i and 10 or 4))
    g:led(i + 13, 8 + off, voice[i + 3].mute and 2 or (key_focus == i + 3 and 10 or 4))
    if off == 0 then
      g:led(i, 9, voice[i].sustain and pulse_key_slow or 0)
      g:led(i + 13, 9, voice[i + 3].sustain and pulse_key_slow or 0)
    end
  end
end

function voice_options_draw(off)
  local off = off and off or 0
  g:led(1, 10 + off, voice[key_focus].keys_option == 1 and 8 or 4)
  g:led(2, 10 + off, voice[key_focus].keys_option == 2 and 8 or 4)
  g:led(1, 11 + off, voice[key_focus].keys_option == 3 and 8 or 4)
  g:led(2, 11 + off, voice[key_focus].keys_option == 4 and 8 or 4)
end

function kit_grid_draw(off)
  local off = off and off or 0
  for x = 1, 2 do
    for y = 10, 11 do
      local i = (x + (11 - y) * 8) % 16
      g:led(x + 3, y + off, gkey[x + 3][y].active and 15 or (kit_mute.key[i] and 0 or 2))
      g:led(x + 5, y + off, gkey[x + 5][y].active and 15 or (kit_mute.key[i + 2] and 0 or 4))
      g:led(x + 7, y + off, gkey[x + 7][y].active and 15 or (kit_mute.key[i + 4] and 0 or 2))
      g:led(x + 9, y + off, gkey[x + 9][y].active and 15 or (kit_mute.key[i + 6] and 0 or 4))
    end
    g:led(13, x + 9 + off, gkey[13][x + 9].active and 15 or 8)
  end
  g:led(12, 10 + off, drmfm_clipboard_contains and pulse_key_mid or ((kit_mod_keys == 2 and gkey[12][10].active) and 15 or 1))
  g:led(12, 11 + off, gkey[12][11].active and 15 or (kit_mute.active and pulse_key_mid or 1))
  if kit_edit_mutes then
    for i = 1, 6 do
      g:led(i + 5, 9 + off, (kit_mute.active and kit_mute.focus == i) and 15 or 6)
    end
  end
end

function int_grid_draw(off)
  local off = off and off or 0
  for i = 8, 9 do
    g:led(i, 9 + off, 6) -- home
    g:led(i, 10 + off, transposing and pulse_key_mid or (key_link and 2 or 0)) -- key link/transpose
    g:led(i, 11 + off, 10) -- interval 0
  end
  for i = 1, 4 do
    g:led(i + 3, 10 + off, 12 - i * 2) -- intervals dec
    g:led(i + 9, 10 + off, 2 + i * 2) -- intervals inc
  end
end

function octave_options_draw(off)
  local off = off and off or 0
  if ansi_view then
    for i = 1, 4 do
      g:led(1, i + 12 + off, ansi_trig[i] and 15 or 2)
    end
  else
    -- int/key octave
    if kit_view then
      g:led(1, 13 + off, 8 + kit_oct * 2)
      g:led(1, 14 + off, 8 - kit_oct * 2)
    else
      g:led(1, 13 + off, 8 + notes_oct_int[int_focus] * 2)
      g:led(1, 14 + off, 8 - notes_oct_int[int_focus] * 2)
    end
    -- key octave
    if chordkeys_options then
      g:led(1, 15 + off, 8 + chord_oct_shift * 2)
      g:led(1, 16 + off, 8 - chord_oct_shift * 2)
    else
      g:led(1, 15 + off, 8 + notes_oct_key[key_focus] * 2)
      g:led(1, 16 + off, 8 - notes_oct_key[key_focus] * 2)
    end
    -- afterfouch, modwheel, pitchbend
    g:led(2, 13 + off, math.floor(at[key_focus].value * 15))
    g:led(2, 14 + off, math.floor(mw[key_focus].value * 15))
    g:led(2, 15 + off, pb[key_focus].dir == 1 and math.floor(pb[key_focus].value * 15) or 0) -- pitchbend up
    g:led(2, 16 + off, pb[key_focus].dir == -1 and math.floor(pb[key_focus].value * 15) or 0) -- ptichbend down
  end
end

function event_options_draw(off)
  local off = off and off or 0
  if key_repeat_view then
    for i = 1, 4 do
      g:led(16, i + 12 + off, rk[i] == 1 and 15 or i * 2)
    end
    if off == 0 then
      g:led(16, 12, latch_key_repeat and pulse_key_slow or 0)
    else
      g:led(15, 8, latch_key_repeat and pulse_key_slow or 0)
    end
  else
    if off == 0 then
      g:led(16, 12, sequencer_config and pulse_key_slow or 0)
      if sequencer_config then
        for x = 1, 8 do
          g:led(x + 4, 12, params:get("key_seq_rate") == x and 6 or 1)
        end
      end
    end
    g:led(16, 13 + off, seq_active and 10 or 4)
    g:led(16, 14 + off, collecting_notes and 10 or 2)
    g:led(16, 15 + off, appending_notes and 10 or 2)
    g:led(16, 16 + off, seq_hold and 15 or 2)
  end
end

function keyboard_draw(off)
  local off = off and off or 0
  if voice[key_focus].keys_option == 1 then
    local octave = #scale_intervals[current_scale] - 1
    for i = 1, 12 do
      g:led(i + 2, 13 + off, gkey[i + 2][13].active and 15 or (((i + scalekeys_y * 3) % octave) == 1 and 10 or 2))
      g:led(i + 2, 14 + off, gkey[i + 2][14].active and 15 or (((i + scalekeys_y * 2) % octave) == 1 and 10 or 2))
      g:led(i + 2, 15 + off, gkey[i + 2][15].active and 15 or (((i + scalekeys_y) % octave) == 1 and 10 or 2))
      g:led(i + 2, 16 + off, gkey[i + 2][16].active and 15 or ((i % octave) == 1 and 10 or 2))
    end
  elseif voice[key_focus].keys_option == 2 then
    for x = 3, 14 do
      for y = 13, 16 do
        local note = (x * chromakeys_x - 3) + chromakeys_y * (16 - y)
        local st = note % 12
        if st == 0 or st == 2 or st == 4 or st == 5 or st == 7 or st == 9 or st == 11 then -- white keys
          g:led(x, y + off, gkey[x][y].active and 15 or 6)
        else
          g:led(x, y + off, gkey[x][y].active and 15 or 1)  -- black keys 
        end
      end
    end
  elseif voice[key_focus].keys_option == 3 then
    for x = 3, 14 do
      for y = 13, 15 do
        g:led(x, y + off, gkey[x][y].active and 15 or crd[x - 2][y - 12].viz)
      end
    end
    g:led(3, 16 + off, chord_play and 14 or 2)
    g:led(4, 16 + off, chord_strum and 10 or 2)
    g:led(5, 16 + off, strum_count_options and 15 or 0)
    g:led(6, 16 + off, strum_mode_options and 15 or 0)
    g:led(7, 16 + off, strum_skew_options and 15 or 0)
    if strum_count_options then
      for i = 4, 12 do
        g:led(i + 2, 16 + off, strum_count == i and 10 or 1)
      end
    elseif strum_mode_options then
      for i = 1, 5 do
        g:led(i + 9, 16 + off, strum_mode == i and 10 or 2)
      end
    elseif strum_skew_options then
      g:led(9, 16 + off, gkey[9][16].active and 15 or (strum_rate == 0.5 and 10 or 4))
      g:led(10, 16 + off, gkey[10][16].active and 15 or (strum_rate == 0.02 and 10 or 4))
      local val = util.clamp(math.floor(math.abs((strum_skew) / 2) + 4), 3, 15)
      g:led(12, 16 + off, strum_skew < 0 and val or 2)
      g:led(13, 16 + off, strum_skew == 0 and 10 or 2)
      g:led(14, 16 + off, strum_skew > 0 and val or 2)
    else
      g:led(8, 16 + off, gkey[8][16].active and 15 or 2)
      g:led(9, 16 + off, gkey[9][16].active and 15 or 2)
      g:led(10, 16 + off, chord_preview and (pulse_key_slow - 4) or 0)
      for i = 1, 4 do
        g:led(i + 10, 16 + off, chord_inversion == i and 8 or 2)
      end
    end
  elseif voice[key_focus].keys_option == 4 then
    for x = 3, 14 do
      for y = 14, 16 do
        g:led(x, y + off, gkey[x][y].active and 15 or 2 * (y - 14) + 2)
      end
    end
    for i = 1, 12 do
      if kit_edit_mutes then
        g:led(i + 2, 13 + off, drm_mute.key[i] and 0 or 6)
      else
        g:led(i + 2, 13 + off, drm_mute.key[i] and pulse_key_mid - 4 or 0)
      end
    end
  end 
end

return grd
