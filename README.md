# BossDPSBroadcast v2.1

Palworld 1.0 专用服务器 UE4SS Lua Boss 团队伤害统计插件。

## 当前功能

- Boss 第一次受到可归属给玩家的 `ActualDamage` 时自动开始。
- 玩家帕鲁的伤害归属训练家，同时单独记录具体帕鲁输出。
- 每个 Boss 实例独立统计；同一房间的多个 Boss 不会串伤害。
- 击杀、捕捉和 300 秒无伤害均可结束会话；1.0 捕捉使用 `PalCaptureJudgeObject:OnCaptureSuccess`。
- 每 10 秒发送两行实时战况：累计伤害、最近窗口当前 DPS、个人累计占比和个人当前 DPS。
- 结算包含团队伤害/团队 DPS、最高伤害队伍、最高伤害玩家角色、最高伤害帕鲁和玩家综合排名。
- 帕鲁显示名优先使用玩家自定义昵称；若昵称不同于物种名，显示为 `昵称（物种中文名）`。
- Boss 名优先使用游戏本地化数据库和中文覆盖表，绝不显示完整 `/Game/...` UObject 路径。
- 所有游戏内消息只发给本场造成过有效伤害的玩家；旁观者和其他在线玩家不会收到。

## 统计口径

- 团队总伤害：本场所有已归属 `ActualDamage` 的总和。
- 玩家综合伤害：玩家本人伤害加该玩家所有帕鲁伤害。
- 玩家角色伤害：只统计玩家本人武器/技能伤害。
- 帕鲁伤害：按帕鲁个体分别统计，再归属训练家。
- 队伍伤害：按 `PlayerState.GuildBelongTo` 聚合；无公会时按单人小队处理。
- 当前 DPS：最近一次 10 秒播报窗口内的伤害除以实际窗口秒数。
- 最终 DPS：整场累计伤害除以整场持续秒数。
- 并列规则：伤害相同时，有效命中次数多者优先，再按显示名稳定排序。

## 多 Boss 与手动命令设计

当前版本按 Boss 实例分别统计和结算。1.0 服务端二进制存在 `RaidBossAreaInstanceId`、`DungeonInstanceId`、`OnRaidBossBattleStart`、`OnRaidBossBattleFinish` 等可用于遭遇战分组的反射名称，但尚未确认完整类路径和运行时参数，因此没有用时间窗口强行合并，避免把地图上另一队的战斗混入。

`!DPS` 手动开关可通过当前服务器已确认加载的 `/Script/Pal.PalPlayerController:EnterChat_Receive` 读取 `FPalChatMessage` 实现，而且 Controller 可直接确定发起玩家。推荐后续语义：发起者第一次输入建立房间会话；其首个 Boss 命中作为种子；攻击该 Boss 的玩家加入会话；已加入玩家攻击的新 Boss 并入同一会话；只有发起者再次输入可结束。该功能尚未进入 v2.1。服务器现有 `AdminCommands` 同样占用 `!` 前缀，因此实现前还需处理命令注册冲突。

## 安全结构

伤害、死亡和捕捉钩子只复制临时事件字段，不执行 UObject/UFunction 查询或聊天发送。事件进入有界 FIFO 后，通过 `ExecuteInGameThread` 在游戏线程分批处理。聊天使用 `ExecuteInGameThreadWithDelay` 串行泵送，并通过 `SendSystemToPlayerChat` 只发送给贡献者 UID 快照。

默认最多排队 8192 条伤害事件，每批最多处理 256 条。队列满时只丢弃额外伤害，死亡/捕捉结束事件仍保留。

## 配置

配置文件为 `Scripts/config.lua`：

- `ProgressIntervalSeconds`：实时战况间隔，默认 10 秒；设为 0 可关闭。
- `ProgressMaxRows`：实时战况最多展开人数，默认 4。
- `MaxResultRows`：最终排名最多展开人数。
- `MessageIntervalMilliseconds`：消息行间隔，默认 1000 毫秒。
- `InactivityTimeoutSeconds`：无伤害自动结束时间，默认 300 秒。
- `BossNameOverrides`、`PalNameOverrides`：中文名覆盖表。

## 离线验证

```powershell
cd "C:\Users\Administrator\Documents\帕鲁服务器\BossDPSBroadcast\tests"
.\run_all.ps1
```

测试覆盖 Lua 解析、UTF-8、危险 API、线程约束、临时参数生命周期、参与者隔离、击杀/捕捉/超时、多 Boss、滚动 DPS、队伍/玩家/帕鲁奖项、昵称优先级和 10,000 次伤害压力。
