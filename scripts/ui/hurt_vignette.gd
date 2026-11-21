class_name HurtVignette
extends Control
## 영웅이 맞으면 화면 가장자리가 잠깐 붉게 (R3). 실제 시간으로 줄어든다 (타격 멈춤·슬로에 늘어지지 않게).
## 수치는 CombatFeelData.reaction (vignette_*).

@export var player: Player

var _left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if player:
		player.hurt.connect(func(_a: int) -> void: flash())


func flash() -> void:
	_left = Feedback.feel_data().reaction_data().vignette_time
	queue_redraw()


## 지금 진하기 (0~1 × vignette_alpha).
func strength() -> float:
	var d := Feedback.feel_data().reaction_data()
	if _left <= 0.0 or d.vignette_time <= 0.0:
		return 0.0
	return d.vignette_alpha * _left / d.vignette_time


func step(real_delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - real_delta, 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	step(delta / maxf(Engine.time_scale, 0.001))


func _draw() -> void:
	var a := strength()
	if a <= 0.0:
		return
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	BossBanner.draw_edge_glow(self, vp, Feedback.feel_data().reaction_data().vignette_color, a, 0.28)
