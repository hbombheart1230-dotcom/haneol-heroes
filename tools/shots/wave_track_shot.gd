extends SceneTree
## 물결 진행 표시 확인용 (1080x2400): 네 전장마다 물결 처음·중간·중간 우두머리·우두머리 때 화면을 찍는다.
## godot --path . -s res://tools/shots/wave_track_shot.gd -- <출력 폴더> [전장 번호 0~3]
## 파일: <폴더>/<전장>_<처음|중간|중간우두머리|우두머리>.png (전체 화면)

const STAGES := [["hansan_1592", "yi_sun_sin"], ["manchuria_395", "gwanggaeto"], ["chochungdo", "shin_saimdang"],
	["gyeongbokgung_1433", "sejong"]]

var sv: SubViewport


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _boot(stage: String, hero: String) -> Node:
	GameSettings.settings_path = GameSettings.test_path()
	DirAccess.remove_absolute(GameSettings.settings_path)
	GameSettings.hero_stages = {}
	GameSettings.hero_clears = {}
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_picked = true
	GameSettings.hero_id = StringName(hero)
	GameSettings.stage_picked = true
	GameSettings.stage_id = StringName(stage)
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.story_enabled = false
	sv = SubViewport.new()
	sv.size = Vector2i(1080, 2400)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	sv.add_child(main)
	await _frames(20)
	return main


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var only := int(args[1]) if args.size() > 1 else -1
	for si in STAGES.size():
		if only >= 0 and only != si:
			continue
		var main := await _boot(STAGES[si][0], STAGES[si][1])
		var sp := main.get_node("EnemySpawner") as EnemySpawner
		sp.active = false  # 물결이 저절로 넘어가지 않게
		var player := main.get_node("Player") as Player
		player.grant_invulnerability(999.0)
		var steps := [["처음", 0], ["중간", 1], ["중간우두머리", 2], ["우두머리", -1]]
		for st in steps:
			if st[1] >= 0:
				sp.waves.index = st[1]
				sp.waves.phase = WaveRunner.Phase.RUN
			else:
				sp.waves.index = sp.waves.data.waves.size() - 1
				sp.waves.phase = WaveRunner.Phase.BOSS
				var boss := sp.spawn_boss()
				boss.set_physics_process(false)
				for i in 6:
					if main.seal_choice and main.seal_choice.is_open():
						main.seal_choice.pick(0)
					await _frames(40)
			if st[1] >= 0:  # 물결 시작 알림 (무대 시작 문구가 지난 뒤)
				main.state.elapsed = 10.0
				main.hud.on_wave_announce(st[1], st[1] == 2)
				await _frames(14)
			await _frames(6)
			sv.get_texture().get_image().save_png("%s/%d_%s.png" % [dir, si, st[0]])
		sv.queue_free()
		await _frames(3)
	quit()
