extends GdUnitTestSuite
## 2단계 기술 이펙트: 코드로 만든 텍스처, 입자 터짐·상한, 번개 줄기, 기술 발동·적중·내리꽂힘 연결, 영웅 데이터.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const HEROES := ["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"]


func after_test() -> void:
	Feedback.instance = null


func _feedback() -> Feedback:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	return f


func _vfx(shape: SkillVfxData.Shape, n: int = 6) -> SkillVfxData:
	var d := SkillVfxData.new()
	d.shape = shape
	d.count = n
	return d


func test_every_shape_texture_is_solid_in_middle_and_clear_at_corner() -> void:
	for shape in SkillVfxData.Shape.values():
		var img := VfxTextures.make_image(shape)
		var c := VfxTextures.SIZE / 2
		assert_float(img.get_pixel(c, c).a).override_failure_message("shape %d centre" % shape).is_greater(0.5)
		assert_float(img.get_pixel(0, 0).a).override_failure_message("shape %d corner" % shape).is_less(0.05)
	assert_object(VfxTextures.get_texture(SkillVfxData.Shape.STAR)).is_same(VfxTextures.get_texture(SkillVfxData.Shape.STAR))


func test_burst_count_cap_and_fade_out() -> void:
	var v: SkillVfx = auto_free(SkillVfx.new())
	v.burst(_vfx(SkillVfxData.Shape.DOT, 10), Vector2.ZERO)
	assert_int(v.count()).is_equal(10)
	for i in 40:
		v.burst(_vfx(SkillVfxData.Shape.DOT, 10), Vector2.ZERO)
	assert_int(v.count()).is_equal(v.feel.max_vfx_particles)
	v.step(5.0)
	assert_int(v.count()).is_equal(0)
	v.burst(null, Vector2.ZERO)
	assert_int(v.count()).is_equal(0)


func test_forward_aim_stays_in_spread() -> void:
	var v: SkillVfx = auto_free(SkillVfx.new())
	var d := _vfx(SkillVfxData.Shape.SHARD, 30)
	d.aim = SkillVfxData.Aim.FORWARD
	d.spread_deg = 40.0
	v.burst(d, Vector2.ZERO, Vector2.RIGHT)
	for p in v._parts:
		assert_float(absf((p["vel"] as Vector2).angle())).is_less_equal(deg_to_rad(20.0) + 0.001)


func test_glyphs_cycle() -> void:
	var v: SkillVfx = auto_free(SkillVfx.new())
	var d := _vfx(SkillVfxData.Shape.GLYPH, 3)
	d.glyphs = "ㄱㄴ"
	v.burst(d, Vector2.ZERO)
	assert_array(v._parts.map(func(p: Dictionary) -> String: return p["glyph"])).is_equal(["ㄱ", "ㄴ", "ㄱ"])


func test_gravity_pulls_down() -> void:
	var v: SkillVfx = auto_free(SkillVfx.new())
	var d := _vfx(SkillVfxData.Shape.PETAL, 1)
	d.speed = Vector2.ZERO
	d.gravity = 300.0
	d.life = Vector2(2, 2)
	v.burst(d, Vector2.ZERO)
	var y0: float = (v._parts[0]["pos"] as Vector2).y
	for i in 10:
		v.step(0.05)
	assert_float((v._parts[0]["pos"] as Vector2).y).is_greater(y0)


func test_bolt_points_are_stored_once() -> void:
	var fx: FxLayer = auto_free(FxLayer.new())
	fx.add_bolt(Vector2.ZERO, Vector2(0, 400), 10.0, 0.2, Color.WHITE, 6, 20.0)
	var f: Dictionary = fx._fx[0]
	var pts: PackedVector2Array = f["pts"]
	assert_int(pts.size()).is_equal(7)
	assert_vector(pts[0]).is_equal(Vector2.ZERO)
	assert_vector(pts[6]).is_equal(Vector2(0, 400))


func test_context_impact_and_hit_use_skill_vfx() -> void:
	var f := _feedback()
	var p: Player = auto_free(Player.new())
	add_child(p)
	var skill := SkillDef.new()
	skill.vfx_hit = _vfx(SkillVfxData.Shape.DOT, 3)
	skill.vfx_impact = _vfx(SkillVfxData.Shape.SHARD, 5)
	skill.vfx_impact.bolt_segments = 5
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.fx = f.fx
	ctx.skill = skill
	ctx.impact(Vector2(100, 0))
	assert_int(f.skill_vfx.count()).is_equal(5)
	assert_int(f.fx._fx.filter(func(x: Dictionary) -> bool: return x["kind"] == "bolt").size()).is_equal(1)
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(60, 0)
	assert_bool(ctx.hit(e, 1)).is_true()
	assert_int(f.skill_vfx.count()).is_equal(8)
	# 기술이 없으면 (테스트용 컨텍스트) 이펙트 없음
	ctx.skill = null
	ctx.impact(Vector2.ZERO)
	assert_int(f.skill_vfx.count()).is_equal(8)


func test_every_hero_skill_has_effects_from_data() -> void:
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		for slot in ["tap", "dash", "charge", "counter"]:
			var d: SkillDef = h.kit.get(slot)
			if d == null:
				continue
			assert_object(d.vfx_cast).override_failure_message("%s %s cast" % [id, slot]).is_not_null()
			assert_object(d.vfx_hit).override_failure_message("%s %s hit" % [id, slot]).is_not_null()
			assert_object(d.vfx_impact).override_failure_message("%s %s impact" % [id, slot]).is_not_null()
	var gw: HeroData = load("res://data/heroes/gwanggaeto.tres")
	assert_bool(gw.kit.charge.vfx_impact.has_bolt()).is_true()  # 광개토 = 번개
	var sj: HeroData = load("res://data/heroes/sejong.tres")
	assert_int(sj.kit.tap.vfx_hit.shape).is_equal(SkillVfxData.Shape.GLYPH)  # 세종 = 글자
	var sa: HeroData = load("res://data/heroes/shin_saimdang.tres")
	assert_int(sa.kit.tap.vfx_impact.shape).is_equal(SkillVfxData.Shape.PETAL)  # 사임당 = 꽃잎


func test_feel_tres_holds_vfx_numbers() -> void:
	var d: CombatFeelData = load("res://data/feel/combat_feel.tres")
	assert_int(d.max_vfx_particles).is_greater(0)
	assert_float(d.bolt_glow_width).is_greater(d.bolt_body_width)
