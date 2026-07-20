local config = {}

-- Prefix used for every public system-chat line.
config.MessagePrefix = "[BossDPS]"

-- Maximum number of contributors shown in the final ranking.
config.MaxResultRows = 20

-- Delay between public result lines to avoid flooding the chat channel.
config.MessageIntervalMilliseconds = 350

-- If a boss receives no tracked player damage for this many seconds, publish
-- the partial result and close the session. Set to 0 to disable timeouts.
config.InactivityTimeoutSeconds = 300
config.CleanupIntervalSeconds = 30

-- Include per-player DPS in addition to damage and percentage.
config.ShowDPS = true

-- Log every accepted damage event to UE4SS.log. Keep this false normally.
config.TraceDamage = false

-- Optional display-name replacements keyed by Pal CharacterID.
-- Example: config.BossNameOverrides["PinkCat"] = "捣蛋猫"
config.BossNameOverrides = {}

-- Extra case-insensitive actor-name fragments treated as bosses if the
-- Palworld boss database/component check is unavailable.
config.BossNamePatterns = {
    "boss",
    "raid",
    "gym_",
}

return config
