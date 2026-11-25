extends GdUnitTestSuite
## 세종 성좌진(모으기) 크기 보고 (사용자 "세종 모으기 좀 키워 줘"): 앞쪽 무리(왜군 졸병 24, 씨앗 셋)에 바로 놓음·반·다 모음으로 한 번 쏴
## 맞은 적 수와 준 피해를 로그([sejong-charge])에 남긴다. 판정이 커진 만큼 세지는 정도를 재는 용도 (우두머리 쪽은
## HH_USE_CHARGE=1 test_boss_balance_sim 세종 줄).

const HERO := "res://data/heroes/sejong.tres"
const SOLDIER := "res://data/enemies/waegun_soldier.tres"
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const DT := 1.0 / 60.0


func after_test() -> void:
	BossSim.reset_globals()


func _cast(c: float, s: int) -> Array:
	BossSim.reset_globals()
	seed(s)
	var kept := {}
	for n in get_children():
		kept[n] = true
	var hero := ResourceLoader.load(HERO, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData
	var p := Player.new()
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	p.facing = Vector2.RIGHT
	var list: Array = []
	var d := ResourceLoader.load(SOLDIER, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData
	d = d.duplicate() as EnemyData
	d.max_hp = 100000
	for i in 24:
		var e: Enemy = ENEMY_SCENE.instantiate()
		e.data = d
		e.target = p
		add_child(e)
		e.set_physics_process(false)
		e.global_position = Vector2(randf_range(60.0, 620.0), randf_range(-300.0, 300.0))
		list.append(e)
	var caster := SkillCaster.new()
	caster.player = p
	caster.kit = hero.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return list
	add_child(caster)
	caster.set_physics_process(false)
	caster.cast(SkillCaster.Slot.CHARGE, c)
	for i in 120:
		caster.tick(DT, i * DT)
		for n in get_children():
			if n is WaveRake:
				(n as WaveRake)._physics_process(DT)
	var hit := 0
	var dmg := 0
	for e in list:
		var lost: int = e.health.max - e.health.current
		hit += 1 if lost > 0 else 0
		dmg += lost
	for n in get_children():
		if not kept.has(n):
			n.queue_free()
	await get_tree().process_frame
	return [hit, dmg]


func test_charge_hits_on_a_pack() -> void:
	for c in [0.0, 0.5, 1.0]:
		var hits := 0.0
		var dmg := 0.0
		for s in [5, 17, 29]:
			var r: Array = await _cast(c, s)
			hits += r[0] / 3.0
			dmg += r[1] / 3.0
		print("[sejong-charge] charge %.1f: %.1f of 24 hit, %.0f damage" % [c, hits, dmg])
	assert_bool(true).is_true()
