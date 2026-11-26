extends GdUnitTestSuite
## 같이 싸우기 (AllyHero): 불려 온 영웅의 피해 배율 사본, 느낌 데이터 기본값.

const YI := preload("res://data/heroes/yi_sun_sin.tres")


func test_scaled_hero_scales_only_damage_and_leaves_the_original() -> void:
	var c := AllyHero.scaled_hero(YI, 0.5)
	assert_object(c).is_not_same(YI)
	assert_int(c.attack.melee_damage).is_equal(maxi(roundi(YI.attack.melee_damage * 0.5), 1))
	assert_float(c.attack.melee_range).is_equal(YI.attack.melee_range)
	assert_object(c.kit).is_not_same(YI.kit)
	assert_object(c.kit.tap).is_not_same(YI.kit.tap)
	assert_object(c.sprite_sheet).is_same(YI.sprite_sheet)  # 그림·움직임은 그대로
	assert_float(c.move_speed).is_equal(YI.move_speed)
	assert_object(AllyHero.scaled_hero(YI, 1.0)).is_same(YI)


func test_feel_data_is_known() -> void:
	var d := HomeSummonData.get_default()
	assert_array([&"boss", &"guard"]).contains([d.ally_focus])
	assert_array([&"ink", &"dash"]).contains([d.ally_exit])
	assert_float(d.ally_time).is_greater(0.0)
	assert_float(d.ally_hit_scale).is_greater(0.0)
