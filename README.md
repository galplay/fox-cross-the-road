# 小狐狸过马路

一个用 Godot 4 做的无限向上过马路小游戏：按住方向键让小编幅奔跑，穿过一条条车流，走得越高分数越高，碰到车就掉一条命。

![菜单截图](art_shots/p_menu.png)

## 玩法

- 起始站在底部草地上，方向键或 `WASD` 控制小狐狸自由奔跑（可以上下左右，也可以斜着跑）。
- 道路会随高度不断向上生成，每 8 行为一个主题段，段与段之间夹一条安全草地。
- 每向前进一格 +1 分，路上随机刷新的金币每颗 +10 分。
- 一共 3 条命：撞车后回到最近的安全草地继续跑，命用完则本局结束，最高分自动存档。
- 车越往上的车道越快、卡车越多，难度是随行数递增的，没有关卡上限。

| 按键 | 作用 |
| --- | --- |
| `↑↓←→` / `WASD` | 奔跑 |
| `Enter` / `空格` | 开始游戏、结束后重开、暂停时继续 |
| `Esc` | 暂停 / 继续 |

## 运行

需要 [Godot 4.7](https://godotengine.org/download)（Forward Plus 渲染 + Jolt Physics，已在项目中配置）。

1. 打开 Godot，点「导入」，选择本目录下的 `project.godot`。
2. 按 `F5` 运行，主场景是 `scenes/Main.tscn`。

想打包成可执行文件：项目 → 导出，装好对应平台的导出模板后选择 Windows / macOS / Linux 模板即可。

## 目录结构

```
scenes/            场景文件
  Main.tscn        主场景（GameManager + World + Player + Camera2D + HUD）
  Player.tscn      小狐狸
  Car.tscn         车辆（含小车与卡车两种车身）
  Lane.tscn        单车道
  Coin.tscn        金币
  HUD.tscn         分数、生命、开始/暂停/结束界面
scripts/           GDScript 源码
  game_config.gd   全局常量与车道预设（自动加载单例 GameConfig）
  game_manager.gd  游戏状态机：计分、生命、镜头跟随、存档
  world.gd         无限车道生成与回收
  lane.gd          单车道的车流生成、移动与清理
  car.gd           车辆行驶与碰撞区域
  player.gd        小狐狸的移动、朝向与死亡动画
  coin.gd          金币生成与拾取
  hud.gd           界面逻辑
  fox_sprite.gd    用代码绘制的狐狸图形
  draw_utils.gd    通用绘制工具
  _autotest.gd     开发用自动化检查脚本
  _stress.gd       开发用压力测试脚本
  _shot.gd         开发用截图脚本
art_shots/         游戏画面截图
```

画面全部由代码绘制（没有外部美术资源），配色集中在 `scripts/game_config.gd` 顶部的调色板常量里。

本仓库不包含任何第三方插件。本地开发时挂载了一个 AI 调试插件（`addons/godot_ai/`，已从版本库忽略），`project.godot` 里因此残留两行引用。打开项目时若出现「找不到插件」的警告，按下面处理即可，不影响游戏运行：

- 项目设置 → 插件：把 Godot AI 一行删掉（或直接忽略警告）。
- 项目设置 → 全局 → 自动加载：移除 `_mcp_game_helper` 这一项。
- 手动清理 `project.godot`：删掉 `[editor_plugins]` 整段，以及 `[autoload]` 里的 `_mcp_game_helper=...` 一行（`GameConfig` 那行请保留，游戏逻辑依赖它）。

## 改数值

要调手感，优先改这三处：

- `scripts/game_config.gd`：格子大小 `TILE`、横向格数 `GRID_W`、最大生命 `MAX_LIVES`、金币概率 `COIN_CHANCE`、难度增长 `DIFF_SPEED_GROWTH` / `DIFF_MAX_SPEED`，以及 `LANE_PRESETS`（每类车道的速度、车距、卡车比例、行驶方向、颜色）。
- 场景节点上的 `@export` 变量：在编辑器里选中 `Player` / `Car` / `Lane` / `Coin` 节点，检查器面板就能直接调速度、碰撞盒、生成参数等，无需改代码。
- `scenes/Main.tscn` 的 `GameManager` 节点：镜头跟随距离与平滑度、最高分存档路径。

最高分存在用户目录的 `user://fox_best.save`（Windows 下一般是 `%APPDATA%\Godot\app_userdata\小狐狸过马路\`），删掉该文件即可清零。

## 许可

游戏代码（`scenes/`、`scripts/` 及项目配置）可自由修改和使用，不附带任何保证。
仓库内不含第三方代码；引擎本身为 MIT 许可的 Godot 4.7。
