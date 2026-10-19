extends SceneTree
## 物理版截图：菜单 / 奔跑 / 撞车。
## 使用真实主循环驱动（不手动调用 _physics_process）。
## 截图改为「先标记，下一帧再抓」，避免在 _process 内 await 打断主循环。

var main: Node2D
var frames := 0
var shot_queue: Array[String] = []
var shots_done: Array[String] = []


func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1

	# 先处理上一帧排队的截图
	if shot_queue.size() > 0:
		var nm: String = shot_queue.pop_front()
		var img := root.get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art_shots"))
		var p := "res://art_shots/%s.png" % nm
		img.save_png(p)
		shots_done.append(nm)
		print("saved ", p)
		if shots_done.size() >= 3:
			print("全部截图完成")
			quit(0)
			return false

	if frames == 6:
		shot_queue.append("p_menu")
	elif frames == 20:
		main.start_game()
		# 先在草地停留一瞬，抓一张"开始画面"确认狐狸渲染
	elif frames == 40:
		shot_queue.append("p_start")
	elif frames == 45:
		Input.action_press("ui_up")
	elif frames == 66:
		# 上移约 21 帧 ≈ 84px，狐狸进入第 1 条马路行，验证马路上的渲染层级
		Input.action_release("ui_up")
		shot_queue.append("p_running")
	elif frames == 260:
		# 向右跑一段，验证镜像绘制（若已死亡则跳过）
		if main.state == 1:
			Input.action_press("ui_right")
	elif frames == 340:
		Input.action_release("ui_right")
		if main.state == 1:
			shot_queue.append("p_run_right")
		else:
			shot_queue.append("p_dead_late")
			print("WARN: 狐狸在右移阶段已死亡, state=", main.state)
	return false
