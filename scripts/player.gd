extends Area2D
class_name Player
## 小狐狸：物理自由奔跑。
## 按住方向键即以固定速度连续移动；碰到车（Area2D 接触）立刻失败。
##
## 【编辑器可见】挂在 scenes/Player.tscn 上，结构：
##     Player (Area2D, player.gd)
##     ├── Sprite (Node2D, fox_sprite.gd)   ← 狐狸图形
##     └── CollisionShape2D                 ← 碰撞盒（检查器可调）

signal hit_car
signal advanced(altitude_px: float)

const TILE := 64

## ── 可导出参数 ──────────────────────────────────────────
@export_group("移动")
## 奔跑速度（像素/秒）
@export_range(40.0, 800.0, 5.0) var speed_px: float = 240.0
## 是否允许玩家输入（游戏未开始时为 false）
@export var active: bool = false

@export_group("动画")
## 跑动时身体摆动幅度（弧度）
@export_range(0.0, 0.5, 0.01) var bob_amount: float = 0.10
## 跑动摆动频率
@export_range(1.0, 40.0, 1.0) var bob_rate: float = 16.0
## ────────────────────────────────────────────────────

var facing := 1
var is_dead := false

var _bob_t := 0.0
var _sprite: FoxSprite = null


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as FoxSprite
	# 必须高于 World 的路面（World.z_index=0）与车辆（Lane.z_index=2），
	# 否则会被父节点绘制的地面/车道覆盖而“消失”。
	z_index = 6
	area_entered.connect(_on_area_entered)


func setup(start_px: Vector2) -> void:
	position = start_px
	queue_redraw()


## 中心点 → 目标像素位置（保持与车道/金币中心对齐）
func grid_center_px(gx: int, gy: int) -> Vector2:
	return Vector2(float(gx) * TILE + TILE * 0.5, -float(gy) * TILE - TILE * 0.5)


func _physics_process(delta: float) -> void:
	if is_dead or not active:
		return
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		position += dir * speed_px * delta
		# 左右边界限制
		var half := 16.0
		position.x = clampf(position.x, half, float(GameConfig.GRID_W) * TILE - half)
		if dir.x != 0.0:
			# 只记录朝向；镜像由 FoxSprite 按 facing 绘制完成，
			# 不再翻转 scale（否则会二次镜像，图形错位甚至“消失”）。
			facing = 1 if dir.x > 0.0 else -1


func _process(delta: float) -> void:
	var moving := false
	if not is_dead and active:
		moving = Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down") \
			or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") \
			or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) \
			or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D)

	if moving:
		_bob_t += delta * bob_rate
		rotation = sin(_bob_t) * bob_amount
	else:
		_bob_t = 0.0
		rotation = lerp_angle(rotation, 0.0, 8.0 * delta)

	if _sprite:
		_sprite.facing = facing
		_sprite.moving = moving
		_sprite.tile_size = float(TILE)


func _on_area_entered(area: Area2D) -> void:
	if is_dead or not active:
		return
	if area is Car:
		is_dead = true
		hit_car.emit()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(scale.x * 1.3, 0.6), 0.10)
	tw.parallel().tween_property(self, "modulate", Color("#E24B4A"), 0.10)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)


func revive(at_px: Vector2) -> void:
	is_dead = false
	modulate = Color.WHITE
	scale = Vector2(1, 1)
	rotation = 0.0
	_bob_t = 0.0
	position = at_px
	queue_redraw()
