extends Node2D
class_name FoxSprite
## 小狐狸绘制节点（Player.tscn 的子节点 Sprite）。
##
## 只负责「画」狐狸。朝向、是否在跑动由 Player 根节点写入，
## 也可在编辑器检查器中单独调整预览。

## 格边长（像素）——决定狐狸大小
@export_range(16.0, 128.0, 1.0) var tile_size: float = 64.0:
	set(v):
		tile_size = v
		queue_redraw()

## 朝向：+1 向右，-1 向左
@export_enum("向左:-1", "向右:1") var facing: int = 1:
	set(v):
		facing = v
		queue_redraw()

## 是否处于跑动状态（影响脚步抬起）
@export var moving: bool = false:
	set(v):
		moving = v
		queue_redraw()

## 整体缩放（相对格边长）
@export_range(0.3, 1.5, 0.01) var fox_scale: float = 0.92:
	set(v):
		fox_scale = v
		queue_redraw()

## 视觉重心下压比例（以格边长为单位）
@export_range(-0.5, 0.5, 0.01) var y_bias: float = 0.06:
	set(v):
		y_bias = v
		queue_redraw()


func _draw() -> void:
	var s := tile_size * fox_scale
	var cx := 0.0
	var cy := tile_size * y_bias
	# 尾巴（身后，用扇形三角近似）
	var tail_dir := -float(facing)
	var tail := PackedVector2Array([
		Vector2(cx + tail_dir * s * 0.28, cy + s * 0.10),
		Vector2(cx + tail_dir * s * 0.55, cy - s * 0.12),
		Vector2(cx + tail_dir * s * 0.40, cy + s * 0.28),
	])
	draw_colored_polygon(tail, DrawUtils.C_FOX_BODY())
	# 尾巴尖白
	var tip := PackedVector2Array([
		Vector2(cx + tail_dir * s * 0.44, cy - s * 0.05),
		Vector2(cx + tail_dir * s * 0.55, cy - s * 0.12),
		Vector2(cx + tail_dir * s * 0.48, cy + s * 0.06),
	])
	draw_colored_polygon(tip, Color.WHITE)
	# 身体（圆角矩形）
	var body := Rect2(cx - s * 0.30, cy - s * 0.30, s * 0.60, s * 0.62)
	draw_rect(body, DrawUtils.C_FOX_BODY())
	# 头部
	var head_r := s * 0.24
	draw_circle(Vector2(cx + float(facing) * s * 0.06, cy - s * 0.24), head_r, DrawUtils.C_FOX_BODY())
	# 耳朵（两个三角）
	var ear_y := cy - s * 0.42
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s * 0.16, ear_y + s * 0.10),
		Vector2(cx - s * 0.08, ear_y - s * 0.06),
		Vector2(cx - s * 0.01, ear_y + s * 0.10),
	]), DrawUtils.C_FOX_DARK())
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + s * 0.02, ear_y + s * 0.10),
		Vector2(cx + s * 0.09, ear_y - s * 0.06),
		Vector2(cx + s * 0.16, ear_y + s * 0.10),
	]), DrawUtils.C_FOX_DARK())
	# 口鼻
	draw_circle(Vector2(cx + float(facing) * s * 0.12, cy - s * 0.17), s * 0.09, DrawUtils.C_FOX_FACE())
	# 眼睛
	draw_circle(Vector2(cx + float(facing) * s * 0.10, cy - s * 0.28), s * 0.035, Color("#2C2C2A"))
	# 脚（移动时交替抬起）
	var foot_a := s * 0.05 if moving else 0.0
	draw_rect(Rect2(cx - s * 0.22, cy + s * 0.30 - foot_a, s * 0.16, s * 0.08), DrawUtils.C_FOX_DARK())
	draw_rect(Rect2(cx + s * 0.06, cy + s * 0.30 + foot_a, s * 0.16, s * 0.08), DrawUtils.C_FOX_DARK())
