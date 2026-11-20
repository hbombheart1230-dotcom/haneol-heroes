extends GdUnitTestSuite
## P0-B 기본 전투: 적 추적·분리·사망, 스포너(최대 30), 자동 공격, 투사체 적중, 접촉 피해, 게임 상태.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


func _node_at(pos: Vector2) -> Node2D:
	var n: Node2D = auto_free(Node2D.new())
	add_child(n)
	n.global_position = pos
	return n


func _enemy_at(pos: Vector2, target: Node2D = null) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.target = target
	add_child(auto_free(e))
	e.global_position = pos
	return e


func _player_at(pos: Vector2) -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.global_position = pos
	return p


# --- Targeting ---

func test_nearest_within_range() -> void:
	var a := _node_at(Vector2(100, 0))
	var b := _node_at(Vector2(50, 0))
	_node_at(Vector2(500, 0))
	assert_object(Targeting.nearest([a, b], Vector2.ZERO, 200)).is_same(b)
	assert_object(Targeting.nearest([a, b], Vector2.ZERO, 40)).is_null()


func test_in_arc_only_front() -> void:
	var front := _node_at(Vector2(60, 0))
	var back := _node_at(Vector2(-60, 0))
	var far := _node_at(Vector2(300, 0))
	var hits := Targeting.in_arc([front, back, far], Vector2.ZERO, Vector2.RIGHT, 110, 140)
	assert_array(hits).contains_exactly([front])


# --- Enemy ---

func test_enemy_chases_target() -> void:
	var target := _node_at(Vector2(300, 0))
	var e := _enemy_at(Vector2.ZERO, target)
	var v := e.compute_velocity([])
	assert_float(v.length()).is_equal_approx(e.move_speed, 0.01)
	assert_float(v.normalized().x).is_greater(0.99)


func test_enemies_separate_when_overlapping() -> void:
	var target := _node_at(Vector2(0, -1000))
	var a := _enemy_at(Vector2(0, 0), target)
	var b := _enemy_at(Vector2(10, 0), target)
	var v := a.compute_velocity([a, b])
	assert_float(v.x).is_less(0.0)  # b의 반대쪽으로 밀림


func test_enemy_dies_and_emits_killed() -> void:
	var e := _enemy_at(Vector2.ZERO)
	var killed: Array = []
	e.killed.connect(func(en: Enemy) -> void: killed.append(en))
	e.health.damage(e.health.max)
	assert_int(killed.size()).is_equal(1)
	assert_bool(e.is_queued_for_deletion()).is_true()
	assert_bool(e.is_in_group(Enemy.GROUP)).is_false()


# --- Spawner ---

func _spawner(target: Node2D) -> EnemySpawner:
	var s: EnemySpawner = auto_free(EnemySpawner.new())
	s.enemy_scene = ENEMY_SCENE
	s.target = target
	s.rng.seed = 1234
	add_child(s)
	return s


func test_spawner_caps_at_30_alive() -> void:
	var s := _spawner(_node_at(Vector2.ZERO))
	for i in 1800:  # 30초
		s.tick(1.0 / 60.0)
	assert_int(s.alive_count()).is_equal(30)
	assert_object(s.spawn_one()).is_null()


func test_spawner_refills_after_kill() -> void:
	var s := _spawner(_node_at(Vector2.ZERO))
	for i in 1800:
		s.tick(1.0 / 60.0)
	var victim := s.get_child(0) as Enemy
	victim.health.kill()
	assert_int(s.alive_count()).is_equal(29)
	assert_object(s.spawn_one()).is_not_null()


func test_spawn_position_in_ring_and_arena() -> void:
	var s := _spawner(_node_at(Vector2.ZERO))
	for i in 200:
		var p := s.pick_spawn_position(Vector2.ZERO)
		var d := p.length()
		assert_bool(d >= s.ring_min - 0.01 and d <= s.ring_max + 0.01).is_true()
	s.arena_rect = Rect2(-100, -100, 200, 200)
	for i in 50:
		assert_bool(s.arena_rect.grow(0.01).has_point(s.pick_spawn_position(Vector2.ZERO))).is_true()


func test_spawn_interval_ramps_down() -> void:
	var s := _spawner(_node_at(Vector2.ZERO))
	assert_float(s.current_interval()).is_equal_approx(s.interval_start, 0.001)
	s.elapsed = s.ramp_time
	assert_float(s.current_interval()).is_equal_approx(s.interval_min, 0.001)


func test_spawner_inactive_spawns_nothing() -> void:
	var s := _spawner(_node_at(Vector2.ZERO))
	s.active = false
	s.tick(5.0)
	assert_int(s.alive_count()).is_equal(0)


# --- AutoAttack ---

func _attack(player: Player) -> AutoAttack:
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = player
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	add_child(a)
	return a


func test_melee_hits_enemies_in_front_arc() -> void:
	var p := _player_at(Vector2.ZERO)
	var a := _attack(p)
	var front := _enemy_at(Vector2(60, 0))
	var front2 := _enemy_at(Vector2(70, 30))
	var back := _enemy_at(Vector2(-80, 0))
	a.tick(0.016, [front, front2, back])
	assert_int(front.health.current).is_equal(front.health.max - a.stats().melee_damage)
	assert_int(front2.health.current).is_equal(front2.health.max - a.stats().melee_damage)
	assert_int(back.health.current).is_equal(back.health.max)


func test_melee_respects_interval() -> void:
	var p := _player_at(Vector2.ZERO)
	var a := _attack(p)
	var e := _enemy_at(Vector2(50, 0))
	a.tick(0.016, [e])
	a.tick(0.016, [e])
	assert_int(e.health.current).is_equal(e.health.max - a.stats().melee_damage)
	a.tick(a.stats().melee_interval, [e])
	assert_int(e.health.current).is_equal(e.health.max - 2 * a.stats().melee_damage)


func test_ranged_fires_at_nearest_out_of_melee_range() -> void:
	var p := _player_at(Vector2.ZERO)
	var a := _attack(p)
	var e := _enemy_at(Vector2(0, -300))
	var fired: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: fired.append(pr))
	a.tick(0.016, [e])
	assert_int(fired.size()).is_equal(1)
	assert_vector((fired[0] as Projectile).direction).is_equal_approx(Vector2.UP, Vector2(0.001, 0.001))
	a.tick(0.016, [e])
	assert_int(fired.size()).is_equal(1)  # 쿨다운
	for pr in fired:
		(pr as Node).queue_free()


func test_no_attack_without_enemies_in_range() -> void:
	var p := _player_at(Vector2.ZERO)
	var a := _attack(p)
	var e := _enemy_at(Vector2(0, 2000))
	var fired: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: fired.append(pr))
	a.tick(0.016, [e])
	assert_int(fired.size()).is_equal(0)
	assert_int(e.health.current).is_equal(e.health.max)


func test_projectile_damages_enemy_via_hurtbox() -> void:
	var e := _enemy_at(Vector2(150, 0))
	e.set_physics_process(false)
	var pr: Projectile = PROJECTILE_SCENE.instantiate()
	pr.direction = Vector2.RIGHT
	add_child(pr)
	pr.global_position = Vector2.ZERO
	for i in 30:
		await get_tree().physics_frame
	assert_int(e.health.current).is_equal(e.health.max - pr.damage if is_instance_valid(pr) else e.health.max - 10)
	assert_bool(not is_instance_valid(pr) or pr.is_queued_for_deletion()).is_true()


# --- Player 접촉 피해 ---

func test_contact_damage_with_invulnerability_window() -> void:
	var p := _player_at(Vector2.ZERO)
	assert_bool(p.apply_contact_damage(0.016, 10)).is_true()
	assert_int(p.health.current).is_equal(90)
	assert_bool(p.apply_contact_damage(0.016, 10)).is_false()
	assert_bool(p.apply_contact_damage(p.hurt_invuln_time, 10)).is_true()
	assert_int(p.health.current).is_equal(80)


func test_no_contact_damage_while_dashing() -> void:
	var p := _player_at(Vector2.ZERO)
	p.request_dash(Vector2.RIGHT)
	assert_bool(p.apply_contact_damage(0.016, 10)).is_false()
	assert_int(p.health.current).is_equal(p.health.max)


func test_player_dies() -> void:
	var p := _player_at(Vector2.ZERO)
	for i in 10:
		p.apply_contact_damage(p.hurt_invuln_time, 10)
	assert_bool(p.is_dead()).is_true()
	assert_bool(p.apply_contact_damage(p.hurt_invuln_time, 10)).is_false()


# --- GameState ---

func test_survive_60s_is_victory() -> void:
	var g := GameState.new(60.0)
	var results: Array = []
	g.ended.connect(func(r: GameState.Result) -> void: results.append(r))
	for i in 3599:
		g.tick(1.0 / 60.0)
	assert_bool(g.is_playing()).is_true()
	g.tick(1.0 / 60.0 + 0.001)
	assert_int(g.result).is_equal(GameState.Result.VICTORY)
	assert_array(results).is_equal([GameState.Result.VICTORY])


func test_player_death_is_defeat_and_freezes_state() -> void:
	var g := GameState.new(60.0)
	g.add_kill()
	g.player_died()
	g.add_kill()
	g.tick(100.0)
	assert_int(g.result).is_equal(GameState.Result.DEFEAT)
	assert_int(g.kills).is_equal(1)


# --- 메인 씬 통합 ---

func test_main_scene_spawns_and_ends_on_player_death() -> void:
	_skip_hero_select()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 120:
		await get_tree().physics_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	assert_int(spawner.alive_count()).is_greater(0)
	var player := main.get_node("Player") as Player
	player.health.kill()
	await get_tree().physics_frame
	assert_int(main.state.result).is_equal(GameState.Result.DEFEAT)
	assert_bool(get_tree().paused).is_true()
	get_tree().paused = false
	main.queue_free()


## 메인 씬 테스트: 영웅 고르기 화면 없이 이순신으로, 실제 설정 파일은 건드리지 않는다.
func _skip_hero_select() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.hero_picked = true
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()
