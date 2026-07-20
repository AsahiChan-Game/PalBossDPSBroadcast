# PalBossDPSBroadcast v3.0.0

适用于 Palworld 1.0 专用服务器的 UE4SS Lua Boss 伤害统计模组。

服务端自动统计 Boss 战中的团队伤害、玩家综合伤害、占比和 DPS，并通过游戏聊天窗口向本场实际参与者发送结算。客户端无需安装。

## 默认效果

公开版默认采用低打扰模式。一场三人 Boss 战只发送四行：

```text
[BossDPS] 击杀播报：玩家A 的 帕鲁昵称 击败了 Boss名称｜用时 104秒｜团队DPS 8,185｜团队伤害 851,258｜3人
[BossDPS] MVP #1 玩家A｜伤害 600,904｜70.6%｜DPS 5,778
[BossDPS] #2 玩家B｜伤害 243,426｜28.6%｜DPS 2,341
[BossDPS] #3 玩家C｜伤害 6,928｜0.8%｜DPS 67
```

默认关闭开始提示、10 秒实时播报、趣味点评、角色/帕鲁奖项和逐只帕鲁明细。这些组件都可以在配置中独立开启。

## 功能

- Boss 首次受到可归属给玩家的有效伤害时自动开始统计。
- 每个 Boss 实例独立记录，同一房间的多个 Boss 不会串数据。
- 支持击杀、捕捉和长时间无伤害三种结算路径。
- 玩家本人和其所有帕鲁伤害合并为玩家综合排名。
- 内部仍按玩家角色和每只帕鲁分别记录，可选显示详细奖项和队内明细。
- 坐骑技能优先归属实际帕鲁；玩家武器伤害归属玩家角色。
- 帕鲁名称优先使用玩家自定义昵称。
- Boss 名优先使用游戏本地化名称，不显示冗长的 `/Game/...` 对象路径。
- 只向本场造成过伤害的玩家发送消息，旁观者和其他在线玩家不会收到。
- 所有收件人通过一个 `TArray<FGuid>` 批量发送，同一行不会按参与人数重复。
- 有界事件队列和游戏线程消息泵避免在原生伤害回调中调用 UObject/UFunction。

## 环境要求

- Windows Palworld Dedicated Server 1.0
- UE4SS 3.x
- 服务端文件访问权限

Palworld 或 UE4SS 更新后，反射函数名称可能变化。更新游戏前建议备份当前可用版本。

## 安装

1. 停止专用服务器。
2. 安装并确认 UE4SS 可以正常加载 Lua 模组。
3. 下载 Release 压缩包并解压。
4. 将整个 `BossDPSBroadcast` 文件夹复制到：

   ```text
   PalServer/Pal/Binaries/Win64/ue4ss/Mods/BossDPSBroadcast
   ```

5. 确认目录结构如下：

   ```text
   BossDPSBroadcast/
   ├─ enabled.txt
   └─ Scripts/
      ├─ main.lua
      ├─ config.lua
      └─ commentary.lua
   ```

6. 启动服务器，在 `ue4ss/UE4SS.log` 中搜索：

   ```text
   [BossDPSBroadcast] loaded v3.0.0
   ```

更新旧版本时，先备份自己的 `Scripts/config.lua`，再覆盖模组文件并重新应用配置。

## 配置

编辑 `BossDPSBroadcast/Scripts/config.lua`，保存后重启服务器一次。

| 配置项 | 默认值 | 作用 |
|---|---:|---|
| `EnableDPSRecording` | `true` | 总开关；关闭后不记录也不发送任何战报 |
| `BroadcastStart` | `false` | 首次有效命中时发送开始提示 |
| `EnableProgressReports` | `false` | 发送周期性实时战况 |
| `ProgressIntervalSeconds` | `10` | 实时战况间隔秒数 |
| `ProgressMaxRows` | `4` | 实时战况最多显示的玩家数 |
| `EnableFunComments` | `false` | 开启阈值点评和结算点评 |
| `EnableDetailedAwards` | `false` | 显示最高队伍、玩家角色和帕鲁奖项 |
| `EnableTeamDetails` | `false` | 向队内发送玩家角色和逐只帕鲁明细 |
| `TeamDetailMaxRows` | `12` | 队内明细最大行数 |
| `MarkTopAsMVP` | `true` | 将第一名标记为 `MVP #1` |
| `MaxResultRows` | `10` | 最终综合排名最大行数 |
| `ShowDPS` | `true` | 在最终排名中显示个人 DPS |
| `InactivityTimeoutSeconds` | `60` | 无伤害多久后结束未完成战斗 |
| `CleanupIntervalSeconds` | `10` | 超时检查间隔 |
| `MessageIntervalMilliseconds` | `1000` | 消息行之间的发送间隔 |

完整示例和预设见 [配置说明](docs/CONFIGURATION.md)。

## 统计口径

- 团队伤害：本场所有已归属 `ActualDamage` 的总和。
- 玩家综合伤害：玩家角色伤害加该玩家所有帕鲁伤害。
- 当前 DPS：最近一次实时播报窗口的伤害除以实际窗口时长。
- 最终 DPS：整场累计伤害除以战斗持续时间。
- 并列时按有效命中次数排序，再按显示名稳定排序。
- 多 Boss 按实际 Actor 实例分别统计，不以时间窗口强制合并。

## 常见问题

### 完全没有战报

检查 `enabled.txt` 是否存在、`EnableDPSRecording` 是否为 `true`，并在 `UE4SS.log` 中确认出现 `loaded v3.0.0`。

### 别人的 Boss 战也发给我，或三个人重复三遍

这是旧版将单个 `FGuid` 错当成收件人数组导致的问题。v3.0.0 使用一次调用中的完整 `TArray<FGuid>`。确认日志加载的是 v3.0.0，而不是旧版本。

### 捕捉后不立即结算

确认日志中出现：

```text
capture completion hook=/Script/Pal.PalUtility:PalCaptureSuccess
```

未识别的特殊捕捉流程仍会由无伤害超时兜底。

### 聊天窗口信息太多

使用默认配置，或关闭 `BroadcastStart`、`EnableProgressReports`、`EnableFunComments`、`EnableDetailedAwards` 和 `EnableTeamDetails`。

## 测试

离线测试需要 Node.js/npm，测试过程不会连接或重启 PalServer：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run_all.ps1
```

覆盖范围见 [测试说明](docs/TESTING.md)。

## 许可与免责声明

项目采用 [MIT License](LICENSE)。本项目是非官方社区模组，与 Pocketpair 或 UE4SS 项目无隶属关系。使用服务端模组前请备份存档，并遵守服务器规则及相关软件许可。
