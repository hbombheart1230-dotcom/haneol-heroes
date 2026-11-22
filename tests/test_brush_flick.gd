extends GdUnitTestSuite
## 사임당 중거리 먹 털기 연출 (BrushFlick, BrushFlickData, BrushFlickFx).


func test_shape_by_arc() -> void:
	var d := BrushFlickData.new()
	assert_int(d.shape_of(110.0)).is_equal(0)  # 1타 가로 털기 = 부채꼴 획
	assert_int(d.shape_of(44.0)).is_equal(1)  # 2타 세로 털기 = 한 줄 획
	assert_int(d.shape_of(363.0)).is_equal(2)  # 3타 원으로 뿌리기 = 고리
	assert_bool(d.applies_to(&"shin_saimdang")).is_true()
	assert_bool(d.applies_to(&"yi_sun_sin")).is_false()


func test_saimdang_shapes_follow_her_hit_data() -> void:
	var hero: HeroData = load("res://data/heroes/shin_saimdang.tres")
	var p: Player = auto_free(Player.new())
	p.hero = hero
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.data = hero.attack
	var d := BrushFlickData.get_default()
	var arcs: Array[int] = []
	for s in [1, 2, 3]:
		a.chain_step = s
		var shape := BrushFlick.shape_for(a)
		arcs.append(d.shape_of(shape.y))
		var want := hero.attack.melee_range * ComboSteps.at(hero.attack.step_range_mults, s, 1.0)
		assert_float(shape.x).is_equal_approx(want, 0.01)  # 그림 = 판정 거리
	assert_array(arcs).contains_exactly([0, 1, 2])
	assert_bool(BrushFlick.applies(a)).is_true()


func test_other_heroes_do_not_flick() -> void:
	var p: Player = auto_free(Player.new())
	p.hero = load("res://data/heroes/yi_sun_sin.tres")
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	assert_bool(BrushFlick.applies(a)).is_false()


func test_flick_draws_and_clears() -> void:
	var fx: BrushFlickFx = auto_free(BrushFlickFx.new(BrushFlickData.new(), PlaceholderTexture2D.new()))
	fx.flick(Vector2.ZERO, Vector2.RIGHT, 230.0, 110.0, 1, Color.WHITE)
	fx.flick(Vector2.ZERO, Vector2.RIGHT, 200.0, 363.0, 3, Color.WHITE)
	assert_int(fx.stroke_count()).is_equal(2)
	assert_int(fx.splat_count()).is_greater(0)
	fx.step(5.0)
	assert_int(fx.stroke_count()).is_equal(0)
	assert_int(fx.splat_count()).is_equal(0)


func test_pool_is_capped() -> void:
	var d := BrushFlickData.new()
	d.max_strokes = 2
	d.max_splats = 5
	var fx: BrushFlickFx = auto_free(BrushFlickFx.new(d, PlaceholderTexture2D.new()))
	for i in 10:
		fx.flick(Vector2.ZERO, Vector2.UP, 200.0, 363.0, 3, Color.WHITE)
	assert_int(fx.stroke_count()).is_less_equal(2)
	assert_int(fx.splat_count()).is_less_equal(5)


func test_attach_once() -> void:
	var a: AutoAttack = auto_free(AutoAttack.new())
	add_child(a)
	var n := a.melee_swung.get_connections().size()
	BrushFlick.attach(a)
	assert_int(a.melee_swung.get_connections().size()).is_equal(n)
