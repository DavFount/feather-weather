WeatherConfig = {
    -- Restart intentionally resets authority to these defaults. No persistence.
    clock = { mode = 'simulated', seconds = 21600, rate = 30, frozen = false, offsetSeconds = 0 },
    weather = { name = 'sunny', frozen = false, transitionSeconds = 15, snow = false },
    -- Weather interval is in simulation seconds, independent of clock freeze.
    weatherIntervalSeconds = 3600,
    forecastCount = 12,
    -- Ordered weighted choices; each row totals 100. Exceptional storms are opt-in.
    pattern = {
        sunny = { { name = 'sunny', weight = 60 }, { name = 'clouds', weight = 40 } },
        clouds = { { name = 'sunny', weight = 40 }, { name = 'clouds', weight = 30 }, { name = 'overcast', weight = 30 } },
        overcast = { { name = 'clouds', weight = 50 }, { name = 'rain', weight = 50 } },
        rain = { { name = 'overcast', weight = 60 }, { name = 'rain', weight = 40 } }
    },
    -- Initial release holds base wind constant; automatic wind/shear is deferred.
    wind = { direction = 0, speed = 0 },
    syncIntervalMs = 5000,
    tickIntervalMs = 250,
    clientIntervalMs = 250,
    maxCatchUpSteps = 64,
    conflictResources = { 'weathersync' },
    -- Server exports may mutate only for explicitly allowed invoking resources.
    trustedResources = {},
    -- Client scene overrides are disabled for callers until explicitly admitted.
    -- Example (integration is separate): ['feather-character'] = { maxPriority = 10 }
    overrideOwners = {},
    maxOverrides = 16,
    maxOverrideSeconds = 1800
}
