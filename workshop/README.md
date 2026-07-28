# Steam 创意工坊发行目录

`content/` 是 Palworld 1.0 创意工坊上传目录，结构依据游戏当前的 `Info.json`/`InstallRule` 模组安装机制。

## 构建

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\workshop\build_workshop.ps1
```

脚本会：

- 将共享核心、语言选择器和 17 个语言包同步到单机包；
- 保留单机专用 `Scripts/config.lua`；
- 校验 `Info.json`、封面、依赖和本地消息模式；
- 在 `workshop/dist/` 生成用于留档检查的 ZIP。

实际上传时，将 `workshop/content/` 作为 Workshop item content folder。首次创建后，把 Steam 返回的 Published File ID 写回 `content/.workshop.json`，以后使用相同 ID 更新。

`localizations.json` 是创意工坊 17 种标题/描述的唯一清单。发布前运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\workshop\validate_localizations.ps1
```

SteamCMD 更新英语回退内容和 Mod 文件；其余语言使用创意工坊页面的语言下拉框维护。

## 上传

安装 Valve 官方 SteamCMD 后，在可交互的 PowerShell 窗口运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\workshop\upload_workshop.ps1 `
  -SteamCmdPath "C:\steamcmd\steamcmd.exe" `
  -SteamAccountName "你的Steam登录名"
```

脚本默认以私密可见性创建项目，方便先完成游戏内验证。SteamCMD 会在当前终端要求输入密码和 Steam Guard 验证码；脚本不接收、保存或将密码放入命令行。上传成功后会自动记录 Published File ID。更新现有项目时保留原可见性参数。

确认页面内容和依赖无误后：

1. 接受 Steam Workshop Legal Agreement；
2. 在项目页面将 UE4SS item `3625223587` 设置为 Required Item；
3. 完成单人世界测试；
4. 再将可见性调整为公开。

## 依赖

- Palworld App ID：`1623730`
- UE4SS Workshop 依赖：`UE4SSExperimentalPW`
- 当前参考 Workshop item：`3625223587`

创意工坊网页还应将 UE4SS 项目标记为 Required Item。`Info.json` 中的 `Dependencies` 用于 Palworld 模组管理器识别依赖，两者都要保留。
