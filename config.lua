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
    -- Regional presentation enabled by default after representative gameplay acceptance.
    -- Set enabled=false for global-only presentation.
    regions = {
        enabled = true,
        sampleIntervalMs = 1000,
        settleMs = 2000,
        transitionSeconds = 10,
        rules = {
            {
                id = 'grizzlies_snow', priority = 100, zoneType = 10,
                -- Preserve natural mountain coverage; only translate precipitation.
                zones = { 'GrizzliesWest' }, autoSnow = false,
                weather = { rain='snow', drizzle='snowlight', shower='snowlight',
                    thunderstorm='blizzard', hurricane='whiteout' }
            },
            {
                id = 'new_austin_dry', priority = 50, zoneType = 10,
                zones = { 'GaptoothRidge', 'ChollaSprings', 'RioBravo', 'HennigansStead' }, autoSnow = false,
                weather = { rain='drizzle', shower='drizzle', thunderstorm='thunder',
                    hurricane='sandstorm', snow='overcast', snowlight='overcast',
                    blizzard='overcastdark', groundblizzard='overcastdark', whiteout='overcastdark', sleet='drizzle' }
            },
            {
                id = 'guarma_tropical', priority = 50, zoneType = 10,
                zones = { 'GuarmaD' }, autoSnow = false,
                weather = { snow='rain', snowlight='drizzle', blizzard='thunderstorm',
                    groundblizzard='rain', whiteout='thunderstorm', sleet='drizzle' }
            }
        }
    },
    syncIntervalMs = 5000,
    tickIntervalMs = 250,
    clientIntervalMs = 250,
    maxCatchUpSteps = 64,
    conflictResources = { 'weathersync' },
    -- Server exports may mutate only for explicitly allowed invoking resources.
    trustedResources = {},
    -- Character owns only local selection/creation presentation, never shared state.
    -- Admit other scene consumers explicitly; development test owners are not enabled here.
    overrideOwners = { ['feather-character'] = { maxPriority = 10 } },
    maxOverrides = 16,
    maxOverrideSeconds = 1800
}
