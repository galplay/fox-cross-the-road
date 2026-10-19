extends Node2D
class_name CarBody
## 车身绘制节点（Car.tscn 的子节点 Body）。
##
## 只负责「画」——把 Car 根节点上的导出参数（长度/颜色/朝向）
## 呈现为可见图形。放在独立节点里，是为了在编辑器场景树中
## 一眼看到车辆由哪些部分组成，也方便单独替换美术。

const TILE := 64

## 车身长度（格）
@export_range(1, 4, 1) var length_tiles: int = 1:
	set(v):
		length_tiles = v
		queue_redraw()

## 车身颜色
@export var body_color: Color = Color("#7F77DD"):
	set(v):
		body_color = v
		queue_redraw()

## 朝向：+1 向右，-1 向左（决定挡风玻璃位置）
@export_enum("向左:-1", "向右:1") var facing: int = 1:
	set(v):
		facing = v
		queue_redraw()

## 由 Car 调用，同步外观并重绘
func configure(p_len: int, p_color: Color, p_facing: int) -> void:
	length_tiles = p_len
	body_color = p_color
	facing = p_facing
	queue_redraw()


func _draw() -> void:
	var total_w := float(length_tiles) * TILE
	var w := total_w - 8.0
	var h := TILE - 14.0
	var rect := Rect2(Vector2(4.0, -h * 0.5), Vector2(w, h))
	draw_rect(rect, body_color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.42)), body_color.lightened(0.15))
	var glass_x := rect.position.x + (rect.size.x * 0.66 if facing > 0 else rect.size.x * 0.18)
	draw_rect(Rect2(glass_x, rect.position.y + h * 0.14, rect.size.x * 0.14, h * 0.30), Color("#B5D4F4"))
	var lamp_x := rect.position.x + (rect.size.x - 6.0 if facing > 0 else 6.0)
	draw_circle(Vector2(lamp_x, rect.position.y + rect.size.y * 0.70), 3.0, Color("#FAEEDA"))
