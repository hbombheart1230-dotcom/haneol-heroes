extends GdUnitTestSuite
## 사임당 1번 풀벌레: 처음엔 수명을 줄였고 (사용자 9e19cfb "나비 너무 세. 사기야"), 2026-11-26부터는 무는 횟수로 끝난다
## ("초가 아니라 타격 횟수로"). 한 번 부를 때의 피해가 횟수로 정해져 겹쳐 쌓여도 더 세지지 않는다. 마릿수 상한(max_alive)은 남겨 두되 끔.

const HERO := preload("res://data/heroes/shin_saimdang.tres")


const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const HEAVY := preload("res://data/enemies/heavy.tres")
const DT := 1.0 / 60.0


## 무는 횟수로 끝난다 (사용자 2026-11-26 "초가 아니라 타격 횟수로"): 한 마리는 bites번 물면 사라지고, 마지막 물기는 크게.
## 시간은 안전 상한만 (물 적이 없으면 lifetime 뒤 사라짐).
func test_critter_ends_after_its_bites() -> void:
	var d := HERO.kit.tap as CritterSkill
	assert_int(d.bites).is_greater(0)
	assert_bool(d.cap_lifetime).is_false()
	var e: Enemy = auto_free(ENEMY_SCENE.instantiate())
	e.data = HEAVY
	add_child(e)
	e.set_physics_process(false)
	e.health.max = 99999
	e.health.current = 99999
	e.global_position = Vector2(120, 0)
	var c := _critter(d.bites, d.lifetime, [e])
	var t := 0.0
	while t < d.lifetime and not c.is_queued_for_deletion():
		c._physics_process(DT)
		t += DT
	assert_bool(c.is_queued_for_deletion()).is_true()
	assert_int(c.hits).is_equal(d.bites)
	assert_float(t).is_less(d.lifetime)  # 횟수가 먼저 끝낸다


func test_wandering_critter_ends_at_the_safety_lifetime() -> void:
	var c := _critter(4, 1.0, [])
	for i in 70:
		if c.is_queued_for_deletion():
			break
		c._physics_process(DT)
	assert_bool(c.is_queued_for_deletion()).is_true()
	assert_int(c.hits).is_equal(0)


func test_last_bite_is_the_big_one() -> void:
	var c := _critter(3, 99.0, [])
	assert_bool(c.is_last_bite()).is_false()
	c.hits = 2
	assert_bool(c.is_last_bite()).is_true()


## 긴 숨 패 = 무는 횟수 +1: 늘 실제로 늘어 헛된 패가 아니고, 패 글은 "무는 횟수 지금 → 뒤".
func test_long_breath_adds_a_bite() -> void:
	var b := RunBuild.new()
	b.hero = HERO.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	var d := b.hero.kit.tap as CritterSkill
	var long_up: UpgradeDef = null
	for u in b.hero.upgrade_pool.upgrades:
		if u.id == &"critter_long":
			long_up = u
	var n := d.bites
	assert_bool(UpgradeEffect.useful(b, long_up)).is_true()
	var l := UpgradeReadout.lines(long_up, b, 1)
	assert_str(String(l[0]["label"])).is_equal("무는 횟수")
	assert_str(String(l[0]["from"])).is_equal(str(n))
	assert_str(String(l[0]["to"])).is_equal(str(n + 1))
	b.apply(long_up)
	assert_int(d.bites).is_equal(n + 1)
	assert_bool(UpgradeEffect.useful(b, long_up)).is_true()


func _critter(bites: int, life: float, foes: Array) -> SummonCritter:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = HERO
	add_child(p)
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.world = self
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return foes
	var c: SummonCritter = auto_free(SummonCritter.new())
	c.ctx = ctx
	c.owner_node = p
	c.bites = bites
	c.lifetime = life
	add_child(c)
	return c


func _alive() -> int:
	return get_tree().get_nodes_in_group(CritterSkill.GROUP).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


## 상한 스위치는 그대로 쓸 수 있다 (켜면 오래된 것부터 사라짐).
func test_max_alive_switch_still_works() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = HERO
	add_child(p)
	var caster: SkillCaster = auto_free(SkillCaster.new())
	caster.player = p
	caster.world = self
	caster.enemy_source = func() -> Array: return []
	add_child(caster)
	var d := (HERO.kit.tap as CritterSkill).duplicate() as CritterSkill
	d.count = 4
	d.extra_butterflies = 3
	d.max_alive = 2
	caster.kit = HERO.kit.duplicate() as SkillKit
	caster.kit.tap = d
	for i in 4:
		caster.cast(SkillCaster.Slot.TAP)
		await get_tree().process_frame
		assert_int(_alive()).is_less_equal(2)
	for n in get_tree().get_nodes_in_group(CritterSkill.GROUP):
		n.queue_free()
