extends SceneTree
## 모으는 중 끌기 (실제 터치 입력, Input.parse_input_event): 누르고 모으기 → 왼쪽으로 천천히 끌기(조준) → 칸 띠.
## 칸: 모으기 시작 · 끄는 중 넷. 그림이 모으는 자세를 지키고 몸만 끄는 쪽으로 도는지 본다 (사용자 6d0635c "순신이 일어남").
## godot --path . --resolution 720x1280 -s res://tools/shots/charge_pose_shot.gd -- <2d|3d> <출력 png> [영웅 id=yi_sun_sin]

const CROP := Vector2i(260, 300)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	ProjectSettings.set_setting("hh/art/live3d", args[0] == "3d")
	var main: Node = await ShotStage.open(self, &"hansan_1592", StringName(args[2]) if args.size() > 2 else &"yi_sun_sin")
	await _wait(3.0)
	ShotStage.move_hero(main, ShotStage.brazier_spot(main) + Vector2(0, 200))
	await _wait(0.5)
	var at := Vector2(360, 1000)
	_touch(at, true)
	await _wait(0.6)
	var shots: Array[Image] = []
	shots.append(await _grab())
	for i in 24:
		at += Vector2(-6, 2)
		_drag(at)
		await _wait(0.03)
		if i % 6 == 5:
			shots.append(await _grab())
	_touch(at, false)
	var out := Image.create(CROP.x * shots.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	out.save_png(args[1])
	quit()


func _touch(p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)


func _drag(p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	e.relative = Vector2(-6, 2)
	Input.parse_input_event(e)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var c := (img.get_size() / 2 - CROP / 2 + Vector2i(20, -60)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
