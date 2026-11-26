extends GdUnitTestSuite
## 강화 패 그림 2차 (#229 ②): 판정·수치 그대로, 그림만.
##  - 파도격 긴 물길·벽력돌파 넓은 벼락: 띠 폭 = 판정 폭 + 적 몸 둘 (예전 고정 130·150)
##  - 사방 검기: 작은 물결 날 그림 (판정 원 안)
##  - 넓은 진동·위엄: 판정 끝 그림이 화면 상한에 막히면 판정 둘레에 작은 명중 그림을 찍어 끝을 보인다

const YI := preload("res://data/heroes/yi_sun_sin.tres")
const GW := preload("res://data/heroes/gwanggaeto.tres")


func test_band_width_follows_hit_width() -> void:
	assert_float((YI.kit.dash as PadoSkill).strip_edge_px).is_greater(0.0)
	assert_float((GW.kit.dash as ThunderTrailSkill).strip_edge_px).is_greater(0.0)


func test_radial_blades_have_art_inside_their_hit() -> void:
	var c := YI.kit.counter as CounterSlashSkill
	assert_object(c.blade_art).is_not_null()
	assert_float(c.blade_art_size.y * 0.5 * 1.3).is_less_equal(12.0 * 1.3 + 22.0)  # 판정 원 + 적 몸 안


func test_big_rings_mark_their_edge() -> void:
	for d in [GW.kit.tap, GW.kit.counter]:
		assert_object((d as SkillDef).vfx_impact.edge_mark_vfx).is_not_null()
