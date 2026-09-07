# PalBossDPSBroadcast v3.4.1

适用于 Palworld 1.0 专用服务器的 UE4SS Boss 伤害统计模组。v3.2 将高频伤害采集移到可选 C++ 聚合器；v3.3 新增 Palworld 官方全部 17 种语言的自动本地化；v3.4 增加直观的逐只帕鲁伤害明细开关。原生组件不可用时默认自动回退到纯 Lua。

服务端自动统计 Boss 战中的团队伤害、玩家综合伤害、占比和 DPS，并通过游戏聊天窗口向本场实际参与者发送结算。客户端无需安装。

仓库同时提供面向 Steam 创意工坊的单机发行包。单机版复用同一统计核心，但只向本机玩家发送聊天结果。构建和适用边界见 [Workshop 说明](workshop/README.md)。

## 默认效果

公开版默认采用低打扰模式。一场三人 Boss 战发送一行开始确认和四行最终结算：

```text
[BossDPS] 开始统计：Boss名称 已进入战斗
[BossDPS] 击杀播报：玩家A 的 帕鲁昵称 击败了 Boss名称｜用时 104秒｜团队DPS 8,185｜团队伤害 851,258｜3人
[BossDPS] MVP #1 玩家A｜伤害 600,904｜70.6%｜DPS 5,778
[BossDPS] #2 玩家B｜伤害 243,426｜28.6%｜DPS 2,341
[BossDPS] #3 玩家C｜伤害 6,928｜0.8%｜DPS 67
```

默认保留开始提示，方便确认模组已识别当前 Boss；10 秒实时播报、趣味点评、角色/帕鲁奖项和逐只帕鲁明细保持关闭。这些组件都可以在配置中独立开启。

## 功能

- Boss 首次受到可归属给玩家的有效伤害时自动开始统计。
- 普通 Boss 实例独立记录；月亮领主的身体、头部和双手合并为一场遭遇，同一时间存在的两个复合 Boss 仍按共同 Owner/父 Actor 隔离。
- 支持击杀、捕捉和长时间无伤害三种结算路径。
- 玩家本人和其所有帕鲁伤害合并为玩家综合排名。
- 内部仍按玩家角色和每只帕鲁分别记录，可选显示详细奖项和队内明细。
- 坐骑技能优先归属实际帕鲁；玩家武器伤害归属玩家角色。
- 帕鲁名称优先使用玩家自定义昵称。
- Boss 名优先使用游戏本地化名称，不显示冗长的 `/Game/...` 对象路径。
- 只向本场造成过伤害的玩家发送消息，旁观者和其他在线玩家不会收到。
- 所有收件人通过一个 `TArray<FGuid>` 批量发送，同一行不会按参与人数重复。
- 有界事件队列和游戏线程消息泵避免在原生伤害回调中调用 UObject/UFunction。
- 普通目标负缓存以及攻击来源、玩家和帕鲁元数据缓存减少多段技能产生的游戏线程反射查询。

## 环境要求

- Windows Palworld Dedicated Server 1.0
- UE4SS 3.0.1 `c2ac246`（原生采集器二进制的精确 ABI 目标）
- 服务端文件访问权限

Lua 回退路径仍可兼容其他 UE4SS 3.x，但随 Release 提供的 C++ DLL 只支持上面的精确版本。升级 Palworld 或 UE4SS 后应重新编译原生组件；不匹配时不要强行加载旧 DLL。

## 安装

1. 停止专用服务器。
2. 安装并确认 UE4SS 版本为 3.0.1 `c2ac246`。
3. 下载 Release 压缩包并解压。
4. 将压缩包中的两个文件夹一起复制到：

   ```text
   PalServer/Pal/Binaries/Win64/ue4ss/Mods/
   ```

5. 确认目录结构如下：

   ```text
   BossDPSNativeCollector/
   ├─ enabled.txt
   └─ dlls/
      └─ main.dll

   BossDPSBroadcast/
   ├─ enabled.txt
   └─ Scripts/
      ├─ main.lua
      ├─ config.lua
      └─ commentary.lua
   ```

6. 启动服务器，在 `ue4ss/UE4SS.log` 中搜索：

   ```text
   [BossDPSBroadcast] loaded v3.4.1; collector=native
   ```

若显示 `collector=lua-fallback`，统计仍可工作，但高频伤害仍走旧 Lua 路径。更新旧版本时，先备份自己的 `Scripts/config.lua`，再覆盖模组文件并重新应用配置。

## 配置

编辑 `BossDPSBroadcast/Scripts/config.lua`，保存后重启服务器一次。

想看自己每只帕鲁的贡献，使用以下配置；同公会其他人的详细来源不会发给你，团队综合排名仍正常显示：

```lua
config.EnablePalDamageBreakdown = true
config.PalDamageBreakdownScope = "personal"
```

将范围改为 `"team"` 可共享本场同公会的来源明细。个人模式占比按“本人角色 + 本人帕鲁”总伤害计算，公会模式按本场公会总伤害计算。v3.4.1 起，新开关显式设为 `false` 会关闭明细，即使旧开关仍为 `true`。

| 配置项 | 默认值 | 作用 |
|---|---:|---|
| `EnableDPSRecording` | `true` | 总开关；关闭后不记录也不发送任何战报 |
| `Language` | `"auto"` | 自动跟随 Palworld 语言，也可显式指定 `en`、`zh-CN`、`fr` 等 |
| `PreferNativeCollector` | `true` | 可用时优先使用 C++ 聚合采集 |
| `RequireNativeCollector` | `false` | 原生组件不可用时禁止 Lua 回退；一般不要开启 |
| `NativeDrainIntervalMilliseconds` | `50` | Lua 拉取原生聚合桶的间隔 |
| `NativeMaxBucketsPerDrain` | `512` | 单轮最多处理的聚合来源数量 |
| `LocalOnlyMessages` | `false` | 仅单机/房主发行包使用；只向本机参与者显示战报 |
| `BroadcastStart` | `true` | 首次有效命中时发送一行开始确认 |
| `EnableProgressReports` | `false` | 发送周期性实时战况 |
| `ProgressIntervalSeconds` | `10` | 实时战况间隔秒数 |
| `ProgressMaxRows` | `4` | 实时战况最多显示的玩家数 |
| `EnableFunComments` | `false` | 开启阈值点评和结算点评 |
| `EnableDetailedAwards` | `false` | 显示最高队伍、玩家角色和帕鲁奖项 |
| `EnablePalDamageBreakdown` | `false` | 显示玩家角色及每只帕鲁的伤害、占比和 DPS；创意工坊单机版默认 `true` |
| `EnableTeamDetails` | `false` | 仅在未设置 `EnablePalDamageBreakdown` 时作为旧版兼容开关 |
| `PalDamageBreakdownScope` | `"personal"` | 自己的角色和帕鲁明细仅发给本人；`"team"` 按公会共享。旧配置缺少此项时保持公会模式 |
| `TeamDetailMaxRows` | `12` | 队内明细最大行数 |
| `MarkTopAsMVP` | `true` | 将第一名标记为 `MVP #1` |
| `MaxResultRows` | `10` | 最终综合排名最大行数 |
| `ShowDPS` | `true` | 在最终排名中显示个人 DPS |
| `InactivityTimeoutSeconds` | `60` | 无伤害多久后结束未完成战斗 |
| `CleanupIntervalSeconds` | `10` | 超时检查间隔 |
| `MessageIntervalMilliseconds` | `1000` | 消息行之间的发送间隔 |
| `NonBossCacheSeconds` | `60` | 普通非 Boss 目标的快速判定缓存时间 |
| `CompositePartJoinWindowSeconds` | `15` | 无共同 Owner 信息时，复合 Boss 部位加入同场遭遇的兜底窗口 |

完整示例和预设见 [配置说明](docs/CONFIGURATION.md)。

## 统计口径

- 团队伤害：本场所有已归属 `ActualDamage` 的总和。
- 玩家综合伤害：玩家角色伤害加该玩家所有帕鲁伤害。
- 当前 DPS：最近一次实时播报窗口的伤害除以实际窗口时长。
- 最终 DPS：整场累计伤害除以战斗持续时间。
- 并列时按有效命中次数排序，再按显示名稳定排序。
- 普通多 Boss 按实际 Actor 实例分别统计；仅配置中明确列出的复合 Boss 部位会合并。

## 常见问题

### 完全没有战报

检查两个 `enabled.txt` 是否存在、`EnableDPSRecording` 是否为 `true`，并在 `UE4SS.log` 中确认出现 `loaded v3.4.1`。

### 别人的 Boss 战也发给我，或三个人重复三遍

这是旧版将单个 `FGuid` 错当成收件人数组导致的问题。v3.0.0 及以上版本使用一次调用中的完整 `TArray<FGuid>`。确认日志加载的是 v3.4.1，而不是旧版本。

### 月亮领主出现四次统计或战斗时明显卡顿

v3.4.0 会先在 C++ 中合并同一目标/来源的高频命中；Lua 再将身体、头部和左右部件合并成一场遭遇。确认日志显示 `collector=native`，并且只出现一次 `session started boss=月亮领主`。

### 怎么显示每一只帕鲁的伤害

在 `Scripts/config.lua` 中设置：

```lua
config.EnablePalDamageBreakdown = true
```

结算会额外列出玩家角色和每只参战帕鲁的伤害、占比及 DPS，帕鲁优先显示玩家设置的昵称。专用服务器默认关闭以减少聊天行数；创意工坊单机版从 v1.2.0 起默认开启。使用上方 `PalDamageBreakdownScope` 选择个人或公会范围；只显示造成过伤害的来源，截断行数不会改变占比分母。修改后需要重启游戏或服务器一次。

### 竞技场能否统计

如果“竞技场”指 Boss、塔主或召唤 Boss 的战斗场地，只要开战时出现“开始统计”，逐只帕鲁明细就会正常结算。如果指玩家对战的 PvP 竞技场，则当前 Boss 模式不会统计：模组会主动排除玩家拥有的目标，避免把对手帕鲁误判成世界 Boss。

### 捕捉后不立即结算

确认日志中出现：

```text
capture completion hook=/Script/Pal.PalUtility:PalCaptureSuccess
```

未识别的特殊捕捉流程仍会由无伤害超时兜底。

### 聊天窗口信息太多

使用默认服务端配置，或关闭 `BroadcastStart`、`EnableProgressReports`、`EnableFunComments`、`EnableDetailedAwards`、`EnablePalDamageBreakdown` 和 `EnableTeamDetails`。

## 测试

离线测试需要 Node.js/npm，测试过程不会连接或重启 PalServer：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run_all.ps1
```

覆盖范围见 [测试说明](docs/TESTING.md)。

## 许可与免责声明

项目采用 [MIT License](LICENSE)。本项目是非官方社区模组，与 Pocketpair 或 UE4SS 项目无隶属关系。使用服务端模组前请备份存档，并遵守服务器规则及相关软件许可。
