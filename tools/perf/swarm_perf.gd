extends SceneTree
## 잡몹 떼 성능 재기: 실제 main 장면(무대·영웅 고름)에서 적 N마리를 영웅 둘레에 늘 채워 두고, 영웅이 탭 연타로 치고
## 죽이며(맞는 효과·처치 효과·먹 튐이 계속 생긴다) 프레임마다 처리 시간·그리기 호출·물체 수·메모리를 잰다.
## godot --path . --resolution 720x1280 -s res://tools/perf/swarm_perf.gd -- [무대 id] [영웅 id] [N들, 쉼표] [적 id] [nofire|noshader|none] [--live=0|1] [--boss]
## 결과 줄 (수직 동기 끔): PERF <무대> n=<N> frame_ms avg/p99 physics_ms draw_calls objects nodes obj_growth/s mem_growth_kb/s

const WARM := 60
const FRAMES := 300

var main: Node
var spawner: EnemySpawner
var player: Player
var caster: SkillCaster
## 원인 나누기: "nofire" = 도깨비불 끔, "noshader" = 적 테두리·망령 셰이더 끔.
var strip := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	var all := OS.get_cmdline_user_args()
	var args := Array(all).filter(func(a: String) -> bool: return not a.begins_with("--"))
	var flags := Array(all).filter(func(a: String) -> bool: return a.begins_with("--"))
	# --live=0|1: 실시간 3D 끄고 켜기 (hh/art/live3d), --boss: 무대 보스 하나를 세워 둔다 (안 죽게)
	for f in flags:
		if f.begins_with("--live="):
			ProjectSettings.set_setting("hh/art/live3d", f.ends_with("1"))
	var stage := StringName(args[0] if args.size() > 0 else "hansan_1592")
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"  # 사용자 설정을 건드리지 않게
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = stage
	GameSettings.hero_id = StringName(args[1] if args.size() > 1 else "yi_sun_sin")
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # 화면 주기에 묶이지 않은 한 프레임 비용
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	caster = player.get_node_or_null("SkillCaster") as SkillCaster
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.BOSS  # 물결은 멈추고 손으로 채운다
	var st: StageTheme = load("res://data/stages/%s.tres" % stage)
	var trash: EnemyData = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	strip = args[4] if args.size() > 4 else ""
	if strip == "nofire":
		for n in main.find_children("*", "GhostFire", true, false):
			n.queue_free()
	if args.size() > 3:  # 다른 적으로 바꿔 비교 (무대 탓인지 적 탓인지)
		trash = load("res://data/enemies/%s.tres" % args[3])
	await _wait(3.2)  # 무대 제목 띠
	player.grant_invulnerability(9999.0)
	if flags.has("--boss"):
		var b := spawner.spawn_boss()
		if b:
			b.global_position = player.global_position + Vector2(0, -260)
			b.health.max = 10000000
			b.health.current = 10000000
	await _measure(String(stage), trash, 10, false)  # 데우기 (셰이더·텍스처 첫 사용)
	for n_s in (args[2] if args.size() > 2 else "5,10,20").split(","):
		await _measure(String(stage), trash, int(n_s))
	quit()


func _measure(stage: String, d: EnemyData, n: int, report: bool = true) -> void:
	var frame := PackedFloat32Array()
	var phys := 0.0
	var draws := 0.0
	var objs := 0.0
	var nodes := 0.0
	var obj0 := 0.0
	var mem0 := 0.0
	var t0 := 0
	var tap := 0.0
	for i in WARM + FRAMES:
		_fill(d, n)
		tap -= 1.0 / 60.0
		if caster and tap <= 0.0:
			tap = 0.2
			caster.combo_tap()
		var before := Time.get_ticks_usec()
		await process_frame
		if i == WARM:
			obj0 = Performance.get_monitor(Performance.OBJECT_COUNT)
			mem0 = Performance.get_monitor(Performance.MEMORY_STATIC)
			t0 = Time.get_ticks_usec()
		if i < WARM:
			continue
		frame.append((Time.get_ticks_usec() - before) / 1000.0)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		nodes += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
	if not report:
		return
	var sorted := frame.duplicate()
	sorted.sort()
	var avg := 0.0
	for f in frame:
		avg += f
	print("PERF %s n=%d frame_ms %.2f/%.2f physics_ms %.2f draw_calls %d objects %d nodes %d obj_growth/s %.1f mem_growth_kb/s %.1f" % [
		stage, n, avg / FRAMES, sorted[int(FRAMES * 0.99)], phys / FRAMES, roundi(draws / FRAMES), roundi(objs / FRAMES),
		roundi(nodes / FRAMES), (Performance.get_monitor(Performance.OBJECT_COUNT) - obj0) / secs,
		(Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1024.0 / secs])


## 살아 있는 적을 n마리로 (영웅 둘레 120~260px).
func _fill(d: EnemyData, n: int) -> void:
	var alive := 0
	for c in spawner.get_children():
		if c is Enemy and not c.is_queued_for_deletion() and not (c as Enemy).health.is_dead():
			alive += 1
	for i in maxi(n - alive, 0):
		var at := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(120.0, 260.0)
		var e := spawner.spawn_at(d, at)
		if e and strip == "noshader" and e.sprite:
			e.sprite.material = null


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0
