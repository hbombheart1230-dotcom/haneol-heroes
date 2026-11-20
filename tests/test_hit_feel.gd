extends GdUnitTestSuite
## 타격감 1차 (docs/game_feel_research.md ①②③): 개별 멈칫, 처치 날림, 먹물·군대별 죽음, 방향 흔들림.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ELITE := preload("res://data/enemies/jurchen_elite.tres")
const SOLDIER := preload("res://data/enemies/jurchen_soldier.tres")
const MOUSE := preload("res://data/enemies/cc_mouse.tres")
const PROJ := preload("res://scenes/projectile.tscn")


func after_test() -> void:
	Feedback.instance = null
	GameTime.reset()


func _feedback() -> Feedback:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	return f


func _enemy(data: EnemyData = null, pos: Vector2 = Vector2(60, 0)) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = data
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	return e


func test_feel_data_numbers() -> void:
	var d: CombatFeelData = load("res://data/feel/combat_feel.tres")
	assert_float(d.freeze_for(5)).is_equal(d.hit_freeze)
	assert_float(d.freeze_for(d.heavy_damage)).is_equal(d.hit_freeze_heavy)
	assert_float(d.launch_distance(0)).is_equal(d.launch_base)
	assert_float(d.launch_distance(10000)).is_equal(d.launch_max)
	assert_float(d.launch_distance(10, 0.5)).is_equal((d.launch_base + 10 * d.launch_per_damage) * 0.5)


func test_corpse_flight_arcs_and_lands() -> void:
	var f := CorpseFlight.new(Vector2.ZERO, Vector2.RIGHT, 200.0, 60.0, 0.4, 1.5)
	assert_float(f.lift(0.0)).is_equal(0.0)
	assert_float(f.lift(0.2)).is_equal_approx(60.0, 0.01)
	assert_float(f.lift(0.4)).is_equal_approx(0.0, 0.01)
	assert_vector(f.ground(0.4)).is_equal_approx(Vector2(200, 0), Vector2(0.01, 0.01))
	assert_float(f.ground(0.2).x).is_greater(100.0)  # 빨리 나가서 느려짐
	assert_float(f.angle(0.4)).is_equal_approx(1.5 * TAU, 0.001)
	assert_float(CorpseFlight.new(Vector2.ZERO, Vector2.LEFT, 10, 1, 1, 1).spins).is_less(0.0)
	assert_bool(f.landed(0.39)).is_false()
	assert_bool(f.landed(0.4)).is_true()


func test_kill_fx_caps_corpses_and_drops() -> void:
	var k: KillFx = auto_free(KillFx.new())
	var tex := PlaceholderTexture2D.new()
	for i in k.feel.max_corpses + 5:
		k.launch(Vector2.ZERO, Vector2.RIGHT, 10, tex, 1.0, Vector2.ZERO, Color.WHITE, &"smoke")
	assert_int(k.corpse_count()).is_equal(k.feel.max_corpses)
	for i in 40:
		k.drops(Vector2.ZERO, Vector2.UP, 5)
	assert_int(k.drop_count()).is_equal(k.feel.max_drops)


func test_corpse_lands_into_mark_and_army_style() -> void:
	var k: KillFx = auto_free(KillFx.new())
	k.launch(Vector2.ZERO, Vector2.RIGHT, 10, PlaceholderTexture2D.new(), 1.0, Vector2.ZERO, Color.WHITE, &"paper")
	assert_int(k.bit_count()).is_equal(0)
	k.step(k.feel.launch_time + 0.01)
	assert_int(k.corpse_count()).is_equal(0)
	var kinds := {}
	for b in k._bits:
		kinds[b["kind"]] = true
	assert_bool(kinds.has("mark")).is_true()
	assert_bool(kinds.has("paper")).is_true()
	k.death_burst(Vector2.ZERO, &"smoke", true)
	kinds.clear()
	for b in k._bits:
		kinds[b["kind"]] = true
	assert_bool(kinds.has("smoke")).is_true()
	assert_bool(kinds.has("ring")).is_true()  # 정예·보스 금빛 고리
	k.step(5.0)
	assert_int(k.bit_count()).is_equal(0)
	assert_int(k.drop_count()).is_equal(0)


func test_army_death_styles_in_data() -> void:
	assert_str(String(MOUSE.death_style)).is_equal("paper")
	assert_str(String(SOLDIER.death_style)).is_equal("smoke")
	assert_float(ELITE.launch_scale).is_less(1.0)


func test_hit_freezes_only_that_enemy_and_drops_ink() -> void:
	var f := _feedback()
	var p: Player = auto_free(Player.new())
	add_child(p)
	var e := _enemy(SOLDIER)
	var other := _enemy(SOLDIER, Vector2(-200, 0))
	e.target = p
	e.health.damage(5)
	assert_bool(e.is_frozen()).is_true()
	assert_bool(other.is_frozen()).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)  # 게임 전체는 안 멈춤
	assert_vector(e.last_hit_dir()).is_equal_approx(Vector2.RIGHT, Vector2(0.01, 0.01))
	assert_int(f.kill_fx.drop_count()).is_equal(f.feel.hit_drops)
	# 멈칫 중엔 넉백이 있어도 움직이지 않고, 끝나면 이어진다
	e.apply_knockback(Vector2(300, 0))
	var before := e.global_position
	e._physics_process(0.016)
	assert_vector(e.global_position).is_equal(before)
	for i in 6:
		e._physics_process(0.016)
	assert_bool(e.is_frozen()).is_false()
	assert_float(e.global_position.x).is_greater(before.x)


func test_heavy_hit_freezes_longer() -> void:
	_feedback()
	var e := _enemy(SOLDIER)
	e.health.damage(Feedback.feel_data().heavy_damage)
	assert_float(e._freeze_left).is_equal(Feedback.feel_data().hit_freeze_heavy)


func test_kill_launches_corpse_and_kicks_camera() -> void:
	var f := _feedback()
	var p: Player = auto_free(Player.new())
	add_child(p)
	var e := _enemy(SOLDIER)
	e.target = p
	e.health.damage(9999)
	assert_int(f.kill_fx.corpse_count()).is_equal(1)
	assert_float(f._kick.x).is_greater(0.0)  # 맞은 방향(오른쪽)으로 툭
	assert_float(f.trauma).is_greater(0.0)


func test_elite_kill_slows_time_then_restores() -> void:
	var f := _feedback()
	var p: Player = auto_free(Player.new())
	add_child(p)
	var e := _enemy(ELITE)
	e.target = p
	e.health.damage(99999)
	assert_float(Engine.time_scale).is_equal_approx(f.feel.finisher_time_scale, 0.001)
	await _wait_real(f.feel.finisher_time + 0.1)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_directional_shake_leans_on_hit_direction() -> void:
	var f := _feedback()
	f.add_trauma(1.0, Vector2.RIGHT)
	var side_max := 0.0
	for i in 30:
		var o := f.shake_offset()
		side_max = maxf(side_max, absf(o.y))
	assert_float(side_max).is_less_equal(f.max_shake * f.feel.shake_side_ratio + 0.01)


func test_kick_returns_to_center() -> void:
	var f := _feedback()
	f.kick(Vector2.LEFT, 6.0)
	assert_float(f._kick.x).is_equal(-6.0)
	for i in 60:
		f._process(0.016)
	assert_vector(f._kick).is_equal(Vector2.ZERO)
	assert_vector(f.camera.offset).is_equal(Vector2.ZERO)


func test_ranged_projectile_pushes_enemy() -> void:
	var e := _enemy(SOLDIER)
	var pr: Projectile = auto_free(PROJ.instantiate())
	pr.direction = Vector2.DOWN
	pr.knockback = 50.0
	pr._on_action_applied(e.get_node("HurtBox2D") as HurtBox2D)
	assert_float(e.knockback.y).is_greater(0.0)


func test_hero_data_has_feel_numbers() -> void:
	for id in ["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"]:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_float(h.move_accel_time).is_greater(0.0)
		assert_float(h.attack.melee_recoil).is_greater(0.0)
		assert_float(h.attack.ranged_knockback).is_greater(0.0)
	var heavy: HeroData = load("res://data/heroes/gwanggaeto.tres")
	var light: HeroData = load("res://data/heroes/shin_saimdang.tres")
	assert_float(heavy.move_accel_time).is_greater(light.move_accel_time)


func test_short_stop_does_not_cut_finisher_short() -> void:
	# Codex c6580b8 P1: 정예 슬로모션 중 일반 처치 멈춤이 슬로모션을 일찍 풀면 안 된다
	GameTime.stop(get_tree(), 0.3, 0.25)
	GameTime.stop(get_tree(), 0.03, 0.05)
	assert_float(Engine.time_scale).is_equal_approx(0.25, 0.001)
	await _wait_real(0.12)
	assert_float(Engine.time_scale).is_equal_approx(0.25, 0.001)
	await _wait_real(0.3)
	assert_float(Engine.time_scale).is_equal(1.0)


## 실제 시간으로 기다린다 (ignore_time_scale 타이머는 느린 시간에서 일찍 끝난다).
func _wait_real(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func test_burst_numbers_come_from_data() -> void:
	var feel := CombatFeelData.new()
	feel.burst = InkBurstData.new()
	feel.burst.paper_count = 2
	feel.burst.smoke_count = 3
	var k: KillFx = auto_free(KillFx.new(feel))
	k.death_burst(Vector2.ZERO, &"paper")
	var paper := 0
	for b in k._bits:
		paper += 1 if b["kind"] == "paper" else 0
	assert_int(paper).is_equal(2)
	k.death_burst(Vector2.ZERO, &"smoke", true)
	var smoke := 0
	for b in k._bits:
		smoke += 1 if b["kind"] == "smoke" else 0
	assert_int(smoke).is_equal(3 * feel.burst.finisher_scale)


func test_feel_tres_holds_burst_values() -> void:
	var d: CombatFeelData = load("res://data/feel/combat_feel.tres")
	assert_object(d.burst).is_not_null()
	assert_int(d.burst.paper_count).is_greater(0)
	assert_float(d.burst.ring_width).is_greater(d.burst.ring_width_min)


func test_reset_drops_stop_watch_at_once() -> void:
	GameTime.stop(get_tree(), 1.0, 0.25)
	assert_bool(get_tree().process_frame.is_connected(GameTime._on_frame)).is_true()
	GameTime.reset()
	assert_bool(get_tree().process_frame.is_connected(GameTime._on_frame)).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_seal_slow_time_keeps_running_finisher() -> void:
	# Codex 5fb5388: 정예 처치 슬로모션 직후 인장(기준 0.35)이 열려도 슬로모션이 이어지고, 끝나면 0.35로
	GameTime.stop(get_tree(), 0.2, 0.25)
	GameTime.set_base(0.35)
	assert_float(Engine.time_scale).is_equal_approx(0.35 * 0.25, 0.001)
	await _wait_real(0.3)
	assert_float(Engine.time_scale).is_equal_approx(0.35, 0.001)


func test_haptics_fire_on_hurt_and_finisher_with_gap_and_setting() -> void:
	var f := _feedback()
	var was := GameSettings.haptics_enabled
	GameSettings.haptics_enabled = true
	Haptics.last = []
	assert_bool(f.haptic(f.feel.haptic_hurt_ms, f.feel.haptic_hurt_amp)).is_true()
	assert_array(Haptics.last).is_equal([f.feel.haptic_hurt_ms, f.feel.haptic_hurt_amp])
	assert_bool(f.haptic(10, 0.1)).is_false()  # 간격 제한
	f._last_haptic = -INF
	GameSettings.haptics_enabled = false
	assert_bool(f.haptic(10, 0.1)).is_false()  # 설정 끔
	GameSettings.haptics_enabled = true
	# 정예 처치 → 마무리 진동
	f._last_haptic = -INF
	Haptics.last = []
	var p: Player = auto_free(Player.new())
	add_child(p)
	var e := _enemy(ELITE)
	e.target = p
	e.health.damage(99999)
	assert_array(Haptics.last).is_equal([f.feel.haptic_finisher_ms, f.feel.haptic_finisher_amp])
	GameSettings.haptics_enabled = was
