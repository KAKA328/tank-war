# Tank War

Godot 4.7 的 2D 坦克对战原型，支持同一校园网内的 1v1 联机，也可以把同一 UDP 端口交给 Sakura FRP 做内网穿透。

## 当前能力

- 使用 ENet/UDP 创建或加入房间。
- 地址支持 `IP:端口`、`域名:端口`，不写端口时使用 `7000`。
- 主机作为权威服务器，处理移动、开火、命中、生命值、重生、计分和胜负；客户端只上传输入命令。
- 反射速度计算可直接用于墙面弹射。
- AI 威胁计算可以判断来弹首次进入坦克危险半径的时间。
- 竞技场场景包含可移动坦克、鼠标瞄准、开火信号和自动移动的子弹实体。
- 创建房间或成功加入后自动进入竞技场，返回菜单会关闭当前会话。
- 客户端通过输入 RPC 提交命令，主机广播坦克位置、瞄准和生命值快照。
- 新玩家由主机分配出生点；子弹由主机生成并负责命中扣血。
- 服务器权威的 1v1 比赛闭环：击杀后 3 秒重生，先得 5 分获胜，支持比分、生命、重生倒计时、比赛结束提示和重新开始。
- 网络层同时支持原生 ENet/UDP 和 WebSocket；浏览器客户端只连接外部 WebSocket 权威服务器。
- 自带无第三方依赖的 headless 测试入口。

## 启动

用 Godot 项目管理器导入当前目录的 `project.godot`，然后运行主场景。也可以在终端执行：

```powershell
godot --path .
```

也可以直接双击 [start_tank_war.bat](D:/codex/Game/tank-war/start_tank_war.bat) 一键启动。脚本会自动查找已安装的 Godot 4.7.2。

PowerShell 启动方式：

```powershell
.\start_tank_war.ps1
```

同一校园网内，主机创建房间后，另一台电脑填写主机的校园网 IPv4 地址，例如：

```text
10.20.30.40:7000
```

使用 Sakura FRP 时，需要建立 UDP 隧道，然后填写 Sakura 分配的服务器地址和远程端口。

## 浏览器版本

项目已经包含 Godot Web 导出预设和 GitHub Actions Pages 工作流。推送到 `main` 后，Actions 会导出 `builds/web` 并发布静态页面；首次启用时需要在仓库 Settings → Pages → Build and deployment 中选择 GitHub Actions。

浏览器页面只负责运行客户端，不能在 GitHub Pages 上启动主机权威服务器。要让朋友通过浏览器联机，还需要在云服务器或可公开访问的机器上运行：

```powershell
godot --headless --path . --scene res://server/server.tscn -- --port=7001
```

浏览器菜单中填写服务器的 `wss://域名/路径`。本地验证可以使用 `ws://127.0.0.1:7011`；公网 HTTPS 页面必须使用 `wss://`，不能把 `ws://` 直接混入 HTTPS 页面。

Web 导出要求浏览器支持 WebAssembly 和 WebGL 2，当前项目使用 Compatibility 渲染模式。导出文件不提交到 Git，CI 会在发布时重新生成。

## 验证

```powershell
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 2
godot --headless --path . --export-release Web builds/web/index.html
```

双进程联机和完整比赛冒烟测试（会在本机 UDP 7010 端口启动主机与客户端，约 30 秒）：

```powershell
$godot = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter 'Godot_v4.7.2-stable_win64_console.exe' -Recurse | Select-Object -First 1 -ExpandProperty FullName)
Start-Process $godot -ArgumentList '--headless','--path','.', '--script','res://tests/network_host_smoke.gd'
Start-Process $godot -ArgumentList '--headless','--path','.', '--script','res://tests/network_client_smoke.gd'
```

冒烟测试会验证两进程连接、双方移动、客户端输入 RPC、开火、扣血、死亡、重生、计分、5 分结束，以及客户端请求重新开始。

WebSocket 连接冒烟测试：

```powershell
godot --headless --path . --script res://tests/websocket_smoke.gd -- --role=host
godot --headless --path . --script res://tests/websocket_smoke.gd -- --role=client
```

## 当前限制

当前是确定性原型，尚未加入客户端预测、延迟补偿、道具、坦克点数配置和草丛等特殊地形。AI 决策仍应只在主机执行，客户端只接收结果。

重生时间和胜利分数集中在 `src/core/game_config.gd` 的 `RESPAWN_DELAY` 与 `TARGET_SCORE`，修改后重新启动双方即可生效。
