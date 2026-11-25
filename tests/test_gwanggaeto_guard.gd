extends GdUnitTestSuite
## 광개토 = 맞으면서 밀고 들어가는 장수 (사용자 2026-11-25): 연타·4타를 휘두르는 동안 받는 피해 −30%, 맞아도 휘두르는 그림이
## 끊기지 않음, 체력 +15% (140 → 161). 값은 HeroData.swing_guard (SwingGuardData). 다른 영웅은 없음.

const GW := preload("res://data/heroes/gwanggaeto.tres")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


func _player(h: HeroData) -> Array:
	var p: Player = auto_free(Player.new())
	var hp := Health.new()
	hp.name = "Health"
	p.add_child(hp)
	p.hero = h
	add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = h.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	return [p, a]


func test_data() -> void:
	assert_int(GW.max_hp).is_equal(161)
	assert_float(GW.swing_guard.damage_taken_mult).is_equal_approx(0.7, 0.001)
	for id in ["yi_sun_sin", "sejong", "shin_saimdang"]:
		assert_object((load("res://data/heroes/%s.tres" % id) as HeroData).swing_guard).override_failure_message(id).is_null()


func test_less_damage_only_while_swinging() -> void:
	var pa := _player(GW)
	var p: Player = pa[0]
	var a: AutoAttack = pa[1]
	var full := p.health.current
	assert_bool(p.swing_guarded()).is_false()
	p.apply_hit(20)
	assert_int(full - p.health.current).is_equal(20)  # 서 있을 때는 그대로
	p._hurt_cd = 0.0
	p._hurt_total = 0.0
	a.busy_for(0.3)  # 4타 동작 중
	assert_bool(p.swing_guarded()).is_true()
	var before := p.health.current
	p.apply_hit(20)
	assert_int(before - p.health.current).is_equal(14)
	a.busy_for(0.0)
	a._since_strike = 0.05  # 칼이 막 닿은 뒤 (tail 안)
	assert_bool(p.swing_guarded()).is_true()
	a._since_strike = GW.swing_guard.tail + 0.1
	assert_bool(p.swing_guarded()).is_false()


func test_yi_has_no_guard() -> void:
	var pa := _player(load("res://data/heroes/yi_sun_sin.tres"))
	(pa[1] as AutoAttack).busy_for(0.3)
	assert_bool((pa[0] as Player).swing_guarded()).is_false()
