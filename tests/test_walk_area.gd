extends GdUnitTestSuite
## 걸을 수 있는 곳 (StageTheme.walk_area, WalkArea): 영웅·적·등장 자리가 배 밖·지붕 위로 나가지 않는다.
## 사용자 9e19cfb: "배경에 갈 수 없는 곳을 영웅이나 몹이 갈 수 있다. 배 밖으로."

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]
const SQUARE := [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]


func _sq() -> PackedVector2Array:
	return PackedVector2Array(SQUARE)


func test_inside_point_is_unchanged_and_empty_area_does_nothing() -> void:
	assert_vector(WalkArea.clamp_point(_sq(), Vector2(40, 60))).is_equal(Vector2(40, 60))
	assert_vector(WalkArea.clamp_point(PackedVector2Array(), Vector2(-500, 9))).is_equal(Vector2(-500, 9))


func test_outside_point_comes_back_and_keeps_the_slide_along_the_edge() -> void:
	var p := WalkArea.clamp_point(_sq(), Vector2(130, 40))
	assert_bool(WalkArea.contains(_sq(), p)).is_true()
	assert_float(p.y).is_equal_approx(40.0, 1.0)  # 벽을 따라가는 성분은 남는다 (미끄러짐)
	assert_float(p.x).is_equal_approx(100.0, 1.0)


func test_every_stage_has_a_walk_area_inside_its_map() -> void:
	for id in STAGES:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_int(st.walk_area.size()).override_failure_message(id).is_greater_equal(4)
		for v in st.walk_area:
			assert_bool(st.background_rect.has_point(v)).override_failure_message("%s %s" % [id, v]).is_true()


func test_hansan_water_is_outside_and_deck_is_inside() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	for water in [Vector2(-860, -1300), Vector2(860, -1300), Vector2(-1050, 0), Vector2(1050, 0), Vector2(-860, 1300), Vector2(0, 1500)]:
		assert_bool(WalkArea.contains(st.walk_area, water)).override_failure_message(str(water)).is_false()
	for deck in [Vector2.ZERO, Vector2(0, -1200), Vector2(900, 300), Vector2(-900, 300), Vector2(0, 1250)]:
		assert_bool(WalkArea.contains(st.walk_area, deck)).override_failure_message(str(deck)).is_true()


func test_gyeongbok_roof_corner_is_outside() -> void:
	var st := load("res://data/stages/gyeongbokgung_1433.tres") as StageTheme
	assert_bool(WalkArea.contains(st.walk_area, Vector2(850, 1200))).is_false()
	assert_bool(WalkArea.contains(st.walk_area, Vector2(700, 1200))).is_true()


func test_spawner_points_and_knocked_enemy_stay_inside() -> void:
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	sp.walk_area = st.walk_area
	add_child(sp)
	for at in [Vector2(-1100, -1700), Vector2(1200, 0), Vector2(0, 1600)]:
		assert_bool(WalkArea.contains(st.walk_area, sp.bounded(at))).override_failure_message(str(at)).is_true()
	var e := Node2D.new()
	sp.add_child(e)
	e.global_position = Vector2(-1080, 200)  # 넉백으로 물 위
	WalkArea.keep_enemy(e)
	assert_bool(WalkArea.contains(st.walk_area, e.global_position)).is_true()
