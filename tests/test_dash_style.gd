extends GdUnitTestSuite
## 영웅마다 다른 회피: 시작·자취·도착 이펙트와 도착 효과 (순신 밀기·광개토 기절·세종 느리게·사임당 먹 웅덩이).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const HEROES := ["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"]


func after_test() -> void:
	Feedback.instance = null


func _enemy(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = load("res://data/enemies/jurchen_soldier.tres")
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	return e


func test_every_hero_has_a_distinct_dash() -> void:
	var tints := []
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_object(h.dash_style).override_failure_message(id).is_not_null()
		assert_object(h.dash_style.start_vfx).is_not_null()
		assert_object(h.dash_style.end_vfx).is_not_null()
		assert_object(h.dash_style.end_vfx.decal).override_failure_message(id + " end painting").is_not_null()
		assert_float(h.dash_style.end_radius).is_greater(0.0)
		tints.append(h.dash_style.body_tint)
	for i in tints.size():
		for k in range(i + 1, tints.size()):
			assert_bool(tints[i].is_equal_approx(tints[k])).is_false()


func test_arrival_effects_per_hero() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var gw: HeroData = load("res://data/heroes/gwanggaeto.tres")
	var sj: HeroData = load("res://data/heroes/sejong.tres")
	var sa: HeroData = load("res://data/heroes/shin_saimdang.tres")
	var e := _enemy(Vector2(40, 0))
	DashStyleRunner.new(yi.dash_style).on_end(Vector2.ZERO, [e])
	assert_float(e.knockback.x).is_greater(0.0)  # 순신: 물보라로 밀침
	var e2 := _enemy(Vector2(40, 0))
	DashStyleRunner.new(gw.dash_style).on_end(Vector2.ZERO, [e2])
	assert_bool(e2.is_stunned()).is_true()  # 광개토: 번개 도착 기절
	var e3 := _enemy(Vector2(40, 0))
	DashStyleRunner.new(sj.dash_style).on_end(Vector2.ZERO, [e3])
	assert_float(e3.speed_scale()).is_less(1.0)  # 세종: 해시계 느리게
	# 사임당: 먹 웅덩이는 출발 자리에 남는다
	var r := DashStyleRunner.new(sa.dash_style)
	r.on_start(Vector2(500, 0), Vector2.RIGHT)
	var near_start := _enemy(Vector2(520, 0))
	var near_end := _enemy(Vector2(20, 0))
	assert_int(r.on_end(Vector2.ZERO, [near_start, near_end])).is_equal(1)
	assert_float(near_start.speed_scale()).is_less(1.0)
	assert_float(near_end.speed_scale()).is_equal(1.0)


func test_out_of_range_untouched_and_no_style_safe() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var far := _enemy(Vector2(1000, 0))
	assert_int(DashStyleRunner.new(yi.dash_style).on_end(Vector2.ZERO, [far])).is_equal(0)
	assert_int(DashStyleRunner.new(null).on_end(Vector2.ZERO, [far])).is_equal(0)


func test_player_dash_drives_effects() -> void:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	var p: Player = auto_free(Player.new())
	p.apply_hero(load("res://data/heroes/gwanggaeto.tres"))
	add_child(p)
	assert_object(p.dash_runner).is_not_null()
	var e := _enemy(Vector2(260, 0))
	p.request_dash(Vector2.RIGHT)
	assert_int(f.skill_vfx.count()).is_greater(0)  # 출발 불똥
	for i in 30:
		p.compute_velocity(1.0 / 60.0)
		p.global_position += p.velocity / 60.0
	p.global_position = Vector2(240, 0)
	p._dash_arrived()
	assert_bool(e.is_stunned()).is_true()
	assert_int(f.decals.count()).is_greater(0)  # 도착 번개 그림
