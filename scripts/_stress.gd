extends SceneTree
## 物理版长时间压力测试：持续运行物理帧，验证车辆永不重叠、不爆量。

var main: Node2D
var frames := 0
var phase := 0


func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if phase == 0 and frames > 5:
		phase = 1
		_run()
	return false


func _run() -> void:
	main.start_game()
	var overlaps := 0
	var worst_gap := 99999.0
	var checks := 0
	var max_cars := 0
	var rows_seen := 0

	# 模拟 1200 个物理帧（20 秒游戏时间），玩家持续上行
	for f in 1200:
		if f % 4 == 0:
			main.player.position += Vector2(0, -2.0)
		main._physics_process(1.0 / 60.0)

		if f % 6 == 0:
			for r in main.world.lanes.keys():
				var lane: Lane = main.world.lanes[r]
				for car in lane.cars:
					car._physics_process(1.0 / 60.0)
				max_cars = maxi(max_cars, lane.cars.size())
				rows_seen = maxi(rows_seen, int(r))

		if f % 5 == 0:
			for r in main.world.lanes.keys():
				var lane: Lane = main.world.lanes[r]
				var rs: Array[Vector2] = []
				for car in lane.cars:
					rs.append(Vector2(car.left_px(), car.right_px()))
				rs.sort_custom(func(a, b): return a.x < b.x)
				for i in range(rs.size() - 1):
					var gap := rs[i + 1].x - rs[i].y
					worst_gap = minf(worst_gap, gap)
					checks += 1
					if gap < -1.0:
						overlaps += 1

	print("\n========== 物理版压力测试（1200 帧）==========")
	print("已生成到的最高行: %d" % rows_seen)
	print("车道总数: %d" % main.world.lanes.size())
	print("间距检查次数: %d" % checks)
	print("最小净间距: %.1f px（应 >= -1）" % worst_gap)
	print("重叠次数: %d" % overlaps)
	print("最高单车道车数: %d" % max_cars)
	print("结论: %s" % ("通过 ✓ 车辆从不重叠" if overlaps == 0 else "失败 ✗ 存在重叠"))
	print("==============================================\n")
	quit(0 if overlaps == 0 else 1)
