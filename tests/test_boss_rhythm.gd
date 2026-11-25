extends GdUnitTestSuite
## 한산 보스 박자·연출 (BossFeelData · BossPatternPicker · BossStaging): 같은 공격 연속 금지, 이어치기,
## 등장·전환 대기, 전환 동안 영웅 무적 → 강화 → 부하(보스 뒤, 최대 수), 처치 연출 뒤 승리, 돌진 벽 앞 멈춤.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COMMANDER := preload("res://data/enemies/waegun_commander.tres")
## boss_feel이 없는 옛 방식 보스 (네 무대 보스는 모두 boss_feel이 있어 시험용 사본을 쓴다).
const LEGACY := preload("res://tests/fixtures/legacy_boss.tres")
## 네 무대 보스 (모두 같은 구조: 박자·연출, 3단계, 접촉 피해 0, 군령 이어치기).
const STAGE_BOSSES := ["res://data/enemies/waegun_commander.tres", "res://data/enemies/boss_general.tres",
	"res://data/enemies/jurchen_chieftain.tres", "res://data/enemies/cc_frog.tres"]
const DT := 1.0 / 60.0

var player: Player
var sp: EnemySpawner


func before_test() -> void:
	EnemyAttack.active_windups = 0
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2.ZERO
	sp = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	sp.target = player
	sp.horde_enabled = false
	add_child(sp)
	sp.set_physics_process(false)


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()


func _boss(d: EnemyData = COMMANDER, at: Vector2 = Vector2(0, -150)) -> Enemy:
	sp.boss_data = d
	var b := sp.spawn_boss()
	b.global_position = at
	b.set_physics_process(false)
	return b


func _atk(kind: EnemyAttackData.Kind, trigger: float) -> EnemyAttackData:
	var a := EnemyAttackData.new()
	a.kind = kind
	a.trigger_range = trigger
	return a


func _step(b: Enemy, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		t += DT
		b.attack.tick(DT, b.global_position, player)
		var st := sp.get_node_or_null("BossStaging")
		if st:
			st._physics_process(DT)


## --- 고르기 (순수) ---

func test_picker_never_repeats_last_kind_and_prefers_in_range() -> void:
	var cone := _atk(EnemyAttackData.Kind.CONE, 220.0)
	var charge := _atk(EnemyAttackData.Kind.CHARGE, 420.0)
	var shock := _atk(EnemyAttackData.Kind.SHOCKWAVE, 260.0)
	var list := [cone, charge, shock]
	for roll in [0.0, 0.3, 0.6, 0.99]:
		assert_object(BossPatternPicker.pick(list, EnemyAttackData.Kind.CONE, 100.0, roll)).is_not_same(cone)
	assert_object(BossPatternPicker.pick(list, EnemyAttackData.Kind.SHOCKWAVE, 300.0, 0.0)).is_same(charge)  # 닿는 것만
	assert_object(BossPatternPicker.pick(list, EnemyAttackData.Kind.CHARGE, 900.0, 0.0)).is_same(shock)  # 다 멀면 가장 긴 것
	assert_object(BossPatternPicker.pick([cone], EnemyAttackData.Kind.CONE, 100.0, 0.0)).is_same(cone)  # 하나뿐이면 그것


## --- 데이터: 예고·틈·조합 ---

func _all_attacks(d: EnemyData) -> Array:
	var out: Array = []
	var lists: Array = [d.patterns]
	for ph in d.phases:
		lists.append(ph.patterns)
	for l in lists:
		for a in l:
			if not out.has(a):
				out.append(a)
			if a.follow_up and not out.has(a.follow_up):
				out.append(a.follow_up)
	return out


func test_stage_bosses_rhythm_data() -> void:
	for path in STAGE_BOSSES:
		_check_rhythm_data(load(path) as EnemyData)


func _check_rhythm_data(boss: EnemyData) -> void:
	var ai := Enemy.ai_data()
	for a: EnemyAttackData in _all_attacks(boss):
		assert_bool(a.bypass_cap).is_true()
		assert_bool(boss.sprite_sheet.has_anim(a.anim)).override_failure_message("%s: no clip %s" % [boss.id, a.anim]).is_true()
		assert_float(a.windup).is_greater_equal(maxf(ai.min_windup, 0.8))  # 보스 예고 0.8초 이상 (한 손 세로 화면에서 읽히는 길이)
		if a.follow_up == null:
			assert_float(a.recovery).is_greater_equal(0.9)  # 조합 끝·홑공격 뒤엔 반드시 때릴 틈
			assert_float(maxf(a.cooldown, a.recovery)).is_greater_equal(1.6)  # 타격 → 다음 예고
		elif not a.chain_repeat:  # 일부러 잇는 연속 (격노 3연 돌진)은 빼고
			assert_int(int(a.follow_up.kind)).is_not_equal(int(a.kind))  # 이어치기도 같은 종류 연속 아님
	for a: EnemyAttackData in boss.patterns:
		assert_object(a.follow_up).is_null()  # 1단계는 홑공격만
	assert_int(boss.phases.size()).is_equal(2)  # 3단계 (66%·33%)
	var combos := 0
	for ph: BossPhaseData in boss.phases:
		combos = 0
		for a: EnemyAttackData in ph.patterns:
			combos += 1 if a.follow_up else 0
		assert_int(combos).is_greater(0)
	assert_int(combos).is_equal(2)  # 3단계는 조합 둘
	assert_object(boss.boss_feel).is_not_null()
	assert_int(boss.contact_damage).is_equal(0)  # 모든 피해는 예고로
	assert_float(boss.launch_scale).is_less(1.0)  # 날아가지 않음
	for ph: BossPhaseData in boss.phases:
		assert_int(ph.summon.size()).is_less_equal(boss.boss_feel.max_minions)
		assert_object(ph.seal_art).is_not_null()


## --- 이어치기·대기 ---

func test_combo_chains_without_range_check_after_follow_gap() -> void:
	var b := _boss()
	var opener: EnemyAttackData = COMMANDER.phases[0].patterns[0]
	assert_object(opener.follow_up).is_not_null()
	var a := b.attack
	a.hold_left = 0.0
	a.data = opener
	a._cooldown = 0.0
	a.tick(DT, b.global_position, player)
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)
	_step(b, opener.windup + opener.recovery + DT * 2)
	assert_object(a.data).is_same(opener.follow_up)
	player.global_position = Vector2(0, 2000)  # 멀리 떨어져도 이어치기는 나간다
	_step(b, opener.follow_gap + DT * 3)
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)


func test_intro_hold_and_offscreen_block_attacks() -> void:
	var b := _boss()
	assert_float(b.attack.hold_left).is_equal_approx(COMMANDER.boss_feel.intro_hold, 0.01)
	_step(b, COMMANDER.boss_feel.intro_hold - 0.1)
	assert_int(b.attack.state).is_equal(EnemyAttack.State.READY)
	b.attack.start_check = func(_p: Vector2) -> bool: return false  # 화면 밖
	_step(b, 0.5)
	assert_int(b.attack.state).is_equal(EnemyAttack.State.READY)
	b.attack.start_check = func(_p: Vector2) -> bool: return true
	_step(b, 0.1)
	assert_int(b.attack.state).is_equal(EnemyAttack.State.WINDUP)


func test_other_bosses_keep_old_rotation() -> void:
	var b := _boss(LEGACY)
	assert_object(BossStaging.of(b)).is_null()
	assert_bool(b.attack.pick_by_range).is_false()
	assert_float(b.attack.hold_left).is_equal(0.0)


## --- 단계 전환 ---

func test_phase_transition_beat_then_pick_then_summons_behind_boss() -> void:
	var b := _boss()
	var f: BossFeelData = COMMANDER.boss_feel
	var picks := [0]
	sp.breather.connect(func(_s: bool) -> void: picks[0] += 1)
	b.health.damage(roundi(b.health.max * 0.4))
	assert_int(b.phase_index).is_equal(1)
	assert_bool(player.is_invulnerable()).is_true()  # 전환 동안 영웅은 맞지 않는다
	assert_float(b.attack.hold_left).is_greater_equal(f.transition_hold - 0.01)
	assert_int(sp._warnings).is_equal(0)  # 아직 부하 없음
	_step(b, f.pick_delay + DT)
	assert_int(picks[0]).is_equal(1)
	assert_int(sp._warnings).is_equal(0)
	_step(b, f.summon_delay - f.pick_delay)
	assert_int(sp._warnings).is_equal(COMMANDER.phases[0].summon.size())
	for c in sp.get_children():
		if c is SpawnWarning:  # 보스 뒤(영웅 반대편)
			assert_float((c as Node2D).global_position.distance_to(player.global_position)) \
				.is_greater(b.global_position.distance_to(player.global_position))
	assert_int(b.attack.state).is_equal(EnemyAttack.State.READY)  # 전환 중엔 치지 않는다


func test_summons_capped_by_max_minions() -> void:
	var b := _boss()
	var stg := BossStaging.of(b)
	var soldier: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	for i in 2:
		sp.spawn_at(soldier, Vector2(300 + i * 40, 0)).set_physics_process(false)
	stg.summon([soldier, soldier, soldier])
	assert_int(stg.minion_count()).is_equal(COMMANDER.boss_feel.max_minions)


## --- 처치 ---

func test_finale_delays_victory_clears_minions_and_protects_hero() -> void:
	var b := _boss()
	var soldier: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var m := sp.spawn_at(soldier, Vector2(200, 0))
	m.set_physics_process(false)
	var won := [false]
	BossStaging.finish(b, func() -> void: won[0] = true)
	assert_bool(won[0]).is_false()
	assert_bool(m.health.is_dead()).is_true()
	assert_bool(player.is_invulnerable()).is_true()
	assert_bool(sp.active).is_false()
	await get_tree().create_timer(COMMANDER.boss_feel.finale_time + 0.2, true, false, true).timeout
	assert_bool(won[0]).is_true()


func test_finish_without_staging_wins_at_once() -> void:
	var won := [false]
	BossStaging.finish(_boss(LEGACY), func() -> void: won[0] = true)
	assert_bool(won[0]).is_true()


func test_banner_shows_defeat_then_fades_before_victory() -> void:
	var banner: BossBanner = auto_free(BossBanner.new())
	add_child(banner)
	var b := _boss()
	banner.show_boss(b)
	b.killed.emit(b)
	assert_bool(banner.defeated).is_true()
	assert_bool(banner.banner_visible()).is_true()
	banner.step(COMMANDER.boss_feel.finale_time)
	assert_bool(banner.banner_visible()).is_false()
	assert_float(banner.mood).is_equal(0.0)  # 처치 때는 붉게 깜박이지 않는다


## --- 돌진 ---

func test_charge_stops_before_blocked_point_and_arena_edge() -> void:
	var b := _boss(COMMANDER, Vector2.ZERO)
	sp.blocked_check = func(p: Vector2, _m: float) -> bool: return p.x > 200.0
	var end := EnemyActions.charge_stop(b, Vector2(460, 0))
	assert_float(end.x).is_less_equal(200.0)
	assert_float(end.x).is_greater(150.0)
	sp.blocked_check = Callable()
	sp.arena_rect = Rect2(-300, -300, 600, 600)
	end = EnemyActions.charge_stop(b, Vector2(0, 460))
	assert_float(end.y).is_less_equal(300.0 - b.body_radius)


## 걸을 수 있는 곳이 전장 사각보다 넓으면 (한산 갑판 x ±960) 사각 밖에서도 돌진하고, 다각형 끝 앞에서 멈춘다.
func test_charge_uses_walk_area_beyond_arena_rect() -> void:
	sp.arena_rect = Rect2(-300, -300, 600, 600)
	sp.walk_area = PackedVector2Array([Vector2(-600, -600), Vector2(600, -600), Vector2(600, 600), Vector2(-600, 600)])
	var b := _boss(COMMANDER, Vector2(400, 0))
	var end := EnemyActions.charge_stop(b, Vector2(400, 200))
	assert_vector(end).is_equal(Vector2(400, 200))  # 사각 밖이어도 다각형 안이면 그대로
	end = EnemyActions.charge_stop(b, Vector2(900, 0))
	assert_float(end.x).is_greater(450.0)
	assert_float(end.x).is_less_equal(600.0 - b.body_radius * b.size_mult)
	sp.walk_area = PackedVector2Array()


## 회복 중 휘청(cancel)으로 끊겨도 이미 친 공격을 다시 내지 않는다 (이어치기도 끊긴다).
func test_stagger_during_recovery_moves_on_without_chain() -> void:
	var b := _boss()
	var a := b.attack
	var opener: EnemyAttackData = COMMANDER.phases[0].patterns[0]
	a.set_patterns(BossPhases.scaled_patterns(COMMANDER.phases[0].patterns, 1.0))
	a.hold_left = 0.0
	a.data = opener
	a._cooldown = 0.0
	_step(b, opener.windup + DT * 3)
	assert_int(a.state).is_equal(EnemyAttack.State.RECOVER)
	a.cancel()
	assert_int(int(a.data.kind)).is_not_equal(int(opener.kind))
	assert_object(a.data).is_not_same(opener.follow_up)
