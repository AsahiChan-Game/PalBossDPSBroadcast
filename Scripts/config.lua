local config = {}

-- Master switch for all boss damage recording and chat reports.
-- Changing this setting requires a server restart.
config.EnableDPSRecording = true

-- Chat report language. "auto" follows Palworld's current language when it
-- can be detected. You may also use any supported code such as en, zh-CN,
-- zh-TW, ja, fr, it, de, es-ES, pt-BR, ru, ko, id, es-419, th, tr, vi or pl.
config.Language = "auto"

-- Prefer the optional C++ collector when it is installed and ABI-compatible.
-- The native layer aggregates high-frequency hits before Lua sees them.
-- Keep RequireNativeCollector false so an incompatible/missing DLL falls back
-- to the proven Lua hook instead of silently disabling all damage recording.
config.PreferNativeCollector = true
config.RequireNativeCollector = false
config.NativeDrainIntervalMilliseconds = 50
config.NativeMaxBucketsPerDrain = 512

-- Single-player/host distribution switch. When true, chat reports are sent
-- only to the local player. The dedicated-server package keeps this false.
config.LocalOnlyMessages = false

-- Prefix used for every participant-only system chat message.
config.MessagePrefix = "[BossDPS]"

-- Optional components. Compact, low-noise output is the public default.
-- Change a switch, then restart the server once to apply it.
config.BroadcastStart = true
config.EnableProgressReports = false
config.EnableDetailedAwards = false
-- Show a final breakdown for the player character and every individual Pal.
-- This is the easiest switch for users who want per-Pal damage, share and DPS.
-- Dedicated servers keep it off by default to avoid extra chat lines.
config.EnablePalDamageBreakdown = false
-- Legacy fallback, used only if EnablePalDamageBreakdown is absent.
-- Explicit true/false in the new switch takes priority.
config.EnableTeamDetails = false
-- "personal": only your character and your Pals, sent only to you.
-- "team": all contributing guild members and their Pals, shared with them.
-- Percentages use your own total in personal mode, guild total in team mode.
-- Old configs without this setting keep the original team report.
config.PalDamageBreakdownScope = "personal"
config.MarkTopAsMVP = true

-- Maximum number of contributors shown in the final ranking.
config.MaxResultRows = 10

-- When EnableProgressReports is true, publish a live report every N seconds.
-- Current DPS is damage dealt inside the latest report window divided by
-- the actual window duration. Set to 0 to disable live reports.
config.ProgressIntervalSeconds = 10
config.ProgressMaxRows = 4

-- Maximum player-character/Pal source rows in the damage breakdown.
config.TeamDetailMaxRows = 12

-- Fun battle comments: progress comments only appear when a threshold is met;
-- every final result receives one comment when enabled. Changing this setting
-- requires a server restart.
config.EnableFunComments = false

-- Delay between result lines to avoid flooding the chat feed.
config.MessageIntervalMilliseconds = 1000

-- End and publish a partial session after this many seconds without damage.
-- Set to 0 to disable inactivity cleanup.
config.InactivityTimeoutSeconds = 60
config.CleanupIntervalSeconds = 10

-- Include per-player DPS in addition to damage and percentage.
config.ShowDPS = true

-- Safety/back-pressure controls. Events above MaxPendingEvents are dropped;
-- each game-thread drain processes at most MaxEventsPerDrain events.
config.MaxPendingEvents = 8192
config.MaxEventsPerDrain = 256
config.MaxSourceOwnerCacheEntries = 2048

-- Cache targets already confirmed to be ordinary non-boss actors. This keeps
-- global damage events from repeatedly running player/Pal ownership queries.
config.NonBossCacheSeconds = 60

-- Known multi-actor bosses. All listed parts share one encounter total. A
-- terminal part ends the whole encounter; non-terminal part deaths do not.
-- Parts with a common Owner/attach parent are matched first. The short join
-- window is only a fallback for builds where that relationship is unavailable.
config.CompositePartJoinWindowSeconds = 15
config.CompositeBossParts = {
    YakushimaBoss002_B = { group = "YakushimaBoss002", terminal = true },
    YakushimaBoss002_Head = { group = "YakushimaBoss002" },
    YakushimaBoss002_L = { group = "YakushimaBoss002" },
    YakushimaBoss002_R = { group = "YakushimaBoss002" },
}

-- Log every accepted damage event. Keep false on a live server.
config.TraceDamage = false

-- If reflected boss flags are unavailable, use these actor-name fragments.
config.UseBossNameFallback = true
config.BossNamePatterns = {
    "boss",
    "raid",
    "gym_",
}

-- Localized fallback names keyed by a normalized character/actor id. The mod
-- first asks Palworld's localization database, then checks this table, and
-- never displays a long /Game/... object path.
config.BossNameOverrides = {
    Suzaku = { en = "Suzaku", ["zh-CN"] = "朱雀", ["zh-TW"] = "朱雀" },
    Suzaku_BOSS = { en = "Suzaku", ["zh-CN"] = "朱雀", ["zh-TW"] = "朱雀" },
    DarkScorpion = { en = "Dark Scorpion", ["zh-CN"] = "冥铠蝎", ["zh-TW"] = "冥鎧蠍" },
    DarkScorpion_BOSS = { en = "Dark Scorpion", ["zh-CN"] = "冥铠蝎", ["zh-TW"] = "冥鎧蠍" },
}

-- Optional localized species-name fallbacks for owned Pals. Player-assigned
-- nicknames still take priority over these names.
config.PalNameOverrides = {
    PinkCat = { en = "Cattiva", ["zh-CN"] = "捣蛋猫", ["zh-TW"] = "搗蛋貓" },
}

return config
