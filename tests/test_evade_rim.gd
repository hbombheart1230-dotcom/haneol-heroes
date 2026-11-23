extends GdUnitTestSuite
## 회피 성공 무적 표시 (사용자 승인): 무적 1초 동안 영웅 몸에 옅은 금빛 테두리, 남은 시간이 줄수록 옅어짐, 피격 무적과는 따로.
## 튜토리얼 반격 단계에 "피한 뒤 1초 동안은 맞지 않습니다".

const YI := preload("res://data/heroes/yi_sun_sin.tres")
const TUTORIAL := preload("res://data/tutorial/controls.tres")
const DT := 1.0 / 60.0


func _player() -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = YI
	add_child(p)
	p.set_physics_process(false)
	return p


func _rim(p: Player) -> EvadeRim:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = YI.sprite_sheet.build_sprite_frames()
	s.play(&"idle_2")
	p.add_child(s)
	var r := EvadeRim.new(p, s)
	p.add_child(r)
	return r


func test_rim_only_after_evade_and_fades() -> void:
	var p := _player()
	var r := _rim(p)
	assert_float(r.strength()).is_equal(0.0)
	p.grant_invulnerability(1.0)  # 회피가 아닌 무적 (보스 연출 등): 테두리 없음
	assert_float(r.strength()).is_equal(0.0)
	p.register_evade()
	assert_float(r.strength()).is_equal_approx(1.0, 0.01)
	for i in 30:
		p.compute_velocity(DT)
	var half := r.strength()
	assert_float(half).is_between(0.3, 0.7)  # 남은 시간만큼 옅어짐
	for i in 40:
		p.compute_velocity(DT)
	assert_float(r.strength()).is_equal(0.0)


## 피격 무적(붉은 깜빡임)에는 금빛 테두리가 없다.
func test_hurt_invuln_has_no_rim() -> void:
	var p := _player()
	var r := _rim(p)
	p._take_hit(5)
	assert_float(r.strength()).is_equal(0.0)


func test_rim_draws_in_tree() -> void:
	var p := _player()
	var r := _rim(p)
	p.register_evade()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(r)).is_true()


func test_tutorial_counter_says_one_second_invulnerable() -> void:
	var found := false
	for s in TUTORIAL.steps:
		if s.event == &"skill_counter":
			assert_str(s.hint).contains("1초 동안은 맞지 않습니다")
			assert_str(s.button_hint).contains("1초 동안은 맞지 않습니다")
			found = true
		if s.event == &"skill_dash":
			assert_str(String(s.hero_hints.get("yi_sun_sin", ""))).contains("뒤로 빠지기")
	assert_bool(found).is_true()
