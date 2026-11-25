extends GdUnitTestSuite
## 사용자 9e19cfb "사임당도 비슷하게 고리 있어, 그것도 빼고": 네 영웅 기술 모두 범위를 재는 듯한 고리를 그리지 않는다.
##  - 강화 단계 금빛 고리 (SkillVfxData.gold_ring): 영웅 기술·시전·명중 그림 모두 false
##  - 기술 반경에 맞춰 긋던 단색 고리 (FxLayer.add_ring, SkillDef.range_rings): 네 영웅 16기술 모두 false
## 조작에 쓰는 표시(조준 길·모으는 고리·다음 탭 마무리 표시)와 예고(유성 떨어질 자리)는 그대로 (데이터로 켤 수 있음).

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


func test_no_range_rings_on_any_hero_skill() -> void:
	for id in HEROES:
		var k := (ResourceLoader.load("res://data/heroes/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData).kit
		for d: SkillDef in [k.tap, k.dash, k.charge, k.counter]:
			assert_bool(d.range_rings).override_failure_message("%s %s range_rings" % [id, d.id]).is_false()
			for v: SkillVfxData in [d.vfx_cast, d.vfx_hit, d.vfx_impact]:
				if v:
					for lv in [0, 3, 6, 9]:
						assert_bool(v.ring_for(lv)).override_failure_message("%s %s gold ring lv%d" % [id, d.id, lv]).is_false()


## 스위치는 데이터: 켜면 예전처럼 (다른 기술·새 기술의 기본값은 켬).
func test_switch_defaults_on() -> void:
	assert_bool(SkillDef.new().range_rings).is_true()
	var v := SkillVfxData.new()
	v.growth = true
	assert_bool(v.ring_for(9)).is_true()
