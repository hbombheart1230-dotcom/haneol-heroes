extends SceneTree
## 한 타 충격 확인용 프레임 띠: 실제 main 장면 (순신 · 한산)에 왜군 병사를 세우고 1타 / 1·2·3타 / 해룡참을 낸 뒤
## 영웅 둘레를 프레임마다 잘라 한 장에 늘어놓는다 (왼쪽 위 → 오른쪽 아래, 칸마다 경과 ms).
## godot --path . --resolution 720x1280 -s res://tools/shots/one_hit_shot.gd -- <hit1|combo|haeryong> <출력 png>

const FRAMES := 18
const EVERY := 2
const CROP := Vector2i(360, 360)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0]
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"hansan_1592"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.active = false
	await _wait(0.1)
	var player := main.get_node("Player") as Player
	var atk := player.get_node("AutoAttack") as AutoAttack
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	var soldier: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var list: Array = []
	var n := 3 if mode == "haeryong" else 1
	for i in n:
		var e := spawner.spawn_at(soldier, player.global_position + Vector2.from_angle(-0.3 + TAU * i / n) * 95.0)
		e.health.max = 9999
		e.health.current = 9999
		list.append(e)
	player.facing = (list[0].global_position - player.global_position).normalized()
	await _wait(3.2)  # 무대 제목 띠가 사라질 때까지
	var shots: Array[Image] = []
	var times := PackedFloat32Array()
	var t0 := Time.get_ticks_msec()
	if mode == "combo":
		atk.manual_strike(1, false, list)
		await _wait(0.28)
		atk.manual_strike(2, false, list)
		await _wait(0.3)
		t0 = Time.get_ticks_msec()
		atk.manual_strike(3, false, list)
	elif mode == "haeryong" and caster:
		caster.cast(SkillCaster.Slot.TAP)
	else:
		atk.manual_strike(1, false, list)
	for f in FRAMES:
		for k in EVERY:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var c := img.get_size() / 2 - CROP / 2 + Vector2i(0, -40)  # 카메라가 영웅을 따라간다
		c = c.clamp(Vector2i.ZERO, img.get_size() - CROP)
		shots.append(img.get_region(Rect2i(c, CROP)))
		times.append(Time.get_ticks_msec() - t0)
	var cols := 6
	var w := CROP.x * 2 / 3
	var h := CROP.y * 2 / 3
	var out := Image.create(w * cols, h * ceili(FRAMES / float(cols)), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var s := shots[i]
		s.convert(Image.FORMAT_RGBA8)
		s.resize(w, h)
		out.blit_rect(s, Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % cols) * w, (i / cols) * h))
	out.save_png(args[1])
	var f := FileAccess.open(args[1] + ".txt", FileAccess.WRITE)
	f.store_string(" ".join(Array(times).map(func(x: float) -> String: return "%d" % x)))
	f.close()
	quit()


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
