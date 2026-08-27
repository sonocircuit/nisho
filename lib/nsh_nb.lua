local player_lib = include 'nisho/lib/nsh_player'

if note_players == nil then
  note_players = {}
end

local nb = {
  players = note_players,
  voice_count = 1,
  none = player_lib:new()
}

nb_player_refcounts = {}

local function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0       
  local iter = function()
    i = i + 1
    if a[i] == nil then
      return nil
    else
      return a[i], t[a[i]]
    end
  end
  return iter
end

function nb:add_param(param_id, param_name)
  local initialized = false
  local names = {}
  for name, _ in pairs(note_players) do
    table.insert(names, name)
  end
  table.sort(names)
  table.insert(names, 1, "none")

  local names_inverted = tab.invert(names)
  params:add_option(param_id, param_name, names, 1)

  local string_param_id = param_id .. "_hidden_string"
  params:add_text(string_param_id, "_hidden string", "")
  params:hide(string_param_id)

  local p = params:lookup_param(param_id)

  function p:get_player()
    local name = params:get(string_param_id)
    if name == "none" then
      if p.player ~= nil then
        p.player:count_down()
      end
      p.player = nil
      return nb.none
    elseif p.player ~= nil and p.player.name == name then
      return p.player
    else
      if p.player ~= nil then
        p.player:count_down()
      end
      local ret = player_lib:new(nb.players[name])
      ret.name = name
      p.player = ret
      ret:count_up()
      return ret
    end
  end

  clock.run(function()
    clock.sleep(1)
    p:get_player()
    initialized = true
  end, p)

  params:set_action(string_param_id, function(name_param)
    local i = names_inverted[params:get(string_param_id)]
    if i ~= nil then
      params:set(param_id, i, true)
    end
    p:get_player()
  end)

  params:set_action(param_id, function()
    if not initialized then return end
    local i = p:get()
    params:set(string_param_id, names[i])
  end)

end

function nb:add_player_params()
  if params.lookup['nb_sentinel_param'] then
    return
  end
  for name, player in pairsByKeys(self:get_players()) do
    player:add_params()
  end
  params:add_binary('nb_sentinel_param', 'nb_sentinel_param')
  params:hide('nb_sentinel_param')
end

function nb:get_players()
  local ret = {}
  for k, v in pairs(self.players) do
    ret[k] = player_lib:new(v)
  end
  table.sort(ret)
  return ret
end

function nb:stop_all()
  for _, player in pairs(self:get_players()) do
    player:stop_all()
  end
end

return nb
