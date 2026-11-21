class_name OpeningVideo
extends Control
## 오프닝 영상 (앱을 켜면 입장 화면 앞에 한 번): 세로 영상을 화면 폭에 맞춰 가운데, 위아래는 검게.
## 화면을 누르면 건너뛴다 (열린 뒤 0.3초는 받지 않음). 영상: assets/video/opening.ogv (Theora).

signal finished

@export var stream: VideoStream

var player: VideoStreamPlayer
var _t := 0.0
var _press_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open() -> void:
	if stream == null:
		finished.emit.call_deferred()
		return
	_t = 0.0
	_press_index = -1
	player = VideoStreamPlayer.new()
	player.stream = stream
	player.expand = true
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)
	player.finished.connect(finish, CONNECT_ONE_SHOT)
	_fit()
	show()
	player.play()


func is_open() -> bool:
	return visible


func _vp() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


## 영상을 화면 안에 비율 그대로 (가운데). 영상 크기를 모르면 화면 가득.
func video_rect() -> Rect2:
	var vp := _vp()
	var tex := player.get_video_texture() if player else null
	var vs := tex.get_size() if tex and tex.get_width() > 0 else Vector2(720, 1260)
	var k := minf(vp.x / vs.x, vp.y / vs.y)
	var s := vs * k
	return Rect2((vp - s) * 0.5, s)


func _fit() -> void:
	if player:
		var r := video_rect()
		player.position = r.position
		player.size = r.size


func finish() -> void:
	if not visible:
		return
	hide()
	if player:
		player.stop()
		player.queue_free()
		player = null
	finished.emit()


func handle_touch(index: int, pressed: bool) -> bool:
	if not visible or _t < 0.3:
		return false
	if pressed:
		_press_index = index
		return true
	if index == _press_index:
		_press_index = -1
		finish()
		return true
	return false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		handle_touch(e.index, e.pressed)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		handle_touch(1000, (event as InputEventMouseButton).pressed)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_fit()
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var vp := _vp()
	draw_rect(Rect2(Vector2.ZERO, vp), Color.BLACK)
	var a := clampf((_t - 1.0) * 2.0, 0.0, 0.7)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, vp.y - 36), "화면을 누르면 건너뜁니다", 22, Color(UiStyle.PAPER, a), vp.x)
