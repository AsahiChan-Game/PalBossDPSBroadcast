[h1]不要查我DPS[/h1]
[b]面向 Palworld 1.0 单人世界的 Boss 伤害统计 Mod。[/b]

攻击 Boss 后自动开始记录；击杀、捕捉或战斗中断时，在聊天窗口生成清晰的伤害结算。看看这一场究竟是你在带帕鲁，还是帕鲁在带你。

[h2]主要功能[/h2]
[list]
[*]自动识别 Boss 战，首次有效命中后显示“开始统计”
[*]显示总伤害、战斗用时、团队 DPS、个人伤害与占比
[*]分别记录玩家角色和每只帕鲁的伤害
[*]帕鲁名称优先使用玩家设置的昵称
[*]支持击杀、捕捉和长时间无伤害后的自动结算
[*]自动合并月亮领主等多部位 Boss，避免重复计算
[*]自动跟随 Palworld 当前语言，支持官方全部 17 种语言
[*]可选十秒实时战况、详细奖项、逐只帕鲁明细和趣味点评
[/list]

[h2]安装与使用[/h2]
[olist]
[*]订阅本 Mod。
[*]订阅并启用必需项目：[url=https://steamcommunity.com/workshop/filedetails/?id=3625223587]UE4SS Experimental (Palworld)[/url]。
[*]在 Palworld 模组管理中确认两个 Mod 均已启用。
[*]进入单人世界并攻击 Boss；第一次有效命中后会看到开始统计提示。
[*]击杀或捕捉 Boss 后，在聊天窗口查看最终结算。
[/olist]

[h2]默认体验[/h2]
开战时确认一次，结束时显示团队结果、伤害排名，以及玩家角色和每只参战帕鲁的伤害明细，不会持续刷屏。

v1.2.0 起逐只帕鲁伤害默认开启；帕鲁优先显示玩家设置的昵称。可在配置文件中修改：[code]config.EnablePalDamageBreakdown = true[/code]。设为 [code]false[/code] 可恢复精简结算。DPS 记录、实时战况、详细奖项和点评功能也可独立开关。

[h2]适用范围[/h2]
[list]
[*][b]正式支持：[/b]单人世界
[*][b]实验支持：[/b]房主模式，仅向本机房主显示
[*][b]Boss 竞技场：[/b]Boss 房间、塔主战和召唤 Boss 场地均可统计
[*][b]PvP 竞技场：[/b]暂不统计玩家与玩家拥有的帕鲁
[*][b]不支持：[/b]作为远程联机客户端统计服务端全队伤害
[/list]

远程客户端无法取得服务器权威的全队伤害数据。专用服务器请使用 GitHub 上的服务端版本。

[h2]配置文件[/h2]
[code]Palworld\Mods\NativeMods\UE4SS\Mods\PalBossDPSBroadcastSP\Scripts\config.lua[/code]

[h2]源码、服务端版本与问题反馈[/h2]
[url=https://github.com/AsahiChan-Game/PalBossDPSBroadcast]GitHub：AsahiChan-Game/PalBossDPSBroadcast[/url]

[i]本项目是非官方社区 Mod，与 Pocketpair、Steam 或 UE4SS 项目无隶属关系。[/i]
