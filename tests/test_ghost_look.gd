extends GdUnitTestSuite
## 망령 표현 (사람 모습으로 굽고 수묵·후처리로): 군대별 망령 색, 셰이더 값, 발밑 도깨비불.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func test_each_army_has_its_own_ghost_color_and_insects_have_none() -> void:
	for id in ["waegun_soldier", "waegun_commander", "jurchen_soldier", "jurchen_chieftain", "chaser", "boss_general"]:
		var d: EnemyData = load("res://data/enemies/%s.tres" % id)
		assert_float(d.ghost_color.a).is_greater(0.0)
	var w: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var j: EnemyData = load("res://data/enemies/jurchen_soldier.tres")
	var k: EnemyData = load("res://data/enemies/chaser.tres")
	assert_bool(w.ghost_color.is_equal_approx(j.ghost_color)).is_false()
	assert_bool(j.ghost_color.is_equal_approx(k.ghost_color)).is_false()
	var bug: EnemyData = load("res://data/enemies/cc_beetle.tres")
	assert_float(bug.ghost_color.a).is_equal(0.0)  # 그림 속 곤충은 망령이 아니다
	var boss: EnemyData = load("res://data/enemies/waegun_commander.tres")
	assert_float(boss.ghost_fire_scale).is_greater(w.ghost_fire_scale)


func test_shader_gets_ghost_params() -> void:
	var d: EnemyData = load("res://data/enemies/jurchen_soldier.tres")
	var m := EnemyLook.material_for(d)
	assert_object(m).is_not_null()
	assert_bool((m.get_shader_parameter("ghost_color") as Color).is_equal_approx(d.ghost_color)).is_true()
	assert_float(m.get_shader_parameter("ghost_body_alpha")).is_equal(d.ghost_body_alpha)


func test_ghost_fire_lists_only_living_ghosts() -> void:
	var gf: GhostFire = auto_free(GhostFire.new())
	add_child(gf)
	var ghost: Enemy = ENEMY_SCENE.instantiate()
	ghost.data = load("res://data/enemies/waegun_soldier.tres")
	add_child(auto_free(ghost))
	var bug: Enemy = ENEMY_SCENE.instantiate()
	bug.data = load("res://data/enemies/cc_beetle.tres")
	add_child(auto_free(bug))
	await get_tree().process_frame
	assert_int(gf.fires().size()).is_equal(1)
	ghost.health.kill()
	assert_int(gf.fires().size()).is_equal(0)


func test_main_scene_has_ghost_fire_layer() -> void:
	var main: Node = auto_free(load("res://scenes/main.tscn").instantiate())
	assert_object(main.get_node_or_null("GhostFire") as GhostFire).is_not_null()
