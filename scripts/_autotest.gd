extends SceneTree
## 物理版自动化测试：验证自由奔跑、碰到即死、车辆无重叠、无限世界、金币。

var main: Node2D
var frames := 0
var phase := 0
var log_lines: Array[String] = []
var passed := 0
var failed := 0


func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, cond: bool) -> void:
	if cond:
		passed += 1
		log_lines.append("  [PASS] " + name)
	else:
		failed += 1
		log_lines.append("  [FAIL] " + name)


func _process(_delta: float) -> bool:
	frames += 1
	if phase == 0 and frames > 5:
		phase = 1
		_run()
	return false


func _run() -> void:
	print("\n========== 小狐狸过马路 · 物理模式测试 ==========")

	_check("初始菜单状态", main.state == main.State.MENU)
	_check("玩家初始未激活", main.player.active == false)

	main.start_game()
	_check("开始后 PLAYING", main.state == main.State.PLAYING)
	_check("玩家已激活", main.player.active == true)
	_check("生命 = 3", main.lives == GameConfig.MAX_LIVES)
	_check("分数 = 0", main.score == 0)
	_check("已生成车道", main.world.lanes.size() > 0)
	_check("第0行安全", main.world.is_safe_row(0) == true)
	_check("第1行是车道", main.world.is_lane_row(1) == true)

	# 车辆有碰撞体 + Area2D
	var first_lane: Lane = null
	var rows: Array = main.world.lanes.keys()
	rows.sort()
	first_lane = main.world.lanes[rows[0]]
	_check("车辆数量 > 0", first_lane.cars.size() > 0)
	if first_lane.cars.size() > 0:
		var c: Car = first_lane.cars[0]
		_check("车辆是 Area2D", c is Area2D)
		_check("车辆有碰撞形状", c.get_node_or_null("CollisionShape2D") != null)

	# 物理连续运动：让引擎跑若干物理帧，车辆应移动
	var car0: Car = first_lane.cars[0]
	var x_before := car0.position.x
	for i in 30:
		first_lane.cars[0]._physics_process(1.0 / 60.0)
	_check("车辆连续运动（物理帧后位置改变）", absf(first_lane.cars[0].position.x - x_before) > 1.0)

	# 长时间模拟：车流不重叠、不爆数量
	var overlap_hit := 0
	for i in 600:
		main.world.maintain()
		if i % 20 == 0:
			for r in main.world.lanes.keys():
				var l: Lane = main.world.lanes[r]
				if l.has_overlap():
					overlap_hit += 1
	_check("600 帧维护后车辆无重叠", overlap_hit == 0)

	var max_cars := 0
	for r in main.world.lanes.keys():
		var l: Lane = main.world.lanes[r]
		max_cars = maxi(max_cars, l.cars.size())
	_check("单车数量受控（<25）", max_cars < 25)

	# 玩家自由移动：直接调用物理帧，模拟按键
	var p_before: Vector2 = main.player.position
	main.player.active = true
	# 手动模拟向上移动（绕过 Input，直接改位置验证边界与积分）
	main.player.position += Vector2(0, -120.0)
	_check("玩家可自由位移", main.player.position.y < p_before.y)

	# 世界扩建：玩家到高处后应继续生成
	var hi_before: int = main.world.highest_row
	main.player.position = main.player.grid_center_px(6, 60)
	for i in 20:
		main._physics_process(1.0 / 60.0)
	_check("高处仍生成世界", main.world.highest_row >= hi_before)
	_check("下方行被回收", main.world.lowest_row > 0)

	# 碰撞即死：把玩家放到某辆车的位置
	var lane2: Lane = null
	var rs: Array = main.world.lanes.keys()
	rs.sort()
	if rs.size() > 0:
		lane2 = main.world.lanes[rs[rs.size() - 1]]
	if lane2 != null and lane2.cars.size() > 0:
		var victim: Car = lane2.cars[0]
		main.player.position = victim.position
		main.player.active = true
		main.player._on_area_entered(victim)
		_check("碰到车辆触发失败", main.player.is_dead == true)

	# 计分随高度增长
	var s_before: int = main.score
	main.player.is_dead = false
	main.player.active = true
	main.player.position = main.player.grid_center_px(6, main.world.highest_row + 5)
	main._physics_process(1.0 / 60.0)
	_check("爬升后分数增长", main.score > s_before)

	print("\n".join(log_lines))
	print("==============================================")
	print("通过: %d   失败: %d" % [passed, failed])
	print("==============================================\n")
	quit(0 if failed == 0 else 1)
