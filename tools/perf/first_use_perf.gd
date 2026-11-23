extends SceneTree
## 효과 첫 사용 멈칫 재기: 실제 main 장면에서 평타 1·2·3타, 탭 마무리, 대시·충전·반격 기술, 적 처치를 차례로 한 번씩 하고
## 각 동작 뒤 FRAMES프레임의 최대 프레임(ms)과 그 프레임의 그리기 CPU 시간(ms)을 적는다. 같은 차례를 한 번 더 해서 두 번째와 비교.
## 큰 프레임에서 그리기 시간이 크면 그리기 쪽(셰이더 컴파일·텍스처 첫 업로드), 작으면 스크립트 쪽(장면 만들기·불러오기·소리).
## godot --path . --resolution 720x1280 -s res://tools/perf/first_use_perf.gd -- [무대 id] [영웅 id] [nowarm | skip=sheets,shapes,flow,draw]
## 결과 줄: FIRSTUSE <영웅> <차례> <동작> max_ms <ms> render_ms <ms>  /  LOAD <영웅> ready_ms <ms> (main 넣고 첫 물결 전까지)

const FRAMES := 40

var main: Node
var player: Player
var caster: SkillCaster
var spawner: EnemySpawner
var trash: EnemyData
var hero := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var stage := StringName(args[0] if args.size() > 0 else "hansan_1592")
	hero = args[1] if args.size() > 1 else "yi_sun_sin"
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"  # 사용자 설정을 건드리지 않게
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = stage
	GameSettings.hero_id = StringName(hero)
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	GameSettings.save_settings()  # 조작 장치가 _ready에서 이 파일을 다시 읽으므로 (안 쓰면 지난번 영웅으로 돌아간다)
	if args.size() > 2 and args[2] == "nowarm":
		FxWarmup.enabled = false
	elif args.size() > 2 and args[2].begins_with("skip="):  # 원인 나누기: skip=flow,draw …
		FxWarmup.skip = args[2].trim_prefix("skip=").split(",")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var t0 := Time.get_ticks_usec()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var worst_load := 0.0
	for i in 10:
		var b := Time.get_ticks_usec()
		await process_frame
		worst_load = maxf(worst_load, (Time.get_ticks_usec() - b) / 1000.0)
	print("LOAD %s ready_ms %.0f worst_frame_ms %.0f warmup_ms %.0f %s" % [hero, (Time.get_ticks_usec() - t0) / 1000.0, worst_load,
		FxWarmup.last_ms, FxWarmup.last_counts])
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	caster = player.get_node_or_null("SkillCaster") as SkillCaster
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.BOSS  # 물결은 멈추고 손으로 채운다
	var st: StageTheme = load("res://data/stages/%s.tres" % stage)
	trash = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	await _frames(200)  # 무대 제목 띠
	player.grant_invulnerability(9999.0)
	for round in [1, 2]:
		await _sequence(round)
	quit()


func _sequence(round: int) -> void:
	_fill(3)
	await _frames(20)
	for i in 3:  # 평타 1·2·3타 (손 탭)
		var atk := caster.auto_attack()
		while not atk.can_manual(caster.tap_gap()):
			await process_frame
		caster.combo_tap()
		await _record(round, "tap%d" % (i + 1))
	caster.reset_cooldown(SkillCaster.Slot.TAP)
	for k in 30:  # 탭 마무리 (3타가 닿은 뒤)
		if caster.combo_tap() == SkillCaster.Slot.TAP:
			break
		await process_frame
	await _record(round, "finisher")
	for pair in [[SkillCaster.Slot.DASH, "dash_skill"], [SkillCaster.Slot.CHARGE, "charge"], [SkillCaster.Slot.COUNTER, "counter"]]:
		_fill(3)
		await _frames(10)
		caster.reset_cooldown(pair[0])
		var c0 := Time.get_ticks_usec()
		caster.cast(pair[0], 1.0)
		print("CASTCALL %s %d %s ms %.1f" % [hero, round, pair[1], (Time.get_ticks_usec() - c0) / 1000.0])
		await _record(round, pair[1])
	_fill(3)
	await _frames(10)
	for c in spawner.get_children():  # 처치 (죽는 효과)
		if c is Enemy and not (c as Enemy).health.is_dead():
			(c as Enemy).health.damage(99999)
			break
	await _record(round, "kill")
	await _frames(60)


func _record(round: int, what: String) -> void:
	var worst := 0.0
	var proc := 0.0
	var at := 0
	for i in FRAMES:
		var b := Time.get_ticks_usec()
		await process_frame
		var ms := (Time.get_ticks_usec() - b) / 1000.0
		if ms > worst:
			worst = ms
			at = i
			proc = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
	print("FIRSTUSE %s %d %s max_ms %.1f render_ms %.1f frame %d" % [hero, round, what, worst, proc, at])


func _fill(n: int) -> void:
	var alive := 0
	for c in spawner.get_children():
		if c is Enemy and not c.is_queued_for_deletion() and not (c as Enemy).health.is_dead():
			alive += 1
	for i in maxi(n - alive, 0):
		spawner.spawn_at(trash, player.global_position + Vector2.from_angle(TAU * i / 3.0) * 150.0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
