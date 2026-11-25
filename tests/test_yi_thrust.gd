extends GdUnitTestSuite
## 순신 1타 찌르기가 찌르기로 읽힌다 (사용자 9e19cfb "순신 찌르기 잘 안 보여"): 1타만 초승달 대신 칼끝 쪽 곧은 붓 획,
## 2·3타와 다른 영웅은 초승달 그대로. 구운 1타는 몸을 180° 돌려 칼끝이 대상 쪽 (3D와 같은 쪽).

const YI := preload("res://data/heroes/yi_sun_sin.tres")


func test_only_first_hit_is_a_thrust() -> void:
	var d := YI.attack
	assert_object(d.thrust_art).is_not_null()
	assert_float(ComboSteps.at(d.step_thrust, 1, 0.0)).is_equal(1.0)
	assert_float(ComboSteps.at(d.step_thrust, 2, 0.0)).is_equal(0.0)
	assert_float(ComboSteps.at(d.step_thrust, 3, 0.0)).is_equal(0.0)
	for id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		var o := (load("res://data/heroes/%s.tres" % id) as HeroData).attack
		assert_bool(o.step_thrust.is_empty()).override_failure_message(id).is_true()


func test_baked_first_hit_turns_to_the_target() -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/yi_sun_sin.json"))
	for a: Dictionary in job["anims"]:
		if a["key"] == "attack":
			assert_float(float(a.get("yaw", 0.0))).is_equal(180.0)
