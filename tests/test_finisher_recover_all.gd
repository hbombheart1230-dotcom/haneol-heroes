extends GdUnitTestSuite
## 넓히기 (사용자 2026-11-24 "다 맞추라"): 넷째 탭 마무리 뒤 잠금(finisher_recover)을 네 영웅 모두 데이터로.

const YI := preload("res://data/heroes/yi_sun_sin.tres")
const GW := preload("res://data/heroes/gwanggaeto.tres")
const SJ := preload("res://data/heroes/sejong.tres")
const SA := preload("res://data/heroes/shin_saimdang.tres")


## 넷째 탭 마무리 뒤 잠금: 네 영웅 모두 데이터 값 (예전엔 순신만, 셋은 시전 동작 전체). 셋은 예전 잠금(시전 동작)보다 조금만 짧게,
## 광개토가 가장 적게 당긴다 (묵직함).
func test_finisher_recover_is_data_for_all() -> void:
	var cut := {}
	for h in [YI, GW, SJ, SA]:
		var hd := h as HeroData
		var rec := hd.kit.finisher_recover
		assert_float(rec).is_greater_equal(0.0)
		var anim := CastAnim.of(hd.kit.tap, hd.sprite_sheet).seconds
		cut[hd.id] = anim - rec
		if hd != YI:
			assert_float(cut[hd.id]).override_failure_message(String(hd.id)).is_between(0.0, 0.12)
	assert_float(cut[GW.id]).is_less_equal(cut[SJ.id])
	assert_float(cut[GW.id]).is_less_equal(cut[SA.id])
