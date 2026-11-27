extends SceneTree
## 구역 건너뛰기 연속 캡처·점검 (ZoneHop, 한산): 실제 main을 굴리며 적은 나온 뒤 kill_after초에 쓰러뜨리고(빠르게 판 진행),
## 화살이 뜨면 그쪽으로 내닫는다. 넘어가는 앞뒤를 frame_every프레임마다 PNG로 (out 폴더), 넘어가는 동안 생긴 일을 적는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/zone_hop_shot.gd -- <영웅 id> <out 폴더> [--summon] [--shots]
## 결과 줄: HOPSTATE (상태 바뀜) · DURINGHOP (넘어가는 동안 나온 적·예고·탄·말) · HOPDONE (넘어간 구역, 걸린 시간) · WAVE (물결 알림 시각)
##   --summon: 화살을 기다리는 동안 주인 영웅 부르기 단추를 누른다 (원정 전장 영웅일 때). --shots: 원거리 적을 늦게 쓰러뜨려 탄이 날게.

var main: Node
var zh: ZoneHop
var _out := ""
var _frame := 0
var _rec_left := 0
var _shot_i := 0
var _last_state := -1
var _await_t := 0.0
var _hop_t0 := 0.0


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var pos := args.filter(func(a: String) -> bool: return not a.begins_with("--"))
	var hero := StringName(pos[0] if pos.size() > 0 else "yi_sun_sin")
	_out = pos[1] if pos.size() > 1 else OS.get_user_data_dir() + "/zone_hop"
	DirAccess.make_dir_recursive_absolute(_out)
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"hansan_1592"
	GameSettings.hero_id = hero
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = true
	GameSettings.save_settings(GameSettings.settings_path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	zh = main.find_children("*", "Node", false, false).filter(func(n: Node) -> bool: return n is ZoneHop).front()
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	var shots := args.has("--shots")
	sp.child_entered_tree.connect(func(n: Node) -> void:
		if zh.state != ZoneHop.State.FIGHT:
			print("DURINGHOP spawn %s t %.2f" % [n.get_class() + ":" + String(n.name), _now()])
		if n is Enemy:
			var e := n as Enemy
			var late: bool = shots and e.data != null and e.data.attack != null and e.data.attack.kind == EnemyAttackData.Kind.SHOOT
			var id := e.get_instance_id()  # 쓰러진 뒤 풀려도 람다가 잡지 않게 번호로
			get_timer(3.0 if late else 0.8).timeout.connect(func() -> void:
				var en := instance_from_id(id) as Enemy
				if en and en.health and not en.health.is_dead() and not (en.data and en.data.is_boss):
					en.health.kill()))
	sp.wave_announce.connect(func(i: int, elite: bool) -> void: print("WAVE %d elite %s t %.2f zone %d" % [i + 1, elite, _now(), zh.plan.current]))
	sp.boss_spawned.connect(func(b: Enemy) -> void: print("BOSS t %.2f zone %d at %s" % [_now(), zh.plan.current, str(b.global_position.round())]))
	zh.hopped.connect(func(z: int) -> void:
		var arena := main.get_node("Arena") as Arena
		print("HOPDONE zone %d (%s) took %.2f s, projectiles %d, critters %d, hazards %d, player %s, wash %s" % [z, zh.plan.zone().title, _now() - _hop_t0, _count_shots(),
			root.find_children("*", "SummonCritter", true, false).size(), arena.hazards.hazard_count(), str(player.global_position.round()), str((arena.get_node("ZoneWash") as ZoneWash).color)])
		_rec_left = 150)
	await _wait(3.2)
	player.grant_invulnerability(9999.0)
	var tap := 0.0
	var dashed := false
	var t0 := _now()
	while _now() - t0 < 360.0:
		await process_frame
		_frame += 1
		var sc = main.get("seal_choice")
		if sc and sc.is_open():
			sc.pick(0)
		tap -= 1.0 / 60.0
		if caster and tap <= 0.0 and zh.state == ZoneHop.State.FIGHT:
			tap = 0.25
			caster.combo_tap()
		if zh.state != _last_state:
			_last_state = zh.state
			print("HOPSTATE %s t %.2f wave %d phase %d alive %d shots %d" % [ZoneHop.State.keys()[zh.state], _now(), sp.waves.index + 1, sp.waves.phase, sp.alive_count() + sp._warnings, _count_shots()])
			if zh.state == ZoneHop.State.AWAIT:
				_await_t = _now()
				dashed = false
				_rec_left = 9999
			if zh.state == ZoneHop.State.HOP:
				_hop_t0 = _now()
		if zh.state == ZoneHop.State.AWAIT and not dashed and not main.is_choosing() and _now() - _await_t > 1.6:
			if args.has("--summon"):
				var hb: Array = main.hud.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n is HomeSummonButton)
				if not hb.is_empty():
					print("SUMMON pressed %s t %.2f" % [str((hb.front() as HomeSummonButton).summon()), _now()])
			root.get_texture().get_image().save_png(_out + "/await_full_%d.png" % zh.plan.current)
			print("VIEW on %s inside %s vis %s z %d path %s playing %s" % [zh.view._on, zh.view.is_inside_tree(), zh.view.is_visible_in_tree(), zh.view.z_index, zh.view.get_path(), main.state.is_playing()])
			var rail := zh.plan.nearest_exit(player.global_position)  # 난간 자리가 있으면 그 아래로 옮겨 그쪽으로 내닫는다
			if rail != Vector2.INF:
				ShotStage.move_hero(main, rail + Vector2(0, 240))
			var ddir: Vector2 = (rail - player.global_position).normalized() if rail != Vector2.INF else zh.plan.zone().exit_dir
			dashed = player.request_dash(ddir)
			print("DASH toward %s rail %s ok %s t %.2f" % [str(ddir), str(rail), dashed, _now()])
		if zh.state == ZoneHop.State.HOP and _frame % 6 == 0:
			print("COVER %.2f screen %s size %s" % [zh.view.cover, zh.view._screen.is_visible_in_tree(), str(zh.view._screen.size)])
			var lines = main.get("hero_lines")
			if lines and lines.get("line") != null and String(lines.get("line")) != "":
				print("DURINGHOP line '%s' t %.2f" % [lines.get("line"), _now()])
		if _rec_left > 0:
			_rec_left -= 1
			if _frame % 4 == 0:
				var img := root.get_texture().get_image()
				img.resize(360, 640, Image.INTERPOLATE_BILINEAR)
				img.save_png("%s/f_%04d.png" % [_out, _shot_i])
				_shot_i += 1
			if _rec_left > 5000 and zh.state == ZoneHop.State.FIGHT:
				_rec_left = 0
		if sp.boss_spawned_once and _now() - t0 > 5.0 and zh.plan.current == zh.plan.zones.size() - 1 and _rec_left <= 0:
			break
	print("END zone %d frames %d" % [zh.plan.current, _shot_i])
	quit()


func _count_shots() -> int:
	return main.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool: return n is Projectile).size()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0


func get_timer(s: float) -> SceneTreeTimer:
	return create_timer(s, false)
