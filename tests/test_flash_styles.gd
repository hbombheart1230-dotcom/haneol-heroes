extends GdUnitTestSuite
## 맞은 순간 몸 색 비교안 (HitReactionData.hit_flash_style): 3 = 흰 번쩍임 + 인주 테두리 (깜빡임),
## 4 = 한지색 실루엣 + 먹 테두리 (한 칸). 기본은 0 흰색 그대로.


func test_default_is_white() -> void:
	var d := HitReactionData.new()
	assert_int(d.hit_flash_style).is_equal(0)
	assert_bool(d.flash_body() == Color.WHITE).is_true()
	assert_float(d.flash_rim().a).is_equal(0.0)


func test_white_seal_blinks_with_seal_rim() -> void:
	var d := HitReactionData.new()
	d.hit_flash_style = 3
	assert_bool(d.blinks()).is_true()
	assert_bool(d.flash_body() == Color.WHITE).is_true()
	assert_bool(d.flash_rim() == d.seal_rim).is_true()


func test_hanji_ink_is_one_frame_silhouette() -> void:
	var d := HitReactionData.new()
	d.hit_flash_style = 4
	assert_bool(d.blinks()).is_false()
	assert_bool(d.flash_body() == d.hanji_silhouette).is_true()
	assert_bool(d.flash_rim() == d.ink_rim).is_true()
