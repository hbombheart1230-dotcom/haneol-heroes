extends GdUnitTestSuite
## 초충도 풀숲 (GrassPlan·GrassHide): 숨으면 적이 겨냥을 놓친다 (우두머리·바로 곁·공격 중은 예외), 나오며 친 첫 공격 ×1.5.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SAIM := preload("res://data/heroes/shin_saimdang.tres")
const MOUSE := preload("res://data/enemies/cc_mouse.tres")
const GRASS := preload("res://data/stages/hazards/chochungdo_grass.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	for n in get_children():
		if n is StageHazards:
			n.free()


func test_inside_and_ambush_extra() -> void:
	var pts := PackedVector3Array([Vector3(0, 0, 100)])
	assert_int(GrassPlan.inside(pts, Vector2(90, 0))).is_equal(0)
	assert_int(GrassPlan.inside(pts, Vector2(110, 0))).is_equal(-1)
	assert_int(GrassPlan.ambush_extra(20, 1.5)).is_equal(10)
	assert_int(GrassPlan.ambush_extra(1, 1.5)).is_equal(1)
	assert_int(GrassPlan.ambush_extra(20, 1.0)).is_equal(0)


func test_state_hides_then_arms_ambush_on_leaving_and_spend_reveals() -> void:
	var st := GrassPlan.State.new(GRASS)
	assert_int(st.step(DT, true)).is_equal(1)
	assert_bool(st.hidden()).is_true()
	assert_bool(st.ambush_ready()).is_true()  # 숨은 채로 쳐도 기습
	assert_int(st.step(DT, false)).is_equal(-1)
	assert_bool(st.hidden()).is_false()
	assert_bool(st.ambush_ready()).is_true()  # 나온 뒤 잠깐
	for i in roundi((GRASS.ambush_window + 0.05) / DT):
		st.step(DT, false)
	assert_bool(st.ambush_ready()).is_false()
	st.step(DT, true)
	st.spend()
	assert_bool(st.hidden()).is_false()  # 친 뒤엔 풀숲 안이어도 드러난다
	for i in roundi((GRASS.reveal_time + 0.05) / DT):
		st.step(DT, true)
	assert_bool(st.hidden()).is_true()


func _setup() -> GrassHide:
	var hz := StageHazards.new()
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	h.max = 100
	h.current = 100
	p.add_child(h)
	add_child(p)
	p.hero = SAIM
	p.set_physics_process(false)
	hz.player = p
	add_child(hz)
	hz.setup([GRASS] as Array[StageHazardData])
	var g := hz.get_child(0) as GrassHide
	g.set_physics_process(false)
	return g


func _enemy(at: Vector2, target: Node2D, boss: bool = false) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = MOUSE
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = at
	e.health.max = 999
	e.health.current = 999
	e.target = target
	if boss:
		e.add_to_group(Enemy.BOSS_GROUP)
	return e


func _grass_center() -> Vector2:
	return Vector2(GRASS.patches[0].x, GRASS.patches[0].y)


func test_hiding_fools_minions_but_not_bosses_or_close_ones_and_leaving_restores() -> void:
	var g := _setup()
	var p := g.host.player
	var far := _enemy(_grass_center() + Vector2(400, 0), p)
	var near := _enemy(_grass_center() + Vector2(40, 0), p)
	var boss := _enemy(_grass_center() + Vector2(-400, 0), p, true)
	p.global_position = _grass_center()
	g._physics_process(DT)
	assert_bool(g.state.hidden()).is_true()
	assert_object(far.target).is_not_same(p)  # 들어간 자리 미끼로
	assert_object(near.target).is_same(p)  # 바로 곁은 안다
	assert_object(boss.target).is_same(p)  # 우두머리는 속지 않는다
	p.global_position = _grass_center() + Vector2(0, 600)
	g._physics_process(DT)
	assert_object(far.target).is_same(p)
	assert_int(g.hides).is_equal(1)
	assert_int(g.lost_aims).is_equal(1)


func test_first_hit_after_leaving_is_an_ambush_and_only_once() -> void:
	var g := _setup()
	var p := g.host.player
	var e := _enemy(Vector2(2000, 2000), p)
	var e2 := _enemy(Vector2(2100, 2000), p)
	p.global_position = _grass_center()
	g._physics_process(DT)  # 숨고 적 피해 알림에 붙는다
	p.global_position = _grass_center() + Vector2(0, 600)
	g._physics_process(DT)  # 나옴: 기습 시간
	e.health.damage(20)
	e2.health.damage(20)  # 같은 틀(한 번 휘두름)에 맞은 다른 적도 기습
	assert_int(e.health.current).is_equal(999 - 30)
	assert_int(e2.health.current).is_equal(999 - 30)
	assert_int(g.ambushes).is_equal(1)
	g._physics_process(DT)  # 다음 틀: 기습을 썼다
	e.health.damage(20)
	assert_int(e.health.current).is_equal(999 - 50)
	assert_int(g.ambushes).is_equal(1)
