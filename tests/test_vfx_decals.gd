extends GdUnitTestSuite
## 그려진 기술 이펙트 (아이콘·GPT 그림): 강화 단계에 따라 커지고 겹이 늘고 고리가 붙는다.

const HEROES := ["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"]


func after_test() -> void:
	Feedback.instance = null


func _decal(level_layers: int = 1) -> SkillVfxData:
	var d := SkillVfxData.new()
	d.decal = PlaceholderTexture2D.new()
	d.decal_layers = level_layers
	return d


func test_level_math() -> void:
	var d := _decal()
	d.count = 10
	assert_float(d.size_mult(0)).is_equal(1.0)
	assert_float(d.size_mult(3)).is_equal_approx(1.0 + d.level_size * 3, 0.001)
	assert_float(d.size_mult(99)).is_equal(d.size_mult(d.max_level))
	assert_int(d.count_for(4)).is_greater(d.count_for(0))
	assert_int(d.layers_for(d.flourish_level)).is_equal(d.decal_layers + 1)
	d.glow = 0.5
	assert_float(d.glow_for(3)).is_greater(d.glow_for(0))


func test_higher_level_is_bigger_and_layered_with_ring() -> void:
	var v: VfxDecals = auto_free(VfxDecals.new())
	var d := _decal()
	v.burst(d, Vector2.ZERO, Vector2.ZERO, 0)
	assert_int(v.count()).is_equal(1)
	assert_int(v.ring_count()).is_equal(0)
	var small: float = v._items[0]["size"]
	v.burst(d, Vector2.ZERO, Vector2.ZERO, d.ring_level)
	assert_int(v.count()).is_equal(1 + d.layers_for(d.ring_level))
	assert_int(v.ring_count()).is_equal(1)
	assert_float(float(v._items[1]["size"])).is_greater(small)
	v.step(10.0)
	assert_int(v.count()).is_equal(0)
	assert_int(v.ring_count()).is_equal(0)


func test_cap_and_no_decal() -> void:
	var v: VfxDecals = auto_free(VfxDecals.new())
	for i in 100:
		v.burst(_decal(2), Vector2.ZERO)
	assert_int(v.count()).is_equal(v.feel.max_decals)
	v.burst(SkillVfxData.new(), Vector2.ZERO)  # 그림 없는 데이터는 무시
	v.burst(null, Vector2.ZERO)
	assert_int(v.count()).is_equal(v.feel.max_decals)


func test_align_and_upright() -> void:
	var v: VfxDecals = auto_free(VfxDecals.new())
	var d := _decal()
	d.decal_align = true
	d.decal_angle_deg = 90.0
	v.burst(d, Vector2.ZERO, Vector2.RIGHT)
	assert_float(float(v._items[0]["rot"])).is_equal_approx(-PI * 0.5, 0.001)
	var u := _decal()
	u.decal_upright = true
	v.burst(u, Vector2.ZERO, Vector2.RIGHT)
	assert_float(float(v._items[1]["rot"])).is_equal(0.0)


func test_upgrades_raise_skill_vfx_level() -> void:
	var p: Player = auto_free(Player.new())
	p.hero = load("res://data/heroes/yi_sun_sin.tres")
	add_child(p)
	var build := RunBuild.new()
	build.begin(p, null, null)
	var u := UpgradeDef.new()
	var m := StatMod.new()
	m.target = &"tap"
	m.property = &"damage"
	m.value = 1.1
	var m2 := StatMod.new()
	m2.target = &"tap"
	m2.property = &"cooldown"
	m2.value = 0.9
	u.mods = [m, m2] as Array[StatMod]
	build.apply(u)
	assert_int(build.hero.kit.tap.vfx_level).is_equal(1)  # 같은 기술은 한 성장에 한 번만
	u.vfx_level_gain = 3
	build.apply(u)
	assert_int(build.hero.kit.tap.vfx_level).is_equal(4)
	var original: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	assert_int(original.kit.tap.vfx_level).is_equal(0)  # 원본은 그대로


func test_major_upgrades_count_more() -> void:
	for id in HEROES:
		var pool: UpgradePool = load("res://data/upgrades/%s_major.tres" % id)
		for u in pool.upgrades:
			assert_int(u.vfx_level_gain).override_failure_message("%s %s" % [id, u.id]).is_equal(3)


func test_every_skill_has_a_painted_effect() -> void:
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		for slot in ["tap", "dash", "charge", "counter"]:
			var d: SkillDef = h.kit.get(slot)
			if d == null:
				continue
			var painted := (d.vfx_impact and d.vfx_impact.decal) or (d.vfx_cast and d.vfx_cast.decal)
			assert_bool(painted).override_failure_message("%s %s" % [id, slot]).is_true()


func test_feedback_routes_to_decals() -> void:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	Feedback.vfx_burst(_decal(), Vector2.ZERO, Vector2.ZERO, 0)
	assert_int(f.decals.count()).is_equal(1)
