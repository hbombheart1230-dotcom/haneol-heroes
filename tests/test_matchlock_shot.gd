extends GdUnitTestSuite
## 한산 조총 (테스터 "임진왜란인데 왜 화살 쏘냐, 조총 써야지"): 철포병·조총 명수·철포 횡대의 탄은 납탄 + 불빛 꼬리,
## 쏘는 순간 총구 불꽃과 흰 화약 연기, 소리 e_gun. 예전엔 철포병이 waegun_volley 행동의 공격(화살 그림·기본 소리 e_bow·불꽃 없음)을 썼다.
## 다른 전장 궁수는 화살 그대로. 속도·피해·판정은 그대로.

const GUNNERS := ["waegun_gunner", "waegun_gunner_captain"]
const ARCHERS := ["archer", "jurchen_archer", "cc_grasshopper", "khitan_bow_captain", "jurchen_bow_captain", "cc_hopper_captain"]


func _shots(id: String) -> Array:
	var d := load("res://data/enemies/%s.tres" % id) as EnemyData
	var out: Array = []
	var main_atk: EnemyAttackData = d.behaviour.attack if d.behaviour and d.behaviour.attack else d.attack
	for a in [main_atk] + Array(d.patterns):
		if a and (a as EnemyAttackData).kind == EnemyAttackData.Kind.SHOOT:
			out.append(a)
	return out


func test_gunners_fire_musket_balls_with_smoke_and_gun_sound() -> void:
	for id in GUNNERS:
		var shots := _shots(id)
		assert_int(shots.size()).override_failure_message(id).is_greater(0)
		for a: EnemyAttackData in shots:
			assert_str(String(a.strike_sfx)).override_failure_message(id).is_equal("e_gun")
			assert_object(a.fire_vfx).override_failure_message(id).is_not_null()
			assert_object(a.smoke_vfx).override_failure_message(id).is_not_null()
			assert_object(a.shot_look).override_failure_message(id).is_not_null()


func test_archers_keep_arrows() -> void:
	for id in ARCHERS:
		for a: EnemyAttackData in _shots(id):
			assert_object(a.shot_look).override_failure_message(id).is_null()
			assert_object(a.smoke_vfx).override_failure_message(id).is_null()


func test_shot_carries_look_and_texture_fits_rect() -> void:
	var a := (_shots("waegun_gunner")[0] as EnemyAttackData)
	var arrow: EnemyArrow = auto_free(EnemyArrow.new())
	arrow.setup(null, Vector2.ZERO, a)
	assert_object(arrow.look).is_same(a.shot_look)
	assert_float(arrow.speed).is_equal(a.projectile_speed)  # 속도·피해는 그대로
	assert_int(arrow.damage).is_equal(a.damage)
	var t := a.shot_look.texture()
	var r := a.shot_look.texture_rect()
	assert_int(t.get_width()).is_equal(ceili(r.size.x))
	assert_int(t.get_height()).is_equal(ceili(r.size.y))
	assert_object(a.shot_look.texture()).is_same(t)  # 한 번만 만든다
