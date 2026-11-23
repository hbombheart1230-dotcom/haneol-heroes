extends GdUnitTestSuite
## 마무리(넷째 탭 기술) 동작이 끝나기 전엔 다음 1타가 끼어들지 않는다 (사용자 판 피드백, 네 영웅 공통):
## 손·자동 평타 모두 막고, 그 사이 탭은 한 번만 기억했다가 풀리면 1타로. 대시는 언제든 끊는다.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang", "sejong"]
const DT := 1.0 / 60.0

var _t: float = 0.0


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()
	for n in get_children():
		if n is Projectile or n is OrbitGlyphs or n is DamageZone:
			remove_child(n)
			n.free()


func _rig(hero: HeroData) -> Array:
	_t = 0.0
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = hero.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	var c := SkillCaster.new()
	c.name = "SkillCaster"
	c.player = p
	c.kit = hero.kit
	c.projectile_scene = PROJECTILE_SCENE
	c.world = self
	c.hit_stop_enabled = false
	var enemies: Array = []
	c.enemy_source = func() -> Array: return enemies
	p.add_child(c)
	c.set_physics_process(false)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(80, 0)
	e.health.max = 99999
	e.health.current = 99999
	e.attack = null
	enemies.append(e)
	return [p, a, c, enemies]


func _step(r: Array, seconds: float) -> void:
	for i in ceili(seconds / DT):
		_t += DT
		(r[1] as AutoAttack).tick(DT, r[3])
		(r[2] as SkillCaster).tick(DT, _t)


## 세 타를 이은 뒤 넷째 탭 마무리가 나가는 순간까지.
func _to_finisher(r: Array) -> void:
	var a: AutoAttack = r[1]
	var c: SkillCaster = r[2]
	var cast := [false]
	c.skill_cast.connect(func(s: SkillCaster.Slot, _n: int) -> void: cast[0] = cast[0] or s == SkillCaster.Slot.TAP)
	c.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: cast[0] = cast[0] or s == SkillCaster.Slot.TAP)
	for i in 4:
		var guard := 0
		while not a.can_manual(c.tap_gap()) and guard < 240 and not cast[0]:
			_step(r, DT)
			guard += 1
		c.combo_tap()
	var w := 0
	while not cast[0] and w < 60:  # 마무리는 3타가 닿은 뒤 나간다 (finisher_after_strike)
		_step(r, DT)
		w += 1


func test_every_hero_finisher_has_a_recover_time() -> void:
	for id: String in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		var r := _rig(h)
		var t := TapChain.recover(r[2])
		assert_float(t).override_failure_message("%s finisher recover %.3f" % [id, t]).is_greater(0.1)
		assert_float(t).is_equal_approx(CastAnim.of(h.kit.tap, h.sprite_sheet).seconds, 0.001)


## 마무리 동안: 손 탭도 자동 평타도 1타를 내지 않고 탭은 한 번만 기억, 풀리면 기억한 탭이 다음 연타의 1타로.
func test_no_first_hit_during_finisher_then_one_buffered_tap() -> void:
	for id: String in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		var r := _rig(h)
		var a: AutoAttack = r[1]
		var c: SkillCaster = r[2]
		_to_finisher(r)
		var busy := a.busy_left()
		assert_float(busy).override_failure_message("%s busy %.3f" % [id, busy]).is_greater(0.1)
		var early := [0]
		a.melee_windup.connect(func(_d: Vector2) -> void: early[0] += int(a.busy_left() > 0.0))
		a.ranged_windup.connect(func(_d: Vector2) -> void: early[0] += int(a.busy_left() > 0.0))
		for i in 4:  # 마무리 중에 연타
			c.combo_tap()
			_step(r, DT * 2.0)
		assert_int(early[0]).override_failure_message("%s: hit during finisher" % id).is_equal(0)
		assert_bool(c.combo.has_buffer()).override_failure_message("%s: tap not kept" % id).is_true()
		assert_int(c.combo.streak).is_equal(0)
		_step(r, a.busy_left() + 0.3)
		assert_int(early[0]).is_equal(0)
		assert_int(c.combo.streak).override_failure_message("%s: buffered tap" % id).is_equal(1)  # 기억한 탭 한 번 = 1타
		assert_bool(c.combo.has_buffer()).is_false()


func test_dash_cancels_finisher_lock() -> void:
	var r := _rig(load("res://data/heroes/yi_sun_sin.tres"))
	var a: AutoAttack = r[1]
	_to_finisher(r)
	assert_float(a.busy_left()).is_greater(0.0)
	ComboSteps.cancel_swing(a)  # 대시 시작 (Player.dash_started)
	assert_float(a.busy_left()).is_equal(0.0)


func test_recover_override_from_data() -> void:
	var h: HeroData = load("res://data/heroes/gwanggaeto.tres").duplicate()
	h.kit = h.kit.duplicate()
	h.kit.finisher_recover = 0.2
	var r := _rig(h)
	assert_float(TapChain.recover(r[2])).is_equal(0.2)
