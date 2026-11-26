extends SceneTree
## 사임당 1번 풀벌레가 한 번 부를 때 실제로 무는 횟수·총 피해 (적 수 1·5·15, 강화별). 적은 죽지 않는 허수아비.
## 실제 발동처럼 4타 마무리 배율(TapCombo.scaled_def)을 건 사본으로 부르고, 프레임을 손으로 굴린다 (1/60초).
## godot --headless --path . -s res://tools/probe/critter_bites.gd
## 결과 줄: CRITTER <강화> foes <n> critters <n> bites <합> per_critter avg <..> max <..> damage <합> life_s <마지막이 사라진 초>

const HERO := preload("res://data/heroes/shin_saimdang.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const HEAVY := preload("res://data/enemies/heavy.tres")
const DT := 1.0 / 60.0

var world: Node2D
var enemies: Array = []


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	world = Node2D.new()
	root.add_child(world)
	var builds := [["base", []], ["long2", ["critter_long", "critter_long"]], ["more2", ["critter_more", "critter_more"]],
		["quick3", ["critter_quick", "critter_quick", "critter_quick"]], ["jaw3", ["critter_dmg", "critter_dmg", "critter_dmg"]],
		["butterflies", ["major_butterflies"]],
		["all", ["critter_long", "critter_long", "critter_more", "critter_more", "critter_quick", "major_butterflies"]]]
	for b in builds:
		for n in [1, 5, 15]:
			_run(b[0], b[1], n)
	quit()


func _build(ids: Array) -> RunBuild:
	var b := RunBuild.new()
	b.hero = HERO.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	for id in ids:
		for pool in [b.hero.upgrade_pool, b.hero.major_pool]:
			if pool == null:
				continue
			for u in pool.upgrades:
				if u.id == StringName(id):
					b.apply(u)
	return b


func _run(label: String, ids: Array, n: int) -> void:
	var b := _build(ids)
	var kit := b.hero.kit
	var player := Player.new()
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = b.hero
	world.add_child(player)
	enemies = []
	for i in n:
		var e: Enemy = ENEMY_SCENE.instantiate()
		e.data = HEAVY
		world.add_child(e)
		e.set_physics_process(false)
		e.health.max = 999999
		e.health.current = 999999
		e.global_position = Vector2.from_angle(TAU * i / n) * (150.0 + 30.0 * (i % 5))
		enemies.append(e)
	var ctx := SkillContext.new()
	ctx.player = player
	ctx.world = world
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies
	var d := TapCombo.scaled_def(kit.tap, kit.combo_finisher_mult) as CritterSkill
	ctx.skill = d
	d.cast(ctx, 0.0)
	var cs: Array = world.get_children().filter(func(c: Node) -> bool: return c is SummonCritter)
	var t := 0.0
	var gone_at := 0.0
	while t < 20.0:
		t += DT
		var live := 0
		for c in cs:
			var sc := c as SummonCritter
			if is_instance_valid(sc) and not sc.is_queued_for_deletion():
				sc._physics_process(DT)
				live += 1
		if live == 0:
			gone_at = t
			break
	var bites := 0
	var mx := 0
	for c in cs:
		bites += (c as SummonCritter).hits
		mx = maxi(mx, (c as SummonCritter).hits)
	var dmg := 0
	for e in enemies:
		dmg += 999999 - (e as Enemy).health.current
	print("CRITTER %-11s foes %2d critters %d bites %3d per_critter avg %.1f max %d damage %4d life_s %.2f" % [
		label, n, cs.size(), bites, float(bites) / maxf(cs.size(), 1), mx, dmg, gone_at])
	for c in cs:
		c.free()
	for e in enemies:
		e.free()
	player.free()
