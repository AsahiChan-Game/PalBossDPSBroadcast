# 配置说明

配置文件位于模组的 `Scripts/config.lua`。专用服务器版由管理员修改后重启服务器，客户端无需改动；创意工坊单机版修改后重启 Palworld。

## 推荐预设

### 默认精简模式

适合公共服务器，只显示结算摘要、MVP 和玩家综合排名：

```lua
config.EnableDPSRecording = true
config.Language = "auto"
config.BroadcastStart = true
config.EnableProgressReports = false
config.EnableFunComments = false
config.EnableDetailedAwards = false
config.EnablePalDamageBreakdown = false
config.EnableTeamDetails = false
config.MarkTopAsMVP = true
```

三位玩家参与时，通常发送一行开始确认和四行最终结算。

## 语言

`Language = "auto"` 会读取 Palworld 当前语言。也可以明确指定：

```lua
config.Language = "fr"
```

支持 `en`、`zh-CN`、`zh-TW`、`ja`、`fr`、`it`、`de`、`es-ES`、`pt-BR`、`ru`、`ko`、`id`、`es-419`、`th`、`tr`、`vi` 和 `pl`。无法识别时回退英语。趣味点评梗池仍仅提供简体中文；其他语言即使开启该开关，也只显示完整本地化的核心战报。

## 原生采集器

专用服务器 v3.2 推荐保持：

```lua
config.PreferNativeCollector = true
config.RequireNativeCollector = false
config.NativeDrainIntervalMilliseconds = 50
config.NativeMaxBucketsPerDrain = 512
```

正常启动日志应显示 `collector=native`。如果 DLL 缺失、UE4SS ABI 不匹配或伤害结构反射失败，会显示 `collector=lua-fallback`，并继续使用旧 Lua 钩子。`RequireNativeCollector=true` 只适合性能诊断；开启后原生组件不可用会直接禁止伤害统计。

`NativeDrainIntervalMilliseconds` 控制 Lua 多久拉取一次聚合结果，通常不应低于 50。`NativeMaxBucketsPerDrain` 限制的是不同目标/来源组合，不是命中次数；同一个多段技能的数百次命中通常只占一个桶。

### 实时战况模式

在默认配置基础上开启：

```lua
config.EnableProgressReports = true
config.ProgressIntervalSeconds = 10
config.ProgressMaxRows = 4
```

实时战况只发给已经对该 Boss 造成过伤害的玩家。石板 Boss 或长时间战斗可能产生较多消息，公共服务器建议保持关闭。

### 显示玩家角色和每只帕鲁的伤害

在默认配置基础上开启：

```lua
config.EnablePalDamageBreakdown = true
config.PalDamageBreakdownScope = "personal"
config.TeamDetailMaxRows = 12
```

结算时会额外列出玩家角色和每只参战帕鲁的伤害、队内占比与 DPS。帕鲁优先显示玩家设置的昵称，未设置昵称时显示物种名。专用服务器默认关闭，避免多人战斗产生太多聊天行；创意工坊单机版从 v1.2.0 起默认开启。

`PalDamageBreakdownScope` 决定明细范围：

| 值 | 包含的伤害来源 | 谁能收到 | 占比分母 |
|---|---|---|---|
| `"personal"` | 本人角色与本人每只参战帕鲁 | 本人 | 本人角色与帕鲁伤害之和 |
| `"team"` | 本场同公会参战者的角色与帕鲁 | 本场同公会参战者 | 本场公会总伤害 |

新配置默认 `"personal"`；旧配置缺少此项时保留原公会模式。房主的 `LocalOnlyMessages=true` 在两种范围下均只向本机发送。团队综合排名不受这个范围开关影响。

例如本人武器打了 600、帕鲁打了 400，个人明细分别是 60% 和 40%，即使同公会其他玩家也参战。仅显示造成过伤害的来源；`TeamDetailMaxRows` 限制显示行数，不减少伤害统计，超出时会提示还有多少来源未展开。

v3.4.1 / 单机 v1.2.1 起，`EnablePalDamageBreakdown` 的明确值优先；设为 `false` 即可关闭明细。仅当该配置项不存在时，才读取旧的 `EnableTeamDetails`。旧配置不必强制迁移；合并配置时建议删除旧开关，避免混淆。

如果还想显示最高伤害队伍、最高伤害玩家角色和最高伤害帕鲁等奖项，可以另外开启：

```lua
config.EnableDetailedAwards = true
```

### 竞技场边界

- Boss 房间、塔主战和召唤 Boss 场地：只要首次有效命中时出现“开始统计”，就支持玩家角色与逐只帕鲁的明细结算。
- 玩家对战的 PvP 竞技场：当前 Boss 模式不统计。模组会主动排除玩家拥有的受击目标，避免把对手帕鲁误判成世界 Boss。

### 完全关闭 DPS 模组

```lua
config.EnableDPSRecording = false
```

关闭后伤害、死亡和捕捉回调不会进入统计队列，也不会创建会话或发送消息。模组仍会被 UE4SS 加载，以便下次只改配置即可恢复。

## 名称覆盖

模组优先读取游戏本地化数据库。若某个 Boss 或帕鲁仍显示内部英文 ID，可以在配置末尾添加覆盖：

```lua
config.BossNameOverrides = {
    InternalBossId = {
        en = "English Boss Name",
        ["zh-CN"] = "中文Boss名",
    },
}

config.PalNameOverrides = {
    InternalPalId = {
        en = "English Pal Name",
        ["zh-CN"] = "中文帕鲁名",
    },
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

这些队列参数只约束纯 Lua 回退路径及死亡/捕捉事件。原生路径使用独立的聚合上限。队列满时仅丢弃额外伤害事件，结束事件仍会保留。`TraceDamage` 会产生大量日志，只建议在短时间诊断时开启。

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
