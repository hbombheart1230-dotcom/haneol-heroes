extends SceneTree
## 연타 박자 재기 (진단): 실제 한산 장면에서 영웅 앞에 왜군 병사 n마리 (안 죽고 안 침), 탭을 gap초마다 계속 누른다.
## 타마다 시작(휘두르기·던지기·마무리 시전)·닿음(칼이 닿음·탄 놓음) 시각을 실제 시각(ms)으로 찍고,
## 흐름을 멈추는 것들의 실제 시간을 더한다: 게임 시간 느려짐(GameTime 멈춤 = Engine.time_scale < 1), 영웅 그림 멈춤(역경직),
## 칼 박힘(BladeBite), 마무리 잠금(AutoAttack.busy_left), 기억한 탭(TapCombo 버퍼). 몹이 피해를 입은 시각(dmg)과 그때 영웅 자리도.
## godot --path . --resolution 720x1280 -s res://tools/shots/tap_rhythm.gd -- <hero id> [병사 수=1] [탭 간격 초=0.05] [초=7]

var _events: Array = []
var _t0: int = 0
var _player: Node2D


func _initialize() -> void:
	_run()


func _now() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := StringName(args[0])
	var count := int(args[1]) if args.size() > 1 else 1
	var gap := float(args[2]) if args.size() > 2 else 0.05
	var seconds := float(args[3]) if args.size() > 3 else 7.0
	var main: Node = await ShotStage.open(self, &"hansan_1592", hero)
	await _wait(3.0)
	var player := main.get_node("Player") as Player
	_player = player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	var view := player.get_node("PlayerView")
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var reach := atk.stats().melee_range * 0.6 if atk.stats().use_melee else 200.0
	var foes: Array = []
	for i in count:
		var off := Vector2(reach, (i - (count - 1) * 0.5) * 40.0)
		var e := spawner.spawn_at(data, spot + off)
		e.global_position = spot + off
		e.health.max = 999999
		e.health.current = 999999
		e.attack = null
		e.set_physics_process(false)
		foes.append([e, off])
		e.health.damaged.connect(func(_en: Node, _ty: int, amount: int, _i: int, _m: float, _a: int) -> void: _log("dmg", amount, true))
	await _wait(0.5)
	atk.melee_windup.connect(func(_d: Vector2) -> void: _log("start", atk.chain_step, atk.last_manual))
	atk.ranged_windup.connect(func(_d: Vector2) -> void: _log("start", atk.ranged_step, atk.last_manual))
	atk.melee_swung.connect(func(_d: Vector2, hits: int) -> void: _log("hit", hits, atk.swing_manual))
	atk.projectile_fired.connect(func(_p: Projectile) -> void: _log("shot", 1, atk.shot_manual))
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void:
		if s == SkillCaster.Slot.TAP:
			_log("finish", 4, true))
	_t0 = Time.get_ticks_msec()
	var slow := 0.0
	var frozen := 0.0
	var biting := 0.0
	var locked := 0.0
	var kept := 0.0
	var tap_left := 0.0
	var last := _now()
	while _now() < seconds:
		for f in foes:  # 밀려나도 제자리 (같은 거리에서 계속 친다)
			(f[0] as Node2D).global_position = player.global_position + (f[1] as Vector2)
		tap_left -= _now() - last
		var dt := _now() - last
		last = _now()
		if Engine.time_scale < 0.99:
			slow += dt
		var hs: Variant = view.get("_hitstop_left")
		if hs != null and float(hs) > 0.0:
			frozen += dt
		if player.bite.active():
			biting += dt
		if atk.busy_left() > 0.0:
			locked += dt
		if caster.combo.has_buffer():
			kept += dt
		if tap_left <= 0.0:
			tap_left = gap
			caster.combo_tap()
		await process_frame
	var starts := 0
	for e in _events:
		starts += int(e[1] == "start" and e[3]) + int(e[1] == "finish")
	print("RHYTHM %s foes=%d tapgap=%.2f over %.1fs: slow %.2fs, pose frozen %.2fs, biting %.2fs, finisher lock %.2fs, tap kept %.2fs, %.2f hand hits/s" % [
		hero, count, gap, seconds, slow, frozen, biting, locked, kept, starts / seconds])
	var line := PackedStringArray()
	for e in _events:
		line.append("%.3f %s%s%s @%d,%d" % [e[0], e[1], e[2], "" if e[3] else "(auto)", e[4].x, e[4].y])
	print("EVENTS " + " | ".join(line))
	quit()


func _log(kind: String, n: int, manual: bool) -> void:
	_events.append([_now(), kind, n, manual, _player.global_position if _player else Vector2.ZERO])


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
