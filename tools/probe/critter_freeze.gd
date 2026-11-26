extends SceneTree
## 사임당 풀벌레가 적 하나를 얼마나 멈춰 세우나: 다 갖춘 판(마릿수·횟수·턱 패)으로 4타 마무리 간격마다 계속 부르며
## 20초 동안 적이 멈춤(피해 멈춤 freeze) 또는 경직(잡몹)인 시간 비율, 가장 긴 연속 멈춤, 피해. 적은 죽지 않고 제자리.
## godot --headless --path . -s res://tools/probe/critter_freeze.gd
## 환경: HH_FLINCH=0|1|2 (CritterSkill.flinch), HH_BITES=n, HH_MAX_ALIVE=n, HH_QUICK=1 (빠른 붓 셋)
## 결과 줄: FREEZE <적> <빌드> gap <초> casts <n> stopped_pct <%> longest_stop_s <s> dmg <n>

const HERO := preload("res://data/heroes/shin_saimdang.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const DT := 1.0 / 60.0
const SPAN := 20.0
const HP := 9999999

var world: Node2D
var enemies: Array = []


func _initialize() -> void:
	_go()


func _go() -> void:
	await process_frame
	world = Node2D.new()
	root.add_child(world)
	var full := ["critter_more", "critter_more", "major_butterflies", "critter_long", "critter_long", "critter_dmg",
		"critter_dmg", "critter_dmg"]
	if OS.get_environment("HH_QUICK") == "1":
		full += ["critter_quick", "critter_quick", "critter_quick"]
	for foe in ["cc_frog", "jurchen_elite", "waegun_gunner"]:
		_run(foe, "base", [])
		_run(foe, "full", full)
	quit()


func _build(ids: Array) -> HeroData:
	var b := RunBuild.new()
	b.hero = HERO.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	for id in ids:
		for pool in [b.hero.upgrade_pool, b.hero.major_pool]:
			for u in pool.upgrades:
				if u.id == StringName(id):
					b.apply(u)
	var t := b.hero.kit.tap as CritterSkill
	if OS.get_environment("HH_FLINCH") != "":
		t.flinch = int(OS.get_environment("HH_FLINCH"))
	if OS.get_environment("HH_BITES") != "":
		t.bites = int(OS.get_environment("HH_BITES"))
	if OS.get_environment("HH_MAX_ALIVE") != "":
		t.max_alive = int(OS.get_environment("HH_MAX_ALIVE"))
	return b.hero


func _run(foe: String, label: String, ids: Array) -> void:
	var hero := _build(ids)
	var kit := hero.kit
	var player := Player.new()
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = hero
	world.add_child(player)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = load("res://data/enemies/%s.tres" % foe)
	world.add_child(e)
	e.set_physics_process(false)
	e.health.max = HP
	e.health.current = HP
	e.global_position = Vector2(160, 0)
	enemies = [e]
	var ctx := SkillContext.new()
	ctx.player = player
	ctx.world = world
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies
	var gap := (kit.tap as SkillDef).cooldown * kit.combo_finisher_cd_ratio
	var t := 0.0
	var next_cast := 0.0
	var casts := 0
	var stopped := 0
	var run_len := 0
	var longest := 0
	var n_alive := 0
	while t < SPAN:
		if t >= next_cast:
			var d := TapCombo.scaled_def(kit.tap, kit.combo_finisher_mult) as CritterSkill
			ctx.skill = d
			d.cast(ctx, 0.0)
			casts += 1
			next_cast += gap
		for c in world.get_children():
			if c is SummonCritter and not c.is_queued_for_deletion():
				(c as SummonCritter)._physics_process(DT)
		var stop := e._freeze_left > 0.0 or (e.reaction != null and e.reaction.is_staggered())
		e._freeze_left = maxf(e._freeze_left - DT, 0.0)
		if e.reaction:
			e.reaction.tick(DT)
		if stop:
			stopped += 1
			run_len += 1
			longest = maxi(longest, run_len)
		else:
			run_len = 0
		t += DT
	var cs := world.get_children().filter(func(c: Node) -> bool: return c is SummonCritter).size()
	print("FREEZE %-13s %-4s gap %.1fs casts %d stopped_pct %.0f longest_stop_s %.2f dmg %d" % [foe, label, gap, casts,
		100.0 * stopped / (SPAN / DT), longest * DT, HP - e.health.current])
	for c in world.get_children():
		c.free()
	enemies = []
