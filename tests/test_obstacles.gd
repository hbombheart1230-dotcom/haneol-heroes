extends GdUnitTestSuite
## 막히는 장애물: 지도·소품 원, 영웅이 막히는지, 적이 끼지 않고 돌아오는지.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CHASER := preload("res://data/enemies/chaser.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const IDS := ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]


func test_stage_blockers_stay_clear_of_start_and_solid_props_exist() -> void:
	for id in IDS:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_int(st.map_blockers.size()).is_greater(10)
		for c in st.map_blockers:
			assert_float(Vector2(c.x, c.y).length() - c.z).is_greater(st.clear_radius)
		var names := st.prop_textures.map(func(t: Texture2D) -> String: return t.resource_path.get_file().get_basename())
		for n in st.solid_props:
			assert_bool(names.has(n)).is_true()


func test_build_makes_circle_bodies_on_obstacle_layer() -> void:
	var obs: Obstacles = auto_free(Obstacles.new())
	add_child(obs)
	obs.build(PackedVector3Array([Vector3(100, 0, 40), Vector3(-200, 50, 60)]))
	assert_int(obs.get_child_count()).is_equal(2)
	var body := obs.get_child(0) as StaticBody2D
	assert_int(body.collision_layer).is_equal(Obstacles.LAYER)
	assert_bool(body.is_in_group(Obstacles.GROUP)).is_true()
	assert_bool(obs.blocks(Vector2(120, 0))).is_true()
	assert_bool(obs.blocks(Vector2(0, 0))).is_false()
	obs.build(PackedVector3Array())
	await get_tree().process_frame
	assert_int(obs.get_child_count()).is_equal(0)


func test_arena_builds_map_and_solid_prop_obstacles() -> void:
	var arena: Arena = auto_free(Arena.new())
	add_child(arena)
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	arena.apply_theme(st)
	var from_props := Obstacles.from_props(arena.props.items, st)
	assert_int(arena.obstacles.circles.size()).is_equal(st.map_blockers.size() + from_props.size())


func test_steer_around_turns_along_the_wall() -> void:
	var v := Obstacles.steer_around(Vector2(100, 0), Vector2(-1, 0), 1.0)  # 정면 벽
	assert_float(absf(v.y)).is_greater(50.0)
	assert_float(v.length()).is_equal_approx(100.0, 0.01)
	var w := Obstacles.steer_around(Vector2(100, 30), Vector2(-1, 0), -1.0)  # 목표가 아래쪽이면 아래로
	assert_float(w.y).is_greater(0.0)


func test_player_is_stopped_by_obstacle() -> void:
	var obs: Obstacles = auto_free(Obstacles.new())
	add_child(obs)
	obs.build(PackedVector3Array([Vector3(200, 0, 60)]))
	var scene: Node = auto_free(load("res://scenes/main.tscn").instantiate())
	var p: Player = scene.get_node("Player")
	scene.remove_child(p)
	add_child(auto_free(p))
	p.global_position = Vector2.ZERO
	for i in 90:
		p.set_move_input(Vector2.RIGHT)
		await get_tree().physics_frame
	assert_float(p.global_position.x).is_less(200.0 - 60.0)


func test_enemy_gets_around_obstacle_to_target() -> void:
	var obs: Obstacles = auto_free(Obstacles.new())
	add_child(obs)
	obs.build(PackedVector3Array([Vector3(0, 0, 90)]))
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	target.global_position = Vector2(300, 0)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = CHASER
	add_child(auto_free(e))
	e.target = target
	e.global_position = Vector2(-300, 0)
	for i in 300:
		await get_tree().physics_frame
	assert_float(e.global_position.x).is_greater(100.0)  # 돌아서 반대편까지
