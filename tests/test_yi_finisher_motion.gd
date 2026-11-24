extends GdUnitTestSuite
## 순신 4타(해룡참) 동작이 눈에 읽히는 길이로 지켜진다 (사용자 07f0d8f "4타 모션이 없다"):
## 예전엔 24fps 다섯 칸 0.21초를 틀고 0.11초 뒤 다음 1타가 덮었다. 이제 4타 전용 cast_speed로 0.3초 넘게,
## 그동안 다음 1타가 끼어들지 않는다 (finisher_recover ≈ 동작 길이). 평타 빠르기와는 따로.

const YI := preload("res://data/heroes/yi_sun_sin.tres")


func test_finisher_motion_is_long_enough_and_guarded() -> void:
	var c := CastAnim.of(YI.kit.tap, YI.sprite_sheet)
	assert_str(c.anim).is_equal("cast_tap")
	assert_float(c.seconds).is_greater_equal(0.3)
	assert_float(YI.kit.finisher_recover).is_greater_equal(c.seconds - 0.01)  # 동작이 끝날 때까지 다음 1타가 덮지 않는다
	var caster: SkillCaster = auto_free(SkillCaster.new())
	var p: Player = auto_free(Player.new())
	p.hero = YI
	caster.player = p
	caster.kit = YI.kit
	assert_float(TapChain.recover(caster)).is_equal_approx(c.seconds, 0.01)


## 평타 빠르기가 올라가도 (타격감 세션이 한 바퀴 1.02 → 0.9초로 당기는 중) 4타 동작 길이는 그대로.
func test_finisher_motion_ignores_basic_attack_speed() -> void:
	var before := CastAnim.of(YI.kit.tap, YI.sprite_sheet).seconds
	var atk := YI.attack.duplicate() as BasicAttackData
	atk.melee_interval *= 0.8
	assert_float(CastAnim.of(YI.kit.tap, YI.sprite_sheet).seconds).is_equal(before)  # 기술 데이터만 본다


## 4타 물결 고리: 그림 바깥 끝 = 판정 반경 + 적 몸 (왜군 병사). 판정 자체는 그대로.
func test_ring_edge_is_the_soldier_body() -> void:
	var h := YI.kit.tap as HaeryongSkill
	var e: Enemy = load("res://scenes/enemy.tscn").instantiate()
	e.data = load("res://data/enemies/waegun_soldier.tres")
	add_child(auto_free(e))
	e.set_physics_process(false)
	assert_float(h.ring_edge_px).is_equal_approx(SkillContext.edge_of(e), 2.0)
	assert_float(h.radius).is_equal(170.0)  # 판정 반경은 그대로 (그림만 맞춘다)
