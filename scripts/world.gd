extends Node2D
class_name World
## 世界：无限向上延伸的车道带。
## 玩家位置是连续像素，按所在「行」触发上方生成与下方回收。
##
## 【编辑器可见】
##   World 上挂着 world.gd，可选择要实例化的「车道场景」与「金币场景」；
##   路面配色、车道段长度等参数在下面 @export 分组里直接调。
##   注意：无限世界的每一行车道的具体内容（车速/方向/颜色）仍由
##   行号 + 种子确定性地推导，这样无论跑到多高都能复现同一格局；
##   但其基础参数来自 GameConfig.LANE_PRESETS。

const TILE := 64

## 要实例化生成的车道场景
@export var lane_scene: PackedScene
## 要实例化生成的金币场景
@export var coin_scene: PackedScene

@export_group("路面配色")
@export var road_color_a: Color = Color("#D3D1C7")
@export var road_color_b: Color = Color("#B4B2A9")
@export var grass_color: Color = Color("#EAF3DE")
@export var grass_edge_color: Color = Color("#C0DD97")

@export_group("金币")
## 每行生成金币的概率
@export_range(0.0, 1.0, 0.01) var coin_chance: float = 0.12
@export_group("")

var lanes: Dictionary = {}          # row(int) -> Lane
var coins: Array[Coin] = []

var lowest_row := 0
var highest_row := 0
var highlight_row := -9999
var coin_gen_row := 0

## 金币被捡起时的回调（由 GameManager 注入）
var coin_picked_cb: Callable = Callable()

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 0
	queue_redraw()


## 像素 y → 行号（行 gy 占据 [-(gy+1)*TILE, -gy*TILE)）
func row_at_pixel_y(py: float) -> int:
	return int(floor(-py / float(TILE)))


func is_lane_row(row: int) -> bool:
	if row <= 0:
		return false
	var idx := (row - 1) % (GameConfig.ROW_CHUNK + GameConfig.SAFE_ROWS)
	return idx < GameConfig.ROW_CHUNK


func _preset_for_row(row: int) -> Dictionary:
	var chunk := (row - 1) / (GameConfig.ROW_CHUNK + GameConfig.SAFE_ROWS)
	var seed_val := hash("row_%d" % row) ^ (chunk * 7919)
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var base: Dictionary = GameConfig.LANE_PRESETS[r.randi_range(0, GameConfig.LANE_PRESETS.size() - 1)]
	var p: Dictionary = base.duplicate()
	var height_mult := minf(pow(GameConfig.DIFF_SPEED_GROWTH, float(row)), GameConfig.DIFF_MAX_SPEED)
	p["speed"] = float(p["speed"]) * height_mult
	p["gap"] = maxf(float(p["gap"]) - float(chunk) * 0.25, GameConfig.MIN_CAR_GAP + 1.6)
	return p


func _speed_scale_for_row(row: int) -> float:
	return minf(pow(GameConfig.DIFF_SPEED_GROWTH, float(row)), GameConfig.DIFF_MAX_SPEED)


func _create_lane(row: int) -> Lane:
	var scene := lane_scene
	if scene == null:
		scene = load("res://scenes/Lane.tscn")
	var lane: Lane = scene.instantiate()
	lane.name = "Lane%d" % row
	add_child(lane)
	lane.configure(row, row, _preset_for_row(row))
	lane.speed_scale = _speed_scale_for_row(row)
	lane.z_index = 2
	lane.populate()
	lanes[row] = lane
	return lane


func _remove_lane(row: int) -> void:
	if lanes.has(row):
		var lane: Lane = lanes[row]
		lane.queue_free()
		lanes.erase(row)


func ensure_range(row_lo: int, row_hi: int, player_row: int) -> void:
	for row in range(row_lo, row_hi + 1):
		if is_lane_row(row) and not lanes.has(row):
			_create_lane(row)
	var kill_below := player_row - GameConfig.KEEP_ROWS_BELOW
	var to_remove: Array[int] = []
	for row in lanes.keys():
		if int(row) < kill_below:
			to_remove.append(int(row))
	for row in to_remove:
		_remove_lane(row)
	_update_bounds()


func _update_bounds() -> void:
	if lanes.is_empty():
		return
	var keys: Array = lanes.keys()
	keys.sort()
	lowest_row = int(keys[0])
	highest_row = int(keys[keys.size() - 1])


func reset() -> void:
	for row in lanes.keys():
		var lane: Lane = lanes[row]
		lane.queue_free()
	lanes.clear()
	for coin in coins:
		coin.queue_free()
	coins.clear()
	lowest_row = 1
	highest_row = 0
	coin_gen_row = 0
	queue_redraw()


func is_safe_row(gy: int) -> bool:
	return not is_lane_row(gy)


func lane_at_row(gy: int) -> Lane:
	return lanes.get(gy, null)


## 每帧推进所有车道（回收 + 生成由各 Lane 内部完成）
func maintain() -> void:
	for row in lanes.keys():
		var lane: Lane = lanes[row]
		lane.maintain(0.0)


func set_highlight_row(row: int) -> void:
	if row == highlight_row:
		return
	highlight_row = row
	queue_redraw()


## 在玩家前方的车道上稀疏撒金币（每行只掷一次骰子，避免泛滥）
func spawn_coins_ahead(from_row: int, to_row: int) -> void:
	if to_row < from_row:
		return
	var start := maxi(from_row, coin_gen_row + 1)
	if start > to_row:
		return
	for row in range(start, to_row + 1):
		if not is_lane_row(row):
			continue
		if rng.randf() > coin_chance:
			continue
		var lane: Lane = lanes.get(row, null)
		var gx := rng.randi_range(0, GameConfig.GRID_W - 1)
		if lane != null:
			var guard := 0
			while _lane_blocked_at(lane, gx) and guard < 8:
				guard += 1
				gx = rng.randi_range(0, GameConfig.GRID_W - 1)
			if _lane_blocked_at(lane, gx):
				continue
		_add_coin(Vector2i(gx, row))
	coin_gen_row = maxi(coin_gen_row, to_row)


## 某格是否被车占据（像素级区间判断）
func _lane_blocked_at(lane: Lane, gx: int) -> bool:
	var cell_lo := float(gx) * TILE
	var cell_hi := float(gx + 1) * TILE
	for car in lane.cars:
		if cell_hi > car.left_px() + 6.0 and cell_lo < car.right_px() - 6.0:
			return true
	return false


func _add_coin(cell: Vector2i) -> void:
	for coin in coins:
		if coin.grid_pos == cell:
			return
	var scene := coin_scene
	if scene == null:
		scene = load("res://scenes/Coin.tscn")
	var coin: Coin = scene.instantiate()
	coin.name = "Coin_%d_%d" % [cell.x, cell.y]
	add_child(coin)
	coin.setup(cell)
	coin.z_index = 4
	coin.picked.connect(_on_coin_picked)
	coins.append(coin)


func _on_coin_picked() -> void:
	if coin_picked_cb.is_valid():
		coin_picked_cb.call()


func prune_coins(player_row: int) -> void:
	var kill := player_row - GameConfig.KEEP_ROWS_BELOW
	var keep: Array[Coin] = []
	for coin in coins:
		if coin.grid_pos.y < kill:
			coin.queue_free()
		else:
			keep.append(coin)
	coins = keep


func remove_coin(coin: Coin) -> void:
	coins.erase(coin)
	coin.queue_free()


func _draw() -> void:
	var w := float(GameConfig.GRID_W) * TILE

	# 起始草地（row 0 及以下）
	draw_rect(Rect2(0, -float(TILE), w, TILE * 8.0), grass_color.darkened(0.02))
	draw_line(Vector2(0, 0), Vector2(w, 0), grass_edge_color, 2.0)
	_draw_blades(Rect2(0, TILE * 0.5, w, TILE * 2.0), 7)

	if lanes.is_empty():
		return

	var keys: Array = lanes.keys()
	keys.sort()
	var row_min: int = int(keys[0])
	var row_max: int = int(keys[keys.size() - 1])
	var lane_no := 0

	for row in range(row_min, row_max + 1):
		var y := -float(row + 1) * TILE
		if is_lane_row(row):
			var col := road_color_a if (lane_no % 2 == 0) else road_color_b
			draw_rect(Rect2(0, y, w, TILE), col)
			lane_no += 1
			var dash_y := y + TILE - 3.0
			var x := 0.0
			while x < w:
				draw_rect(Rect2(x, dash_y, 26, 3), Color(1, 1, 1, 0.75))
				x += 52
			if row == highlight_row:
				draw_rect(Rect2(0, y, w, TILE), Color(1, 0.85, 0.35, 0.16))
				draw_rect(Rect2(0, y, w, 3), Color("#EF9F27"))
				draw_rect(Rect2(0, y + TILE - 3, w, 3), Color("#EF9F27"))
		else:
			draw_rect(Rect2(0, y, w, TILE), grass_color)
			_draw_blades(Rect2(0, y, w, TILE), row * 31 + 5)
			if row == highlight_row:
				draw_rect(Rect2(0, y, w, TILE), Color(0.5, 0.8, 0.4, 0.18))


func _draw_blades(rect: Rect2, seed_val: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var n := int(rect.size.x / 26.0)
	for i in n:
		var x := rect.position.x + 14.0 + float(i) * 26.0 + r.randf_range(-6, 6)
		var y := rect.position.y + r.randf_range(12.0, rect.size.y - 6.0)
		draw_line(Vector2(x, y), Vector2(x + r.randf_range(-4, 4), y - r.randf_range(5, 10)),
			grass_edge_color, 2.0)
