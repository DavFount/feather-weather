-- Pure authority model: no Cfx globals, native calls, IO, or remote handlers.
WeatherEngine = {}
local E, W = WeatherEngine, Weather
E.__index = E

function E.New(config, epoch, random)
    if not W.Config(config) then return W.Err('invalid_config', 'Invalid Weather configuration; check clock, weather, pattern, limits and owner policies.') end
    local self = setmetatable({ config=W.Copy(config), epoch=epoch, revision=1,
        clock=W.Copy(config.clock), weather=W.Copy(config.weather), wind=W.Copy(config.wind),
        pattern=W.Copy(config.pattern), progress=0, transitionId=1, transitionRemaining=0,
        generation=0, catchUpResets=0, random=random or math.random }, E)
    self:Rebuild()
    return W.Ok(self)
end

function E:Next(name)
    -- Manual exceptional weather may not have a graph row. Resume via configured default.
    local row = self.pattern[name] or self.pattern[self.config.weather.name]
    if not row then
        local keys = {}
        for key in pairs(self.pattern) do keys[#keys + 1] = key end
        table.sort(keys)
        row = self.pattern[keys[1]]
    end
    local roll, total = self.random(1, 100), 0
    for _, choice in ipairs(row) do
        total = total + choice.weight
        if roll <= total then return choice.name end
    end
    error('validated weighted graph produced no choice')
end

function E:Rebuild()
    self.queue = {}
    local name = self.weather.name
    for index = 1, self.config.forecastCount do
        name = self:Next(name)
        self.queue[index] = name
    end
    self.generation = self.generation + 1
end

function E:Advance(elapsed, wallSeconds)
    if not W.Number(elapsed, 0, math.huge) or elapsed == math.huge then return false end
    if not self.clock.frozen then
        if self.clock.mode == 'wall' then
            self.clock.seconds = (wallSeconds + self.clock.offsetSeconds) % W.WEEK
        else
            self.clock.seconds = (self.clock.seconds + elapsed * self.clock.rate) % W.WEEK
        end
    end
    self.transitionRemaining = math.max(0, self.transitionRemaining - elapsed)
    local changed = false
    if not self.weather.frozen then
        local rate, interval = W.Rate(self.clock), self.config.weatherIntervalSeconds
        self.progress = self.progress + elapsed * rate
        local steps = math.floor(self.progress / interval)
        self.progress = self.progress % interval
        if steps > self.config.maxCatchUpSteps then
            -- Explicit long-stall policy: hold current weather, reset its interval,
            -- rebuild a new bounded forecast, and expose the discontinuity.
            self.progress = 0
            self.catchUpResets = self.catchUpResets + 1
            self:Rebuild()
            changed = true
        else
            for _ = 1, steps do
                self.weather.name = table.remove(self.queue, 1)
                self.queue[#self.queue + 1] = self:Next(self.queue[#self.queue] or self.weather.name)
                self.transitionId = self.transitionId + 1
                changed = true
            end
            if steps > 0 then
                local age = rate > 0 and self.progress / rate or 0
                self.transitionRemaining = math.max(0, self.weather.transitionSeconds - age)
            end
        end
    end
    self.revision = self.revision + 1
    return changed
end

function E:Snapshot()
    return W.Copy({ epoch=self.epoch, revision=self.revision, clock=self.clock, weather=self.weather,
        wind=self.wind, transitionId=self.transitionId, transitionRemainingSeconds=self.transitionRemaining,
        scheduleGeneration=self.generation, catchUpResets=self.catchUpResets })
end

function E:Forecast(options)
    options = options or {}
    if not W.Fields(options, { count=true }) then return W.Err('invalid_input', 'Expected forecast options with optional count.') end
    local count = options.count or self.config.forecastCount
    if not W.Number(count, 1, self.config.forecastCount, true) then return W.Err('invalid_input', 'Forecast count exceeds configured bounds.') end
    local result, rate = {}, W.Rate(self.clock)
    for index = 1, count do
        local due = self.config.weatherIntervalSeconds * index - self.progress
        result[index] = { name=self.queue[index], dueSimulationSeconds=due }
        if not self.weather.frozen and rate > 0 then result[index].dueRealSeconds = due / rate end
    end
    return W.Ok({ epoch=self.epoch, revision=self.revision, generation=self.generation,
        paused=self.weather.frozen or rate == 0, basis='elapsed_simulation', entries=result })
end

function E:Mutate(action, spec)
    if action == 'clock' then
        local nextValue = W.Merge(self.clock, spec, W.Clock)
        if not nextValue then return W.Err('invalid_input', 'Invalid clock patch.') end
        self.clock = nextValue
        -- Progress/queued weather are retained; forecast dueRealSeconds uses the new rate.
    elseif action == 'weather' then
        local nextValue = W.Merge(self.weather, spec, W.Weather)
        if not nextValue then return W.Err('invalid_input', 'Invalid weather patch.') end
        self.weather, self.progress = nextValue, 0
        self.transitionId = self.transitionId + 1
        self.transitionRemaining = nextValue.transitionSeconds
        self:Rebuild()
    elseif action == 'wind' then
        local nextValue = W.Merge(self.wind, spec, W.Wind)
        if not nextValue then return W.Err('invalid_input', 'Invalid wind patch.') end
        self.wind = nextValue
    elseif action == 'pattern' then
        if not W.Pattern(spec) then return W.Err('invalid_input', 'Pattern must be a closed ordered weighted graph; each row totals 100.') end
        self.pattern, self.progress = W.Copy(spec), 0
        self:Rebuild()
    elseif action == 'reset' then
        if spec ~= nil and not W.Fields(spec, {}) then return W.Err('invalid_input', 'Reset takes no options; all domains reset.') end
        self.clock, self.weather, self.wind = W.Copy(self.config.clock), W.Copy(self.config.weather), W.Copy(self.config.wind)
        self.pattern, self.progress = W.Copy(self.config.pattern), 0
        self.transitionId = self.transitionId + 1
        self.transitionRemaining = self.weather.transitionSeconds
        self:Rebuild()
    else
        return W.Err('invalid_input', 'Unknown mutation.')
    end
    self.revision = self.revision + 1
    return W.Ok(self:Snapshot())
end
