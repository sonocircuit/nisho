-- clocked pattern recorder library @alanza and @dan_derks
-- modified for nisho @sonocircuit

local reflection = {}
reflection.__index = reflection

--- constructor
function reflection.new(id)
  local p = {}
  setmetatable(p, reflection)
  p.id = id or 1
  p.rec = 0
  p.rec_enabled = 0
  p.play  = 0
  p.event = {}
  p.event_prev = {}
  p.step  = 0
  p.count = 0
  p.loop = 0
  p.clock = nil
  p.queued_rec  = nil
  p.rec_dur = nil
  p.quantize = 1/32
  p.endpoint = 0
  p.endpoint_init = 0
  p.step_min = 0
  p.step_max = 0
  p.position = 1
  p.manual_length = false
  p.start_callback = function() end
  p.step_callback = function() end
  p.end_of_loop_callback = function() end
  p.end_of_rec_callback = function() end
  p.end_callback = function() end
  p.process = function(_) end
  return p
end

local PPQN = 64 -- clock resolution in ppqn

local function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
end

--- copy data from one reflection to another
function reflection.copy(to, from)
  to.event = deep_copy(from.event)
  to.endpoint = from.endpoint
end

--- doubles the current loop
function reflection:double()
  local copy = deep_copy(self.event)
  for i = 1, self.endpoint do
    self.event[self.endpoint + i] = copy[i]
  end
  self.endpoint = self.endpoint * 2
  self.step_max = self.endpoint
end

--- start transport
function reflection:start(beat_sync)
  beat_sync = beat_sync or self.quantize
  if self.clock then
    clock.cancel(self.clock)
  end
  self.clock = clock.run(function()
    clock.sync(beat_sync)
    self:begin_playback()
  end)
end

--- stop transport
function reflection:stop()
  if self.clock then
    clock.cancel(self.clock)
  end
  self.clock = clock.run(function()
    clock.sync(self.quantize)
    self:end_playback()
  end)
end

--- enable / disable record head
-- rec 1 for recording, 2 for queued recording or 0 for not recording
-- dur (optional) duration in beats for recording
-- beat_sync (optional) sync recording start to beat value
function reflection:set_rec(rec, dur, beat_sync)
  self.rec = rec == 1 and 1 or 0
  self.rec_enabled = rec > 0 and 1 or 0
  if rec == 1 and self.play == 0 then
    self:start(beat_sync)
  end
  if rec == 1 and self.count > 0 then
    self.event_prev = {}
    self.event_prev = deep_copy(self.event)
  end
  if rec == 1 and dur then
    self.rec_dur = {count = dur, length = dur}
  end
  if rec == 2 then
    if self.count > 0 then
      local fn = self.start_callback
      self.start_callback = function()
        self:set_rec(1, dur)
        fn()
        self.start_callback = fn
      end
    else
      self.queued_rec = {queued = true, active = true, duration = dur}
    end
  end
  if rec == 0 then
    self.queued_rec = nil
    self:_clear_flags()
    self.end_of_rec_callback()
  end
end

--- enable / disable looping
function reflection:set_loop(loop)
  self.loop = loop == 0 and 0 or 1
end

--- quantize playback
function reflection:set_quantization(q)
  self.quantize = q == nil and 1/48 or q
end

--- set length in beats
function reflection:set_length(beats)
  if self.count > 0 then
    self.endpoint = beats * PPQN
    self.step_max = self.endpoint
  end
end

-- if temp event table contains data then replace event table
function reflection:undo()
  if next(self.event_prev) then
    self.event = deep_copy(self.event_prev)
  end
end

--- reset pattern
function reflection:clear()
  if self.clock then
    clock.cancel(self.clock)
  end
  self.rec = 0
  self.rec_enabled = 0
  self.play = 0
  self.event = {}
  self.event_prev = {}
  self.step = 0
  self.count = 0
  self.endpoint = 0
  self.endpoint_init = 0
  self.queued_rec = nil
  self.step_min = 0
  self.step_max = 0
  self.position = 1
  self.manual_length = false
end

--- watch
function reflection:watch(event)
  local step_one = false
  local offset = 1
  if self.queued_rec ~= nil then
    if self.queued_rec.queued then
      self:set_rec(1, self.queued_rec.duration, 1/64)
      self.queued_rec.queued = false
    end
    if self.queued_rec.active then
      step_one = true
    end
    offset = 2
  end
  if (self.rec == 1 and self.play == 1) or step_one then
    event._flag = true
    local s = step_one and 1 or math.floor(self.step + offset)
    if not self.event[s] then
      self.event[s] = {}
    end
    table.insert(self.event[s], event)
    self.count = self.count + 1
  end
end

function reflection:begin_playback()
  self.step = self.step_min
  self.play = 1
  self.start_callback()
  if self.queued_rec ~= nil then
    self.queued_rec.active = false
  end
  while self.play == 1 do
    clock.sync(1/PPQN)
    self.step = self.step + 1
    local q = math.floor(PPQN * self.quantize)
    if self.endpoint == 0 then
      -- don't process on first pass
      if self.rec_dur then
        self.rec_dur.count = self.rec_dur.count - 1/PPQN
        if self.rec_dur.count <= 0 then
          self.endpoint = self.rec_dur.length * PPQN
          self.endpoint_init = self.endpoint
          self.step_max = self.endpoint
          self:set_rec(0)
          self.rec_dur = nil
          -- if loop then start from beginning
          if self.loop == 1 then
            self.start_callback()
            self.step = self.step_min
            self.play = 1
          end
        end
      else
        if self.rec == 0 and self.count > 0 then
          self.endpoint = self.step
          self.endpoint_init = self.step
          self.manual_length = true
          self.step_max = self.step
          if self.loop == 1 then 
            self.step = self.step_min
            self:_clear_flags()
            self:start_callback()
          end
        end
      end
    -- if not first pass then do the quantization math
    else
      self:step_callback()
      if self.step % q ~= 1 then goto continue end
      for i = q - 1, 0, - 1 do
        if self.event[self.step - i] and next(self.event[self.step - i]) then
          for j = 1, #self.event[self.step - i] do
            local event = self.event[self.step - i][j]
            if not event._flag then self.process(event, self.id) end
          end
        end
      end
      ::continue::
      -- if overdubbing with dur as arg then cound down and end rec
      if self.rec_dur then
        self.rec_dur.count = self.rec_dur.count - 1/PPQN
        if self.rec_dur.count <= 0 then
          self:set_rec(0)
          self.rec_dur = nil
        end
      end
      -- if the endpoint is reached restart or stop playback
      if self.count > 0 and self.step >= self.step_max then
        self.end_of_loop_callback()
        if self.loop == 0 then
          self:end_playback()
        elseif self.loop == 1 then
          self.step = self.step_min
          self:_clear_flags()
          self:start_callback()
        end
      end
    end
  end
end

function reflection:end_playback()
  if self.clock then
    clock.cancel(self.clock)
  end
  self.play = 0
  self.rec = 0
  -- if first pass then set the endpoint if events were recorded
  if self.endpoint == 0 and next(self.event) then
    self.endpoint = self.step
    self.step_max = self.endpoint
  end
  self:_clear_flags()
  self.end_callback()
end

function reflection:_clear_flags()
  if self.endpoint == 0 then return end
  for i = 1, self.endpoint do
    local list = self.event[i]
    if list then
      for _, event in ipairs(list) do
        event._flag = nil
      end
    end
  end
end

return reflection
