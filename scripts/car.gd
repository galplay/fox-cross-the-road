extends Area2D
class_name Car
## 车辆：物理连续运动。
##
## 【编辑器可见】
##   本脚本挂在 scenes/Car.tscn 的根节点 Car 上，该场景结构为：
##       Car (Area2D, car.gd)
##       └── Body (Node2D, car_body.gd)   ← 负责绘制车身
##       └── CollisionShape2D             ← 碰撞盒（检查器可拖拽调整）
##
## 坐标约定：position 为车辆【左端中点】的像素坐标；
## 车辆占据的横向像素范围 = [position.x, position.x + length_px]。
## 向右行驶 dir = +1；向左行驶 dir = -1。
##
## 无重叠保证：每帧先求出本车道内位于自己「行驶前方」的最近车辆，
## 若距离小于安全跟车距离则按比例减速，从而自然保持车距，永不追尾重叠。

const TILE := 64

## ── 可导出参数（在检查器中直接调整）─────────────────────────
@export_group("行驶")
## 行驶方向：+1 向右，-1 向左
@export_enum("向左:-1", "向右:1") var lane_dir: int = 1
## 基础速度（像素/秒）
@export_range(0.0, 600.0, 1.0) var speed_px: float = 64.0
## 车身长度（格）：1 = 小轿车，2 = 卡车
@export_range(1, 4, 1) var length_tiles: int = 1

@export_group("外观")
## 车身颜色
@export var body_color: Color = Color("#7F77DD")

@export_group("跟车")
## 最小安全净间距（像素）—— 低于此值立即刹停
@export_range(0.0, 200.0, 1.0) var safe_gap_px: float = 26.0
## 跟车减速区间长度（像素）—— 距离前车在此范围内按比例减速
@export_range(0.0, 400.0, 1.0) var brake_range_px: float = 80.0
## 加/减速平滑系数
@export_range(1.0, 30.0, 0.5) var accel_smooth: float = 6.0
## ────────────────────────────────────────────────────────

var vel := 0.0                   # 当前实际速度（像素/秒，标量）
var lane_y := 0

var _lane: Lane = null           # 所属车道（用于查询前车）
var _body: Node2D = null         # 车身绘制节点


func _ready() -> void:
	_body = get_node_or_null("Body")
	_sync_appearance()


## 由 Lane 在生成时调用（也可在编辑器中直接调检查器参数预览）
func setup(p_dir: int, p_speed_px: float, p_len: int, p_color: Color, start_left_px: float, p_lane_y: int, p_lane: Lane) -> void:
	lane_dir = p_dir
	speed_px = p_speed_px
	length_tiles = p_len
	body_color = p_color
	lane_y = p_lane_y
	_lane = p_lane
	position = Vector2(start_left_px, -float(lane_y) * TILE - TILE * 0.5)
	vel = speed_px
	_sync_appearance()


## 把导出参数同步到子节点（碰撞盒尺寸 + 车身绘制）
func _sync_appearance() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		var rect := RectangleShape2D.new()
		var w := float(length_tiles) * TILE - 8.0
		var h := TILE - 14.0
		rect.size = Vector2(w, h)
		cs.shape = rect
		cs.position = Vector2(w * 0.5 + 4.0, 0.0)
	if _body == null:
		_body = get_node_or_null("Body")
	if _body and _body.has_method("configure"):
		_body.call("configure", length_tiles, body_color, lane_dir)
	queue_redraw()


## 车辆左端的像素 x（供车道排序 / 生成使用）
func left_px() -> float:
	return position.x


func right_px() -> float:
	return position.x + float(length_tiles) * TILE


func is_off_screen() -> bool:
	var margin_px := float(GameConfig.SPAWN_MARGIN) * TILE
	return right_px() < -margin_px or left_px() > float(GameConfig.GRID_W) * TILE + margin_px


func _physics_process(delta: float) -> void:
	# 1) 计算期望速度
	var target := speed_px
	# 2) 跟车减速：找前方最近车辆
	var ahead := _nearest_ahead_gap_px()
	if ahead != INF:
		if ahead <= safe_gap_px:
			target = 0.0                     # 太近：刹停，绝不追尾
		else:
			# 距离越近越慢
			var t := clampf((ahead - safe_gap_px) / maxf(brake_range_px, 1.0), 0.0, 1.0)
			target = minf(target, speed_px * t)
	vel = lerpf(vel, target, accel_smooth * delta)
	position.x += vel * float(lane_dir) * delta


## 返回本车道内「行驶方向前方」最近车辆的净间距（像素）；无则 INF。
##
## 注意：不在前方的车辆必须【跳过】，不能把 gap 留在默认值 0，
## 否则会把「后方车辆」误判成「正前方 0 像素」而永久刹停。
func _nearest_ahead_gap_px() -> float:
	if _lane == null:
		return INF
	var best := INF
	for other in _lane.cars:
		if other == self:
			continue
		var gap := -1.0
		if lane_dir > 0:
			# 向右行驶：前车在自己右边
			if other.left_px() >= right_px() - 0.001:
				gap = other.left_px() - right_px()
		else:
			# 向左行驶：前车在自己左边
			if other.right_px() <= left_px() + 0.001:
				gap = left_px() - other.right_px()
		# gap < 0 表示该车不在前方（或未设置），一律忽略
		if gap >= 0.0 and gap < best:
			best = gap
	return best
