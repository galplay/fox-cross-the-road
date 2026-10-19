extends Node2D
## GameManager：无限向上奔跑，碰到车即失败。
##
## 【编辑器可见】挂在 scenes/Main.tscn 根节点上，子节点 World / Player /
## Camera2D / HUD 都是真实节点（Player 与 HUD 为实例化子场景）。
## 相机跟随、存档路径等参数在下面 @export 分组里可直接调。

const TILE := 64

enum State { MENU, PLAYING, PAUSED, DEAD }

@export_group("镜头")
## 镜头相对玩家向上的偏移（格）
@export_range(0.0, 4.0, 0.1) var camera_lead_tiles: float = 1.5
## 镜头跟随平滑速度
@export_range(1.0, 30.0, 0.5) var camera_smooth: float = 8.0
## 镜头最低位置限制（格，正数表示向下最多到哪）
@export_range(0.0, 8.0, 0.1) var camera_floor_tiles: float = 0.5

@export_group("存档")
## 最高分存档路径
@export var save_path: String = "user://fox_best.save"

@onready var world: World = $World
@onready var player: Player = $World/Player
@onready var camera: Camera2D = $Camera2D
@onready var hud: HUD = $HUD

var state: State = State.MENU
var score := 0
var lives := GameConfig.MAX_LIVES
var best_score := 0
var altitude_px := 0.0               # 到达的最高高度（像素，向上为正）
var spawn_px := Vector2.ZERO         # 本局出生点

var _last_gen_row := 0


func _ready() -> void:
	randomize()
	_load_best()
	_build_start_screen()


func _build_start_screen() -> void:
	player.visible = false
	player.active = false
	state = State.MENU
	hud.show_start(best_score)


func start_game() -> void:
	score = 0
	lives = GameConfig.MAX_LIVES
	altitude_px = 0.0
	state = State.PLAYING
	hud.hide_overlays()

	world.reset()
	_last_gen_row = 0
	# 出生点在起始草地中心（第 0 行）
	spawn_px = player.grid_center_px(GameConfig.GRID_W / 2, 0)
	_extend_world(0)

	player.revive(spawn_px)
	player.visible = true
	player.active = true
	if not player.hit_car.is_connected(_on_player_hit):
		player.hit_car.connect(_on_player_hit)
	world.coin_picked_cb = _on_coin_picked

	_update_camera(0.0)
	hud.update_hud(score, lives, int(altitude_px / TILE), best_score)


func _extend_world(player_row: int) -> void:
	var target_top := player_row + GameConfig.GEN_ROWS_AHEAD
	if target_top > _last_gen_row:
		_last_gen_row = target_top
	var row_lo := maxi(1, player_row - GameConfig.KEEP_ROWS_BELOW)
	var row_hi := maxi(target_top, player_row + GameConfig.GEN_ROWS_AHEAD)
	world.ensure_range(row_lo, row_hi, player_row)
	world.spawn_coins_ahead(row_lo, row_hi)
	world.prune_coins(player_row)


## 金币被捡起（由 World 的 coin_picked_cb 回调）
func _on_coin_picked() -> void:
	if state != State.PLAYING or player.is_dead:
		return
	score += GameConfig.SCORE_COIN
	hud.update_hud(score, lives, int(altitude_px / TILE), best_score)


## ============ 输入 ============

func _unhandled_input(event: InputEvent) -> void:
	if state == State.MENU and event.is_action_pressed("ui_accept"):
		start_game()
		return
	if state == State.DEAD and event.is_action_pressed("ui_accept"):
		start_game()
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	if state == State.PAUSED and event.is_action_pressed("ui_accept"):
		_toggle_pause()
		return


func _toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		player.active = false
		hud.show_pause()
	elif state == State.PAUSED:
		state = State.PLAYING
		get_tree().paused = false
		player.active = true
		hud.hide_overlays()


## ============ 每帧：车流维护 + 世界扩建 + 计分 ============

func _physics_process(_delta: float) -> void:
	if state != State.PLAYING:
		return

	# 车流连续运行 + 回收 / 生成
	world.maintain()

	var cur_row := world.row_at_pixel_y(player.position.y)
	_extend_world(cur_row)
	world.set_highlight_row(cur_row)

	# 计分：按最高高度（像素）折算
	var height := -player.position.y
	if height > altitude_px:
		score += int((height - altitude_px) / float(TILE))
		altitude_px = height

	_update_camera(_delta)
	hud.update_hud(score, lives, int(altitude_px / TILE), best_score)


## ============ 失败 / 复活 ============

func _on_player_hit() -> void:
	if state != State.PLAYING:
		return
	_lose_life()


func _lose_life() -> void:
	lives -= 1
	player.die()
	await get_tree().create_timer(0.45).timeout
	if lives <= 0:
		_game_over()
	else:
		# 回到出生点草地区域（玩家下方最近安全行）
		var cur_row := world.row_at_pixel_y(player.position.y)
		var safe_row := _nearest_safe_row(cur_row)
		player.revive(player.grid_center_px(GameConfig.GRID_W / 2, safe_row))
		player.active = true
		world.set_highlight_row(safe_row)
		_extend_world(safe_row)
		_update_camera(0.0)
		hud.update_hud(score, lives, int(altitude_px / TILE), best_score)
		hud.flash("撞车！剩余 %d 条命" % lives)


func _nearest_safe_row(from_row: int) -> int:
	var r := from_row
	var guard := 0
	while guard < 60:
		guard += 1
		if world.is_safe_row(r):
			return r
		r -= 1
	return 0


func _game_over() -> void:
	state = State.DEAD
	player.active = false
	_save_best()
	hud.update_hud(score, lives, int(altitude_px / TILE), best_score)
	hud.show_game_over(score, best_score, int(altitude_px / TILE))


## ============ 镜头 ============

func _update_camera(_delta: float) -> void:
	# 平滑跟随玩家，但不让镜头低于起始位置太多
	var target_y := player.position.y + TILE * camera_lead_tiles
	target_y = minf(target_y, TILE * camera_floor_tiles)
	camera.position.y = lerpf(camera.position.y, target_y, camera_smooth * maxf(_delta, 0.0001))
	if _delta <= 0.0:
		camera.position.y = target_y


## ============ 存档 ============

func _save_best() -> void:
	if score > best_score:
		best_score = score
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_32(best_score)
			f.close()


func _load_best() -> void:
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			best_score = f.get_32()
			f.close()
