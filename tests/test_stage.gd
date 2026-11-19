extends GdUnitTestSuite
## 무대 테마: 395년 만주 벌판 (바닥 색, 수묵 소품 흩뿌리기, 시작 문구).

const STAGE := preload("res://data/stages/manchuria_395.tres")
const RUN := preload("res://data/runs/default_run.tres")


func test_run_uses_manchuria_stage() -> void:
	assert_object(RUN.stage).is_same(STAGE)
	assert_str(STAGE.year_label).is_equal("395년")
	assert_str(STAGE.title).is_equal("만주 벌판")


func test_props_are_deterministic_and_keep_start_clear() -> void:
	var r := Rect2(-900, -1400, 1800, 2800)
	var a := StageProps.scatter(STAGE, r)
	var b := StageProps.scatter(STAGE, r)
	assert_int(a.size()).is_greater(20)
	assert_array(a.map(func(i: Array) -> Vector2: return i[0])).is_equal(b.map(func(i: Array) -> Vector2: return i[0]))
	for it in a:
		assert_float((it[0] as Vector2).length()).is_greater_equal(STAGE.clear_radius)
		assert_bool(r.has_point(it[0])).is_true()


func test_arena_applies_theme_colours() -> void:
	var arena: Arena = auto_free(Arena.new())
	add_child(arena)
	arena.apply_theme(STAGE)
	var mat := arena.material as ShaderMaterial
	assert_object(mat.get_shader_parameter("paper")).is_equal(STAGE.floor_base)
	assert_int(arena.props.items.size()).is_greater(20)


func test_stage_title_fades_after_start() -> void:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	hud.stage = STAGE
	hud.state = GameState.new(0.0)
	assert_float(hud.stage_title_alpha()).is_equal(1.0)
	hud.state.tick(2.7)
	assert_float(hud.stage_title_alpha()).is_equal_approx(0.5, 0.01)
	hud.state.tick(1.0)
	assert_float(hud.stage_title_alpha()).is_equal(0.0)


func test_picture_props_scattered_apart_and_sorted() -> void:
	var r := Rect2(-900, -1400, 1800, 2800)
	var items := StageProps.scatter(STAGE, r)
	var pics := items.filter(func(i: Array) -> bool: return i[1] == 2)
	assert_int(STAGE.prop_textures.size()).is_equal(13)
	assert_int(pics.size()).is_greater(5)
	for i in pics.size():
		assert_int(pics[i][3]).is_less(STAGE.prop_textures.size())
		for j in range(i + 1, pics.size()):
			assert_float((pics[i][0] as Vector2).distance_to(pics[j][0])).is_greater_equal(220.0)
	for i in items.size() - 1:
		assert_float((items[i][0] as Vector2).y).is_less_equal((items[i + 1][0] as Vector2).y)
