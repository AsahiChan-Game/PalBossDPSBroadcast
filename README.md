# BossDPSBroadcast v2（离线验证候选版）

这是为 Palworld 1.0 专用服务器准备的 UE4SS Lua Boss 团队伤害统计插件。

当前状态：**工作区候选版已完成离线验证，但没有部署到正在运行的服务器。** 发生过崩溃的旧版服务端组件仍保持禁用。首次实机验证必须等维护窗口，并先做单人灰度测试。

工作区只提供 `enabled.txt.template`，因此候选版默认不会加载。不要在朋友在线时把它重命名为 `enabled.txt`。

## 功能

- Boss 首次受到可归属给玩家的真实伤害时自动开始统计。
- 玩家召唤帕鲁造成的伤害归属给训练家。
- 按 Boss 实例分别统计，可同时处理多个 Boss。
- Boss 死亡后，公屏依次播报团队总伤害、用时、个人排名、伤害占比和 DPS。
- 长时间没有伤害时播报并关闭未完成的统计。
- 事件队列有容量和单帧处理上限，避免伤害突发无限占用内存或长时间卡住游戏线程。

## v2 安全结构

伤害与死亡钩子只复制临时事件中的以下值：

- `Attacker`
- `Defender`
- `ActualDamage`
- `SelfActor`

钩子中不执行 Boss 查询、玩家查询或公屏广播。事件会被合并到有界 FIFO，随后通过 `ExecuteInGameThread` 在游戏线程分批处理。延时播报使用 `ExecuteInGameThreadWithDelay`，定时清理使用 `LoopInGameThreadWithDelay`。

Boss 判断直接读取 `UPalStaticCharacterParameterComponent` 的 `IsBoss_Database` 和 `IsTowerBoss_Database` 反射属性，不再调用旧版崩溃路径中的 Boss 判定 UFunction。公屏使用一次 `SendSystemAnnounce`，不再对每名玩家循环调用聊天 UFunction。

## 配置

配置文件为 `Scripts/config.lua`。常用项：

- `MessagePrefix`：公屏前缀。
- `MaxResultRows`：最多显示多少名参与者。
- `MessageIntervalMilliseconds`：结果行之间的间隔，默认 1000 毫秒；所有 Boss 共用一个串行播报队列，避免排名互相穿插。
- `InactivityTimeoutSeconds`：无伤害多久后结束统计。
- `MaxPendingEvents`：待处理事件上限，默认 8192。
- `MaxEventsPerDrain`：每次游戏线程处理上限，默认 256。
- `BossNameOverrides`：按 Boss 短对象名替换显示名称。

## 离线验证

在 PowerShell 中运行：

```powershell
cd "C:\Users\Administrator\Documents\帕鲁服务器\BossDPSBroadcast\tests"
.\run_all.ps1
```

验证包括 Lua 语法、严格 UTF-8、危险 API 静态审计、钩子线程约束、临时参数生命周期、失效 UObject、帕鲁归属、重复死亡、超时、多条播报，以及 10,000 次伤害突发与队列背压。

## 维护窗口灰度步骤（尚未执行）

1. 确认无人在线并完成世界存档备份。
2. 只部署 v2 工作区副本；确认维护窗口后，把 v2 的 `enabled.txt.template` 重命名为 `enabled.txt`，不要恢复旧版文件。
3. 使用一名测试玩家攻击一个低风险 Boss，观察开始播报、伤害累计、击杀结算和服务端日志。
4. 测试玩家帕鲁伤害归属、两名玩家占比和超时结算。
5. 任一异常立即关闭 v2；不要在有人游玩时反复重启试错。

详细崩溃证据与剩余风险见 `CRASH-ANALYSIS.md`，完整验证结果见 `TEST-REPORT.md`。
