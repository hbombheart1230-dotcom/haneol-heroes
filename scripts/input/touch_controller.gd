class_name TouchController
extends Node
## 화면 터치 이벤트를 TouchMoveInput에 전달하고 결과를 플레이어에 적용한다.
## _unhandled_input을 쓰므로 UI(향후 스킬 버튼)가 먼저 소비한 터치는 이동에 쓰이지 않는다.

@export var player: Player
## P0-C 단일 스킬 버튼. 버튼 영역에서 시작한 터치는 이동이 아니라 스킬 입력으로 보낸다.
@export var skill_caster: SkillCaster
@export var skill_button_radius: float = 95.0
## 화면 오른쪽 아래 모서리에서 버튼 중심까지 거리 (뷰포트 px).
@export var skill_button_offset: Vector2 = Vector2(140, 230)

var touch_input := TouchMoveInput.new()
## 디버그 HUD용 마지막 플릭 방향과 시각.
var last_flick_dir: Vector2 = Vector2.ZERO
var last_flick_time: float = -INF


func _unhandled_input(event: InputEvent) -> void:
	if handle_event(event, Time.get_ticks_usec() / 1_000_000.0):
		get_viewport().set_input_as_handled()


## 테스트에서 시간을 직접 넣어 호출할 수 있다. 반환: 이벤트를 처리했으면 true.
func handle_event(event: InputEvent, time: float) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# 버튼 위에서 시작한 터치는 (스킬이 받지 않더라도) 이동 손가락이 되지 않는다.
			if is_on_skill_button(touch.position):
				skill_caster.on_press(touch.index, time)
				return true
			return touch_input.touch_down(touch.index, touch.position, time)
		if _is_skill_finger(touch.index):
			if touch.canceled:
				skill_caster.cancel_input()
			else:
				skill_caster.on_release(touch.index, time)
			return true
		if touch.index != touch_input.get_move_index():
			return false
		if touch.canceled:
			touch_input.reset()
			return true
		_on_flick(touch_input.touch_up(touch.index, touch.position, time), time)
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _is_skill_finger(drag.index):
			return true
		if drag.index != touch_input.get_move_index():
			return false
		_on_flick(touch_input.touch_move(drag.index, drag.position, time), time)
		return true
	return false


func viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(720, 1280)


func skill_button_center() -> Vector2:
	return viewport_size() - skill_button_offset


func is_on_skill_button(pos: Vector2) -> bool:
	return skill_caster != null and pos.distance_to(skill_button_center()) <= skill_button_radius


func _is_skill_finger(index: int) -> bool:
	return skill_caster != null and skill_caster.input.is_down() and skill_caster.input.index == index


func _on_flick(dir: Vector2, time: float) -> void:
	if dir == Vector2.ZERO:
		return
	last_flick_dir = dir
	last_flick_time = time
	if player:
		player.request_dash(dir)


func _physics_process(_delta: float) -> void:
	if player:
		player.set_move_input(touch_input.get_move_vector())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		touch_input.reset()
		if skill_caster:
			skill_caster.cancel_input()
