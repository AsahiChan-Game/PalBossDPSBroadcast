# BossDPSBroadcast v2.4

Palworld 1.0 专用服务器 UE4SS Lua Boss 团队伤害统计插件。

## 当前功能

- Boss 第一次受到可归属给玩家的 `ActualDamage` 时自动开始。
- 玩家帕鲁的伤害归属训练家，同时按每只帕鲁个体单独记录；坐骑技能优先沿 `DamageCauser` 的 `Owner/Instigator` 链识别实际帕鲁，玩家武器仍归玩家角色。
- 每个 Boss 实例独立统计；同一房间的多个 Boss 不会串伤害。
- 击杀、捕捉和 300 秒无伤害均可结束会话；1.0 捕捉使用 `PalCaptureJudgeObject:OnCaptureSuccess`。
- 每 10 秒发送实时战况：累计伤害、最近窗口当前 DPS、个人累计占比和个人当前 DPS；达到爆发、百万伤害、输出翻倍或高占比等条件时额外穿插趣味点评，普通窗口不刷点评。
- 趣味点评使用实时模板数据，可动态带入公会名、玩家名、帕鲁昵称和 Boss 名；点评脚本不再硬编码服务器公会名。
- 结算包含团队伤害/团队 DPS、最高伤害玩家角色、最高伤害帕鲁和玩家综合排名，并且一定附带一条按秒杀、百万伤害、捕捉、失败等结果生成的趣味点评。
- 击杀结算首行使用聊天窗口醒目播报：最后一击玩家（或“训练家 的 帕鲁昵称”）、Boss 名、用时、团队 DPS 和团队伤害；仍只发送给本场贡献者。
- 多队参与时显示最高伤害队伍；只有一个队伍时直接以队伍名作为结算标题，不重复播报“最高伤害队伍”。
- 公共结算只发给本场贡献者；随后按队伍定向发送“队内私报”，列出该队每个玩家角色和每只帕鲁的伤害、队内占比和 DPS，其他队伍看不到。
- 帕鲁显示名优先使用玩家自定义昵称；若昵称不同于物种名，显示为 `昵称（物种中文名）`。
- 玩家、公会、Boss 和帕鲁名称统一进行严格 UTF-8 清理，并按完整 Unicode 字符截断，长中文昵称不会再因截断半个字符导致整条消息发送失败。
- Boss 名优先使用游戏本地化数据库和中文覆盖表，绝不显示完整 `/Game/...` UObject 路径。
- 所有游戏内消息只发给本场造成过有效伤害的玩家；旁观者和其他在线玩家不会收到。

## 统计口径

- 团队总伤害：本场所有已归属 `ActualDamage` 的总和。
- 玩家综合伤害：玩家本人伤害加该玩家所有帕鲁伤害。
- 玩家角色伤害：只统计玩家本人武器/技能伤害。
- 帕鲁伤害：按帕鲁个体分别统计，再归属训练家。
- 伤害来源优先级：`DamageCauser`、网络归属对象、伤害信息中的攻击者、顶层攻击者；技能实体只沿有限层数的 `Owner/Instigator` 链解析，避免把玩家武器误判为坐骑帕鲁。
- 队伍伤害：按 `PlayerState.GuildBelongTo` 聚合；无公会时按单人小队处理。
- 当前 DPS：最近一次 10 秒播报窗口内的伤害除以实际窗口秒数。
- 最终 DPS：整场累计伤害除以整场持续秒数。
- 并列规则：伤害相同时，有效命中次数多者优先，再按显示名稳定排序。

## 多 Boss 与手动命令设计

当前版本按 Boss 实例分别统计和结算。1.0 服务端二进制存在 `RaidBossAreaInstanceId`、`DungeonInstanceId`、`OnRaidBossBattleStart`、`OnRaidBossBattleFinish` 等可用于遭遇战分组的反射名称，但尚未确认完整类路径和运行时参数，因此没有用时间窗口强行合并，避免把地图上另一队的战斗混入。

`!DPS` 手动开关可通过当前服务器已确认加载的 `/Script/Pal.PalPlayerController:EnterChat_Receive` 读取 `FPalChatMessage` 实现，而且 Controller 可直接确定发起玩家。推荐后续语义：发起者第一次输入建立房间会话；其首个 Boss 命中作为种子；攻击该 Boss 的玩家加入会话；已加入玩家攻击的新 Boss 并入同一会话；只有发起者再次输入可结束。该功能尚未进入 v2.4。服务器现有 `AdminCommands` 同样占用 `!` 前缀，因此实现前还需处理命令注册冲突。

## 安全结构

伤害、死亡和捕捉钩子只复制临时事件字段，不执行 UObject/UFunction 查询或聊天发送。事件进入有界 FIFO 后，通过 `ExecuteInGameThread` 在游戏线程分批处理。聊天使用 `ExecuteInGameThreadWithDelay` 串行泵送，并通过 `SendSystemToPlayerChat` 只发送给贡献者 UID 快照。

默认最多排队 8192 条伤害事件，每批最多处理 256 条。队列满时只丢弃额外伤害，死亡/捕捉结束事件仍保留。

## 配置

配置文件为 `Scripts/config.lua`：

- `ProgressIntervalSeconds`：实时战况间隔，默认 10 秒；设为 0 可关闭。
- `ProgressMaxRows`：实时战况最多展开人数，默认 4。
- `MaxResultRows`：最终排名最多展开人数。
- `TeamDetailMaxRows`：每个队伍私报最多展开的玩家角色/帕鲁来源数，默认 12。
- `EnableFunComments`：是否启用趣味点评；10 秒点评仅在触发阈值时出现，最终点评始终出现。
- `MessageIntervalMilliseconds`：消息行间隔，默认 1000 毫秒。
- `InactivityTimeoutSeconds`：无伤害自动结束时间，默认 300 秒。
- `BossNameOverrides`、`PalNameOverrides`：中文名覆盖表。

## 离线验证

```powershell
cd "C:\Users\Administrator\Documents\帕鲁服务器\BossDPSBroadcast\tests"
.\run_all.ps1
```

测试覆盖 Lua 解析、UTF-8、危险 API、线程约束、临时参数生命周期、参与者/队伍隔离、击杀/捕捉/超时、多 Boss、滚动 DPS、趣味点评、队伍私报、坐骑技能与玩家武器分流、队伍/玩家/帕鲁奖项、昵称优先级和 10,000 次伤害压力。测试脚本还要求 Lua 完整运行到成功标记，避免解释器返回码掩盖断言失败。
