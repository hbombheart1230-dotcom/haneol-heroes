extends GdUnitTestSuite
## 데이터 기반 구조: 영웅·적·기술 데이터가 로드되고 노드에 적용되는지.

const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const CHASER := preload("res://data/enemies/chaser.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func test_hero_data_loads_with_kit_and_attack() -> void:
	assert_object(HERO).is_instanceof(HeroData)
	assert_str(HERO.display_name).is_equal("순신")
	assert_object(HERO.attack).is_instanceof(BasicAttackData)
	assert_object(HERO.kit.tap).is_instanceof(HaeryongSkill)
	assert_object(HERO.kit.dash).is_instanceof(PadoSkill)
	assert_object(HERO.kit.charge).is_instanceof(HaeilSkill)
	assert_str(HERO.kit.tap.display_name).is_equal("해룡참")
	assert_float(HERO.kit.tap.cooldown).is_equal(4.0)


func test_player_applies_hero_data() -> void:
	var h: HeroData = HERO.duplicate(true)
	h.max_hp = 150
	h.move_speed = 400.0
	h.max_dash_charges = 3
	var p: Player = auto_free(Player.new())
	var health := Health.new()
	health.name = "Health"
	p.add_child(health)
	p.hero = h
	add_child(p)
	assert_int(p.health.max).is_equal(150)
	assert_int(p.health.current).is_equal(150)
	assert_float(p.move_speed).is_equal(400.0)
	assert_int(p.dash.max_charges).is_equal(3)


func test_enemy_applies_enemy_data() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	var d: EnemyData = CHASER.duplicate()
	d.max_hp = 77
	d.move_speed = 55.0
	e.data = d
	add_child(auto_free(e))
	assert_int(e.health.max).is_equal(77)
	assert_float(e.move_speed).is_equal(55.0)


func test_auto_attack_reads_hero_attack_data() -> void:
	var p: Player = auto_free(Player.new())
	p.hero = HERO
	add_child(p)
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	add_child(a)
	assert_object(a.stats()).is_same(HERO.attack)


func test_skill_caster_uses_hero_kit_by_default() -> void:
	var p: Player = auto_free(Player.new())
	p.hero = HERO
	add_child(p)
	var c: SkillCaster = auto_free(SkillCaster.new())
	c.player = p
	add_child(c)
	assert_object(c.kit).is_same(HERO.kit)
	assert_str(c.display_name(SkillCaster.Slot.CHARGE)).is_equal("해일검기")
	assert_float(c.input.hold_threshold).is_equal(HERO.kit.hold_threshold)


func test_new_hero_needs_only_data() -> void:
	# 다른 영웅 구성 예: 기술 정의만 바꾼 kit로 같은 SkillCaster가 동작
	var kit := SkillKit.new()
	var tap := HaeryongSkill.new()
	tap.display_name = "시험기"
	tap.cooldown = 1.0
	kit.tap = tap
	var p: Player = auto_free(Player.new())
	add_child(p)
	var c: SkillCaster = auto_free(SkillCaster.new())
	c.player = p
	c.kit = kit
	c.enemy_source = func() -> Array: return []
	add_child(c)
	c.on_press(0, 0.0)
	assert_int(c.on_release(0, 0.05)).is_equal(SkillCaster.Slot.TAP)
	assert_bool(c.is_ready(SkillCaster.Slot.DASH)).is_false()  # 정의 없음
	assert_str(c.display_name(SkillCaster.Slot.DASH)).is_equal("")


# --- 리팩터링 동작 보존 회귀 (Codex 43f08b5 지적) ---

func test_pado_aggregate_hits_count_every_strike_in_range() -> void:
	var p: Player = auto_free(Player.new())
	add_child(p)
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(150, 0)
	e.health.max = 10
	e.health.current = 10
	var c: SkillCaster = auto_free(SkillCaster.new())
	c.player = p
	c.kit = _old_rule_kit(HERO.kit)  # 예전 "내닫고 떼기" 규칙 (dash_auto 끔). 새 규칙은 test_dash_auto_skill
	c.enemy_source = func() -> Array: return [e]
	add_child(c)
	c.set_physics_process(false)
	var casts: Array = []
	c.skill_cast.connect(func(s: SkillCaster.Slot, hits: int) -> void: casts.append([s, hits]))
	p.request_dash(Vector2.RIGHT)
	c.on_press(0, 0.0)
	for i in 30:
		c.tick(1.0 / 60.0, i / 60.0)
	assert_array(casts).is_equal([[SkillCaster.Slot.DASH, 3]])


func test_skill_fx_colors_match_pre_refactor() -> void:
	assert_object(HERO.kit.tap.fx_color).is_equal(Color(0.35, 0.75, 1.0))
	assert_object(HERO.kit.dash.fx_color).is_equal(Color(0.4, 0.9, 1.0))
	assert_object(HERO.kit.tap.color).is_equal(Color(0.2, 0.5, 0.9))
	assert_object(HERO.kit.dash.color).is_equal(Color(0.2, 0.85, 0.95))


## 내닫아 치기(kit.dash_auto)를 끈 사본: 내닫는 중·직후 손 떼기·탭·단추 = 둘째 기술 (영웅별로 되돌릴 때의 길).
static func _old_rule_kit(k: SkillKit) -> SkillKit:
	var c := k.duplicate() as SkillKit
	c.dash_auto = false
	return c
