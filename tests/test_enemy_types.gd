extends GdUnitTestSuite
## 2단계 적 3종: 잡병(추적·내려찍기), 궁수(거리 유지·조준선·화살), 중장병(느림·단단함·큰 내려찍기).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CHASER := preload("res://data/enemies/chaser.tres")
const ARCHER := preload("res://data/enemies/archer.tres")
const HEAVY := preload("res://data/enemies/heavy.tres")
const DT := 1.0 / 60.0

var player: Player


func before_test() -> void:
	EnemyAttack.active_windups = 0
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.global_position = Vector2.ZERO


func after_test() -> void:
	EnemyAttack.active_windups = 0


func _enemy(data: EnemyData, pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = data
	e.target = player
	add_child(auto_free(e))
	e.global_position = pos
	return e


func _arrow(pos: Vector2, dir: Vector2) -> EnemyArrow:
	var a: EnemyArrow = auto_free(EnemyArrow.new())
	a.direction = dir
	a.setup(player, pos, ARCHER.attack)
	add_child(a)
	a.set_physics_process(false)
	return a


func _fly(a: EnemyArrow, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		t += DT
		player.compute_velocity(DT)
		if a.step(DT):
			return true
	return false


func test_data_files() -> void:
	assert_int(ARCHER.attack.kind).is_equal(EnemyAttackData.Kind.SHOOT)
	assert_float(ARCHER.preferred_range).is_greater(0.0)
	assert_int(HEAVY.max_hp).is_greater(CHASER.max_hp * 3)
	assert_float(HEAVY.knockback_scale).is_less(1.0)
	assert_float(HEAVY.attack.radius).is_greater(CHASER.attack.radius)


# --- 궁수 ---

func test_shoot_attack_aims_then_fires_without_direct_damage() -> void:
	var a := EnemyAttack.new(ARCHER.attack, 0.0)
	a.tick(DT, Vector2(300, 0), player)
	assert_int(a.state).is_equal(EnemyAttack.State.WINDUP)
	assert_vector(a.aim_dir).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))
	var fired := false
	var t := 0.0
	while t < ARCHER.attack.windup + 0.05:
		t += DT
		if a.tick(DT, Vector2(300, 0), player) == EnemyAttack.Result.FIRED:
			fired = true
	assert_bool(fired).is_true()
	assert_int(player.health.current).is_equal(player.health.max)


func test_archer_enemy_spawns_arrow() -> void:
	var e := _enemy(ARCHER, Vector2(300, 0))
	e.attack = EnemyAttack.new(ARCHER.attack, 0.0)
	var t := 0.0
	while t < ARCHER.attack.windup + 0.1:
		t += DT
		e._physics_process(DT)
	var arrows := get_children().filter(func(c: Node) -> bool: return c is EnemyArrow)
	assert_int(arrows.size()).is_equal(1)
	for a in arrows:
		(a as Node).queue_free()


func test_arrow_hits_standing_player() -> void:
	var a := _arrow(Vector2(200, 0), Vector2.LEFT)
	assert_bool(_fly(a, 1.0)).is_true()
	assert_int(player.health.current).is_equal(player.health.max - ARCHER.attack.damage)


func test_dashing_through_arrow_is_evade_and_no_damage() -> void:
	var evades := [0]
	player.evaded.connect(func() -> void: evades[0] += 1)
	var a := _arrow(Vector2(60, 0), Vector2.LEFT)
	player.request_dash(Vector2.UP)
	_fly(a, 0.1)
	assert_int(evades[0]).is_equal(1)
	assert_int(player.health.current).is_equal(player.health.max)


func test_arrow_passes_invulnerable_player_without_evade() -> void:
	var evades := [0]
	player.evaded.connect(func() -> void: evades[0] += 1)
	player.grant_invulnerability(2.0)
	var a := _arrow(Vector2(100, 0), Vector2.LEFT)
	_fly(a, 0.5)
	assert_int(evades[0]).is_equal(0)
	assert_int(player.health.current).is_equal(player.health.max)


func test_arrow_expires_after_range() -> void:
	var a := _arrow(Vector2(0, 500), Vector2.DOWN)
	assert_bool(_fly(a, 2.0)).is_true()
	assert_float(a.traveled).is_greater_equal(ARCHER.attack.projectile_range)


func test_archer_keeps_distance() -> void:
	var e := _enemy(ARCHER, Vector2(100, 0))
	assert_float(e.compute_velocity([]).x).is_greater(0.0)  # 너무 가까움 → 물러남
	e.global_position = Vector2(ARCHER.preferred_range, 0)
	assert_vector(e.compute_velocity([])).is_equal(Vector2.ZERO)  # 적당 → 멈춤
	e.global_position = Vector2(800, 0)
	assert_float(e.compute_velocity([]).x).is_less(0.0)  # 멀다 → 다가옴


# --- 중장병 ---

func test_heavy_is_tough_and_resists_knockback() -> void:
	var e := _enemy(HEAVY, Vector2(300, 0))
	assert_int(e.health.max).is_equal(HEAVY.max_hp)
	e.apply_knockback(Vector2(100, 0))
	assert_float(e.knockback.x).is_equal_approx(100.0 * HEAVY.knockback_scale, 0.01)
	var c := _enemy(CHASER, Vector2(-300, 0))
	c.apply_knockback(Vector2(100, 0))
	assert_float(c.knockback.x).is_equal_approx(100.0, 0.01)


# --- 생성기 ---

func _spawner() -> EnemySpawner:
	var s: EnemySpawner = auto_free(EnemySpawner.new())
	s.enemy_scene = ENEMY_SCENE
	s.target = player
	s.rng.seed = 7
	var table: Array[EnemyData] = [CHASER, ARCHER, HEAVY]
	s.spawn_table = table
	s.spawn_weights = PackedFloat32Array([6, 2, 1])
	s.unlock_times = PackedFloat32Array([0, 10, 20])
	add_child(s)
	return s


func test_only_chasers_at_start() -> void:
	var s := _spawner()
	for i in 50:
		assert_object(s.pick_data()).is_same(CHASER)


func test_all_types_after_unlock() -> void:
	var s := _spawner()
	s.elapsed = 30.0
	var counts := {CHASER: 0, ARCHER: 0, HEAVY: 0}
	for i in 900:
		counts[s.pick_data()] += 1
	assert_int(counts[ARCHER]).is_greater(100)
	assert_int(counts[HEAVY]).is_greater(40)
	assert_int(counts[CHASER]).is_greater(counts[ARCHER])


func test_spawned_enemy_gets_picked_data() -> void:
	var s := _spawner()
	s.elapsed = 30.0
	var seen := {}
	for i in 30:
		var e := s.spawn_one()
		if e:
			seen[e.data.id] = true
	assert_bool(seen.has(&"archer") or seen.has(&"heavy")).is_true()


func test_boss_patterns_pick_their_own_sprite_animation() -> void:
	var boss_data: EnemyData = preload("res://data/enemies/boss_general.tres")
	var anims := boss_data.patterns.map(func(p: EnemyAttackData) -> String: return String(p.anim))
	assert_array(anims).contains_exactly(["attack2", "attack", "attack"])  # 언월도 휩쓸기 · 내려찍기 · 홑 화살 (멀 때만)
	for a in anims:
		assert_bool(boss_data.sprite_sheet.has_anim(a)).is_true()
