class_name SettingsButton
extends Control
## 오른쪽 위 톱니 단추 (낡은 나무 톱니바퀴): 누르면 설정 화면을 연다. 어느 화면에서나 (제목·이야기·전투) 다른 화면보다 먼저 눌린다.

@export var screen: SettingsScreen
@export var radius: float = 34.0

const GEAR := preload("res://assets/ui/icons/settings_gear.png")

var _press_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func center() -> Vector2:
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	return Vector2(vp.x - 52.0, 112.0)


func is_on(pos: Vector2) -> bool:
	return pos.distance_to(center()) <= radius + 14.0


## 누름 처리 (테스트에서 직접 부른다). 단추 위의 누름이면 true (다른 화면으로 넘기지 않음).
func handle_touch(index: int, pos: Vector2, pressed: bool) -> bool:
	if screen == null or screen.is_open():
		return false
	if pressed:
		if not is_on(pos):
			return false
		_press_index = index
		queue_redraw()
		return true
	if index != _press_index:
		return false
	_press_index = -1
	queue_redraw()
	if is_on(pos):
		screen.open()
	return true


func _input(event: InputEvent) -> void:
	var used := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		used = handle_touch(t.index, t.position, t.pressed)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		used = handle_touch(1000, m.position, m.pressed)
	if used:
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	visible = screen != null and not screen.is_open()


## 낡은 나무 톱니바퀴 그림 (tools/art/make_settings_gear.py). 누르면 어두워지며 살짝 돈다.
func _draw() -> void:
	var c := center()
	var pressed := _press_index != -1
	var s := radius * 2.5
	draw_set_transform(c, deg_to_rad(20.0) if pressed else 0.0, Vector2.ONE)
	draw_texture_rect(GEAR, Rect2(-s * 0.5, -s * 0.5, s, s), false,
		Color(0.7, 0.62, 0.55) if pressed else Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
