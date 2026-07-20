# 配置说明

配置文件位于 `Scripts/config.lua`。所有开关都在服务端读取，修改后重启服务器一次即可生效，客户端无需改动。

## 推荐预设

### 默认精简模式

适合公共服务器，只显示结算摘要、MVP 和玩家综合排名：

```lua
config.EnableDPSRecording = true
config.BroadcastStart = true
config.EnableProgressReports = false
config.EnableFunComments = false
config.EnableDetailedAwards = false
config.EnableTeamDetails = false
config.MarkTopAsMVP = true
```

三位玩家参与时，通常发送一行开始确认和四行最终结算。

### 实时战况模式

在默认配置基础上开启：

```lua
config.EnableProgressReports = true
config.ProgressIntervalSeconds = 10
config.ProgressMaxRows = 4
```

实时战况只发给已经对该 Boss 造成过伤害的玩家。石板 Boss 或长时间战斗可能产生较多消息，公共服务器建议保持关闭。

### 详细分析模式

在默认配置基础上开启：

```lua
config.EnableDetailedAwards = true
config.EnableTeamDetails = true
config.TeamDetailMaxRows = 12
```

`EnableDetailedAwards` 会增加最高伤害队伍、玩家角色和帕鲁奖项。`EnableTeamDetails` 会按队伍发送每个玩家角色和每只帕鲁的伤害来源明细。

### 完全关闭 DPS 模组

```lua
config.EnableDPSRecording = false
```

关闭后伤害、死亡和捕捉回调不会进入统计队列，也不会创建会话或发送消息。模组仍会被 UE4SS 加载，以便下次只改配置即可恢复。

## 名称覆盖

模组优先读取游戏本地化数据库。若某个 Boss 或帕鲁仍显示内部英文 ID，可以在配置末尾添加覆盖：

```lua
config.BossNameOverrides = {
    InternalBossId = "中文Boss名",
}

config.PalNameOverrides = {
    InternalPalId = "中文帕鲁名",
}
```

玩家为帕鲁设置的昵称始终优先于物种覆盖名。

## 安全参数

以下参数一般不需要修改：

```lua
config.MaxPendingEvents = 8192
config.MaxEventsPerDrain = 256
config.MaxSourceOwnerCacheEntries = 2048
config.NonBossCacheSeconds = 60
config.TraceDamage = false
```

队列满时仅丢弃额外伤害事件，结束事件仍会保留。`TraceDamage` 会产生大量日志，只建议在短时间诊断时开启。

## 复合 Boss 部位

月亮领主由多个可受伤 Actor 组成。默认配置会把这些部位合并成一场遭遇：

```lua
config.CompositePartJoinWindowSeconds = 15
config.CompositeBossParts = {
    YakushimaBoss002_B = { group = "YakushimaBoss002", terminal = true },
    YakushimaBoss002_Head = { group = "YakushimaBoss002" },
    YakushimaBoss002_L = { group = "YakushimaBoss002" },
    YakushimaBoss002_R = { group = "YakushimaBoss002" },
}
```

`terminal=true` 表示该主体死亡时结束整场遭遇；头部和双手提前被破坏不会单独结算。不要仅凭中文显示名添加部位，以免把两个同名 Boss 串到一起。
