# Tank War

Godot 4.7 的 2D 坦克对战项目框架。当前版本建立了局域网和 UDP 内网穿透共用的连接入口，以及可测试的弹道反射和 AI 来弹威胁计算。

## 当前能力

- 使用 ENet/UDP 创建或加入房间。
- 地址支持 `IP:端口`、`域名:端口`，不写端口时使用 `7000`。
- 主机作为权威服务器，后续由主机处理移动、开火、命中、AI 和胜负。
- 反射速度计算可直接用于墙面弹射。
- AI 威胁计算可以判断来弹首次进入坦克危险半径的时间。
- 竞技场场景包含可移动坦克、鼠标瞄准、开火信号和自动移动的子弹实体。
- 创建房间或成功加入后自动进入竞技场，返回菜单会关闭当前会话。
- 客户端通过输入 RPC 提交命令，主机广播坦克位置、瞄准和生命值快照。
- 新玩家由主机分配出生点；子弹由主机生成并负责命中扣血。
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

## 验证

```powershell
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 2
```

## 当前限制

当前已经完成多玩家出生点、输入同步、子弹同步和主机扣血；还没有完成重生、胜负流程、客户端预测和延迟补偿。AI 决策仍应只在主机执行，客户端只接收结果。

## 下一里程碑

加入服务器权威的玩家生成、输入 RPC、子弹碰撞结算、生命值和胜负状态。
