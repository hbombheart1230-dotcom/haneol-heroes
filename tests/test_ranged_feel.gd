extends GdUnitTestSuite
## 원거리 평타 한 발의 타격감 (RangedFeel, RangedFeelData, RangedFxLayer).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


var _heroes: PackedStringArray


func before_test() -> void:
	_heroes = RangedFeelData.get_default().heroes
	RangedFeelData.get_default().heroes = PackedStringArray()  # 영웅 없는 시험용 플레이어도 연출을 받게


func after_test() -> void:
	RangedFeelData.get_default().heroes = _heroes


func _player_at(pos: Vector2) -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.global_position = pos
	return p


func _attack(player: Player) -> AutoAttack:
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = player
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	add_child(a)
	return a


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.global_position = pos
	e.set_physics_process(false)
	return e


func _fire_one() -> Projectile:
	var a := _attack(_player_at(Vector2.ZERO))
	var shots: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: shots.append(pr))
	a.tick(0.016, [_enemy_at(Vector2(0, -300))])
	assert_int(shots.size()).is_equal(1)
	return shots[0]


func test_data_defaults() -> void:
	var d := RangedFeelData.new()
	assert_bool(d.is_heavy(3)).is_true()
	assert_bool(d.is_heavy(2)).is_false()
	assert_float(d.knock_extra(3)).is_greater(d.knock_extra(1))
	assert_float(d.knock_extra(1) / 8.0).is_between(5.0, 15.0)  # 감쇠 8: 기존 원거리 밀림에 더해 15~20px
	assert_object(RangedFeelData.get_default()).is_not_null()


func test_fired_shot_is_faster_with_same_reach_and_glows() -> void:
	var stats := BasicAttackData.new()
	var pr := _fire_one()
	var d := RangedFeelData.get_default()
	assert_float(pr.speed).is_equal_approx(stats.ranged_speed * d.speed_mult, 0.01)
	assert_float(pr.speed * pr.lifetime).is_equal_approx(stats.ranged_speed * stats.ranged_lifetime, 0.5)  # 사거리 그대로
	assert_object(pr.get_node_or_null("RangedGlow")).is_not_null()
	assert_int(int(pr.get_meta(&"ranged_step", 0))).is_equal(1)
	assert_int(pr.damage).is_equal(stats.ranged_damage)  # 피해 그대로
	pr.queue_free()


func test_hit_pushes_along_shot_and_bursts() -> void:
	var pr := _fire_one()
	var e := _enemy_at(Vector2(200, 0))
	var hb := e.get_node("HurtBox2D") as HurtBox2D
	pr.direction = Vector2.RIGHT
	pr.hits = 1
	var before := e.knockback
	RangedFeel.on_hit(pr, hb, 1, Color.WHITE)
	assert_float(e.knockback.x - before.x).is_greater(0.0)
	assert_bool(pr.get_meta(&"ranged_burst", false)).is_true()
	assert_bool(RangedFeel.should_fizzle(pr)).is_false()  # 맞아서 부서졌으면 풀리지 않음
	pr.queue_free()


func test_third_shot_is_heavy() -> void:
	var pr := _fire_one()
	var e := _enemy_at(Vector2(200, 0))
	pr.hits = 1
	RangedFeel.on_hit(pr, e.get_node("HurtBox2D") as HurtBox2D, 3, Color.WHITE)
	assert_bool(e.is_frozen()).is_true()  # 근접 3타처럼 멈춤
	var pr2 := _fire_one()
	var e2 := _enemy_at(Vector2(-200, 0))
	pr2.hits = 1
	RangedFeel.on_hit(pr2, e2.get_node("HurtBox2D") as HurtBox2D, 1, Color.WHITE)
	assert_bool(e2.is_frozen()).is_false()
	pr.queue_free()
	pr2.queue_free()


func test_pierce_hit_does_not_burst() -> void:
	var pr := _fire_one()
	pr.pierce = true
	pr.hits = 1
	RangedFeel.on_hit(pr, _enemy_at(Vector2(200, 0)).get_node("HurtBox2D") as HurtBox2D, 1, Color.WHITE)
	assert_bool(pr.get_meta(&"ranged_burst", false)).is_false()
	pr.queue_free()


func test_fizzle_only_when_lifetime_ran_out() -> void:
	var pr := _fire_one()
	assert_bool(RangedFeel.should_fizzle(pr)).is_false()  # 날아가는 중 (장면이 바뀌어 지워지는 탄은 그리지 않음)
	pr._age = pr.lifetime
	assert_bool(RangedFeel.should_fizzle(pr)).is_true()
	pr.queue_free()


func test_layer_pool_is_capped_and_clears() -> void:
	var d := RangedFeelData.new()
	d.max_active = 4
	var l: RangedFxLayer = auto_free(RangedFxLayer.new(d))
	for i in 10:
		l.muzzle(Vector2.ZERO, Vector2.RIGHT, 1, Color.WHITE)
	l.burst(Vector2.ZERO, Vector2.RIGHT, 3, Color.WHITE, PlaceholderTexture2D.new(), Vector2(80, 30), "")
	l.fizzle(Vector2.ZERO, Vector2.RIGHT, Color.WHITE, null, Vector2(40, 40), "ㄱ")
	assert_int(l.active_count()).is_equal(4)
	assert_int(l.capacity()).is_equal(4)
	l.step(1.0)
	assert_int(l.active_count()).is_equal(0)


func test_attach_once() -> void:
	var a := _attack(_player_at(Vector2.ZERO))
	var n := a.projectile_fired.get_connections().size()
	RangedFeel.attach(a)
	assert_int(a.projectile_fired.get_connections().size()).is_equal(n)


func test_only_sejong_by_default() -> void:
	var d := RangedFeelData.new()
	assert_bool(d.applies_to(&"sejong")).is_true()
	assert_bool(d.applies_to(&"yi_sun_sin")).is_false()
	assert_bool(d.applies_to(&"gwanggaeto")).is_false()
	d.heroes = PackedStringArray()
	assert_bool(d.applies_to(&"yi_sun_sin")).is_true()


func test_other_heroes_shots_untouched() -> void:
	RangedFeelData.get_default().heroes = PackedStringArray(["sejong"])
	var stats := BasicAttackData.new()
	var pr := _fire_one()  # 영웅 없는 플레이어 = 목록 밖
	assert_float(pr.speed).is_equal(stats.ranged_speed)
	assert_object(pr.get_node_or_null("RangedGlow")).is_null()
	pr.queue_free()


func test_strike_works_without_a_projectile() -> void:
	var e := _enemy_at(Vector2(200, 0))
	var before := e.knockback
	RangedFeel.strike(e, Vector2.RIGHT, 1, Color.WHITE, true)  # 사임당 먹 털기 같은 탄 없는 닿음
	assert_float(e.knockback.x - before.x).is_greater(0.0)
