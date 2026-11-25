extends SceneTree
## 중간 우두머리 구간 끊김 재기 (사용자 S20 d311b10: "좀 끊긴다, 중간 우두머리쯤"): 실제 main 장면을 3물결(셋 무리)부터
## 굴리고 (영웅 무적, 탭 연타), 프레임마다 실제 시간·스크립트(process)·물리·그리기 호출·적 수를 적는다.
## 셋이 나오는 순간 앞뒤 1초의 가장 큰 프레임(첫 불러오기 멈칫)과, 구간별(셋 전 잡몹 / 셋 싸움) 평균·99%·최대를 낸다.
## godot --path . --resolution 720x1280 -s res://tools/perf/mid_boss_perf.gd -- [무대 id] [영웅 id] [초]
## 결과 줄: MIDPERF <구간> frames <n> avg_ms <ms> p99_ms <ms> max_ms <ms> process_ms <ms> physics_ms <ms> draws <n> enemies <n>
##          MIDSPIKE t <초> frame_ms <ms> (셋 등장 ±1초 최대)  /  HITCH t <초> ms <ms> enemies <n> (33ms 넘는 프레임)

var main: Node
var spawner: EnemySpawner
var player: Player
var caster: SkillCaster
var _rows: Array = []  # [t, frame_ms, process_ms, physics_ms, draws, enemies]
var _spawn_t: Array = []
var _added: Array = []  # 이번 프레임에 생성기 아래 새로 붙은 것
var _off: PackedStringArray = PackedStringArray()  # 끌 main 자식 노드 (원인 나누기: --off=HUD,FxLayer)
var _wave := 2  # 시작 물결 (0부터, --wave=0이면 판 처음부터)
var _crit_args: Array = []  # 사임당 1번 풀벌레 덮어쓰기 (성장한 상태 흉내: --critters=7, 예전 수명: --lifetime=8)
var _critters := 0
var _crit_max := 0
var _nodes := 0
var _slow_ms := 0.0  # 게임 시간이 느려진 (time_scale < 0.5) 실제 시간 합 — 히트스톱이 잦으면 "끊김"으로 느껴진다
var _stops := 0  # 느려짐이 새로 시작된 횟수
var _was_slow := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	for f in args:
		if String(f).begins_with("--live="):
			ProjectSettings.set_setting("hh/art/live3d", String(f).ends_with("1"))
		if String(f).begins_with("--wave="):
			_wave = int(String(f).substr(7))
		if String(f).begins_with("--critters=") or String(f).begins_with("--lifetime="):
			_crit_args.append(String(f))
		if String(f).begins_with("--off="):
			_off = String(f).substr(6).split(",")
	args = args.filter(func(a: String) -> bool: return not a.begins_with("--"))
	var stage := StringName(args[0] if args.size() > 0 else "hansan_1592")
	var secs := float(args[2]) if args.size() > 2 else 75.0
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()  # 사용자 설정·다른 측정과 겹치지 않게 (실행마다 따로)
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
	GameSettings.save_settings(GameSettings.settings_path)  # main이 저장본을 다시 읽어도 이 무대·영웅이 되게
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	caster = player.get_node_or_null("SkillCaster") as SkillCaster
	for p in _off:
		var n := main.get_node_or_null(p)
		if n:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			if "visible" in n:
				n.set("visible", false)
	if OS.get_cmdline_user_args().has("--nofinish") and caster:  # 원인 나누기: 4타 마무리(1번 기술)를 못 내게
		caster.kit = caster.kit.duplicate() as SkillKit
		caster.kit.combo_hits = 999
	if OS.get_cmdline_user_args().has("--noxp") and spawner.waves:  # 원인 나누기: 경험치 0 (레벨 오름 없음)
		spawner.waves.data.xp_mult = 0.0
	if OS.get_cmdline_user_args().has("--nokill"):  # 원인 나누기: 맞기만 하고 죽지 않게
		spawner.child_entered_tree.connect(func(n: Node) -> void:
			if n is Enemy:
				(func() -> void:
					if is_instance_valid(n) and (n as Enemy).health:
						(n as Enemy).health.max = 10000000
						(n as Enemy).health.current = 10000000).call_deferred())
	if OS.get_cmdline_user_args().has("--nosfx"):  # 원인 나누기: 효과음만 끔 (음악·소리 장치는 그대로)
		var fb := main.get_node_or_null("Feedback")
		if fb:
			fb.set("sfx_enabled", false)
	if OS.get_cmdline_user_args().has("--nomusic"):  # 원인 나누기: 음악만 끔
		var fbm := main.get_node_or_null("Feedback")
		if fbm:
			fbm.call("play_music", null)
			for c in fbm.get_children():
				if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing and (c as AudioStreamPlayer).bus != &"SFX":
					print("MUSIC player %s bus %s stream %s" % [c.name, (c as AudioStreamPlayer).bus, (c as AudioStreamPlayer).stream])
			fbm.set("_music", null)
	if not _crit_args.is_empty() and caster and caster.kit and caster.kit.tap is CritterSkill:
		caster.kit = caster.kit.duplicate() as SkillKit
		var ck := caster.kit.tap.duplicate() as CritterSkill
		for a in _crit_args:
			if String(a).begins_with("--critters="):
				ck.count = int(String(a).substr(11))
				ck.extra_butterflies = 0
			else:
				ck.lifetime = float(String(a).substr(11))
		caster.kit.tap = ck
	print("STAGE %s hero %s off %s" % [str(main.call("run_stage_id")), str((main.get_node("Player") as Player).hero.id), str(_off)])
	spawner.child_entered_tree.connect(func(n: Node) -> void: _added.append(n.get_class() + ":" + (String((n as Enemy).data.id) if n is Enemy and (n as Enemy).data else String(n.name))))
	spawner.elite_spawned.connect(func(_e: Enemy) -> void: _spawn_t.append(_now()))
	await _wait(3.2)  # 무대 제목 띠
	player.grant_invulnerability(9999.0)
	if spawner.waves:  # 3물결(셋 무리)부터
		spawner.waves.index = _wave - 1
		spawner.waves.phase = WaveRunner.Phase.GAP
		spawner.waves._timer = 0.1
	var t0 := Time.get_ticks_usec()
	var tap := 0.0
	var done_t := -1.0
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		var before := Time.get_ticks_usec()
		tap -= 1.0 / 60.0
		if caster and tap <= 0.0:
			tap = 0.2
			caster.combo_tap()
		await process_frame
		var t := (Time.get_ticks_usec() - t0) / 1e6
		var frame_ms := (Time.get_ticks_usec() - before) / 1000.0
		var slow := Engine.time_scale < 0.5
		if slow:
			_slow_ms += frame_ms
			if not _was_slow:
				_stops += 1
		_was_slow = slow
		if _rows.size() % 600 == 0:
			print("STATE t %.1f paused %s time_scale %.3f phase %s idx %d alive %d" % [t, str(paused), Engine.time_scale, str(spawner.waves.phase) if spawner.waves else "-", spawner.waves.index if spawner.waves else -1, _enemies()])
		if _rows.size() % 30 == 0:  # 풀벌레·노드 수 (30프레임마다)
			_critters = root.find_children("*", "SummonCritter", true, false).size()
			_crit_max = maxi(_crit_max, _critters)
			_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if frame_ms > 100.0:
			print("BIGFRAME t %.2f ms %.1f added %s" % [t, frame_ms, str(_added)])
		_added.clear()
		_rows.append([t, (Time.get_ticks_usec() - before) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), _enemies()])
		if not _spawn_t.is_empty() and done_t < 0.0 and spawner.waves and spawner.waves.phase != WaveRunner.Phase.RUN:
			done_t = t
		if done_t > 0.0 and t > done_t + 3.0:
			break
	print("COUNTS critters_max %d nodes_last %d" % [_crit_max, _nodes])
	var total_ms: float = (_rows[-1][0] as float) * 1000.0
	print("SLOWTIME share %.1f%% stops %d per_s %.2f" % [100.0 * _slow_ms / maxf(total_ms, 1.0), _stops, _stops / maxf(total_ms / 1000.0, 0.1)])
	_report()
	quit()


func _now() -> float:
	return Time.get_ticks_usec() / 1e6


func _enemies() -> int:
	var n := 0
	for c in spawner.get_children():
		if c is Enemy and not (c as Enemy).health.is_dead():
			n += 1
	return n


func _report() -> void:
	var first: float = _rows[0][0]
	var abs0: float = _now() - (_rows[-1][0] as float)  # 행 시각 → 절대 시각 보정
	var trio_at: float = (_spawn_t[0] - abs0) if not _spawn_t.is_empty() else INF
	_line("before_trio", _rows.filter(func(r: Array) -> bool: return r[0] < trio_at - 1.0 and r[0] > first + 1.0))
	_line("trio_fight", _rows.filter(func(r: Array) -> bool: return r[0] > trio_at + 1.0))
	var spike := 0.0
	for r in _rows:
		if absf(r[0] - trio_at) <= 1.0:
			spike = maxf(spike, r[1])
	print("MIDSPIKE t %.2f frame_ms %.1f elites %d" % [trio_at, spike, _spawn_t.size()])
	for r in _rows:
		if r[1] > 33.0:
			print("HITCH t %.2f ms %.1f process %.1f physics %.1f enemies %d" % [r[0], r[1], r[2], r[3], r[5]])


func _line(name: String, rows: Array) -> void:
	if rows.is_empty():
		print("MIDPERF %s frames 0" % name)
		return
	var f := PackedFloat32Array()
	var pr := 0.0
	var ph := 0.0
	var dr := 0.0
	var en := 0.0
	var en_max := 0
	for r in rows:
		f.append(r[1])
		pr += r[2]
		ph += r[3]
		dr += r[4]
		en += r[5]
		en_max = maxi(en_max, r[5])
	var s := f.duplicate()
	s.sort()
	var avg := 0.0
	for x in f:
		avg += x
	var n := rows.size()
	print("MIDPERF %s frames %d avg_ms %.2f p99_ms %.2f max_ms %.1f process_ms %.2f physics_ms %.2f draws %d enemies %.1f/%d" % [
		name, n, avg / n, s[int(n * 0.99)], s[-1], pr / n, ph / n, roundi(dr / n), en / n, en_max])


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0
