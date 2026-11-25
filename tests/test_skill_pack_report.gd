extends GdUnitTestSuite
## 기술 하나 무리 보고 (보고용, 결정적): 앞쪽 무리(왜군 졸병 24, 씨앗 셋)에 영웅 기술 하나를 한 번 쏴 맞은 적 수와 준 피해를
## 로그([skill-pack])에 남긴다. HH_HERO(기본 yi_sun_sin)·HH_SLOT(tap|dash|charge|counter, 기본 dash)·HH_LEVEL(강화 단계, 기본 0).
## 무리는 영웅 앞 HH_FIELD_X px(기본 900)까지 ±300px에 고르게 흩어 둔다. 2번(dash)은 내닫아 치기 배율(dash_auto_damage_mult)로 쏜다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const SOLDIER := "res://data/enemies/waegun_soldier.tres"
const DT := 1.0 / 60.0


func after_test() -> void:
	BossSim.reset_globals()


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.has_environment(k) else d


func _cast(hero: HeroData, slot: SkillCaster.Slot, level: int, s: int) -> Array:
	BossSim.reset_globals()
	seed(s)
	var kept := {}
	for n in get_children():
		kept[n] = true
	var p := Player.new()
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	p.facing = Vector2.RIGHT
	var list: Array = []
	var d := (ResourceLoader.load(SOLDIER, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData).duplicate() as EnemyData
	d.max_hp = 100000
	var far := float(_env("HH_FIELD_X", "900"))
	for i in 24:
		var e: Enemy = ENEMY_SCENE.instantiate()
		e.data = d
		e.target = p
		add_child(e)
		e.set_physics_process(false)
		e.global_position = Vector2(randf_range(60.0, far), randf_range(-300.0, 300.0))
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
	caster.def_of(slot).vfx_level = level
	var mult := hero.kit.dash_auto_damage_mult if slot == SkillCaster.Slot.DASH and hero.kit.dash_auto else 1.0
	caster.cast(slot, 1.0, mult)
	for i in int(_env("HH_FRAMES", "150")):
		caster.tick(DT, i * DT)
		for n in get_children():
			if n is WaveRake:
				(n as WaveRake)._physics_process(DT)
			elif (n is SummonCritter or n is OrbitGlyphs or n is DamageZone) and not n.is_queued_for_deletion():
				n.set_physics_process(false)  # 내 편 소환물·장판도 굴린다
				n._physics_process(DT)
			elif n is Projectile and not n.is_queued_for_deletion():
				var pr := n as Projectile
				pr._physics_process(DT)
				for e in list:
					if not pr.is_queued_for_deletion() and not pr.has_meta(&"hit_%d" % e.get_instance_id()) \
							and pr.global_position.distance_to(e.global_position) <= BossSim.HURT_R + 12.0 * pr.size_scale:
						pr.set_meta(&"hit_%d" % e.get_instance_id(), true)
						pr._on_area_entered(e.get_node("HurtBox2D"))
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


func test_skill_on_a_pack() -> void:
	var id := _env("HH_HERO", "yi_sun_sin")
	var slot_name := _env("HH_SLOT", "dash")
	var level := int(_env("HH_LEVEL", "0"))
	var slot: SkillCaster.Slot = {"tap": SkillCaster.Slot.TAP, "dash": SkillCaster.Slot.DASH,
		"charge": SkillCaster.Slot.CHARGE, "counter": SkillCaster.Slot.COUNTER}[slot_name]
	var hero := ResourceLoader.load("res://data/heroes/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as HeroData
	var hits := 0.0
	var dmg := 0.0
	for s in [5, 17, 29]:
		var r: Array = await _cast(hero, slot, level, s)
		hits += r[0] / 3.0
		dmg += r[1] / 3.0
	print("[skill-pack] %s %s lv%d: %.1f of 24 hit, %.0f damage" % [id, slot_name, level, hits, dmg])
	assert_bool(true).is_true()
