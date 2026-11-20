extends GdUnitTestSuite
## 2단계 시그니처: 적 예고 공격 → 대시 회피 성공 → 1초 강화 반격.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const CHASER := preload("res://data/enemies/chaser.tres")
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var enemies: Array = []
var casts: Array = []


func before_test() -> void:
	EnemyAttack.active_windups = 0
	enemies = []
	casts = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.global_position = Vector2.ZERO
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = HERO.kit
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_cast.connect(func(s: SkillCaster.Slot, _h: int) -> void: casts.append(s))


func after_test() -> void:
	Engine.time_scale = 1.0
	EnemyAttack.active_windups = 0


func _attack() -> EnemyAttack:
	return EnemyAttack.new(CHASER.attack, 0.0)


func _run_attack(a: EnemyAttack, from: Vector2, seconds: float) -> Array:
	var results: Array = []
	var t := 0.0
	while t < seconds:
		t += DT
		player.compute_velocity(DT)
		var r := a.tick(DT, from, player)
		if r != EnemyAttack.Result.NONE:
			results.append(r)
	return results


# --- 예고 공격 ---

func test_attack_winds_up_then_hits_standing_player() -> void:
	var a := _attack()
	a.tick(DT, Vector2(60, 0), player)
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)
	assert_vector(a.target_point).is_equal(Vector2.ZERO)
	var results := _run_attack(a, Vector2(60, 0), CHASER.attack.windup + 0.05)
	assert_array(results).is_equal([EnemyAttack.Result.HIT])
	assert_int(player.health.current).is_equal(player.health.max - CHASER.attack.damage)


func test_out_of_range_never_attacks() -> void:
	var a := _attack()
	a.tick(DT, Vector2(500, 0), player)
	assert_int(a.state).is_equal(EnemyAttack.State.READY)


func test_dash_through_strike_is_evade() -> void:
	var a := _attack()
	var evades := [0]
	player.evaded.connect(func() -> void: evades[0] += 1)
	a.tick(DT, Vector2(60, 0), player)
	_run_attack(a, Vector2(60, 0), CHASER.attack.windup - 0.1)
	player.request_dash(Vector2.UP)  # 대시 중(무적)에 타격 → 원 안이어도 회피
	player.global_position = Vector2(0, -20)
	var results := _run_attack(a, Vector2(60, 0), 0.15)
	assert_array(results).is_equal([EnemyAttack.Result.EVADED])
	assert_int(evades[0]).is_equal(1)
	assert_int(player.health.current).is_equal(player.health.max)


func test_dash_out_just_before_strike_is_evade() -> void:
	var a := _attack()
	a.tick(DT, Vector2(60, 0), player)
	_run_attack(a, Vector2(60, 0), CHASER.attack.windup - 0.3)
	player.request_dash(Vector2.LEFT)
	player.global_position = Vector2(-260, 0)  # 원 밖으로 빠져나감
	var results := _run_attack(a, Vector2(60, 0), 0.4)
	assert_array(results).is_equal([EnemyAttack.Result.EVADED])


func test_walking_out_early_is_just_a_miss() -> void:
	var a := _attack()
	a.tick(DT, Vector2(60, 0), player)
	player.global_position = Vector2(-300, 0)  # 대시 없이 이미 벗어남
	var results := _run_attack(a, Vector2(60, 0), CHASER.attack.windup + 0.05)
	assert_array(results).is_equal([EnemyAttack.Result.MISSED])


func test_concurrent_windups_are_capped() -> void:
	var attacks: Array = []
	for i in 6:
		var a := _attack()
		a.tick(DT, Vector2(50, 0), player)
		attacks.append(a)
	var winding := attacks.filter(func(a: EnemyAttack) -> bool: return a.state == EnemyAttack.State.WINDUP)
	assert_int(winding.size()).is_equal(EnemyAttack.max_concurrent)
	(attacks[0] as EnemyAttack).cancel()
	assert_int(EnemyAttack.active_windups).is_equal(EnemyAttack.max_concurrent - 1)


func test_enemy_stands_still_during_windup() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.target = player
	add_child(auto_free(e))
	e.global_position = Vector2(80, 0)
	e.attack = _attack()
	e._physics_process(DT)
	assert_bool(e.attack.is_busy()).is_true()
	assert_vector(e.velocity).is_equal(Vector2.ZERO)


# --- 반격 ---

func test_evade_opens_counter_and_tap_casts_counter() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(150, 0)
	enemies.append(e)
	player.register_evade()
	assert_bool(caster.is_counter_open()).is_true()
	assert_int(caster.preview_slot()).is_equal(SkillCaster.Slot.COUNTER)
	caster.gesture_down(0, Vector2(300, 900), 0.0)
	assert_int(caster.gesture_up(0, 0.05)).is_equal(SkillCaster.Slot.COUNTER)
	assert_array(casts).is_equal([SkillCaster.Slot.COUNTER])
	assert_bool(not is_instance_valid(e) or e.health.current < e.health.max).is_true()
	assert_bool(caster.is_counter_open()).is_false()


func test_counter_beats_dash_skill_priority() -> void:
	player.request_dash(Vector2.RIGHT)
	player.register_evade()
	assert_bool(caster.try_dash_release()).is_true()
	assert_array(casts).is_equal([SkillCaster.Slot.COUNTER])
	assert_bool(caster.is_ready(SkillCaster.Slot.DASH)).is_true()


func test_counter_window_expires_after_one_second() -> void:
	player.register_evade()
	caster.tick(0.5, 0.5)
	assert_bool(caster.is_counter_open()).is_true()
	caster.tick(0.55, 1.05)
	assert_bool(caster.is_counter_open()).is_false()
	caster.gesture_down(0, Vector2(300, 900), 1.1)
	assert_int(caster.gesture_up(0, 1.15)).is_equal(SkillCaster.Slot.TAP)


func test_plain_release_without_dash_does_not_counter() -> void:
	player.register_evade()
	assert_bool(caster.try_dash_release()).is_false()  # 대시 아닌 손 떼기
	assert_bool(caster.is_counter_open()).is_true()


func test_counter_hit_stop_restores_time_scale() -> void:
	var ctx := SkillContext.new()
	ctx.player = player
	ctx.hit_stop(0.05)
	assert_float(Engine.time_scale).is_less(0.5)
	await _wait_real(0.15)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_hero_data_has_counter() -> void:
	assert_object(HERO.kit.counter).is_instanceof(CounterSlashSkill)
	assert_float(HERO.kit.counter_window).is_equal(1.0)


# --- 회피 성공 즉시 무적 (파고들어 반격) ---

func test_dash_out_of_circle_grants_invulnerability_immediately() -> void:
	var a := _attack()
	a.tick(DT, Vector2(60, 0), player)
	_run_attack(a, Vector2(60, 0), 0.1)  # 예고 시작 직후 (타격까지 약 0.5초 남음)
	player.request_dash(Vector2.LEFT)
	player.global_position = Vector2(-260, 0)  # 대시로 원 밖으로
	a.tick(DT, Vector2(60, 0), player)  # 다음 프레임: 타격 전인데도 바로 회피 처리
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)
	assert_float(player.skill_invuln_left()).is_greater(0.0)
	assert_bool(caster.is_counter_open()).is_true()
	for i in 12:  # 대시가 끝나도 무적
		player.compute_velocity(DT)
	assert_bool(player.is_dashing()).is_false()
	assert_bool(player.apply_hit(10)).is_false()
	assert_bool(player.apply_contact_damage(DT, 10)).is_false()
	var results := _run_attack(a, Vector2(60, 0), 0.6)
	assert_array(results).is_equal([EnemyAttack.Result.EVADED])  # 타격 때 중복 처리 없음


func test_walking_out_then_nothing_until_strike() -> void:
	var a := _attack()
	a.tick(DT, Vector2(60, 0), player)
	player.global_position = Vector2(-300, 0)  # 대시 없이 걸어서 나감
	a.tick(DT, Vector2(60, 0), player)
	assert_float(player.skill_invuln_left()).is_equal(0.0)
	assert_bool(caster.is_counter_open()).is_false()


func test_only_one_evade_per_attack() -> void:
	var a := _attack()
	var evades := [0]
	player.evaded.connect(func() -> void: evades[0] += 1)
	a.tick(DT, Vector2(60, 0), player)
	player.request_dash(Vector2.LEFT)
	player.global_position = Vector2(-200, 0)
	a.tick(DT, Vector2(60, 0), player)
	player.global_position = Vector2(0, 0)  # 다시 들어왔다가
	a.tick(DT, Vector2(60, 0), player)
	player.global_position = Vector2(-200, 0)  # 또 나감
	_run_attack(a, Vector2(60, 0), 0.7)
	assert_int(evades[0]).is_equal(1)


func test_evade_invulnerability_lasts_about_one_second() -> void:
	player.register_evade()
	assert_float(player.skill_invuln_left()).is_equal(player.evade_invuln_time)
	for i in int(ceil(player.evade_invuln_time / DT)) + 1:
		player.compute_velocity(DT)
	assert_bool(player.apply_hit(10)).is_true()


func test_invulnerable_inside_next_circle_is_not_another_evade() -> void:
	# 무적으로 원 안에 서 있으면 피해는 없지만 회피(반격 기회)를 또 주지 않는다 (무한 반복 방지)
	player.register_evade()
	var a := _attack()
	var evades := [0]
	player.evaded.connect(func() -> void: evades[0] += 1)
	a.tick(DT, Vector2(60, 0), player)
	var results := _run_attack(a, Vector2(60, 0), 0.5)  # 0.6초 예고보다 짧게 → 아직 타격 전
	assert_array(results).is_empty()
	results = _run_attack(a, Vector2(60, 0), 0.15)
	assert_array(results).is_equal([EnemyAttack.Result.MISSED])
	assert_int(evades[0]).is_equal(0)
	assert_int(player.health.current).is_equal(player.health.max)


func test_hero_data_sets_evade_invulnerability() -> void:
	var p: Player = auto_free(Player.new())
	p.hero = HERO
	add_child(p)
	assert_float(p.evade_invuln_time).is_equal(HERO.evade_invuln_time)


# --- Codex e593772 회귀 ---

func test_overlapping_hit_stops_restore_only_after_the_last() -> void:
	var ctx := SkillContext.new()
	ctx.player = player
	# 준비 단계의 긴 프레임이 다음 프레임 delta에 섞여 타이머를 한꺼번에 끝내지 않게 한 프레임 비운다.
	await get_tree().process_frame
	await get_tree().process_frame
	ctx.hit_stop(0.05)
	ctx.hit_stop(0.25)
	await _wait_real(0.12)
	assert_float(Engine.time_scale).is_less(0.5)  # 첫 번째가 끝나도 두 번째 진행 중
	await _wait_real(0.25)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_held_button_during_evade_casts_counter_not_dash_skill() -> void:
	caster.on_press(0, 0.0)  # 버튼을 먼저 누르고 있음 (탭 판정 전)
	player.request_dash(Vector2.RIGHT)
	player.register_evade()
	caster.tick(DT, DT)
	assert_array(casts).is_equal([SkillCaster.Slot.COUNTER])
	assert_bool(caster.is_ready(SkillCaster.Slot.DASH)).is_true()


## 실제 시간으로 기다린다 (ignore_time_scale 타이머는 느린 시간에서 일찍 끝난다).
func _wait_real(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
