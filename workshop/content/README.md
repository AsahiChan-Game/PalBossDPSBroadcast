# 不要查我DPS

Palworld 1.0 创意工坊 UE4SS Lua 模组。在单人世界中自动统计 Boss 战伤害，并通过游戏聊天窗口显示开战提示、团队 DPS、伤害占比和最终排名。

## 使用方法

1. 在创意工坊订阅本模组及依赖 `UE4SS Experimental (Palworld)`。
2. 启动游戏，在模组管理中确认两者均已启用。
3. 进入单人世界并攻击 Boss。第一次有效命中后会看到开始统计提示。
4. 击杀、捕捉或长时间无伤害时自动结算。

战报会自动跟随 Palworld 当前语言，支持官方全部 17 种语言。v1.2.0 起，单机版默认在最终结算中列出玩家角色和每只参战帕鲁的伤害、占比及 DPS，帕鲁优先显示玩家设置的昵称。趣味点评默认开启，但梗池仅在简体中文下生效，也可以在配置中关闭。

配置文件安装后位于：

```text
Palworld\Mods\NativeMods\UE4SS\Mods\PalBossDPSBroadcastSP\Scripts\config.lua
```

关闭全部点评：

```lua
config.EnableFunComments = false
```

逐只帕鲁伤害明细开关：

```lua
config.EnablePalDamageBreakdown = true
```

设为 `false` 可恢复更精简的最终战报。Boss 房间、塔主战和召唤 Boss 场地均可统计；玩家对战的 PvP 竞技场目前不支持。

## 运行边界

- 正式支持单人世界。
- 房主模式可以实验性使用，但只向本机房主显示战报。
- 作为远程联机客户端时无法取得服务端权威的全队真实伤害，因此不保证产生统计。
- 专用服务器请使用 GitHub 上的服务端版本，不要使用这个单机发行包。

项目主页：https://github.com/AsahiChan-Game/PalBossDPSBroadcast

本项目是非官方社区模组，与 Pocketpair 或 UE4SS 项目无隶属关系。
