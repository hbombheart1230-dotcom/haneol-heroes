extends GdUnitTestSuite
## 강화 패 "효과는 있는데 안 보임"(#229 ②) 1차 그림: 고르면 무엇이 달라졌는지 보이게. 판정·수치는 그대로.
##  - 순신 큰 변형 물보라: 물길 끝 물결 판 (end_burst_vfx, 반경 + 몸)
##  - 순신 연파: 한 타 = 물결 띠 한 줄 (타수 = 줄 수)
##  - 세종 큰 변형 북두칠성: 별마다 터짐 그림 (star_burst_vfx, 반경 + 몸)
##  - 세종 큰 변형 유성우: 작은 별도 떨어지는 그림 + 시차
##  - 느려짐 (해시계 긴 그림자, 발묵 진한 먹): 발밑 표시 짙기 = 느려진 정도, 호 = 남은 시간

const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SJ := preload("res://data/heroes/sejong.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func test_new_art_is_wired_in_the_hero_data() -> void:
	assert_object((YI.kit.dash as PadoSkill).end_burst_vfx).is_not_null()
	assert_object((SJ.kit.charge as ConstellationSkill).star_burst_vfx).is_not_null()
	assert_object((SJ.kit.dash as MeteorSkill).fall_art).is_not_null()
	assert_float((SJ.kit.dash as MeteorSkill).extra_stagger).is_greater(0.0)


## 유성우: 작은 별은 본 별 뒤로 extra_stagger초씩 차례로 떨어진다 (한꺼번에 터지지 않음).
func test_meteor_shower_lands_one_after_another() -> void:
	var m := (SJ.kit.dash as MeteorSkill).duplicate() as MeteorSkill
	m.extra_stars = 4
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.skill = m
	ctx.world = self
	ctx.enemy_source = func() -> Array: return []
	var run := m.cast(ctx, 0.0)
	assert_bool(run.tick(m.delay + 0.001)).is_false()  # 본 별만
	assert_bool(run.tick(m.extra_stagger * 2.0)).is_false()  # 작은 별 둘
	assert_bool(run.tick(m.extra_stagger * 3.0)).is_true()  # 나머지


## 느려짐 표시는 남은 시간 비율을 안다 (호가 줄어듦).
func test_slow_remembers_its_total_time() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.slow(0.32, 2.0)
	var total: float = e._slow_total
	assert_float(total).is_greater(0.0)
	e._physics_process(total * 0.5)
	assert_float(e._slow_left / e._slow_total).is_equal_approx(0.5, 0.05)
	assert_float(Enemy.ai_data().slow_mark_scale).is_greater(1.0)
