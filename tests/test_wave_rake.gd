extends GdUnitTestSuite
## 해일검기 긁기 (WaveRake): 총 피해·넉백은 그대로 나눠 여러 번, 타수는 충전에 따라, 멈춤은 끝날 때 한 번.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0

var enemies: Array = []


func before_test() -> void:
	enemies = []
	FxLayer.stack_key = 0


func after_test() -> void:
	for n in get_children():
		if n is Projectile or n is WaveRake:
			n.free()
	GameTime.reset()


func _ctx() -> SkillContext:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.hero = YI
	p.set_physics_process(false)
	var ctx := SkillContext.new()
	ctx.player = p
	ctx.world = self
	ctx.skill = YI.kit.charge
	ctx.projectile_scene = PROJECTILE_SCENE
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies
	return ctx


func _enemy(pos: Vector2, hp: int = 9999) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	e.health.max = hp
	e.health.current = hp
	enemies.append(e)
	return e


func test_plan_keeps_totals_and_last_is_biggest() -> void:
	for c in [[14, 3], [66, 8], [32, 5], [5, 8]]:
		var pl := WaveRake.plan(c[0], c[1], 2.0, 280.0, 0.35)
		var dmg: PackedInt32Array = pl[0]
		var push: PackedFloat32Array = pl[1]
		assert_int(dmg.size()).is_equal(c[1])
		var sd := 0
		for v in dmg:
			sd += v
		var sp := 0.0
		for v in push:
			sp += v
		assert_int(sd).is_equal(c[0])
		assert_float(sp).is_equal_approx(280.0, 0.01)
		assert_int(dmg[dmg.size() - 1]).is_greater_equal(dmg[0])
		assert_float(push[push.size() - 1]).is_greater(push[0])


func test_hit_count_grows_with_charge() -> void:
	var s := YI.kit.charge as HaeilSkill
	assert_int(s.rake_count(0.0)).is_equal(s.rake_hits.x)
	assert_int(s.rake_count(1.0)).is_equal(s.rake_hits.y)
	assert_int(s.rake_count(0.6)).is_between(s.rake_hits.x, s.rake_hits.y)


## 물결이 닿은 적마다 계획한 타수만큼, 합이 총 피해와 같게 들어간다 (물결이 지나간 뒤에도 남은 타는 이어진다).
func test_each_caught_enemy_gets_every_hit() -> void:
	var ctx := _ctx()
	var s := YI.kit.charge as HaeilSkill
	var foes := [_enemy(Vector2(0, -100)), _enemy(Vector2(0, -160)), _enemy(Vector2(0, -220))]
	var p := s._wave(ctx, Vector2.UP, 1.0)
	var total := s.charge_scaling.damage_at(s.min_damage, s.max_damage, 1.0)
	var r: WaveRake = null
	s._rake(ctx, p, 1.0)
	for n in get_children():
		if n is WaveRake:
			r = n
	assert_object(r).is_not_null()
	for f in foes:  # 앞머리가 닿은 것처럼 (HitBox 첫 타)
		(f as Enemy).health.damage(r.damages[0])
		r.on_caught((f as Enemy).get_node("HurtBox2D") as HurtBox2D)
	p.free()
	for i in 90:
		r._physics_process(DT)
	for f in foes:
		assert_int(9999 - (f as Enemy).health.current).is_equal(total)
	assert_int(r.total_hits).is_equal(3 * s.rake_count(1.0))


## 상한을 넘는 적은 남은 피해를 한 번에 받는다 (피해 총량은 같다).
func test_cap_applies_rest_at_once() -> void:
	var ctx := _ctx()
	var r := WaveRake.new()
	r.ctx = ctx
	var pl := WaveRake.plan(40, 5, 2.0, 100.0, 0.35)
	r.damages = pl[0]
	r.pushes = pl[1]
	r.max_targets = 1
	add_child(r)
	var a := _enemy(Vector2(0, -100))
	var b := _enemy(Vector2(0, -150))
	for e in [a, b]:
		e.health.damage(r.damages[0])
		r.on_caught(e.get_node("HurtBox2D") as HurtBox2D)
	assert_int(9999 - b.health.current).is_equal(40)  # 상한 밖: 바로 다
	r.wave_alive = false
	for i in 60:
		r._physics_process(DT)
	assert_int(9999 - a.health.current).is_equal(40)


## 쌓이는 숫자: 같은 열쇠는 한 숫자에 더한다.
func test_numbers_stack_on_one_label() -> void:
	var l: FxLayer = auto_free(FxLayer.new())
	l.add_number(Vector2.ZERO, 5)
	l._fx[0]["key"] = 77
	FxLayer.stack_key = 77
	l.add_number(Vector2.ZERO, 7)
	l.add_number(Vector2.ZERO, 3)
	FxLayer.stack_key = 0
	assert_int(l.number_count()).is_equal(1)
	assert_str(String(l._fx[0]["text"])).is_equal("15")
	assert_int(int(l._fx[0]["hits"])).is_equal(3)
