extends SceneTree
## 대형 연속 캡처·점검 (FormationBrain): 실제 main을 물결 하나부터 굴리고 (영웅 무적, 치지 않음 — 대형이 보이게),
## 대형이 서면 frame_every 프레임마다 PNG, 겨눔마다 구성원별 남은 예고 시간(모두 같아야 함)과 발사 프레임을 적는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/formation_shot.gd -- <무대 id> <영웅 id> <out 폴더> [--wave=1] [--tap]
## 결과 줄: FORMATION (나옴) · AIMED n left [..] (같은 순간 겨눔) · FIRED n frame · PHASE · LOST · BROKEN

var main: Node
var _out := ""
var _shot_i := 0
var _rec := false
var _frame := 0
var _fire_frames := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var pos := args.filter(func(a: String) -> bool: return not a.begins_with("--"))
	var wave := 2
	for a in args:
		if String(a).begins_with("--wave="):
			wave = int(String(a).substr(7))
	_out = pos[2] if pos.size() > 2 else OS.get_user_data_dir() + "/formation"
	DirAccess.make_dir_recursive_absolute(_out)
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = StringName(pos[0] if pos.size() > 0 else "hansan_1592")
	GameSettings.hero_id = StringName(pos[1] if pos.size() > 1 else "yi_sun_sin")
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	GameSettings.save_settings(GameSettings.settings_path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	await _wait(3.2)
	player.grant_invulnerability(9999.0)
	sp.waves.index = wave - 2  # --wave는 1부터 (다음 GAP 뒤 이 물결이 시작)
	sp.waves.phase = WaveRunner.Phase.GAP
	sp.waves._timer = 0.1
	var seen := {}
	var tap := 0.0
	var t0 := _now()
	var rec_end := INF
	while _now() - t0 < 60.0 and _now() < rec_end:
		await process_frame
		_frame += 1
		var sc = main.get("seal_choice")
		if sc and sc.is_open():
			sc.pick(0)
		if args.has("--tap") and caster:
			tap -= 1.0 / 60.0
			if tap <= 0.0:
				tap = 0.25
				caster.combo_tap()
		for b: FormationBrain in sp.formations:
			if not seen.has(b):
				seen[b] = true
				_watch(b)
				_rec = true
				rec_end = _now() + 14.0
		if _rec and _frame % 3 == 0:
			var img := root.get_texture().get_image()
			img.resize(360, 640, Image.INTERPOLATE_BILINEAR)
			img.save_png("%s/f_%04d.png" % [_out, _shot_i])
			_shot_i += 1
	print("END frames %d" % _shot_i)
	quit()


func _watch(b: FormationBrain) -> void:
	print("FORMATION %s count %d at %s facing %s t %.2f frame %d" % [b.data.resource_path.get_file(), b.data.count, str(b.anchor.round()), str(b.facing), _now(), _frame])
	b.phase_changed.connect(func(p: int) -> void: print("PHASE %s alive %d frame %d shot %d" % [FormationCycle.Phase.keys()[p], b.alive().size(), _frame, _shot_i]))
	b.aimed.connect(func(m: Array) -> void:
		var lefts := m.map(func(e: Enemy) -> String: return "%.3f" % e.attack.windup_left())
		print("AIMED %d left %s frame %d shot %d" % [m.size(), str(lefts), _frame, _shot_i]))
	b.fired.connect(func(m: Array) -> void: print("FIRED %d frame %d shot %d" % [m.size(), _frame, _shot_i]))
	b.member_lost.connect(func(s: int) -> void: print("LOST slot %d frame %d" % [s, _frame]))
	b.broken.connect(func() -> void: print("BROKEN frame %d" % _frame))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0
