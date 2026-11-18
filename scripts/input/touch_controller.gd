class_name TouchController
extends Node
## 화면 터치 이벤트를 이동·대시·스킬 입력으로 나눠 보낸다 (터치 ID 기준).
## - 이동 손가락: 드래그 = 이동, 플릭 = 대시, 제스처 = 스킬 (한 손 조작, 기본)
## - 스킬 버튼(설정에서 켤 때만): 버튼 영역에서 시작한 터치는 스킬 전용
## - 버튼 켜기/끄기 토글: 화면 오른쪽 위
## _unhandled_input을 쓰므로 UI가 먼저 소비한 터치는 여기로 오지 않는다.

@export var player: Player
@export var skill_caster: SkillCaster
## 이동 손가락 제스처로 스킬 사용 (한 손 조작).
@export var gestures_enabled: bool = true
## 스킬 버튼 사용 여부. _ready에서 GameSettings 값으로 덮어쓴다.
@export var skill_button_enabled: bool = false
## 보이는 버튼 반지름 (뷰포트 px).
@export var skill_button_radius: float = 110.0
## 화면 오른쪽 아래 모서리에서 버튼 중심까지 거리 (뷰포트 px).
@export var skill_button_offset: Vector2 = Vector2(170, 300)
## 실제 터치 판정 범위 = 보이는 반지름 × 이 값.
@export var skill_button_hit_scale: float = 1.3
## 버튼 켜기/끄기 토글 영역 (화면 오른쪽 위 기준 크기).
@export var toggle_size: Vector2 = Vector2(150, 56)

var touch_input := TouchMoveInput.new()
## 디버그 HUD용 마지막 플릭 방향과 시각.
var last_flick_dir: Vector2 = Vector2.ZERO
var last_flick_time: float = -INF
## 토글을 누르고 있는 손가락 (-1 = 없음). 누르는 동안 다른 손가락은 토글하지 못한다.
var _toggle_index: int = -1


func _ready() -> void:
	GameSettings.load_settings()
	skill_button_enabled = GameSettings.skill_button_enabled


func _unhandled_input(event: InputEvent) -> void:
	if handle_event(event, Time.get_ticks_usec() / 1_000_000.0):
		get_viewport().set_input_as_handled()


## 테스트에서 시간을 직접 넣어 호출할 수 있다. 반환: 이벤트를 처리했으면 true.
func handle_event(event: InputEvent, time: float) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			return _on_down(touch.index, touch.position, time)
		return _on_up(touch.index, touch.position, time, touch.canceled)
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		return _on_drag(drag.index, drag.position, time)
	return false


func _on_down(index: int, pos: Vector2, time: float) -> bool:
	if is_on_toggle(pos):
		# 동시에 여러 손가락이 닿아도 한 번만 바뀐다 (Codex edeb579 지적).
		if _toggle_index == -1:
			_toggle_index = index
			set_skill_button_enabled(not skill_button_enabled)
		return true
	# 버튼 위에서 시작한 터치는 (스킬이 받지 않더라도) 이동 손가락이 되지 않는다.
	if is_on_skill_button(pos):
		skill_caster.on_press(index, time)
		return true
	if not touch_input.touch_down(index, pos, time):
		return false
	if gestures_enabled and skill_caster:
		skill_caster.gesture_down(index, pos, time)
	return true


func _on_drag(index: int, pos: Vector2, time: float) -> bool:
	if index == _toggle_index or _is_button_finger(index):
		return true
	if index != touch_input.get_move_index():
		return false
	if skill_caster:
		skill_caster.gesture_move(index, pos, time)
	var flick := touch_input.touch_move(index, pos, time)
	if not _is_charging():  # 충전 중 대시 연계는 P0 범위 밖
		_on_flick(flick, time)
	return true


func _on_up(index: int, pos: Vector2, time: float, canceled: bool) -> bool:
	if index == _toggle_index:
		_toggle_index = -1
		return true
	if _is_button_finger(index):
		if canceled:
			skill_caster.cancel_input()
		else:
			skill_caster.on_release(index, time)
		return true
	if index != touch_input.get_move_index():
		return false
	if canceled:
		touch_input.reset()
		if skill_caster:
			skill_caster.gesture_cancel(index)
		return true
	var charging := _is_charging()
	var flick := touch_input.touch_up(index, pos, time)
	if skill_caster:
		if flick != Vector2.ZERO and not charging:
			skill_caster.gesture_cancel(index)
		else:
			skill_caster.gesture_up(index, time)
	if not charging:
		_on_flick(flick, time)
	return true


func set_skill_button_enabled(enabled: bool) -> void:
	skill_button_enabled = enabled
	GameSettings.skill_button_enabled = enabled
	if is_inside_tree():
		GameSettings.save_settings()


func viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(720, 1280)


func skill_button_center() -> Vector2:
	return viewport_size() - skill_button_offset


func is_on_skill_button(pos: Vector2) -> bool:
	return skill_button_enabled and skill_caster != null \
		and pos.distance_to(skill_button_center()) <= skill_button_radius * skill_button_hit_scale


func toggle_rect() -> Rect2:
	return Rect2(Vector2(viewport_size().x - toggle_size.x - 12, 44), toggle_size)


func is_on_toggle(pos: Vector2) -> bool:
	return skill_caster != null and toggle_rect().has_point(pos)


func _is_button_finger(index: int) -> bool:
	return skill_caster != null and skill_caster.input.is_from(SkillInput.Source.BUTTON) \
		and skill_caster.input.index == index


func _is_charging() -> bool:
	return skill_caster != null and skill_caster.is_gesture_charging()


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
		_toggle_index = -1
		if skill_caster:
			skill_caster.cancel_input()
