extends GdUnitTestSuite
## 적이 잘 보이게: 군대별 테두리·밝기 재질 (shaders/enemy_rim.gdshader), 데이터, 스프라이트 연결.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func _all_enemy_data() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for f in DirAccess.get_files_at("res://data/enemies"):
		if f.ends_with(".tres"):
			out.append(load("res://data/enemies/" + f))
	return out


func test_no_rim_means_no_material() -> void:
	var d := EnemyData.new()
	assert_object(EnemyLook.material_for(d)).is_null()
	assert_object(EnemyLook.material_for(null)).is_null()


func test_material_is_shared_and_carries_data() -> void:
	var d: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var m := EnemyLook.material_for(d)
	assert_object(m).is_not_null()
	assert_object(EnemyLook.material_for(d)).is_same(m)
	assert_object(m.shader).is_same(EnemyLook.SHADER)
	assert_float(float(m.get_shader_parameter("rim_width"))).is_equal(d.rim_width)
	assert_float(float(m.get_shader_parameter("tint_mix"))).is_equal(d.tint_mix)


func test_every_enemy_has_a_rim_and_elites_bosses_thicker() -> void:
	for d in _all_enemy_data():
		assert_float(d.rim_color.a).override_failure_message("%s rim" % d.id).is_greater(0.0)
		if d.is_boss or d.is_elite:
			assert_float(d.rim_width).override_failure_message("%s thick" % d.id).is_greater(3.0)
		else:
			assert_float(d.rim_width).override_failure_message("%s thin" % d.id).is_equal(3.0)


func test_armies_get_distinct_rims() -> void:
	var w: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var j: EnemyData = load("res://data/enemies/jurchen_soldier.tres")
	var b: EnemyData = load("res://data/enemies/chaser.tres")
	var c: EnemyData = load("res://data/enemies/cc_mouse.tres")
	var rims := [w.rim_color, j.rim_color, b.rim_color, c.rim_color]
	for i in rims.size():
		for k in range(i + 1, rims.size()):
			assert_bool(rims[i].is_equal_approx(rims[k])).is_false()
	assert_float(w.body_lift).is_greater(0.0)
	assert_str(String(c.death_style)).is_equal("paper")  # 다시 만들어도 초충도 죽는 모양 유지


func test_enemy_sprite_uses_look_material() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = load("res://data/enemies/jurchen_heavy.tres")
	add_child(auto_free(e))
	e.set_physics_process(false)
	assert_object(e.sprite).is_not_null()
	assert_object(e.sprite.material).is_same(EnemyLook.material_for(e.data))


func test_rim_stays_inside_its_sheet_cell() -> void:
	# Codex 79a3232: 이웃 프레임 알파를 읽지 않게 칸 크기를 넘긴다
	var d: EnemyData = load("res://data/enemies/cc_mouse.tres")
	var m := EnemyLook.material_for(d)
	assert_float(float(m.get_shader_parameter("cell_px"))).is_equal(float(d.sprite_sheet.frame_size))
