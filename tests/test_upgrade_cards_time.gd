extends GdUnitTestSuite
## 패 고르기 화면은 실제 시간으로 나타난다: 반격·마무리 느린 시간(GameTime.stop) 직후 열려도 흐린 채 남지 않는다
## (S20 실기 1e4da72: 조작 안내 "강화 고르기" 단계에서 패 셋이 아주 흐리게 판 위에 남아 보였다).

const YI := preload("res://data/heroes/yi_sun_sin.tres")


func after_test() -> void:
	get_tree().paused = false
	GameTime.reset()


func test_cards_fade_in_on_real_time_during_slow_time() -> void:
	var sc: SealChoice = auto_free(SealChoice.new())
	add_child(sc)
	GameTime.stop(get_tree(), 3.0, 0.05)  # 반격 컷인·마무리 같은 긴 느린 시간
	assert_float(Engine.time_scale).is_less(0.1)
	var choices: Array[UpgradeDef] = YI.upgrade_pool.upgrades.slice(0, 3)
	sc.open(choices, Vector2.ZERO, false, {})
	assert_bool(get_tree().paused).is_true()
	await get_tree().create_timer(0.5, true, false, true).timeout  # 실제 0.5초
	assert_float(sc.cards._age).is_greater(0.4)  # 0.05배로 기면 0.025초
	assert_bool(sc.cards.accepting()).is_true()  # 다 나타나 누름을 받는다
	sc.pick(0)
	assert_bool(sc.cards.visible).is_false()  # 고른 뒤엔 완전히 숨는다
	assert_bool(get_tree().paused).is_false()


func test_closed_cards_are_hidden_and_draw_nothing() -> void:
	var sc: SealChoice = auto_free(SealChoice.new())
	add_child(sc)
	var choices: Array[UpgradeDef] = YI.upgrade_pool.upgrades.slice(0, 3)
	sc.open(choices, Vector2.ZERO, false, {})
	sc.close()
	assert_bool(sc.cards.visible).is_false()
	assert_bool(sc.cards.choices.is_empty()).is_true()
	assert_bool(sc.cards.handle_touch(0, sc.cards.card_rect(1).get_center(), true)).is_false()
