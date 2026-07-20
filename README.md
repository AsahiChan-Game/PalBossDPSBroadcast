# BossDPSBroadcast

Palworld 1.0 dedicated-server UE4SS Lua mod for automatic public Boss damage rankings.

## Behaviour

- Starts a session when an unowned Boss first receives real damage attributable to an online player.
- Attributes summoned Pal damage to its trainer/owner.
- Counts only `ActualDamage` dealt to that Boss instance.
- On Boss death, sends every connected player system-chat lines containing team damage, ranking, damage percentage, and DPS.
- Supports simultaneous Boss instances without mixing their statistics.
- Publishes a partial result after the configured inactivity timeout.

## Server install

Copy the `BossDPSBroadcast` directory to:

`PalServer/Pal/Binaries/Win64/ue4ss/Mods/BossDPSBroadcast`

The included `enabled.txt` makes UE4SS load the mod. No client installation is required.

Configuration is in `Scripts/config.lua`. Restart the dedicated server after changes.

## Verification

In `ue4ss/UE4SS.log`, startup should contain:

`[BossDPSBroadcast] loaded; damage and death hooks registered`

Then attack and defeat a field, tower, raid, or other database-marked Boss with two players. Everyone online should receive the start line and the same final ranking.

The repository also includes `tests/test_main.lua`, a mocked integration test covering automatic start, real-damage aggregation, Pal-to-owner attribution, final percentages, and per-player chat delivery.
