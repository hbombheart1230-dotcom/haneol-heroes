extends GdUnitTestSuite
## 궁극기 모으기 발밑 표시: 영웅별 그림, 충전만큼 커짐, 모으는 동안 입자, 다 찬 순간 번쩍.

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


func test_every_hero_has_a_distinct_marker() -> void:
	var arts := []
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		var m := h.charge_marker
		assert_object(m).override_failure_message(id).is_not_null()
		assert_object(m.art).is_not_null()
		assert_object(m.art2).is_not_null()
		assert_object(m.spark_vfx).is_not_null()
		assert_object(m.full_vfx).is_not_null()
		assert_float(m.size_max).is_greater(m.size_min)
		arts.append(m.art)
	for i in arts.size():
		for k in range(i + 1, arts.size()):
			assert_object(arts[i]).is_not_same(arts[k])


func test_sparks_while_charging_and_flash_once_when_full() -> void:
	var f := _feedback()
	var m := ChargeMarker.new((load("res://data/heroes/sejong.tres") as HeroData).charge_marker)
	assert_bool(m.tick(0.016, true, 0.3, Vector2.ZERO)).is_false()
	assert_int(f.skill_vfx.count()).is_greater(0)  # 모으는 동안 별
	assert_bool(m.tick(0.016, true, 1.0, Vector2.ZERO)).is_true()  # 다 찬 순간
	assert_float(m.flash_left()).is_greater(0.0)
	assert_int(f.decals.count()).is_greater(0)  # 자모 그림이 터짐
	assert_bool(m.tick(0.016, true, 1.0, Vector2.ZERO)).is_false()  # 한 번만
	m.tick(0.016, false, 0.0, Vector2.ZERO)  # 손 뗌
	assert_bool(m.tick(0.016, true, 1.0, Vector2.ZERO)).is_true()  # 다음 충전엔 다시


func test_no_marker_data_is_safe() -> void:
	var m := ChargeMarker.new(null)
	assert_bool(m.tick(0.016, true, 1.0, Vector2.ZERO)).is_false()
	var c: Node2D = auto_free(Node2D.new())
	add_child(c)
	m.draw(c, true, 0.5)  # 공통 붓 고리로 그린다 (오류 없이)


func test_caster_draws_marker_behind_the_hero() -> void:
	var p: Player = auto_free(Player.new())
	p.hero = load("res://data/heroes/yi_sun_sin.tres")
	var sc: SkillCaster = auto_free(SkillCaster.new())
	sc.player = p
	p.add_child(sc)
	add_child(p)
	assert_bool(sc.show_behind_parent).is_true()
	assert_object(sc._marker().data).is_same(p.hero.charge_marker)
