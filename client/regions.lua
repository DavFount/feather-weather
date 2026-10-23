-- Pure regional policy/state machine. Native observations are injected by main.lua.
WeatherRegions = {}
local R, W = WeatherRegions, Weather
R.__index = R
local snowy = { snow=true, snowlight=true, blizzard=true, groundblizzard=true, whiteout=true, sleet=true }

function R.Hash(value)
    if not W.Number(value,-2147483648,4294967295,true) then return nil end
    return value % 4294967296
end

function R.New(policy, hashName)
    assert(W.RegionalPolicy(policy), 'invalid regional policy')
    local self = setmetatable({policy=W.Copy(policy or {enabled=false}), rules={},
        current=nil, pending=nil, pendingSince=nil, revision=0, blendUntil=0,
        lastSample=nil, observation={}, status='disabled', error=nil},R)
    if not self.policy.enabled then return self end
    self.status = 'waiting_sample'
    for index, rule in ipairs(self.policy.rules) do
        local compiled = W.Copy(rule)
        compiled.order, compiled.hashes = index, {}
        for _, name in ipairs(rule.zones) do
            local hash = R.Hash(hashName(name))
            assert(hash and hash ~= 0, 'invalid configured zone hash: ' .. name)
            compiled.hashes[hash] = true
        end
        self.rules[#self.rules+1] = compiled
    end
    table.sort(self.rules, function(a,b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.order < b.order
    end)
    return self
end

function R:Observe(observation, now)
    if not self.policy.enabled then return end
    -- A native error or malformed observation fails back to shared presentation.
    if type(observation) ~= 'table' or R.Hash(observation[0]) == nil or R.Hash(observation[10]) == nil then
        if self.current then self.revision=self.revision+1; self.blendUntil=now+self.policy.transitionSeconds end
        self.current,self.pending,self.pendingSince,self.observation=nil,nil,nil,{}
        self.status,self.error='fallback','zone_probe_failed'
        return
    end
    self.observation = {[0]=R.Hash(observation[0]), [10]=R.Hash(observation[10])}
    self.error = nil
    local candidate
    for _, rule in ipairs(self.rules) do
        if rule.hashes[self.observation[rule.zoneType]] then candidate=rule; break end
    end
    local nextId = candidate and candidate.id or 'global'
    local currentId = self.current and self.current.id or 'global'
    if nextId == currentId then
        self.pending,self.pendingSince=nil,nil
        self.status='stable'
        return
    end
    if self.pending ~= nextId then self.pending,self.pendingSince=nextId,now end
    self.status='settling'
    if now-self.pendingSince >= self.policy.settleMs/1000 then
        self.current,self.pending,self.pendingSince=candidate,nil,nil
        self.revision=self.revision+1
        self.blendUntil=now+self.policy.transitionSeconds
        self.status='stable'
    end
end

function R:Sample(now, probe)
    if not self.policy.enabled then return end
    if self.lastSample and now-self.lastSample < self.policy.sampleIntervalMs/1000 then return end
    self.lastSample=now
    local ok, observation=pcall(probe)
    self:Observe(ok and observation or nil,now)
end

function R:Translate(name, snow)
    local rule = self.current
    -- Exactly one translation from authoritative input; never feed the result back.
    local translated = rule and rule.weather[name] or name
    return translated, snow or (rule ~= nil and rule.autoSnow and snowy[translated] == true)
end

function R:Context(now)
    return { enabled=self.policy.enabled, id=self.current and self.current.id or 'global',
        pending=self.pending, status=self.status, error=self.error, revision=self.revision,
        sampleAgeSeconds=self.lastSample and math.max(0,now-self.lastSample) or nil,
        observedZones=W.Copy(self.observation) }
end

function R:TransitionFloor(now) return math.max(0,self.blendUntil-now) end
