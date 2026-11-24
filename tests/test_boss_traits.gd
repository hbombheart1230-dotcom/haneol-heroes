extends GdUnitTestSuite
## 우두머리 공통 바탕 (데이터, 이번엔 한산 대장만 켬): 추격 속도, 격노(주기·휘청 면역), 단계마다 휘청 게이지 증가,
## 멀 때만 고르는 공격, 깃발·북잡이 둘레(아군 빠르게·먹물 장판), 중간 우두머리 무리(동시 예고 상한·마지막만 처치 연출).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COMMANDER_PATH := "res://data/enemies/waegun_commander.tres"
const FLAG := preload("res://data/enemies/waegun_flag.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0

var player: Player
var sp: EnemySpawner


func before_test() -> void:
	BossSim.reset_globals()
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.set_physics_process(false)
	sp = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	sp.target = player
	sp.horde_enabled = false
	add_child(sp)
	sp.set_physics_process(false)


func after_test() -> void:
	BossSim.reset_globals()


func _d(path: String) -> EnemyData:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData


func test_far_only_attack_is_picked_only_when_far() -> void:
	var near := EnemyAttackData.new()
	near.kind = EnemyAttackData.Kind.CONE
	near.trigger_range = 220.0
	var far := EnemyAttackData.new()
	far.kind = EnemyAttackData.Kind.CHARGE
	far.trigger_range = 620.0
	far.min_range = 320.0
	for roll in [0.0, 0.5, 0.99]:
		assert_object(BossPatternPicker.pick([near, far], -1, 150.0, roll)).is_same(near)  # 가까우면 멀 때 공격은 안 나옴
		assert_object(BossPatternPicker.pick([near, far], -1, 500.0, roll)).is_same(far)


func test_commander_chases_and_rage_grows_stagger_gauge() -> void:
	sp.boss_data = _d(COMMANDER_PATH)
	var b := sp.spawn_boss()
	assert_float(b.move_speed).is_equal(b.data.boss_feel.chase_speed)
	assert_float(b.move_speed).is_greater(b.data.move_speed)
	var g0 := b.poise.gauge_max
	BossPhases.enter(b, b.data.phases[0])  # 66% 전환
	assert_float(b.poise.gauge_max).is_equal_approx(g0 * 1.5, 0.01)
	BossPhases.enter(b, b.data.phases[1])  # 33% 격노
	assert_float(b.poise.immune_left).is_greater(7.0)
	assert_int(b.poise.on_damage(b.health.max)).is_equal(EnemyPoise.Event.NONE)  # 격노 동안 휘청 없음
	b.poise.tick(9.0)
	assert_int(b.poise.on_damage(roundi(b.poise.gauge_max) + 1)).is_equal(EnemyPoise.Event.STAGGER)


func test_rage_triple_charge_reaims_each_time() -> void:
	var d := _d(COMMANDER_PATH)
	var rage: BossPhaseData = d.phases[1]
	var first: EnemyAttackData = null
	for a: EnemyAttackData in rage.patterns:
		if a.follow_up and a.follow_up.kind == a.kind:
			first = a
	assert_object(first).is_not_null()
	var n := 1
	var a := first
	while a.follow_up:
		assert_bool(a.chain_repeat).is_true()
		a = a.follow_up
		n += 1
	assert_int(n).is_equal(3)
	assert_float(rage.cooldown_mult).is_equal(0.75)


func test_flag_slows_hero_inside_and_speeds_allies() -> void:
	var f := sp.spawn_at(FLAG, Vector2(0, -50))
	var ally := sp.spawn_at(SOLDIER, Vector2(60, -50))
	f._physics_process(DT)
	assert_float(ally.speed_scale()).is_equal_approx(FLAG.aura.ally_speed_mult, 0.01)
	assert_float(player._swing_mult).is_equal_approx(FLAG.aura.field_slow_mult, 0.01)  # 장판 안 영웅은 느려짐 (피해 없음)
	assert_int(player.health.current).is_equal(player.health.max)


func test_plant_respects_cap() -> void:
	sp.boss_data = _d(COMMANDER_PATH)
	var b := sp.spawn_boss()
	var flag_atk: EnemyAttackData = null
	for a: EnemyAttackData in (b.data.phases[0] as BossPhaseData).patterns:
		if a.spawn_on_strike:
			flag_atk = a
	assert_object(flag_atk).is_not_null()
	b.attack.target_point = Vector2(0, 100)
	for i in 4:
		EnemyActions.plant(b, flag_atk)
	var flags := sp.get_children().filter(func(c: Node) -> bool: return c is Enemy and (c as Enemy).data == flag_atk.spawn_on_strike)
	assert_int(flags.size()).is_equal(flag_atk.spawn_cap)


func test_mid_group_caps_windups_and_only_last_plays_finale() -> void:
	var stage := load("res://data/stages/hansan_1592.tres") as StageTheme
	var group: Array = (stage.waves.waves[2] as WaveData).elite_group
	assert_int(group.size()).is_equal(3)
	var ms: Array = []
	for i in group.size():
		ms.append(sp.spawn_elite(Vector2(-150 + 150 * i, -200), group[i]))
	var staged := ms.filter(func(m: Enemy) -> bool: return BossStaging.of(m) != null)
	assert_int(staged.size()).is_equal(3)
	var cap: int = (group[0] as EnemyData).boss_feel.group_windup_cap
	assert_int(cap).is_equal(2)
	var attackers := ms.filter(func(m: Enemy) -> bool: return m.attack != null)
	for m: Enemy in attackers:  # 둘이 예고 중이면 셋째는 시작 못 함
		m.attack.state = EnemyAttack.State.WINDUP
	var third: Enemy = attackers[0]
	third.attack.state = EnemyAttack.State.READY
	var busy := attackers.filter(func(m: Enemy) -> bool: return m.attack.state == EnemyAttack.State.WINDUP).size()
	assert_bool(BossStaging.of(third).can_start(third.global_position)).is_equal(busy < cap)
	sp.spawn_at(SOLDIER, Vector2(300, 0))
	(ms[0] as Enemy).health.kill()
	assert_bool(sp.active).is_true()
	await get_tree().process_frame
	assert_int(sp.alive_count()).is_greater(2)  # 무리가 남아 있으면 부하를 지우지 않는다
	(ms[1] as Enemy).health.kill()
	(ms[2] as Enemy).health.kill()
	await get_tree().process_frame
	assert_int(sp.alive_count()).is_equal(0)  # 마지막이 쓰러지면 남은 부하도 흩어짐 → 물결 끝


## 만주 거란 부족장 (A안): 공통 성질 (추격·단계별 비틀림 게이지·3단계 면역·멀 때만 쓰는 공격) + 뒤로 빠지며 화살 3연사 + 돌진 뒤 회전 베기.
func test_manchuria_boss_traits() -> void:
	var d := _d("res://data/enemies/boss_general.tres")
	assert_float(d.boss_feel.chase_speed).is_greater(0.0)
	for ph: BossPhaseData in d.phases:
		assert_float(ph.stagger_gauge_mult).is_greater(1.0)
	assert_float((d.phases[1] as BossPhaseData).stagger_immune).is_greater(0.0)
	var far: EnemyAttackData = d.patterns.filter(func(a: EnemyAttackData) -> bool: return a.min_range > 0.0)[0]
	assert_int(int(far.kind)).is_equal(int(EnemyAttackData.Kind.SHOOT))  # 1단계는 홑 화살 (멀 때만)
	var volley: EnemyAttackData = (d.phases[0] as BossPhaseData).patterns.filter(func(a: EnemyAttackData) -> bool: return a.min_range > 0.0)[0]
	assert_int(int(volley.kind)).is_equal(int(EnemyAttackData.Kind.SHOOT))
	assert_float(volley.kite_while_aiming).is_greater(0.0)
	var n := 1
	var a := volley
	while a.follow_up:
		a = a.follow_up
		n += 1
	assert_int(n).is_equal(3)
	var spin: Array = (d.phases[0] as BossPhaseData).patterns.filter(func(p: EnemyAttackData) -> bool:
		return p.kind == EnemyAttackData.Kind.CHARGE and p.follow_up and p.follow_up.angle_degrees >= 360.0)
	assert_int(spin.size()).is_equal(1)


## 경복궁 여진 추장 (A안): 공통 성질 + 갔다 오는 돌진 (450, 멀 때만 쓰는 것도) + 두 겹 고리 충격파.
func test_gyeongbok_boss_traits() -> void:
	var d := _d("res://data/enemies/jurchen_chieftain.tres")
	assert_float(d.boss_feel.chase_speed).is_greater(0.0)
	for ph: BossPhaseData in d.phases:
		assert_float(ph.stagger_gauge_mult).is_greater(1.0)
	assert_float((d.phases[1] as BossPhaseData).stagger_immune).is_greater(0.0)
	assert_int(int((d.patterns.filter(func(a: EnemyAttackData) -> bool: return a.min_range > 0.0)[0] as EnemyAttackData).kind)).is_equal(int(EnemyAttackData.Kind.CHARGE))  # 1단계는 홑 돌진
	var far: EnemyAttackData = (d.phases[0] as BossPhaseData).patterns.filter(func(a: EnemyAttackData) -> bool: return a.min_range > 0.0)[0]
	assert_float(far.length).is_equal(450.0)
	assert_int(int(far.follow_up.kind)).is_equal(int(EnemyAttackData.Kind.CHARGE))  # 갔다가 돌아온다
	var rings: Array = (d.phases[0] as BossPhaseData).patterns.filter(func(a: EnemyAttackData) -> bool:
		return a.kind == EnemyAttackData.Kind.SHOCKWAVE and a.follow_up and a.follow_up.kind == EnemyAttackData.Kind.SHOCKWAVE)
	assert_int(rings.size()).is_equal(1)
	var r: EnemyAttackData = rings[0]
	assert_float(r.follow_up.radius).is_greater(r.radius)  # 안 고리 → 바깥 고리


## 초충도 개구리 장군 (A안): 공통 성질 + 늪 장판 (둘레 안 영웅 느려짐) + 혀 두 번 연달아 끌기 (혀 500).
func test_chochung_boss_traits() -> void:
	var d := _d("res://data/enemies/cc_frog.tres")
	assert_float(d.boss_feel.chase_speed).is_greater(0.0)
	for ph: BossPhaseData in d.phases:
		assert_float(ph.stagger_gauge_mult).is_greater(1.0)
	assert_float((d.phases[1] as BossPhaseData).stagger_immune).is_greater(0.0)
	assert_object(d.aura).is_not_null()
	assert_float(d.aura.field_slow_mult).is_less(1.0)  # 늪
	var far: EnemyAttackData = d.patterns.filter(func(a: EnemyAttackData) -> bool: return a.min_range > 0.0)[0]
	assert_int(int(far.kind)).is_equal(int(EnemyAttackData.Kind.PULL))  # 1단계는 홑 혀 (멀 때만)
	assert_float(far.length).is_equal(500.0)
	for ph: BossPhaseData in d.phases:
		var twice: Array = ph.patterns.filter(func(a: EnemyAttackData) -> bool:
			return a.kind == EnemyAttackData.Kind.PULL and a.follow_up and a.follow_up.kind == EnemyAttackData.Kind.PULL)
		assert_int(twice.size()).is_equal(1)
		assert_float((twice[0] as EnemyAttackData).follow_up.length).is_equal(500.0)
