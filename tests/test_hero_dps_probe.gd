extends GdUnitTestSuite
## 영웅 화력 재기 (보고용, 결정적): 영웅을 무적으로 두고 30초 동안 탭 연타 + 자동 공격만으로
##  - 한 놈: 움직이지 않는 큰 허수아비 하나에 준 초당 피해 (보스전 화력)
##  - 떼: 같은 왜군 졸병 여섯이 계속 다시 나올 때 초당 처치 (잡몹 구간 화력)
## 결과는 로그([hero-dps])에 남긴다. 보스 체력 배율(HeroData.boss_hp_mult)의 근거.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const SOLDIER_PATH := "res://data/enemies/waegun_soldier.tres"
const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const DT := 1.0 / 60.0
const TIME := 30.0
const TAP_GAP := 0.2
## 떼가 다시 나오는 자리 반지름(px) (원거리 세종도 근접 영웅도 닿는 거리).
const RING := 160.0

var _t := 0.0


func after_test() -> void:
	BossSim.reset_globals()


func _hero(id: String) -> HeroData:
	return ResourceLoader.load("res://data/heroes/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData


func _enemy(d: EnemyData, p: Player, at: Vector2, n: int) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = d
	e.target = p
	e.ai_seed = n
	add_child(e)
	e.set_physics_process(false)
	e.global_position = at
	return e


## [허수아비 초당 피해, 떼 초당 처치]
func _measure(hero: HeroData) -> Array:
	BossSim.reset_globals()
	await get_tree().physics_frame
	seed(5)
	_t = 0.0
	EnemyAttack.clock = func() -> float: return _t
	DashStyleRunner.clock = func() -> float: return _t
	var kept := {}
	for c in get_children():
		kept[c] = true
	var p := Player.new()
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	p.grant_invulnerability(1000.0)
	var atk := AutoAttack.new()
	atk.name = "AutoAttack"
	atk.player = p
	atk.data = hero.attack
	atk.projectile_scene = PROJECTILE_SCENE
	atk.projectile_parent = self
	p.add_child(atk)
	atk.set_physics_process(false)
	var list: Array = []
	var caster := SkillCaster.new()
	caster.player = p
	caster.kit = hero.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return list
	add_child(caster)
	caster.set_physics_process(false)
	var soldier := ResourceLoader.load(SOLDIER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	var dummy := soldier.duplicate() as EnemyData
	dummy.max_hp = 1000000
	dummy.move_speed = 0.0
	dummy.attack = null
	dummy.knockback_scale = 0.0
	# 한 놈
	var d := _enemy(dummy, p, Vector2(0, -90), 1)
	list = [d]
	_loop(p, atk, caster, list, func() -> void: pass)
	var dps := float(d.health.max - d.health.current) / TIME
	d.free()
	# 떼
	var n := [1]
	var kills := [0]
	list = []
	for i in 6:
		list.append(_enemy(soldier, p, Vector2.from_angle(TAU * i / 6.0) * RING, n[0] + i))
	n[0] += 6
	var refill := func() -> void:
		for i in list.size():
			var e: Enemy = list[i]
			if not is_instance_valid(e) or e.health.is_dead():
				kills[0] += 1
				if is_instance_valid(e):
					e.free()
				n[0] += 1
				list[i] = _enemy(soldier, p, p.global_position + Vector2.from_angle(TAU * n[0] / 6.37) * RING, n[0])
	_t = 0.0
	_loop(p, atk, caster, list, refill)
	var kps: float = kills[0] / TIME
	for c in get_children():
		if not kept.has(c):
			c.free()
	BossSim.reset_globals()
	return [dps, kps]


func _loop(p: Player, atk: AutoAttack, caster: SkillCaster, list: Array, refill: Callable) -> void:
	var t0 := _t
	var tap_t := 0.0
	while _t - t0 < TIME:
		_t += DT
		Engine.time_scale = 1.0
		p._physics_process(DT)
		caster.tick(DT, _t)
		tap_t -= DT
		if tap_t <= 0.0:
			tap_t = TAP_GAP
			caster.combo_tap()
		atk.tick(DT, list)
		for c in get_children():
			if c is Projectile and not c.is_queued_for_deletion():
				var pr := c as Projectile
				pr._physics_process(DT)
				if pr.is_queued_for_deletion() or pr.ignore_collisions:
					continue
				for e in list:
					if is_instance_valid(e) and not e.health.is_dead() and not pr.has_meta(&"hit_%d" % e.get_instance_id()) \
							and pr.hit_reach(e.global_position) <= BossSim.HURT_R:
						pr.set_meta(&"hit_%d" % e.get_instance_id(), true)
						pr._on_area_entered(e.get_node("HurtBox2D"))
						if pr.ignore_collisions:
							break
		for e in list:
			if is_instance_valid(e) and not e.health.is_dead():
				e._physics_process(DT)
		refill.call()


func test_hero_firepower_report() -> void:
	var out := {}
	for id in HEROES:
		var r: Array = await _measure(_hero(id))
		out[id] = r
		print("[hero-dps] %s: single %.1f dmg/s, pack %.2f kills/s" % [id, r[0], r[1]])
	var yi: Array = out["yi_sun_sin"]
	for id in HEROES:
		var r: Array = out[id]
		print("[hero-dps] %s vs 순신: single x%.2f, pack x%.2f" % [id, r[0] / maxf(yi[0], 0.01), r[1] / maxf(yi[1], 0.01)])
	assert_int(out.size()).is_equal(HEROES.size())


## 성장한 영웅 화력 (보고용, HH_GROWN=1일 때만): 자기 무대를 성장과 함께 돌아 대장이 나오는 순간의 사본(GrownHeroes)으로
## 같은 30초 재기. 씨앗 셋의 평균과 순신 대비 배율.
func test_grown_firepower_report() -> void:
	if OS.get_environment("HH_GROWN") != "1":
		assert_bool(true).is_true()
		return
	var out := {}
	for id in HEROES:
		var sum := [0.0, 0.0]
		for s in [11, 23, 37]:
			var g: Array = await GrownHeroes.take(self, id, s, GrownHeroes.At.BOSS)
			var r: Array = await _measure(g[0])
			print("[hero-dps-grown] %s seed %d level %d: single %.1f dmg/s, pack %.2f kills/s" % [id, s, g[1], r[0], r[1]])
			sum[0] += r[0] / 3.0
			sum[1] += r[1] / 3.0
		out[id] = sum
	var yi: Array = out["yi_sun_sin"]
	for id in HEROES:
		var r: Array = out[id]
		print("[hero-dps-grown] %s mean: single %.1f (x%.2f), pack %.2f (x%.2f)" % [id, r[0], r[0] / maxf(yi[0], 0.01), r[1], r[1] / maxf(yi[1], 0.01)])
	assert_int(out.size()).is_equal(HEROES.size())
