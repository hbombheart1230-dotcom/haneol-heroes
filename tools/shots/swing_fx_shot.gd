extends SceneTree
## 순신 연타 검기 전·후: 실제 한산 장면, 3D 순신 오른쪽에 왜군 병사. 1·2·3타마다 칼이 닿는 순간(윗줄)과 0.07초 뒤(아랫줄).
## "before"면 같은 판에서 예전으로 (칼을 따라 그리는 궤적 SwingTrail, 평타 재생 배율 1 = 0.19초에 닿음).
## 탭에서 닿기까지 걸린 시간을 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/swing_fx_shot.gd -- <before|after> <출력 png>

const CROP := Vector2i(360, 360)

var _hit := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self)
	await _wait(3.2)
	var player := main.get_node("Player") as Player
	if args[0] == "before":
		player.hero = player.hero.duplicate()
		player.hero.blade_bite = player.hero.blade_bite.duplicate()
		player.hero.blade_bite.swing_speed = 1.0
		var trail := _find_trail(main)
		if trail:
			trail.data = trail.data.duplicate()
			trail.data.heroes = PackedStringArray(["yi_sun_sin"])
			player.set_meta(&"swing_trail", trail.data)
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	process_frame.connect(func() -> void: atk.hold_auto(0.5))  # 자동 평타 없이 손 탭만
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var e := spawner.spawn_at(data, spot + Vector2(110, 0))
	e.global_position = spot + Vector2(110, 0)
	e.health.max = 99999
	e.health.current = 99999
	e.attack = null
	await _wait(0.4)
	atk.melee_swung.connect(func(_d: Vector2, hits: int) -> void: _hit = hits > 0)
	var top: Array[Image] = []
	var low: Array[Image] = []
	var times: PackedStringArray = []
	for i in 3:
		var guard := 0
		while not atk.can_manual(caster.tap_gap()) and guard < 200:
			await physics_frame
			guard += 1
		e.global_position = player.global_position + Vector2(110, 0)
		_hit = false
		caster.combo_tap()
		var t0 := Time.get_ticks_msec()
		var w := 0
		while not _hit and w < 120:
			await physics_frame
			w += 1
		times.append("%d타 %dms" % [i + 1, Time.get_ticks_msec() - t0])
		await RenderingServer.frame_post_draw
		top.append(_grab())
		await _wait(0.07)
		await RenderingServer.frame_post_draw
		low.append(_grab())
		await _wait(0.35)
	print("SWING_FX %s %s" % [args[0], " ".join(times)])
	var out := Image.create(CROP.x * 3, CROP.y * 2, false, Image.FORMAT_RGBA8)
	for i in 3:
		out.blit_rect(top[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
		out.blit_rect(low[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, CROP.y))
	out.save_png(args[1])
	quit()


func _find_trail(n: Node) -> SwingTrail:
	if n is SwingTrail:
		return n
	for c in n.get_children():
		var t := _find_trail(c)
		if t:
			return t
	return null


func _grab() -> Image:
	var img := root.get_texture().get_image()
	var c := (img.get_size() / 2 - CROP / 2 + Vector2i(30, -40)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
