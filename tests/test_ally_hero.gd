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


## 기본은 시안 D (사용자 2026-11-27 "같이싸우기 d"): 10초, 우두머리 있으면 그쪽·없으면 곁, 나올 때 기술 한 번, 내달려 물러감.
func test_default_is_preset_d() -> void:
	var d := HomeSummonData.get_default()
	assert_str(String(d.ally_focus)).is_equal("guard_boss")
	assert_str(String(d.ally_exit)).is_equal("dash")
	assert_float(d.ally_time).is_equal(10.0)
	assert_int(d.ally_skill_times.size()).is_equal(1)
	assert_float(d.ally_hit_scale).is_greater(0.0)
	assert_float(d.ally_skill_scale).is_greater(0.0)


func test_guard_boss_goes_to_the_boss_only_when_there_is_one() -> void:
	var boss: Enemy = auto_free(preload("res://scenes/enemy.tscn").instantiate())
	boss.data = load("res://data/enemies/waegun_commander.tres")
	var grunt: Enemy = auto_free(preload("res://scenes/enemy.tscn").instantiate())
	grunt.data = load("res://data/enemies/waegun_gunner.tres")
	assert_bool(AllyHero.guards(&"guard_boss", boss)).is_false()  # 우두머리: 그쪽으로
	assert_bool(AllyHero.guards(&"guard_boss", grunt)).is_true()  # 잡몹뿐: 곁 지키기
	assert_bool(AllyHero.guards(&"guard_boss", null)).is_true()
	assert_bool(AllyHero.guards(&"guard", boss)).is_true()
	assert_bool(AllyHero.guards(&"boss", grunt)).is_false()
