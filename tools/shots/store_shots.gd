extends SceneTree
## Play 스토어 폰 화면 사진 (1080×1920): 진짜 main.tscn을 띄워 입장 · 영웅 고르기 · 네 영웅 전투(순신은 우두머리전) · 강화 패 고르기.
## godot --path . -s res://tools/shots/store_shots.gd -- <출력 폴더>
## 창이 화면보다 작아도 되게 1080×1920 SubViewport(화면 크기 720×1280을 1.5배로 그림)에 장면을 띄운다.
## 저장은 시험용 설정 파일 (실제 설정을 건드리지 않음). 전투는 톡 연타를 진짜 입력으로 넣고 찍기 직전 기술 하나를 쓴다.

var out := "user://store"
var sv: SubViewport
var cur: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	sv = SubViewport.new()
	sv.size = Vector2i(1080, 1920)
	sv.size_2d_override = Vector2i(720, 1280)
	sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	_run()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot %s %dx%d" % [name, img.get_width(), img.get_height()])


func _tap(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = p
		e.pressed = pressed
		sv.push_input(e, true)
		await _wait(2)


func _open(title: bool, picked: bool, hero: StringName) -> Node:
	GameSettings.title_seen = not title
	GameSettings.hero_picked = picked
	GameSettings.hero_id = hero
	GameSettings.want_stage_list = true
	GameSettings.save_settings()  # 장면이 뜰 때 설정 파일을 다시 읽으므로 (시험용 파일)
	if cur:
		paused = false
		cur.free()
	cur = load("res://scenes/main.tscn").instantiate()
	sv.add_child(cur)
	await _wait(20)
	return cur


## 그 영웅의 첫 전장을 골라 판을 시작하고, 톡 연타를 넣으며 secs초 싸운다.
func _fight(hero: StringName, secs: float) -> Node:
	var m := await _open(false, true, hero)
	await _tap(m.stage_select.card_rect(0).get_center())
	m.player.health.damageable = false  # 찍는 동안 쓰러지지 않게 (붉은 화면·결과 화면 없이)
	print("%s run started: %s as %s" % [hero, not m.waiting_pick, m.player.hero.id])
	var vp := Vector2(720, 1280)
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		await _tap(vp * Vector2(0.5, 0.55))
		await _wait(8)
	return m


func _cast(m: Node, slot: SkillCaster.Slot) -> void:
	var sc := m.player.get_node_or_null("SkillCaster") as SkillCaster
	if sc:
		sc.cast(slot, 1.0)
	await _wait(12)


func _run() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.show_stats = false
	await _open(true, false, &"yi_sun_sin")
	await _wait(60)
	await _shot("01_title")
	await _open(false, false, &"yi_sun_sin")
	await _wait(30)
	await _shot("02_hero_select")
	var m := await _fight(&"gwanggaeto", 10.0)
	await _cast(m, SkillCaster.Slot.CHARGE)
	await _shot("04_gwanggaeto")
	m = await _fight(&"sejong", 10.0)
	await _cast(m, SkillCaster.Slot.CHARGE)
	await _shot("05_sejong")
	m = await _fight(&"shin_saimdang", 10.0)
	await _cast(m, SkillCaster.Slot.DASH)
	await _shot("06_saimdang")
	m = await _fight(&"yi_sun_sin", 6.0)
	m.spawner.spawn_boss()
	for i in 14:  # 등장 글귀가 지나갈 때까지 싸운다
		await _tap(Vector2(360, 704))
		await _wait(20)
	await _cast(m, SkillCaster.Slot.CHARGE)
	await _shot("03_yi_sun_sin_boss")
	m = await _fight(&"yi_sun_sin", 4.0)
	m.progress.pending += 1
	m.break_picks = 1
	m._offer_next()
	await _wait(60)
	await _shot("07_upgrade_cards")
	print("run? ", not m.waiting_pick)
	quit()
