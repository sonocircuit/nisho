--- timed pattern event recorder/player
-- @module lib.pattern
--
-- adapted by @sonocircuit for nisho

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new(id)
  local i = {}
  setmetatable(i, pattern)
  i.rec = 0
  i.play = 0
  i.overdub = 0
  i.prev_time = 0
  i.event = {}
  i.time = {}
  i.count = 0
  i.step = 0
  i.time_factor = 1
  i.clock_run = false
  i.synced = false
  i.sync_rate = 1
  i.sync_time = 1
  i.beat_clock = nil
  i.count_in = true
  i.count_in_num = 1
  i.bpm = nil
  i.flash = false
  i.id = id or "pattern"
  i.metro = metro.init(function() i:next_event() end, 1, 1)
  i.process = function(_) print("event") end
  return i
end

--- clear this pattern
function pattern:clear()
  self:stop()
  self.rec = 0
  self.play = 0
  self.overdub = 0
  self.prev_time = 0
  self.event = {}
  self.time = {}
  self.count = 0
  self.step = 0
  self.time_factor = 1
  self.count_in = true
  self.clock_run = false
  self.sync_rate = 1
  self.sync_time = 1
  self.beat_clock = nil
  self.bpm = nil
  print(self.id.." cleared")
end

--- adjust the time factor of this pattern.
function pattern:set_time_factor(f)
  self.time_factor = f or 1
end

--- start recording
function pattern:rec_start()
  print(self.id.." rec start")
  self.rec = 1
end

--- stop recording
function pattern:rec_stop()
  if self.rec == 1 then
    self.rec = 0
    if self.count ~= 0 then
      local t = self.prev_time
      self.prev_time = util.time()
      self.time[self.count] = self.prev_time - t
      --[[
      -- if predefined length then trim to the specified length
      if self.sync_rate > 1 then
        if self.count > 1 then
          local sum = 0
          for i = 1, #self.time - 1 do
            sum = sum + self.time[i]
            self.time[self.count] = self.sync_time - sum
          end
        else
          self.time[self.count] = self.sync_time
        end
      end
      --/
      ]]
      print(self.id.." rec stop")
    else
      print(self.id.." is empty")
    end
  end
end

--- watch
function pattern:watch(e)
  if self.rec == 1 then
    self:rec_event(e)
  elseif self.overdub == 1 then
    self:overdub_event(e)
  end
end

--- record event
function pattern:rec_event(e)
  local c = self.count + 1
  if c == 1 then
    self.prev_time = util.time()
    -- if not manual then time rec stop according to pattern_len and set variables
    if params:get("pattern_length") ~= 1 then
      clock.run(
        function()
          clock.sleep(pattern_len) -- wait according to pattern length settings
          self:rec_stop()
          self:start()
        end
      )
      local idx = params:get("pattern_length")
      self.sync_rate = options.length_value[idx] * 4
      self.sync_time = options.length_value[idx] * 4 * clock.get_beat_sec()
      self.bpm = clock.get_tempo()
      self.count_in = false
    else
      self.synced = false
    end
    --/
  else
    local t = self.prev_time
    self.prev_time = util.time()
    self.time[c - 1] = self.prev_time - t
  end
  self.count = c
  self.event[c] = e
end

--- add overdub event
function pattern:overdub_event(e)
  local c = self.step + 1
  local t = self.prev_time
  self.prev_time = util.time()
  local a = self.time[c - 1]
  self.time[c - 1] = self.prev_time - t
  table.insert(self.time, c, a - self.time[c - 1])
  table.insert(self.event, c, e)
  self.step = self.step + 1
  self.count = self.count + 1
end

--- stop this pattern
function pattern:stop()
  if self.play == 1 then
    self.play = 0
    self.overdub = 0
    self.metro:stop()
    self.step = 0
    self.count_in = true
    print(self.id.." stop")
    if self.beat_clock ~= nil then
      clock.cancel(self.beat_clock)
      print(self.id.." beatclock cancelled")
    end
    --self.beat_clock = nil
    self.clock_run = false
  end
end

--- beatsync coroutine
function beatsync(target)
  print(target.id.." clock run")
  local count = 0
  target.count_in = true
  while true do
    clock.sync(1)
    count = (count + 1) % target.sync_rate
    if count == 0 then
      target:first()
      --print(target.id.." sync at "..clock.get_beats())
    end
  end
end

--- start pattern
function pattern:start()
  if self.count > 0 then
    if self.synced then
      if self.count_in then
        clock.run(
          function()
            clock.sync(self.count_in_num)
            self:first()
            self.beat_clock = clock.run(beatsync, self)
            self.clock_run = true
            print(self.id.." start")
          end
        )
        self.play = 1
        dirtygrid = true
      else -- if not count_in (i.e. directly form pattern recording when pattern.synced == true)
        self:first()
        self.beat_clock = clock.run(beatsync, self)
        self.clock_run = true
        self.count_in = true
        dirtygrid = true
        print(self.id.." start")
      end
    else
      self:first()
      print(self.id.." start")
    end
  end
end

--- first event
function pattern:first()
  self.prev_time = util.time()
  self.process(self.event[1])
  self.play = 1
  self.step = 1
  self.metro.time = self.time[1] * self.time_factor -- set the time to elapse until the next event is called
  self.metro:start()
  self.flash = true
  dirtygrid = true
  clock.run(function() clock.sleep(0.1) self.flash = false dirtygrid = true end)
  --print(self.id.." step "..self.step)
end

--- process next event
function pattern:next_event()
  self.prev_time = util.time()
  if self.step == self.count then
    self:first()
  else
    self.step = self.step + 1
    --print(self.id.." step "..self.step)
    self.process(self.event[self.step])
    self.metro.time = self.time[self.step] * self.time_factor
    self.metro:start()
  end
end

--- set overdub
function pattern:set_overdub(s)
  if s == 1 and self.play == 1 and self.rec == 0 then
    self.overdub = 1
  else
    self.overdub = 0
  end
end

return pattern
