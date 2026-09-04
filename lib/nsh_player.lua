-- nb player for nisho -  v2.0

local player = {
  is_active = false,
  active_routine = nil
}

if nb_player_refcounts == nil then
  nb_player_refcounts = {}
end

function player:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function player:add_params()
end

function player:note_on(note, vel, properties)
end

function player:note_off(note)
end

function player:pitch_bend(note, amount)
end

function player:modulate(val)
end

function player:modulate_voice(key, val)
end

function player:set_slew(slew)
end

function player:modulate_note(note, key, val)
end

function player:describe()
  return {
    name = "none",
    supports_bend = false,
    supports_slew = false,
    modulate_description = "unsupported",
    note_mod_targets = {},
    voice_mod_tarets = {}, -- note_mod_targets (optional list of targets for "note mod")
    params = {}, -- (optional list of parameter IDs for lookup use in scripts)
  }
end

function player:active()
  self.is_active = true
  self.active_routine = clock.run(function()
    clock.sleep(1)
    if self.is_active then
      self:delayed_active()
    end
    self.active_routine = nil
  end)
end

function player:delayed_active()
end

function player:inactive()
  self.is_active = false
  if self.active_routine ~= nil then
    clock.cancel(self.active_routine)
  end
end

function player:stop_all()
end

function player:play_note(note, vel, length, properties)
  self:note_on(note, vel, properties)
  clock.run(function()
    clock.sleep(length * clock.get_beat_sec())
    self:note_off(note)
  end)
end

----------------------------------- private -----------------------------------
function player:count_up()
  if self.name ~= nil then
    if nb_player_refcounts[self.name] == nil then
      nb_player_refcounts[self.name] = 1
      self:active()
    else
      nb_player_refcounts[self.name] = nb_player_refcounts[self.name] + 1
    end
  end
end

-- Private
function player:count_down()
  if self.name ~= nil then
    if nb_player_refcounts[self.name] ~= nil then
      nb_player_refcounts[self.name] = nb_player_refcounts[self.name] - 1
      if nb_player_refcounts[self.name] == 0 then
        nb_player_refcounts[self.name] = nil
        self:inactive()
      end
    end
  end
end

return player
