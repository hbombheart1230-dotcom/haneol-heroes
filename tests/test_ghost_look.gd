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


## 도깨비불은 모든 불을 삼각형 목록 하나로 (마리마다 그리기 호출을 쌓지 않는다): 불 하나 = 빛무리 RING 조각 + 혀마다 두 삼각형.
func test_ghost_fire_builds_one_triangle_list() -> void:
	var gf: GhostFire = auto_free(GhostFire.new())
	var one := gf.build_mesh([[Vector2.ZERO, 20.0, Color(0.8, 0.5, 0.7, 0.5), 0.0]], 0.3)
	var per_pts := 1 + GhostFire.RING + gf.tongues * 6
	var per_tris := GhostFire.RING + gf.tongues * 2
	assert_int((one[0] as PackedVector2Array).size()).is_equal(per_pts)
	assert_int((one[1] as PackedColorArray).size()).is_equal(per_pts)
	assert_int((one[2] as PackedInt32Array).size()).is_equal(per_tris * 3)
	var many := gf.build_mesh([[Vector2.ZERO, 20.0, Color.WHITE, 0.0], [Vector2(50, 0), 30.0, Color.WHITE, 1.0]], 0.3)
	assert_int((many[2] as PackedInt32Array).size()).is_equal(per_tris * 3 * 2)
	assert_int((many[2] as PackedInt32Array)[per_tris * 3]).is_equal(per_pts)  # 둘째 불 번호는 이어진다
