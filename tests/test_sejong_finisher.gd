extends GdUnitTestSuite
## 세종 넷째 탭 마무리(정음진)가 실제 탭 입력 경로(gesture_down/up → TapChain → cast)로도 겨눈 적에게 간다.
## 폰 의견 (시험판 d4b9868): "세종 4타가 아직 근거리임".

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SEJONG := preload("res://data/heroes/sejong.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0

var enemies: Array = []
var t := 0.0


func before_test() -> void:
	enemies = []
	t = 0.0


func after_test() -> void:
	for n in get_children():  # 고리·글자 탄은 auto_free가 아니다 (다음 시험에 남지 않게)
		if n is OrbitGlyphs or n is Projectile:
			n.free()
	EnemyAttack.active_windups = 0
	GameTime.reset()


func _rig() -> Array:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = SEJONG
	add_child(p)
	p.set_physics_process(false)
	p.global_position = Vector2.ZERO
	p.facing = Vector2.RIGHT
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = SEJONG.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	var c := SkillCaster.new()
	c.name = "SkillCaster"
	c.player = p
	c.kit = SEJONG.kit
	c.projectile_scene = PROJECTILE_SCENE
	c.world = self
	c.enemy_source = func() -> Array: return enemies
	p.add_child(c)
	c.set_physics_process(false)
	return [p, a, c]


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	e.health.max = 9999
	e.health.current = 9999
	enemies.append(e)
	return e


func _step(a: AutoAttack, c: SkillCaster, n: int = 1) -> void:
	for i in n:
		t += DT
		a.tick(DT, enemies)
		c.tick(DT, t)


## 손가락 탭 하나 (제자리 누름 → 뗌).
func _tap(a: AutoAttack, c: SkillCaster) -> void:
	c.gesture_down(0, Vector2(360, 900), t)
	_step(a, c, 3)
	c.gesture_up(0, t)


## 1·2·3타를 친 뒤 넷째 탭을 치고 마무리가 나갈 때까지 돌린다. 반환: 정음진 시전 수.
func _combo(a: AutoAttack, c: SkillCaster, before_finish: Callable = Callable()) -> int:
	var casts := [0]
	c.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void:
		if s == SkillCaster.Slot.TAP:
			casts[0] += 1)
	for i in SEJONG.kit.combo_hits:
		for k in 120:
			if a.can_manual(c.tap_gap()):
				break
			_step(a, c)
		_tap(a, c)
	assert_int(c.combo.streak).is_equal(SEJONG.kit.combo_hits)
	if before_finish.is_valid():
		before_finish.call()
	for k in 120:
		if casts[0] > 0:
			break
		_tap(a, c)
		_step(a, c, 6)
	return casts[0]


func _rings() -> Array[OrbitGlyphs]:
	var out: Array[OrbitGlyphs] = []
	for n in get_children():
		if n is OrbitGlyphs and not n.is_queued_for_deletion():
			out.append(n)
	return out


func test_fourth_tap_ring_lands_on_the_far_enemy() -> void:
	var r := _rig()
	var foe := _enemy_at(Vector2(460, 0))
	assert_int(_combo(r[1], r[2])).is_equal(1)
	var rings := _rings()
	assert_int(rings.size()).is_greater_equal(1)
	for o in rings:
		assert_object(o.follow).is_same(foe)
		assert_vector(o.global_position).is_equal_approx(foe.global_position, Vector2(0.5, 0.5))
		assert_float(o.global_position.length()).is_greater(300.0)  # 영웅 근처가 아니다


## 3타에 밀려나도 사거리 상한 안이면 고리가 그 적에게 씌워진다 (세종 사거리 600 + 밀림).
func test_pushed_enemy_still_gets_the_ring() -> void:
	var r := _rig()
	var foe := _enemy_at(Vector2(500, 0))
	assert_int(_combo(r[1], r[2], func() -> void: foe.global_position = Vector2(650, 0))).is_equal(1)
	assert_object(_rings()[0].follow).is_same(foe)


## 3타에 죽은 적 대신 남은 가장 가까운 적에게 간다.
func test_dead_target_moves_to_next_enemy() -> void:
	var r := _rig()
	var first := _enemy_at(Vector2(300, 0))
	var other := _enemy_at(Vector2(0, -450))
	assert_int(_combo(r[1], r[2], func() -> void: first.health.current = 0)).is_equal(1)
	assert_object(_rings()[0].follow).is_same(other)


## 적이 없으면 앞쪽 기본 거리(target_default, 400)에 선다.
func test_no_enemy_lands_forward_far() -> void:
	var r := _rig()
	var p: Player = r[0]
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.enemy_source = func() -> Array: return enemies
	assert_float(SEJONG.kit.target_default).is_greater_equal(400.0)
	assert_vector(SEJONG.kit.tap.cast_point(ctx)).is_equal_approx(Vector2.RIGHT * SEJONG.kit.target_default, Vector2(0.01, 0.01))


## 시전 연출(vfx_cast)도 영웅 몸이 아니라 겨눈 적 자리에서 터진다. 다른 영웅은 몸.
func test_cast_vfx_point_is_the_target() -> void:
	var r := _rig()
	var foe := _enemy_at(Vector2(420, 120))
	var ctx := SkillContext.new()
	ctx.player = r[0]
	ctx.enemy_source = func() -> Array: return enemies
	assert_vector(SEJONG.kit.tap.cast_point(ctx)).is_equal_approx(foe.global_position, Vector2(0.01, 0.01))
	assert_vector(SEJONG.kit.dash.cast_point(ctx)).is_equal_approx(Vector2.ZERO, Vector2(0.01, 0.01))


## 큰 강화(두 겹 고리)여도 가운데 적은 간격마다 한 번만 맞는다.
func test_two_rings_hit_the_core_once() -> void:
	var r := _rig()
	var foe := _enemy_at(Vector2(300, 0))
	var ctx := (r[2] as SkillCaster)._context()
	var skill := (SEJONG.kit.tap as JeongeumSkill).duplicate() as JeongeumSkill
	skill.outer_radius = 190.0
	skill.launch_px = 0.0
	ctx.skill = skill
	skill.cast(ctx, 0.0)
	var rings := _rings()
	assert_int(rings.size()).is_equal(2)
	var before := foe.health.current
	for o in rings:
		o._physics_process(DT)
	assert_int(rings[0].hits + rings[1].hits).is_equal(1)
	assert_int(before - foe.health.current).is_greater(0)
