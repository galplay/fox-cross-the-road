extends Area2D
class_name Coin
## 金币：物理接触收集。
##
## 【编辑器可见】挂在 scenes/Coin.tscn 的根节点上，结构：
##     Coin (Area2D, coin.gd)
##     └── Shape (CollisionShape2D)   ← 圆形碰撞体（检查器可调半径）
##
## 金币自带旋转动画（靠 _draw 里的横向压缩模拟）。

signal picked

const TILE := 64

## ── 可导出参数 ──────────────────────────────────────────
@export_group("外观")
## 金币正面颜色
@export var face_color: Color = Color("#EF9F27")
## 金币边缘颜色
@export var edge_color: Color = Color("#854F0B")
## 金币半径（像素）
@export_range(6.0, 32.0, 1.0) var radius: float = 14.0
## 高光点颜色
@export var shine_color: Color = Color("#FAEEDA")

@export_group("动画")
## 旋转速度（弧度/秒）
@export_range(0.0, 10.0, 0.1) var spin_speed: float = 3.0
## ────────────────────────────────────────────────────

var grid_pos := Vector2i.ZERO
var _t := 0.0


func _ready() -> void:
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "Shape"
		add_child(cs)
	var shape := CircleShape2D.new()
	shape.radius = radius + 2.0
	cs.shape = shape
	collision_layer = 4
	collision_mask = 1          # 只检测玩家层
	monitoring = true
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Player:
		picked.emit()


func setup(g: Vector2i) -> void:
	grid_pos = g
	position = Vector2(g.x * TILE + 32, -(g.y * TILE) - 32)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta * spin_speed
	queue_redraw()


func _draw() -> void:
	var squash := cos(_t)
	draw_circle(Vector2.ZERO, radius, edge_color)
	var pts := PackedVector2Array()
	var w := maxf(radius * 0.86 * absf(squash), 1.5)
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * w, sin(a) * radius * 0.86))
	draw_colored_polygon(pts, face_color)
	if absf(squash) > 0.35:
		draw_circle(Vector2.ZERO, radius * 0.39, shine_color)
