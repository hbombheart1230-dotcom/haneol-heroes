extends GdUnitTestSuite
## 경복궁 엄폐 (StoneCover): 곧게 날아가는 것을 막고 세 번에 깨진다, 평타 탄은 넘는다, 깨지면 걸음도 풀린다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const COVER := preload("res://data/stages/hazards/gyeongbok_cover.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	for n in get_children():
		if n is StageHazards or n is EnemyArrow or n is Projectile or n is Obstacles:
			n.free()


func test_cover_state_touch_hit_and_break() -> void:
	var st := CoverState.new(COVER)
	assert_int(st.standing()).is_equal(COVER.pieces.size())
	var p := st.at[0]
	assert_int(st.touching(p + Vector2(st.radius[0] + 5.0, 0), 6.0)).is_equal(0)
	assert_int(st.touching(p + Vector2(st.radius[0] + 20.0, 0), 6.0)).is_equal(-1)
	assert_bool(st.hit(0)).is_false()
	assert_bool(st.hit(0)).is_false()
	assert_bool(st.hit(0)).is_true()  # 세 번째에 깨짐
	assert_bool(st.is_broken(0)).is_true()
	assert_int(st.touching(p, 6.0)).is_equal(-1)  # 깨진 것은 더 막지 않는다
	assert_bool(st.hit(0)).is_false()
	assert_int(st.standing()).is_equal(COVER.pieces.size() - 1)


func test_gyeongbok_cover_data() -> void:
	assert_int(COVER.max_hits).is_equal(3)
	assert_bool(COVER.block_enemy_shots).is_true()
	assert_bool(COVER.block_hero_skills).is_true()
	assert_bool(COVER.block_hero_basic).is_false()
	assert_int(COVER.intact.size()).is_equal(COVER.heights.size())
	assert_int(COVER.radii.size()).is_equal(COVER.heights.size())
	for p in COVER.pieces:
		assert_float(Vector2(p.x, p.y).length()).is_greater(260.0)  # 시작 자리 둘레는 비운다


func _setup() -> StoneCover:
	var hz := StageHazards.new()
	var obs := Obstacles.new()
	add_child(obs)
	obs.build(PackedVector3Array([Vector3(5000, 5000, 10)]))
	hz.obstacles = obs
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	h.max = 100
	h.current = 100
	p.add_child(h)
	add_child(p)
	p.hero = YI
	p.set_physics_process(false)
	hz.player = p
	add_child(hz)
	hz.setup([COVER] as Array[StageHazardData])
	var c := hz.get_child(0) as StoneCover
	c.set_physics_process(false)
	return c


func _arrow_at(at: Vector2) -> EnemyArrow:
	var a := EnemyArrow.new()
	a.direction = Vector2.DOWN
	a.radius = 8.0
	add_child(a)
	a.set_physics_process(false)
	a.global_position = at
	return a


func test_arrows_are_stopped_and_the_third_breaks_the_piece() -> void:
	var c := _setup()
	var obs := c.host.obstacles
	assert_int(obs.circles.size()).is_equal(1 + COVER.pieces.size())  # 엄폐도 걸음을 막는다
	var at := c.state.at[0]
	for i in 3:
		var a := _arrow_at(at)
		c._physics_process(DT)
		assert_bool(a.is_queued_for_deletion()).is_true()
		a.free()
	assert_int(c.blocked_enemy).is_equal(3)
	assert_int(c.broken_count).is_equal(1)
	assert_int(obs.circles.size()).is_equal(COVER.pieces.size())  # 깨진 것은 걸음 원도 빠진다
	var b := _arrow_at(at)
	c._physics_process(DT)
	assert_bool(b.is_queued_for_deletion()).is_false()  # 깨진 자리는 지나간다
	b.free()


func test_skill_projectiles_stop_but_basic_shots_pass() -> void:
	var c := _setup()
	var at := c.state.at[2]
	var skill: Projectile = PROJECTILE_SCENE.instantiate()
	add_child(skill)
	skill.set_physics_process(false)
	skill.global_position = at
	var basic: Projectile = PROJECTILE_SCENE.instantiate()
	c._basic[basic.get_instance_id()] = true  # AutoAttack.projectile_fired로 표시된 평타 탄
	add_child(basic)
	basic.set_physics_process(false)
	basic.global_position = at
	c._physics_process(DT)
	assert_bool(skill.is_queued_for_deletion()).is_true()
	assert_bool(basic.is_queued_for_deletion()).is_false()
	assert_int(c.blocked_hero).is_equal(1)
	assert_int(c.state.hits[2]).is_equal(1)


func test_far_shots_are_left_alone() -> void:
	var c := _setup()
	var a := _arrow_at(Vector2(0, 0))
	c._physics_process(DT)
	assert_bool(a.is_queued_for_deletion()).is_false()
	assert_int(c.blocked_enemy).is_equal(0)


## 순신 원정 재기 (시뮬 봇은 해일검기를 쓰지 않아 직접 잰다): 마당 아무 데서나 둘레 150~550px 적에게 곧게 쏠 때
## 엄폐(다 서 있을 때)에 막히는 몫. 적 화살이 영웅에게 오다 막히는 몫도 같은 기하다.
func test_how_often_a_straight_shot_is_blocked_in_gyeongbok() -> void:
	var st := CoverState.new(COVER)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1433
	var arena := Rect2(-1050, -1988, 2110, 3426)  # 경복궁 배경 영역 - prop_inset
	var n := 0
	var blocked := 0
	var near_blocked := 0
	var near_n := 0
	while n < 4000:
		var a := Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y))
		if st.touching(a, 30.0) >= 0:
			continue
		var b := a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(150.0, 550.0)
		if not arena.has_point(b):
			continue
		n += 1
		var hit := st.first_on_segment(a, b, 12.0) >= 0
		blocked += int(hit)
		var near := false  # 엄폐 둘레 300px 안에서 싸울 때
		for p in st.at:
			near = near or a.distance_to(p) < 300.0
		if near:
			near_n += 1
			near_blocked += int(hit)
	var share := float(blocked) / n
	var near_share := float(near_blocked) / maxf(near_n, 1)
	print("[cover-geo] 곧게 쏜 것이 막히는 몫: 마당 전체 %.1f%%, 엄폐 300px 안 %.1f%% (%d/%d)" % [share * 100.0, near_share * 100.0,
		near_n, n])
	assert_float(share).is_less(0.15)  # 원정 순신: 해일검기가 드물게만 막힌다 (재 보니 마당 전체 약 5%, 엄폐 곁 약 12%)
	assert_float(near_share).is_greater(0.08)  # 엄폐 곁에서는 숨을 만큼은 막는다
