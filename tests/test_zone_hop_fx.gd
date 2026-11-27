extends GdUnitTestSuite
## 구역 건너뛰기 뜀·착지 연출 (ZoneHopFx, 사용자 "점프하고 착지할 때 효과가 아예 없고 소리도 없어").
## 시험판의 착지 먹 튐은 먹색 방울 4~8개라 밤바다 갑판(어두운 남색)에 묻혀 보이지 않았다 → 밝은 색·큰 번짐.

const FEEL := preload("res://data/stages/zones/zone_hop_feel.tres")


func after_test() -> void:
	Feedback.instance = null
	GameTime.reset()


func _feedback() -> Feedback:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	return f


func test_data_is_attached_and_readable_on_dark_decks() -> void:
	var d: ZoneHopFxData = FEEL.fx
	assert_object(d).is_not_null()
	assert_float(d.drop_color.get_luminance()).is_greater(0.7)  # 먹색이면 갑판에 묻힌다
	assert_bool(d.land_ink).is_false()
	assert_object(d.land_bloom_vfx).is_not_null()
	assert_float(d.land_bloom_vfx.color.get_luminance()).is_greater(0.7)
	assert_object(d.takeoff_puff_vfx).is_not_null()
	assert_object(d.splash_vfx).is_not_null()
	assert_bool(d.land_sfx.has("gugak_buk")).is_true()  # 국악 한 타는 북 (꽹과리 아님)
	assert_float(d.land_trauma).is_less_equal(0.4)  # 약하게
	assert_float(d.land_stop).is_less_equal(0.08)


func test_takeoff_air_and_land_fire() -> void:
	var f := _feedback()
	var was := GameSettings.haptics_enabled
	GameSettings.haptics_enabled = true
	Haptics.last = []
	var fx := ZoneHopFx.new(FEEL.fx)
	fx.takeoff(Vector2.ZERO, Vector2.UP)
	var after_takeoff: int = f.kill_fx._drops.size()
	assert_int(after_takeoff).is_greater_equal(FEEL.fx.takeoff_drops)
	fx.air(0.5, 0.2, Vector2(0, -100), Vector2(0, -200), Vector2.UP)
	assert_int(f.kill_fx._drops.size()).is_greater(after_takeoff)  # 먹 꼬리
	f._last_haptic = -INF
	fx.land(Vector2(0, -300), Vector2.UP, get_tree())
	assert_array(Haptics.last).is_equal([FEEL.fx.land_haptic_ms, FEEL.fx.land_haptic_amp])
	assert_bool(GameTime.is_stopped()).is_true()
	assert_float(f.trauma).is_greater(0.0)
	GameSettings.haptics_enabled = was
