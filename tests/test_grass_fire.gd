extends GdUnitTestSuite
## 만주 들불 (FireGrid·GrassFire): 번지기·타 버리기·다시 자라기, 번개·유성이 붙이고 물결이 끈다, 불 위 피해 (적 크게·영웅 작게).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const GW := preload("res://data/heroes/gwanggaeto.tres")
const SJ := preload("res://data/heroes/sejong.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const FIRE := preload("res://data/stages/hazards/manchuria_fire.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	for n in get_children():
		if n is StageHazards or n is Projectile:
			n.free()


func _line_fire() -> FireData:
	var d: FireData = FIRE.duplicate()
	d.patches = PackedVector3Array([Vector3(440, 40, 10), Vector3(520, 40, 10), Vector3(600, 40, 10)])  # 칸 가운데에 작은 원: 가로 한 줄 세 칸
	return d


func _steps(g: FireGrid, seconds: float) -> void:
	for i in roundi(seconds / DT):
		g.step(DT)


func test_grid_spreads_one_cell_per_delay_then_burns_out_and_regrows() -> void:
	var g := FireGrid.new(_line_fire())
	assert_int(g.size()).is_equal(3)
	assert_int(g.ignite(Vector2(440, 40), 10.0)).is_equal(1)
	assert_int(g.count(FireGrid.State.BURNING)).is_equal(1)
	_steps(g, g.data.spread_delay - g.data.smoke_time + 0.05)
	assert_bool(g.smoking(1)).is_true()  # 번지기 1초 전부터 이웃 칸에 연기
	_steps(g, g.data.smoke_time)
	assert_int(g.count(FireGrid.State.BURNING)).is_equal(2)
	_steps(g, g.data.spread_delay)
	assert_int(g.count(FireGrid.State.BURNING)).is_equal(3)
	_steps(g, g.data.burn_time)
	assert_int(g.count(FireGrid.State.BURNING)).is_equal(0)
	assert_int(g.count(FireGrid.State.ASH)).is_equal(3)
	assert_int(g.ignite(Vector2(440, 40), 10.0)).is_equal(0)  # 재는 다시 안 붙는다
	_steps(g, g.data.regrow_time)
	assert_int(g.count(FireGrid.State.DRY)).is_equal(3)


func test_douse_puts_out_fire_and_wets_dry_grass() -> void:
	var g := FireGrid.new(_line_fire())
	g.ignite(Vector2(440, 40), 10.0)
	assert_int(g.douse(Vector2(480, 40), 50.0)).is_equal(1)
	assert_int(g.count(FireGrid.State.BURNING)).is_equal(0)
	assert_int(g.ignite(Vector2(520, 40), 10.0)).is_equal(0)  # 젖은 자리는 안 붙는다
	assert_int(g.ignite(Vector2(600, 40), 10.0)).is_equal(1)


func test_pick_ember_prefers_dry_cells_near_enemies_on_screen() -> void:
	var g := FireGrid.new(_line_fire())
	var view := Rect2(0, -600, 720, 1280)
	assert_int(g.pick_ember(view, Vector2(440, 40), PackedVector2Array([Vector2(600, 60)]), 60.0)).is_equal(2)
	assert_int(g.pick_ember(view, Vector2(440, 40), PackedVector2Array(), 60.0)).is_equal(0)  # 적이 없으면 영웅 가까이
	assert_int(g.pick_ember(Rect2(3000, 3000, 10, 10), Vector2.ZERO, PackedVector2Array(), 60.0)).is_equal(-1)


func test_manchuria_fire_data_and_skill_elements() -> void:
	assert_bool(FIRE.ignite.has(&"thunder")).is_true()
	assert_bool(FIRE.ignite.has(&"meteor")).is_true()
	assert_bool(FIRE.douse.has(&"water")).is_true()
	assert_int(FIRE.enemy_damage).is_greater(FIRE.hero_damage * 3)  # 중립이지만 적에게 훨씬 세게
	for p in FIRE.patches:
		assert_float(Vector2(p.x, p.y).length() - p.z).is_greater(150.0)  # 시작 자리 가까이엔 풀밭이 없다
	assert_str(String(GW.kit.charge.element)).is_equal("thunder")  # 낙뢰
	assert_str(String(GW.kit.dash.element)).is_equal("thunder")  # 벽력돌파
	assert_str(String(SJ.kit.dash.element)).is_equal("meteor")  # 유성
	assert_str(String(YI.kit.charge.element)).is_equal("water")  # 해일검기
	assert_str(String(GW.kit.tap.element)).is_equal("")


func _setup(d: FireData) -> GrassFire:
	var hz := StageHazards.new()
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	h.max = 100
	h.current = 100
	p.add_child(h)
	add_child(p)
	p.hero = YI
	p.set_physics_process(false)
	p.global_position = Vector2(-2000, -2000)
	hz.player = p
	add_child(hz)
	hz.setup([d] as Array[StageHazardData])
	var f := hz.get_child(0) as GrassFire
	f.set_physics_process(false)
	return f


func test_elements_ignite_and_douse_through_events() -> void:
	var f := _setup(_line_fire())
	ElementEvents.emit(&"thunder", Vector2(440, 40), 0.0)
	assert_int(f.grid.count(FireGrid.State.BURNING)).is_greater(0)
	ElementEvents.emit(&"water", Vector2(440, 40), 0.0)
	assert_int(f.grid.count(FireGrid.State.BURNING)).is_equal(0)
	ElementEvents.emit(&"glyph", Vector2(600, 40), 0.0)  # 다른 성질은 반응 없음
	assert_int(f.grid.count(FireGrid.State.BURNING)).is_equal(0)


func test_water_projectile_douses_along_its_path() -> void:
	var f := _setup(_line_fire())
	f.grid.ignite(Vector2(600, 40), 10.0)
	var pr: Projectile = PROJECTILE_SCENE.instantiate()
	pr.set_meta(&"element", &"water")
	add_child(pr)
	pr.set_physics_process(false)
	pr.global_position = Vector2(600, 40)
	f._physics_process(DT)
	assert_int(f.grid.count(FireGrid.State.BURNING)).is_equal(0)
	assert_int(f.doused).is_greater(0)


func test_fire_burns_enemies_hard_and_the_hero_lightly() -> void:
	var f := _setup(_line_fire())
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(440, 40)
	e.health.max = 999
	e.health.current = 999
	f.host.player.global_position = Vector2(520, 40)
	f.grid.ignite(Vector2(520, 40), 60.0)
	f._burn_units()
	assert_int(e.health.current).is_equal(999 - FIRE.enemy_damage)
	assert_int(f.host.player.health.current).is_equal(100 - FIRE.hero_damage)
	assert_float(f.host.player.hurt_time_left()).is_equal(0.0)  # 화상은 피격 무적을 주지 않는다
	f.host.player.grant_invulnerability(1.0)
	f._burn_units()
	assert_int(f.host.player.health.current).is_equal(100 - FIRE.hero_damage)  # 대시·무적 중엔 안 탄다


func test_ember_warns_then_ignites() -> void:
	var f := _setup(_line_fire())
	f.host.player.global_position = Vector2(520, 40)
	f.clock.wait = 0.01
	f._physics_process(DT)
	assert_int(f.ember).is_not_equal(-1)
	for i in roundi((FIRE.warn_time + 0.1) / DT):
		f._physics_process(DT)
	assert_int(f.embers).is_equal(1)
	assert_int(f.grid.count(FireGrid.State.BURNING)).is_greater(0)
