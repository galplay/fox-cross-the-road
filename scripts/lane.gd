extends Node2D
class_name Lane
## 车道：物理连续版。车辆持续行驶，按需在视野外补充、出界即回收。
##
## 【编辑器可见】挂在 scenes/Lane.tscn 上，结构：
##     Lane (Node2D, lane.gd)
##     └── DebugDraw (Node2D)  ← 编辑器内显示车道参考线（运行时自动隐藏）
##
## 无重叠保证：生成前检查「上游端」与最靠上游车辆的净间距，不足则本帧
## 不生成；加上 Car 内部的跟车减速，双向保证车辆永不相撞 / 重叠。

const TILE := 64

## 车辆场景（在检查器中可替换成自己的车模场景）
@export var car_scene: PackedScene

## ── 可导出参数 ──────────────────────────────────────────
@export_group("行驶")
## 车道所在行号（决定纵向位置）
@export var lane_y: int = 1
## 行驶方向：+1 向右，-1 向左
@export_enum("向左:-1", "向右:1") var lane_dir: int = 1
## 基准速度（像素/秒）
@export_range(0.0, 600.0, 1.0) var speed_px: float = 64.0

@export_group("车辆分布")
## 目标净间距（像素）
@export_range(32.0, 800.0, 4.0) var gap_px: float = 220.0
## 卡车出现比例 0.0–1.0
@export_range(0.0, 1.0, 0.05) var truck_ratio: float = 0.0
## 该车道车身颜色
@export var body_color: Color = Color("#7F77DD")

@export_group("难度")
## 速度缩放（随高度递增，由 World 写入）
@export_range(0.5, 4.0, 0.05) var speed_scale: float = 1.0
## ────────────────────────────────────────────────────

var cars: Array[Car] = []

var _rng := RandomNumberGenerator.new()
var _spawn_cursor_px := 0.0      # 上游生成游标（像素，左端坐标）


func _ready() -> void:
	if not Engine.is_editor_hint():
		var dbg := get_node_or_null("DebugDraw")
		if dbg:
			dbg.visible = false


## 由 World 在创建车道时调用；也可在编辑器中点「预览」按钮手动铺一次
func configure(p_index: int, p_y: int, preset: Dictionary) -> void:
	lane_y = p_y
	lane_dir = int(preset["dir"])
	speed_px = float(preset["speed"]) * TILE
	gap_px = float(preset["gap"]) * TILE * 0.62
	truck_ratio = float(preset["truck"])
	body_color = Color(preset["color"])
	_rng.seed = hash("lane_%d_%d" % [p_index, p_y])


## 初始铺满：从上游端沿行驶方向依次摆放到下游端
func populate() -> void:
	_clear()
	var pos := _upstream_start_px()
	var guard := 0
	while guard < 120:
		guard += 1
		var len_t := _next_length()
		var left_px := pos if lane_dir > 0 else pos - float(len_t) * TILE
		if _leaves_field(left_px, len_t):
			break
		_spawn(len_t, left_px)
		pos += (float(len_t) * TILE + _next_gap_px()) * float(lane_dir)


## 每帧维护：回收 + 生成
func maintain(_delta: float) -> void:
	_recycle()
	_try_spawn()


func _recycle() -> void:
	var keep: Array[Car] = []
	for car in cars:
		if car.is_off_screen():
			car.queue_free()
		else:
			keep.append(car)
	cars = keep


## 在上游补充车辆：只有当空隙已足够大（新车能放到视野外）时才生成
func _try_spawn() -> void:
	var len_t := _next_length()
	var gap := _next_gap_px()
	var edge := _upstream_edge_px()          # 现有车最靠上游的边界
	var new_outer := edge - (float(len_t) * TILE + gap) * float(lane_dir)
	# 尚未退到视野外 → 空档不够，本帧不生成
	if not _beyond_spawn_point(new_outer):
		return
	var left_px := new_outer if lane_dir > 0 else new_outer - float(len_t) * TILE
	_spawn(len_t, left_px)


func _beyond_spawn_point(outer_px: float) -> bool:
	var lo := -float(GameConfig.SPAWN_MARGIN) * TILE
	var hi := float(GameConfig.GRID_W) * TILE + float(GameConfig.SPAWN_MARGIN) * TILE
	if lane_dir > 0:
		return outer_px <= lo
	return outer_px >= hi


func _upstream_edge_px() -> float:
	if cars.is_empty():
		return _upstream_start_px()
	if lane_dir > 0:
		var best := INF
		for car in cars:
			best = minf(best, car.left_px())
		return best
	else:
		var best2 := -INF
		for car in cars:
			best2 = maxf(best2, car.right_px())
		return best2


func _upstream_start_px() -> float:
	if lane_dir > 0:
		return -float(GameConfig.SPAWN_MARGIN) * TILE - 2.0 * TILE
	return float(GameConfig.GRID_W) * TILE + float(GameConfig.SPAWN_MARGIN) * TILE + 2.0 * TILE


func _leaves_field(left_px: float, len_t: int) -> bool:
	var lo := -float(GameConfig.SPAWN_MARGIN) * TILE
	var hi := float(GameConfig.GRID_W) * TILE + float(GameConfig.SPAWN_MARGIN) * TILE
	if lane_dir > 0:
		return left_px > hi
	return left_px + float(len_t) * TILE < lo


## 生成一辆车：优先使用 car_scene（编辑器可替换），没有则用内置场景
func _spawn(len_t: int, left_px: float) -> void:
	var scene := car_scene
	if scene == null:
		scene = load("res://scenes/Car.tscn")
	var car: Car = scene.instantiate()
	car.name = "Car_%d_%d" % [lane_y, Time.get_ticks_usec()]
	add_child(car)
	car.setup(lane_dir, speed_px * speed_scale, len_t, body_color, left_px, lane_y, self)
	cars.append(car)


func _next_length() -> int:
	return 2 if _rng.randf() < truck_ratio else 1


func _next_gap_px() -> float:
	return gap_px + _rng.randf_range(0.0, 90.0)


func _clear() -> void:
	for car in cars:
		car.queue_free()
	cars.clear()


## 调试用：是否存在重叠
func has_overlap() -> bool:
	var rs: Array[Vector2] = []
	for car in cars:
		rs.append(Vector2(car.left_px(), car.right_px()))
	rs.sort_custom(func(a, b): return a.x < b.x)
	for i in range(rs.size() - 1):
		if rs[i].y > rs[i + 1].x + 0.5:
			return true
	return false
