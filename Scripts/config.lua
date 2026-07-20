local config = {}

-- Prefix used for every participant-only system chat message.
config.MessagePrefix = "[BossDPS]"

-- Announce as soon as the first tracked hit starts a boss session.
config.BroadcastStart = true

-- Maximum number of contributors shown in the final ranking.
config.MaxResultRows = 20

-- Publish a compact live report to participants every N seconds.
-- Current DPS is damage dealt inside the latest report window divided by
-- the actual window duration. Set to 0 to disable live reports.
config.ProgressIntervalSeconds = 10
config.ProgressMaxRows = 4

-- Delay between result lines to avoid flooding the chat feed.
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

-- Chinese fallback names keyed by a normalized character/actor id. The mod
-- first asks Palworld's localization database, then checks this table, and
-- never displays a long /Game/... object path.
config.BossNameOverrides = {
    Suzaku = "朱雀",
    Suzaku_BOSS = "朱雀",
    DarkScorpion = "冥铠蝎",
    DarkScorpion_BOSS = "冥铠蝎",
}

-- Optional Chinese species-name fallbacks for owned Pals. Player-assigned
-- nicknames still take priority over these names.
config.PalNameOverrides = {
    PinkCat = "捣蛋猫",
}

return config
