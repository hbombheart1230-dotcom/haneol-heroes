extends SceneTree
## 일제 사격 예고 찍기·재기: 실제 main 장면 무대 위에 철포병을 대형(횡대·부채꼴·둥근 진)으로 세우고 FormationBrain처럼 한 프레임에 모두 겨누게 한 뒤
## 진행 0.3 · 0.75 · 번쩍(마지막 순간)에 한 장씩. HH_PERF=1이면 예고 중 그리기 호출을 모아 그리기 켬/끔으로 잰다.
## godot --path . --resolution 540x1000 -s res://tools/shots/volley_shot.gd -- <무대 id> <출력 접두어(절대 경로)> <수> <line|fan|ring|line2>
## HH_KILL=1이면 대형을 한 프레임에 다 쓰러뜨리고 뒤 90프레임의 프레임 시간·그리기 호출·동시에 울린 효과음 수를 낸다.
## 환경: HH_LOOK=alt (붐빔 모양 시안: 획 0.7배·진하기 0.8배·그림자 0.6배), HH_BATCH=0 (각자 그리기).
## 결과 줄: VOLLEY <이름> shooters <n> draws <평균> frame_ms <평균>, 찍은 뒤 VOLLEY sync start <구성원별 예고 시작 차이 ms>

const FRAMES := 240

var shooters: Array[Enemy] = []
var player: Player
## 첫 박자에 못 끼고 다음 박자에 쏜 구성원 수 (쿨타임이 덜 돈 사수).
var late_joiners: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = StringName(args[0])
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	var v := VolleyFeelData.default()
	if OS.get_environment("HH_LOOK") == "alt":
		v.crowd_width_mult = 0.7
		v.crowd_alpha_mult = 0.8
		v.crowd_shadow_mult = 0.6
	if OS.get_environment("HH_BATCH") == "0":
		v.batch_telegraphs = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	if main.run_stage_id() != StringName(args[0]):
		StageApply.stage(main, main.stage_by_id(StringName(args[0])))
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	player = main.get_node("Player") as Player
	await _wait(3.4)
	spawner.active = false
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await process_frame
	player.grant_invulnerability(999.0)
	for nm in ["AutoAttack", "SkillCaster"]:  # 사수가 죽지 않게 영웅은 치지 않는다
		var node := player.get_node_or_null(nm)
		if node:
			node.set_physics_process(false)
			node.set_process(false)
	var n := int(args[2])
	var gunner := load("res://data/enemies/waegun_gunner.tres") as EnemyData
	FxLayer.numbers_hidden = OS.get_environment("HH_NONUM") == "1"  # 피해 숫자 없이 (비교용)
	if OS.get_environment("HH_NOPOSE") == "1":  # 쓰러지는 몸 없이 (비교용)
		gunner = gunner.duplicate()
		gunner.death_hold = 0.0
	for p in _places(String(args[3]), n):
		var e := spawner.spawn_at(gunner, player.global_position + p)
		if e:
			var d := e.attack.data.duplicate() as EnemyAttackData
			d.volley = true
			d.trigger_range = 2000.0
			e.attack.data = d
			e.move_speed = 0.0
			e.attack._cooldown = 99.0  # 스스로는 겨누지 않는다 (대형처럼 이 도구가 한꺼번에 부른다)
			shooters.append(e)
	if OS.get_environment("HH_KILL") == "1":
		await _kill_all()
		quit()
		return
	if OS.get_environment("HH_PERF") == "1":
		await _perf()
		quit()
		return
	await _wait(0.4)
	_aim_all()  # FormationBrain._aim_all과 같이: 모두 같은 프레임에 겨눔 시작
	var starts := await _sync_starts()
	print("VOLLEY sync start spread_ms %.1f (n=%d, next beat %d)" % [starts, shooters.size(), late_joiners])
	for k in [0.3, 0.75, 0.97]:
		await _until(k)
		_save("%s_k%d.png" % [args[1], int(k * 100)])
	quit()


## 대형 자리 (영웅 기준). line = 횡대(위쪽 한 줄), line2 = 두 줄, fan = 부채꼴, ring = 둥근 진.
func _places(shape: String, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		match shape:
			"fan":
				out.append(Vector2.from_angle(deg_to_rad(-90.0 + (i - (n - 1) * 0.5) * 22.0)) * 360.0)
			"ring":
				out.append(Vector2.from_angle(TAU * i / n - PI * 0.5) * 340.0)
			"line2":
				var row := i % 2
				var col := i / 2
				var m := (n + 1) / 2
				out.append(Vector2((col - (m - 1) * 0.5) * 72.0, -300.0 - row * 80.0))
			_:
				out.append(Vector2((i - (n - 1) * 0.5) * 72.0, -330.0))
	return out


func _aim_all() -> void:
	for e in shooters:
		if is_instance_valid(e):
			e.attack.begin_windup(e.global_position, player)


## 구성원이 예고를 시작한 순간들의 차이 (ms, 같은 박자여야 0).
func _sync_starts() -> float:
	var first := -1.0
	var last := -1.0
	var seen := {}
	late_joiners = 0
	var guard := 0
	while seen.size() < shooters.size() and guard < 2000:
		guard += 1
		await process_frame
		for e in shooters:
			if is_instance_valid(e) and not seen.has(e) and e.attack.state == EnemyAttack.State.WINDUP:
				var t := Time.get_ticks_usec() / 1000.0 - (e.attack.data.windup * e.attack.windup_ratio()) * 1000.0
				seen[e] = t
				if first >= 0.0 and t - first > 500.0:
					late_joiners += 1
					continue
				first = t if first < 0.0 else minf(first, t)
				last = maxf(last, t)
	return last - first


func _until(k: float) -> void:
	var guard := 0
	while guard < 900:
		guard += 1
		await process_frame
		for e in shooters:
			if is_instance_valid(e) and e.attack.state == EnemyAttack.State.WINDUP and e.attack.windup_ratio() >= k:
				return


## 예고를 진행 k로 붙들어 둔다 (재기용: 쏘지 않게).
func _arm(k: float) -> void:
	for e in shooters:
		var a := e.attack
		if k < 0.0:
			a.state = EnemyAttack.State.READY  # 빈틈 소용돌이(RECOVER)도 안 그리게
			a._cooldown = 99.0
			continue
		a.state = EnemyAttack.State.WINDUP
		a._timer = a.data.windup * (1.0 - k)
		var to := player.global_position - e.global_position
		a.aim_dir = to.normalized()
		a.aim_origin = e.global_position


func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for c in [["none", -1.0], ["aiming", 0.5]]:
		for i in 30:
			_arm(c[1])
			await process_frame
		var draws := 0.0
		var ms := 0.0
		for i in FRAMES:
			var t0 := Time.get_ticks_usec()
			_arm(c[1] if c[1] < 0.0 else fmod(float(i) / 100.0, 0.98))
			await process_frame
			ms += (Time.get_ticks_usec() - t0) / 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("VOLLEY %s shooters %d batch %s draws %.1f frame_ms %.2f" % [c[0], shooters.size(),
			str(VolleyFeelData.default().batch_telegraphs), draws / FRAMES, ms / FRAMES])


## 대형을 한 번에 쓰러뜨림 (쓸어버리기): 처치 효과·소리가 겹쳐 끊기는지.
func _kill_all() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_arm(-1.0)
	for i in 30:
		await process_frame
	var fb := Feedback.instance
	var kills0 := int(Feedback.hit_serial)
	for e in shooters:
		e.health.damage(9999)
	var worst := 0.0
	var total := 0.0
	var draws := 0.0
	var peak_draws := 0.0
	var voices := 0
	var timeline: Array[int] = []
	for i in 90:
		var t0 := Time.get_ticks_usec()
		await process_frame
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		total += ms
		var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draws += dc
		if i % 10 == 0:
			timeline.append(int(dc))
		peak_draws = maxf(peak_draws, dc)
		var on := 0
		if fb:
			for c in fb.get_children():
				if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing:
					on += 1
		voices = maxi(voices, on)
	print("VOLLEY kill shooters %d hits %d frame_ms avg %.2f worst %.2f draws avg %.1f peak %.0f sfx_voices_peak %d" % [
		shooters.size(), int(Feedback.hit_serial) - kills0, total / 90.0, worst, draws / 90.0, peak_draws, voices])
	print("VOLLEY kill draws_every_10_frames ", timeline)
	if OS.get_environment("HH_BREAKDOWN") == "1":
		await _breakdown()


## 한꺼번에 쓰러뜨린 뒤 무엇이 그리기 호출을 늘리는지: 다시 쓰러뜨리고 종류별로 잠깐 숨겨 줄어드는 수를 잰다.
func _breakdown() -> void:
	var spawner := player.get_parent().get_node("EnemySpawner") as EnemySpawner
	var gunner := load("res://data/enemies/waegun_gunner.tres") as EnemyData
	var again: Array[Enemy] = []
	var n := shooters.size()
	for p in _places("line2", n):
		var e := spawner.spawn_at(gunner, player.global_position + p)
		if e:
			e.move_speed = 0.0
			e.attack._cooldown = 99.0
			again.append(e)
	for i in 20:
		await process_frame
	for e in again:
		e.health.damage(9999)
	for i in 6:
		await process_frame
	var main := player.get_parent()
	var cats := {}
	for c in main.get_children():  # 장면 맨 위 노드마다 (전장·효과층·영웅·무대)
		if c is CanvasItem:
			cats[String(c.name)] = [c]
	var fx := Feedback.instance.fx if Feedback.instance else null
	if fx:
		cats["fx(self only: children shown)"] = []
		for c in fx.get_children():
			if c is CanvasItem:
				cats["fx/" + String(c.name)] = [c]
	var out := []
	for k in cats.keys():
		var nodes: Array = cats[k]
		var base := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for nd in nodes:
			if is_instance_valid(nd) and nd is CanvasItem:
				(nd as CanvasItem).visible = false
		await process_frame
		await process_frame
		var hid := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for nd in nodes:
			if is_instance_valid(nd) and nd is CanvasItem:
				(nd as CanvasItem).visible = true
		await process_frame
		var back := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		out.append("%s %d" % [k, roundi((base + back) * 0.5 - hid)])
	print("VOLLEY kill_breakdown ", ", ".join(out))


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("[volley-shot] ", path)
