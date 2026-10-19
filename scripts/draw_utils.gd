class_name DrawUtils
extends RefCounted
## 纯代码绘图工具：不依赖任何外部美术资源。


## 画一只小狐狸。
## size 为格边长；facing 表示面朝方向（1 右 / -1 左）。
##
## 坐标基准（与 Car 一致）：节点原点 = 格中心。
## 即狐狸的身体中心画在 (0, bias) 处，bias 仅用于把视觉重心
## （头/耳偏重）微微下压，使身体压在车道中心线上。
const FOX_Y_BIAS := 0.06        # 以 size 为单位的向下补偿
const FOX_SCALE := 0.92         # 整体缩放

static func draw_fox(ci: CanvasItem, size: float, facing: int, moving: bool = false) -> void:
	var s := size * FOX_SCALE
	var cx := 0.0
	var cy := size * FOX_Y_BIAS
	# 尾巴（身后，用扇形三角近似）
	var tail_dir := -float(facing)
	var tail := PackedVector2Array([
		Vector2(cx + tail_dir * s * 0.28, cy + s * 0.10),
		Vector2(cx + tail_dir * s * 0.55, cy - s * 0.12),
		Vector2(cx + tail_dir * s * 0.40, cy + s * 0.28),
	])
	ci.draw_colored_polygon(tail, C_FOX_BODY())
	# 尾巴尖白
	var tip := PackedVector2Array([
		Vector2(cx + tail_dir * s * 0.44, cy - s * 0.05),
		Vector2(cx + tail_dir * s * 0.55, cy - s * 0.12),
		Vector2(cx + tail_dir * s * 0.48, cy + s * 0.06),
	])
	ci.draw_colored_polygon(tip, Color.WHITE)
	# 身体（圆角矩形）
	var body := Rect2(cx - s * 0.30, cy - s * 0.30, s * 0.60, s * 0.62)
	ci.draw_rect(body, C_FOX_BODY())
	# 头部
	var head_r := s * 0.24
	ci.draw_circle(Vector2(cx + float(facing) * s * 0.06, cy - s * 0.24), head_r, C_FOX_BODY())
	# 耳朵（两个三角）
	var ear_y := cy - s * 0.42
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s * 0.16, ear_y + s * 0.10),
		Vector2(cx - s * 0.08, ear_y - s * 0.06),
		Vector2(cx - s * 0.01, ear_y + s * 0.10),
	]), C_FOX_DARK())
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx + s * 0.02, ear_y + s * 0.10),
		Vector2(cx + s * 0.09, ear_y - s * 0.06),
		Vector2(cx + s * 0.16, ear_y + s * 0.10),
	]), C_FOX_DARK())
	# 口鼻
	ci.draw_circle(Vector2(cx + float(facing) * s * 0.12, cy - s * 0.17), s * 0.09, C_FOX_FACE())
	# 眼睛
	ci.draw_circle(Vector2(cx + float(facing) * s * 0.10, cy - s * 0.28), s * 0.035, Color("#2C2C2A"))
	# 脚（移动时交替抬起）
	var foot_a := s * 0.05 if moving else 0.0
	ci.draw_rect(Rect2(cx - s * 0.22, cy + s * 0.30 - foot_a, s * 0.16, s * 0.08), C_FOX_DARK())
	ci.draw_rect(Rect2(cx + s * 0.06, cy + s * 0.30 + foot_a, s * 0.16, s * 0.08), C_FOX_DARK())


## 画一辆车。含挡风玻璃与车轮。
static func draw_car(ci: CanvasItem, w: float, h: float, body: Color, facing: int) -> void:
	var r := minf(h * 0.22, 10.0)
	ci.draw_rect(Rect2(0, 0, w, h), body)
	# 车顶 / 驾驶舱
	var cab := Rect2(w * 0.18, h * 0.10, w * 0.64, h * 0.34)
	ci.draw_rect(cab, body.lightened(0.18))
	# 挡风玻璃（朝向侧）
	var glass := Rect2(
		w * 0.62 if facing > 0 else w * 0.22,
		h * 0.16, w * 0.16, h * 0.22
	)
	ci.draw_rect(glass, Color("#B5D4F4"))
	# 车轮
	var wr := h * 0.24
	ci.draw_circle(Vector2(w * 0.26, h), wr, Color("#2C2C2A"))
	ci.draw_circle(Vector2(w * 0.74, h), wr, Color("#2C2C2A"))


## 画一枚金币（用 scale_x 模拟旋转）
static func draw_coin(ci: CanvasItem, size: float, squash: float) -> void:
	var r := size * 0.32
	var w := maxf(r * absf(squash), 1.0)
	# 外圈
	ci.draw_circle(Vector2.ZERO, r, C_COIN_EDGE())
	# 内圆（椭圆压缩）
	var pts := PackedVector2Array()
	var seg := 24
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(Vector2(cos(a) * w * 0.82, sin(a) * r * 0.82))
	ci.draw_colored_polygon(pts, C_COIN())


## 画草地砖（带小草点）
static func draw_grass(ci: CanvasItem, rect: Rect2, seed_val: int, with_blades: bool = true) -> void:
	ci.draw_rect(rect, GameConfig.C_GRASS)
	ci.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), GameConfig.C_GRASS_EDGE, 2.0)
	if not with_blades:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var cols := int(rect.size.x / 16.0)
	for i in cols:
		var x := rect.position.x + 8.0 + float(i) * 16.0 + rng.randf_range(-4, 4)
		var y := rect.position.y + rng.randf_range(6.0, maxf(rect.size.y - 6.0, 7.0))
		var hgt := rng.randf_range(4.0, 8.0)
		ci.draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-3, 3), y - hgt), GameConfig.C_GRASS_EDGE, 1.5)


static func C_FOX_BODY() -> Color:
	return Color("#EF9F27")


static func C_FOX_FACE() -> Color:
	return Color("#FAEEDA")


static func C_FOX_DARK() -> Color:
	return Color("#854F0B")


static func C_COIN() -> Color:
	return Color("#EF9F27")


static func C_COIN_EDGE() -> Color:
	return Color("#854F0B")
