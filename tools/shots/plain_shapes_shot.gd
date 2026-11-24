extends SceneTree
## 전투 화면의 단순 도형 대신 먹·붓 결로 바꾼 것들을 찍는다 (1080x2400): 적 체력 막대·정예 막대·우두머리 막대,
## 내닫기 충전 표시, 적 화살, 포격 줄(한산)·불씨(만주) 예고, 적 장판.
## godot --path . -s res://tools/shots/plain_shapes_shot.gd -- <출력 폴더> <머리글자: before|after>
## 파일: <머리글자>_hansan.png (막대·충전·화살·포격 줄·장판), <머리글자>_manchuria.png (불씨)

var sv: SubViewport


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _boot(stage: StringName, hero: StringName) -> Node:
	GameSettings.settings_path = GameSettings.test_path()
	DirAccess.remove_absolute(GameSettings.settings_path)  # 앞 장면에서 저장된 설정이 섞이지 않게
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_picked = true
	GameSettings.hero_id = hero
	GameSettings.stage_picked = true
	GameSettings.stage_id = stage
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = true
	sv = SubViewport.new()
	sv.size = Vector2i(1080, 2400)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	sv.add_child(main)
	await _frames(20)
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	if sp.waves:
		sp.waves.phase = WaveRunner.Phase.BOSS  # 물결 건너뛰기
	await _frames(120)
	for i in 6:  # 강화 고르기가 열리면 닫고, 띠가 사라질 때까지
		if main.seal_choice and main.seal_choice.is_open():
			main.seal_choice.pick(0)
		await _frames(60)
	return main


func _shot(dir: String, name: String) -> void:
	await _frames(3)
	sv.get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _hurt(e: Enemy, frac: float) -> void:
	e.health.current = int(e.health.max * frac)


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var tag: String = OS.get_cmdline_user_args()[1]
	var main := await _boot(&"hansan_1592", &"yi_sun_sin")
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	player.grant_invulnerability(999.0)
	var c := player.global_position
	var foes := [["waegun_soldier", Vector2(-170, -230), 0.7], ["waegun_soldier", Vector2(30, -300), 0.4],
		["waegun_heavy", Vector2(200, -240), 0.55], ["waegun_elite", Vector2(-40, -140), 0.6],
		["waegun_flag", Vector2(260, -60), 0.9], ["jurchen_archer", Vector2(-240, 60), 0.8]]
	for f in foes:
		var d := load("res://data/enemies/%s.tres" % f[0]) as EnemyData
		var e := sp.spawn_at(d, c + f[1], Callable(), true)
		if e:
			_hurt(e, f[2])
			e.set_physics_process(false)  # 자리에 세워 둔다
	var boss := sp.spawn_boss()
	boss.global_position = c + Vector2(0, -520)
	boss.set_physics_process(false)
	_hurt(boss, 0.62)
	for i in 10:  # 강화 고르기가 다시 열리면 닫고 (열려 있으면 시간이 멈춘다), 우두머리 등장 띠가 사라질 때까지
		if main.seal_choice and main.seal_choice.is_open():
			main.seal_choice.pick(0)
		await _frames(40)
	player.dash.charges = 1  # 내닫기: 하나 찼고 하나는 차는 중, 하나 비어
	player.dash.max_charges = 3
	var ar := EnemyArrow.new()
	ar.direction = Vector2(1, 0.25).normalized()
	ar.position = c + Vector2(-180, 150)
	main.add_child(ar)
	ar.set_physics_process(false)
	var ar2 := EnemyArrow.new()
	ar2.direction = Vector2(-0.4, -1).normalized()
	ar2.position = c + Vector2(180, 250)
	main.add_child(ar2)
	ar2.set_physics_process(false)
	for n in main.find_children("*", "LaneStrike", true, false):
		var ls := n as LaneStrike
		ls._begin_warn()
		ls.clock.warn = ls.data.warn_time * 0.55
	await _shot(dir, tag + "_hansan")
	main.queue_free()
	sv.queue_free()
	await _frames(2)
	main = await _boot(&"manchuria_395", &"gwanggaeto")
	for n in main.find_children("*", "GrassFire", true, false):
		var gf := n as GrassFire
		gf.ember = gf._pick_ember()
		gf.clock.warn = gf.data.warn_time * 0.5
	await _shot(dir, tag + "_manchuria")
	quit()
