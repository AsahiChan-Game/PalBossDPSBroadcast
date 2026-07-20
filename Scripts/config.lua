local config = {}

-- Prefix used for every public server announcement.
config.MessagePrefix = "[BossDPS]"

-- Announce as soon as the first tracked hit starts a boss session.
config.BroadcastStart = true

-- Maximum number of contributors shown in the final ranking.
config.MaxResultRows = 20

-- Delay between public result lines to avoid flooding the screen/chat feed.
config.MessageIntervalMilliseconds = 1000

-- End and publish a partial session after this many seconds without damage.
-- Set to 0 to disable inactivity cleanup.
config.InactivityTimeoutSeconds = 300
config.CleanupIntervalSeconds = 30

-- Include per-player DPS in addition to damage and percentage.
config.ShowDPS = true

-- Safety/back-pressure controls. Events above MaxPendingEvents are dropped;
-- each game-thread drain processes at most MaxEventsPerDrain events.
config.MaxPendingEvents = 8192
config.MaxEventsPerDrain = 256

-- Log every accepted damage event. Keep false on a live server.
config.TraceDamage = false

-- If reflected boss flags are unavailable, use these actor-name fragments.
config.UseBossNameFallback = true
config.BossNamePatterns = {
    "boss",
    "raid",
    "gym_",
}

-- Optional display names keyed by the actor's short class/object name.
-- Example: config.BossNameOverrides["RaidBoss_Test"] = "测试首领"
config.BossNameOverrides = {}

return config
