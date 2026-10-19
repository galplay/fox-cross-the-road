extends Node
## 全局配置与常量（自动加载单例 GameConfig）。
##
## 【编辑器可见】
##   - 基础常量（TILE / GRID_W / 难度曲线 / 调色板）保留为 const，
##     便于代码统一引用；
##   - 需要在编辑器里反复试调的参数，改由各场景（Car/Lane/Player/Coin）
##     上的 @export 变量控制，直接选中节点在检查器里调即可；
##   - 车道预设见下方 LANE_PRESETS，修改后会通过 _preset_for_row 生效。

const TILE := 64              # 单格像素
const GRID_W := 13            # 横向格数
const SPAWN_MARGIN := 3       # 车辆在视野外多少格生成/回收

# 无限模式参数
const ROW_CHUNK := 8          # 每 8 行组成一个「主题段」，段间插入安全草地
const SAFE_ROWS := 1          # 每个主题段之间留的安全草地行数
const KEEP_ROWS_BELOW := 12   # 玩家下方保留多少行（超出回收）
const GEN_ROWS_AHEAD := 30    # 玩家上方预生成多少行
const MIN_CAR_GAP := 1.2      # 车辆之间最小净间距（格）——保证不相撞

# 前进方向奖励
const SCORE_STEP := 1
const SCORE_COIN := 10

# 生命
const MAX_LIVES := 3

# 难度：随行数（高度）递增，不再按关卡
const DIFF_SPEED_GROWTH := 1.006   # 每行车速倍率
const DIFF_MAX_SPEED := 2.6

# 金币生成概率（每行掷一次骰子）
const COIN_CHANCE := 0.12

# 车道类型预设：{speed, gap, truck, dir, color}
#   speed = 格/回合基准速度（内部会换算成像素/秒）
#   gap   = 目标车距（格）
#   truck = 卡车出现比例
#   dir   = +1 向右 / -1 向左
# 提示：想要可视化调整时，可复制其中一组参数，
#       填到 scenes/Lane.tscn 对应节点的检查器里单独预览。
const LANE_PRESETS := [
	{"speed": 1.0, "gap": 4, "truck": 0.0, "dir": 1,  "color": Color("#7F77DD")},
	{"speed": 0.7, "gap": 6, "truck": 0.6, "dir": -1, "color": Color("#5DCAA5")},
	{"speed": 1.5, "gap": 5, "truck": 0.0, "dir": 1,  "color": Color("#EF9F27")},
	{"speed": 1.2, "gap": 5, "truck": 0.3, "dir": -1, "color": Color("#D4537E")},
]

# 调色板
const C_GRASS := Color("#EAF3DE")
const C_GRASS_EDGE := Color("#C0DD97")
const C_ROAD_A := Color("#D3D1C7")
const C_ROAD_B := Color("#B4B2A9")
const C_FOX_BODY := Color("#EF9F27")
const C_FOX_FACE := Color("#FAEEDA")
const C_FOX_DARK := Color("#854F0B")
const C_COIN := Color("#EF9F27")
const C_COIN_EDGE := Color("#854F0B")
