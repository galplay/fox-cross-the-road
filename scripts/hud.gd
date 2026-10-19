extends CanvasLayer
class_name HUD
## HUD：分数 / 生命 / 高度显示，以及开始、暂停、结束覆盖层。
##
## 【编辑器可见】挂在 scenes/HUD.tscn 上，所有 Label / 面板都是真实节点：
##     HUD (CanvasLayer, hud.gd)
##     ├── TopBar (HBoxContainer)
##     │   ├── ScoreLabel / LevelLabel / LivesLabel
##     ├── Toast (Label)
##     ├── StartPanel (Control)
##     │   ├── Dim (ColorRect) / Box (VBoxContainer) / Title / Body
##     ├── OverPanel (Control)  ← 同上结构
##     └── PausePanel (Control) ← 同上结构
## 位置、字号、颜色都可以直接在编辑器里拖 / 改。

const PANEL_TITLE_DEFAULT := "游戏结束"

@onready var score_label: Label = $TopBar/ScoreLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var lives_label: Label = $TopBar/LivesLabel
@onready var toast: Label = $Toast

@onready var start_panel: Control = $StartPanel
@onready var over_panel: Control = $OverPanel
@onready var pause_panel: Control = $PausePanel

@onready var start_body: Label = $StartPanel/Box/Body
@onready var over_title: Label = $OverPanel/Box/Title
@onready var over_body: Label = $OverPanel/Box/Body

var _toast_tween: Tween


func _ready() -> void:
	toast.modulate.a = 0.0


func flash(msg: String) -> void:
	toast.text = msg
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(0.9)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.35)


func show_start(best: int) -> void:
	start_panel.visible = true
	over_panel.visible = false
	pause_panel.visible = false
	start_body.text = (
		"方向键 / WASD 移动，自由奔跑穿过无尽车流\n吃到金币加分，走得越高分越多\n\n按 空格 或 任意方向键 开始\n最高分：%d" % best
	)


func show_game_over(final_score: int, best: int, altitude: int) -> void:
	over_title.text = PANEL_TITLE_DEFAULT
	over_body.text = ("到达高度：%d\n本局得分：%d\n历史最高：%d\n\n按 空格 重新开始" % [altitude, final_score, best])
	over_panel.visible = true


func show_pause() -> void:
	pause_panel.visible = true


func hide_overlays() -> void:
	start_panel.visible = false
	over_panel.visible = false
	pause_panel.visible = false


func update_hud(p_score: int, p_lives: int, p_altitude: int, p_best: int) -> void:
	score_label.text = "分数 %d   最高 %d" % [p_score, p_best]
	level_label.text = "高度 %d" % p_altitude
	var h := ""
	for i in p_lives:
		h += "♥"
	lives_label.text = "生命 %s" % (h if h != "" else "—")
