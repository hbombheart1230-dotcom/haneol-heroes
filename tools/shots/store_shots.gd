extends SceneTree
## Play 스토어 폰 화면 사진 (1080×1920, 9:16): 진짜 main.tscn을 띄워 입장 · 영웅 고르기 · 네 영웅 × 네 전장 한 번씩 · 강화 패 고르기.
## 03 광개토 한산 원정 우두머리전 (부르기 단추) · 04 순신 만주 원정 (물결 알림·대사) · 05 세종 경복궁 (적 예고) · 06 사임당 초충도 (대사).
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


func _open(title: bool, picked: bool, hero: StringName, stage: StringName = &"") -> Node:
	GameSettings.title_seen = not title
	GameSettings.hero_picked = picked
	GameSettings.hero_id = hero
	GameSettings.want_stage_list = stage == &""
	GameSettings.stage_picked = stage != &""
	GameSettings.stage_id = stage
	GameSettings.tutorial_seen_heroes = PackedStringArray(["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"])
	GameSettings.save_settings()  # 장면이 뜰 때 설정 파일을 다시 읽으므로 (시험용 파일)
	if cur:
		paused = false
		cur.free()
	cur = load("res://scenes/main.tscn").instantiate()
	sv.add_child(cur)
	await _wait(20)
	return cur


## 그 영웅으로 그 전장 판을 바로 시작하고 (원정이면 부르기 단추), 톡 연타를 넣으며 secs초 싸운다.
func _fight(hero: StringName, stage: StringName, secs: float) -> Node:
	var m := await _open(false, true, hero, stage)
	m.player.health.damageable = false  # 찍는 동안 쓰러지지 않게 (붉은 화면·결과 화면 없이)
	print("%s @ %s started: %s" % [hero, m.run_stage_id(), not m.waiting_pick])
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		await _tap(Vector2(360, 704))
		await _wait(8)
	return m


## until이 참이 될 때까지 (최대 n번) 톡 치며 싸운다.
func _fight_until(m: Node, until: Callable, n: int, gap: int = 4) -> bool:
	for i in n:
		if until.call():
			return true
		await _tap(Vector2(360, 704))
		await _wait(gap)
	return until.call()


func _cast(m: Node, slot: SkillCaster.Slot) -> void:
	var sc := m.player.get_node_or_null("SkillCaster") as SkillCaster
	if sc:
		sc.cast(slot, 1.0)
	await _wait(12)


## 화면 안 적 하나가 공격 예고(WINDUP) 중인지.
func _telegraph(m: Node) -> bool:
	for e in m.get_tree().get_nodes_in_group(Enemy.GROUP):
		var en := e as Enemy
		if en and en.attack and en.attack.state == EnemyAttack.State.WINDUP and not en.is_queued_for_deletion():
			return true
	return false


func _run() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = true
	GameSettings.story_enabled = true  # 영웅 머리 위 대사
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.show_stats = false
	await _open(true, false, &"yi_sun_sin")
	await _wait(60)
	await _shot("01_title")
	await _open(false, false, &"yi_sun_sin")
	await _wait(30)
	await _shot("02_hero_select")
	# 04 순신 · 만주 원정: 물결 알림 띠 + 들어설 때 대사
	var m := await _fight(&"yi_sun_sin", &"manchuria_395", 2.5)
	var ok := await _fight_until(m, func() -> bool: return m.hud._wave_banner.is_showing() and m.hud._wave_banner._age > 0.6, 160)
	print("04 wave=%s line=%s" % [ok, m.hero_lines.text])
	await _shot("04_yi_sun_sin_manchuria")
	# 05 세종 · 경복궁: 적 공격 예고 (먹 붓 테)
	m = await _fight(&"sejong", &"gyeongbokgung_1433", 6.0)
	ok = await _fight_until(m, func() -> bool: return _telegraph(m), 400, 2)
	await _wait(6)  # 예고가 조금 차오르게
	print("05 telegraph=%s" % ok)
	await _shot("05_sejong_gyeongbok")
	# 06 사임당 · 초충도: 들어설 때 대사
	m = await _fight(&"shin_saimdang", &"chochungdo", 2.0)
	ok = await _fight_until(m, func() -> bool: return m.hero_lines.text != "" and m.hero_lines._left > 1.2, 200)
	print("06 line=%s" % m.hero_lines.text)
	await _cast(m, SkillCaster.Slot.DASH)
	await _shot("06_saimdang_chochung")
	# 03 광개토 · 한산 원정 우두머리전: 부르기 단추 (오른쪽 아래) + 우두머리 대사
	m = await _fight(&"gwanggaeto", &"hansan_1592", 6.0)
	m.spawner.spawn_boss()
	ok = await _fight_until(m, func() -> bool: return m.hero_lines._said.has(HeroLines.Case.BOSS) and m.hero_lines._left > 1.0, 260)
	var shown := false
	for c in m.hud.get_children():
		if c is HomeSummonButton:
			shown = (c as HomeSummonButton).shown()
	print("03 boss line=%s summon=%s" % [m.hero_lines.text, shown])
	for i in 25:  # 우두머리 이름 띠가 다 사라질 때까지 더 싸운다 (대사보다 띠 없는 화면을 고름)
		await _tap(Vector2(360, 704))
		await _wait(6)
	await _shot("03_gwanggaeto_hansan_boss")
	# 07 강화 패 고르기 (새 틀·실제 값)
	m = await _fight(&"yi_sun_sin", &"hansan_1592", 4.0)
	m.progress.pending += 1
	m.break_picks = 1
	m._offer_next()
	await _wait(60)
	await _shot("07_upgrade_cards")
	print("run? ", not m.waiting_pick)
	quit()
