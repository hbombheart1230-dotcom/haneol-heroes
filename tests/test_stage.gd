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
	assert_int(a.size()).is_greater(3)  # 배경 지도가 생겨 풀·돌은 빼고 그림 소품만 몇 개
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
	assert_int(arena.props.items.size()).is_greater(3)
	assert_bool(arena.has_map()).is_true()


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
	assert_int(STAGE.prop_textures.size()).is_equal(12)  # 술통은 부서지는 물건으로
	assert_int(pics.size()).is_greater(3)
	for i in pics.size():
		assert_int(pics[i][3]).is_less(STAGE.prop_textures.size())
		# Codex 25dc72d 회귀: 그려지는 그림 전체가 경기장 안, 시작 빈 원 밖
		var box := StageProps.picture_rect(pics[i][0], STAGE.prop_textures[pics[i][3]].get_size() * float(pics[i][2]))
		assert_bool(r.encloses(box)).is_true()
		assert_float(Vector2.ZERO.clamp(box.position, box.end).length()).is_greater_equal(STAGE.clear_radius)
		for j in range(i + 1, pics.size()):
			assert_float((pics[i][0] as Vector2).distance_to(pics[j][0])).is_greater_equal(220.0)
	for i in items.size() - 1:
		assert_float((items[i][0] as Vector2).y).is_less_equal((items[i + 1][0] as Vector2).y)


# --- 배경 지도 ---

func test_every_stage_map_covers_the_arena() -> void:
	var arena_rect := Rect2(-900, -1400, 1800, 2800)
	for id in ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_bool(ResourceLoader.exists(st.background_path)).is_true()
		assert_bool(st.background_rect.encloses(arena_rect)).is_true()
		assert_float(st.grass_per_mpx).is_equal(0.0)  # 지도에 그려져 있다


func test_arena_draws_map_and_clamps_camera() -> void:
	var arena: Arena = auto_free(Arena.new())
	add_child(arena)
	var cam: Camera2D = auto_free(Camera2D.new())
	add_child(cam)
	var st := load("res://data/stages/hansan_1592.tres") as StageTheme
	arena.apply_theme(st)
	arena.clamp_camera(cam)
	assert_bool(arena.has_map()).is_true()
	assert_bool(arena.border.visible).is_false()
	assert_int(cam.limit_left).is_equal(int(st.background_rect.position.x))
	assert_int(cam.limit_bottom).is_equal(int(st.background_rect.end.y))
	var plain := StageTheme.new()
	arena.apply_theme(plain)  # 지도 없는 무대: 한지 바닥 + 먹선, 카메라 풀림
	arena.clamp_camera(cam)
	assert_bool(arena.has_map()).is_false()
	assert_bool(arena.border.visible).is_true()
	assert_int(cam.limit_left).is_less(-100000)
