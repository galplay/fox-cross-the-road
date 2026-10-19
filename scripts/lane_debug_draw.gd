@tool
extends Node2D
class_name LaneDebugDraw
## 车道参考线（仅编辑器可见）。
##
## 在 Lane.tscn 中作为子节点存在，让你在编辑器里一眼看到
## 这条车道占据的横向区域与行驶方向箭头。运行时自动隐藏。

const TILE := 64

@export var lane_length_tiles: int = 13
@export var draw_color: Color = Color(0.9, 0.6, 0.2, 0.35)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var w := float(lane_length_tiles) * TILE
	draw_rect(Rect2(0, -TILE * 0.5, w, TILE), draw_color, false, 2.0)
	# 方向箭头
	var mid := Vector2(w * 0.5, 0)
	var parent := get_parent()
	var dir := 1
	if parent and "lane_dir" in parent:
		dir = int(parent.lane_dir)
	var tip := mid + Vector2(28.0 * float(dir), 0)
	draw_line(mid, tip, draw_color, 3.0)
	draw_line(tip, tip + Vector2(-10.0 * float(dir), -8.0), draw_color, 3.0)
	draw_line(tip, tip + Vector2(-10.0 * float(dir), 8.0), draw_color, 3.0)
