extends GdUnitTestSuite
## 실측 벤치마크 적용 (docs/research/open_data_benchmark.md, hades_data.md): 왜군 대기·피해, 경직 + 대기 다시 세기(상한),
## 물결 상한 3·4·5 + 6·3·9 + 한 마리씩 보충, 예고 끝 떨림, 3타 늦은 감속, 물결 끝 감속 + 복귀.

const HANSAN := preload("res://data/stages/hansan_1592.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const GUNNER := preload("res://data/enemies/waegun_gunner.tres")
const HEAVY := preload("res://data/enemies/waegun_heavy.tres")
const ELITE := preload("res://data/enemies/waegun_elite.tres")
const BOSS := preload("res://data/enemies/waegun_commander.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()


func test_waegun_cycle_and_damage_values() -> void:
	assert_float(SOLDIER.attack.cooldown).is_equal(1.8)
	assert_float(GUNNER.attack.cooldown).is_equal(1.6)
	assert_float(HEAVY.attack.cooldown).is_equal(2.2)
	assert_float(ELITE.attack.cooldown).is_equal(1.8)
	assert_int(SOLDIER.attack.damage).is_equal(15)
	assert_int(ELITE.attack.damage).is_equal(25)
	var hp := float(YI.max_hp)
	for d: EnemyData in [SOLDIER, GUNNER, HEAVY]:  # 잡몹 한 방 2~20%
		assert_float(d.attack.damage / hp).override_failure_message(d.id).is_between(0.02, 0.2)
		assert_float(d.contact_damage / hp).override_failure_message(d.id).is_less_equal(0.2)
	for d: EnemyData in [ELITE, BOSS]:  # 정예·보스 큰 공격만 25%까지
		for a in [d.attack] + d.patterns:
			if a:
				assert_float((a as EnemyAttackData).damage / hp).override_failure_message(d.id).is_less_equal(0.25)


## 대기 다시 세기: 기다리는 중에만, 마지막 공격 뒤 cooldown × 상한 안에는 다시 준비된다.
func test_restart_wait_is_capped() -> void:
	var a := EnemyAttack.new(SOLDIER.attack)
	a._since_strike = 0.5
	a._cooldown = 0.2
	a.restart_wait(1.3)
	assert_float(a._cooldown).is_equal_approx(SOLDIER.attack.cooldown, 0.001)  # 처음부터
	a._since_strike = 2.0
	a._cooldown = 0.0
	a.restart_wait(1.3)
	assert_float(a._cooldown).is_equal_approx(1.8 * 1.3 - 2.0, 0.001)  # 상한까지만
	a._since_strike = 3.0
	a._cooldown = 0.0
	a.restart_wait(1.3)
	assert_float(a._cooldown).is_equal(0.0)  # 상한을 넘었으면 그대로
	a.state = EnemyAttack.State.RECOVER
	a._since_strike = 0.0
	a.restart_wait(1.3)
	assert_float(a._cooldown).is_equal(0.0)  # 기다리는 중이 아니면 건드리지 않음


## 연타로 계속 맞혀도 다음 공격 사이가 정해진 값 안 (영구 경직 없음): 0.2초마다 경직·대기 다시 세기.
func test_constant_hits_cannot_lock_attacks_forever() -> void:
	var a := EnemyAttack.new(SOLDIER.attack)
	var im := Feedback.feel_data().impact_data()
	var t := 0.0
	var last := 0.0
	var worst := 0.0
	var hit_t := 0.0
	var p := Player.new()
	add_child(auto_free(p))
	var strikes := 0
	while t < 20.0:
		t += DT
		hit_t -= DT
		if hit_t <= 0.0:
			hit_t = 0.2
			if a.can_interrupt():
				a.interrupt(im.interrupt_cooldown, im.interrupt_rearm)
			a.restart_wait(im.reset_max_gap_mult)
		var before := a.state
		a.tick(DT, Vector2.ZERO, p)
		if before == EnemyAttack.State.WINDUP and a.state == EnemyAttack.State.RECOVER:
			worst = maxf(worst, t - last)
			last = t
			strikes += 1
		EnemyAttack.active_windups = 0
	assert_int(strikes).is_greater(3)
	var bound := SOLDIER.attack.cooldown * im.reset_max_gap_mult + im.interrupt_cooldown + 2.0 * SOLDIER.attack.windup + 0.05
	assert_float(worst).is_less_equal(bound)


func test_trash_stagger_uses_enemy_value() -> void:
	var r := HitReaction.new(Feedback.feel_data().reaction_data(), HitReaction.Tier.TRASH)
	r.stagger_override = SOLDIER.stagger_time
	r.on_hit(5, 45, Vector2.RIGHT)
	assert_float(r.stagger_left).is_equal(0.3)
	var plain := HitReaction.new(Feedback.feel_data().reaction_data(), HitReaction.Tier.TRASH)
	plain.on_hit(5, 45, Vector2.RIGHT)
	assert_float(plain.stagger_left).is_equal(Feedback.feel_data().reaction_data().stagger_time)  # 다른 무대 적은 그대로
	assert_bool(HEAVY.hit_resets_attack).is_false()  # 슈퍼아머 · 정예 · 보스는 지금 규칙
	assert_bool(ELITE.hit_resets_attack).is_false()


## 한산 물결: 6 · 3 · 9 (30 · 15 · 55%), 상한 3 · 4 · 5, 한 마리씩 보충.
func test_hansan_waves_follow_hades_split() -> void:
	var w := HANSAN.waves
	assert_bool(w.refill_each).is_true()
	var counts := []
	var caps := []
	for wave: WaveData in w.waves:
		counts.append(wave.enemies.size())
		caps.append(wave.max_alive)
	assert_array(counts).is_equal([6, 3, 9])
	assert_array(caps).is_equal([3, 4, 5])
	assert_bool(w.waves[1].elite_last).is_true()  # 큰 강화는 쉬는 물결 끝


## 한 마리씩 보충: 상한까지 채우고, 한 마리 죽으면 한 마리. 난이도 추가는 물결 상한에도 더해진다.
func test_runner_refills_one_for_one_with_wave_cap() -> void:
	var s := WaveSetData.new()
	var wd := WaveData.new()
	for i in 6:
		wd.enemies.append(SOLDIER)
	wd.max_alive = 3
	s.waves.append(wd)
	s.refill_each = true
	s.spawn_stagger = 0.0
	var r := WaveRunner.new(s, 0.0)
	r.tick(DT, 0, false)
	assert_int(r.wave_cap(s.max_alive)).is_equal(3)
	assert_int(r.wave_cap(s.max_alive + 2)).is_equal(5)  # 난이도 +2
	var alive := 0
	while not r.next_spawn(alive, s.max_alive).is_empty():
		alive += 1
	assert_int(alive).is_equal(3)
	alive -= 1  # 한 마리 죽음
	assert_int(r.next_spawn(alive, s.max_alive).size()).is_equal(1)
	assert_int(r.next_spawn(alive + 1, s.max_alive).size()).is_equal(0)


## 감속 복귀: 마지막 ramp 구간에서 배율이 scale → 1로 올라간다 (순수 계산).
func test_game_time_ramp_returns_smoothly() -> void:
	GameTime._stop_until_ms = 10_000
	GameTime._stop_scale = 0.35
	GameTime._ramp_ms = 400
	GameTime._inner_until_ms = 0
	assert_float(GameTime.current_scale(9_000)).is_equal_approx(0.35, 0.001)
	assert_float(GameTime.current_scale(9_800)).is_equal_approx(0.675, 0.001)
	assert_float(GameTime.current_scale(10_000)).is_equal(1.0)


func test_slow_values_match_hades() -> void:
	var f := Feedback.feel_data()
	assert_float(f.wave_end_slow_time).is_equal(0.6)
	assert_float(f.wave_end_slow_back).is_equal(0.4)
	assert_float(f.wave_end_slow_scale).is_equal(0.35)
	var im := f.impact_data()
	assert_float(im.heavy_slow_scale).is_equal(0.1)
	assert_float(im.heavy_slow_delay).is_between(0.02, 0.06)
	assert_float(im.heavy_slow_back).is_between(0.03, 0.07)


## 예고 끝 떨림: 번쩍이는 동안만, 크기 ≤ windup_shake_px.
func test_windup_end_shake_only_while_flashing() -> void:
	var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	assert_float(EnemySprite.windup_shake(e)).is_equal(0.0)
	e.attack.state = EnemyAttack.State.WINDUP
	e.attack._timer = 0.1
	var ai := Enemy.ai_data()
	assert_float(absf(EnemySprite.windup_shake(e))).is_less_equal(ai.windup_shake_px)
	e.attack._timer = 0.5
	assert_float(EnemySprite.windup_shake(e)).is_equal(0.0)
