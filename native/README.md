# 原生伤害采集器

`BossDPSNativeCollector` 是 `BossDPSBroadcast` v3.2 的可选 C++ 前端。它在
UE4SS 原生回调中只读取并累加伤害字段，不执行 Boss 判断、玩家/帕鲁归属查询或
聊天广播。Lua 每隔很短时间拉取已经聚合的记录，继续负责原有战报逻辑。

## 兼容边界

当前二进制只针对专用服务器实际使用的 UE4SS 3.0.1
`c2ac246447a8bcd92541070cb474044e7a2bbbe6` 和 MSVC 14.44 构建。升级
UE4SS 后必须重新编译。加载或反射失败时，Lua 默认回退到原有纯 Lua 伤害钩子。

## 构建

在仓库根目录运行：

```powershell
.\native\build_native.ps1 `
  -UE4SSDll "D:\PalServer\Pal\Binaries\Win64\ue4ss\UE4SS.dll"
```

脚本从服务器实际的 `UE4SS.dll` 导出表生成 import library，不会覆盖或修改
UE4SS 本身。构建结果位于 `native/build-native/main.dll`，同时执行 200 万次并发伤害
聚合压力测试。

## 安装结构

```text
ue4ss/Mods/
├─ BossDPSNativeCollector/
│  ├─ enabled.txt
│  └─ dlls/
│     └─ main.dll
└─ BossDPSBroadcast/
   ├─ enabled.txt
   └─ Scripts/
      ├─ main.lua
      ├─ config.lua
      └─ commentary.lua
```

先停止服务器，安装两个目录，再启动。日志中同时出现
`native damage hook ready` 和 `collector=native` 才表示原生路径已启用。
