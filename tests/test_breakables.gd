extends GdUnitTestSuite
## 부서지는 물건과 탕약: 놓기, 대시·근접 공격으로 깨기, 탕약 마시면 회복, 다시 생기기.

const YI := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0

var player: Player
var field: BreakableField
var data: BreakableData


func before_test() -> void:
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = YI
	add_child(player)
	player.global_position = Vector2.ZERO
	field = auto_free(BreakableField.new())
	field.player = player
	add_child(field)
	data = BreakableData.new()
	data.drop_chance = 1.0


func test_pick_spot_keeps_gap_and_start_clear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rect := Rect2(-700, -1200, 1400, 2400)
	var placed := PackedVector2Array()
	for i in 4:
		var p := BreakableField.pick_spot(rng, rect, placed, 420.0, 260.0)
		assert_bool(rect.has_point(p)).is_true()
		assert_float(p.length()).is_greater_equal(260.0)
		for q in placed:
			assert_float(p.distance_to(q)).is_greater_equal(420.0)
		placed.append(p)


func test_setup_places_count_inside_area() -> void:
	var rect := Rect2(-700, -1200, 1400, 2400)
	field.setup(data, rect, 3)
	assert_int(field.jars.size()).is_equal(data.count)
	for p in field.jars:
		assert_bool(rect.has_point(p)).is_true()
	field.setup(null, rect)
	assert_int(field.jars.size()).is_equal(0)


func test_dash_breaks_jar_drops_potion_and_drinking_heals() -> void:
	field.setup(data, Rect2(-700, -1200, 1400, 2400), 3)
	field.jars = PackedVector2Array([Vector2(300, 0)])
	field.tick(DT)
	assert_int(field.jars.size()).is_equal(1)  # 걷기만으로는 안 깨진다
	player.global_position = Vector2(290, 0)
	field.tick(DT)
	assert_int(field.jars.size()).is_equal(1)
	player._dash_time_left = 0.2  # 대시 중
	player.global_position = Vector2(240, 0)  # 대시 반경 안, 마시는 반경 밖
	field.tick(DT)
	assert_int(field.jars.size()).is_equal(0)
	assert_int(field.potions.size()).is_equal(1)
	player._dash_time_left = 0.0
	player.health.current = 10
	player.global_position = Vector2(300, 0)
	field.tick(DT)
	assert_int(field.potions.size()).is_equal(0)
	assert_int(player.health.current).is_equal(10 + ceili(player.health.max * data.heal_fraction))


func test_potion_fades_and_jar_comes_back() -> void:
	field.setup(data, Rect2(-700, -1200, 1400, 2400), 3)
	field.jars = PackedVector2Array([Vector2(300, 0)])
	field.break_at(0)
	assert_int(field.potions.size()).is_equal(1)
	player.global_position = Vector2(-600, 900)  # 멀리
	field.tick(data.potion_lifetime + 0.1)
	assert_int(field.potions.size()).is_equal(0)
	field.tick(data.respawn_time)
	assert_int(field.jars.size()).is_equal(1)


func test_melee_swing_breaks_only_in_front() -> void:
	var atk: AutoAttack = auto_free(AutoAttack.new())
	atk.player = player
	player.add_child(atk)
	field.auto_attack = atk
	field.setup(data, Rect2(-700, -1200, 1400, 2400), 3)
	var r := atk.stats().melee_range
	field.jars = PackedVector2Array([Vector2(r, 0), Vector2(-r, 0)])
	field._on_melee_swung(Vector2.RIGHT, 1)
	assert_array(Array(field.jars)).is_equal([Vector2(-r, 0)])


func test_every_stage_has_breakable_with_art() -> void:
	for id in ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]:
		var st := load("res://data/stages/%s.tres" % id) as StageTheme
		assert_object(st.breakable).is_not_null()
		assert_object(st.breakable.texture).is_not_null()
		assert_bool(st.prop_textures.has(st.breakable.texture)).is_false()  # 장식 소품과 헷갈리지 않게
