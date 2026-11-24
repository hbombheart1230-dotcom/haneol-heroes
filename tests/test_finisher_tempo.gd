extends GdUnitTestSuite
## 3타 → 4타(마무리) → 다음 1타 박자 (사용자 2026-11-24: "4타가 연계 타이밍이 어색하고 쾌검의 느낌이 부족해, 광개토·사임당이 훨씬 좋아"):
## 고정 틱으로 0.05초마다 탭, 깨끗한 한 바퀴(1·2·3타·마무리·다음 1타)만 잰다. 멈춤(역경직·기술 멈춤)은 빼고 본 박자.
## 목표: 순신 한 바퀴가 광개토·사임당과 같거나 더 빠르고, 마무리 뒤 다음 1타까지가 사임당보다 길지 않다.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang", "sejong"]
const DT := 1.0 / 60.0

var _t: float = 0.0


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()
	GameTime.clock = Callable()
	for n in get_children():
		if n is Projectile or n is OrbitGlyphs or n is DamageZone:
			remove_child(n)
			n.free()


## 반환: 깨끗한 한 바퀴들의 [1→2, 2→3, 3타 닿음→마무리, 마무리→다음 1타, 한 바퀴] 중앙값.
static func measure(suite: Node, id: String, seconds: float = 24.0) -> Dictionary:
	var hero: HeroData = load("res://data/heroes/%s.tres" % id)
	var t := [0.0]
	GameTime.clock = func() -> int: return int(t[0] * 1000.0)
	var p: Player = Player.new()
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	suite.add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = hero.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = suite
	p.add_child(a)
	a.set_physics_process(false)
	var c := SkillCaster.new()
	c.name = "SkillCaster"
	c.player = p
	c.kit = hero.kit
	c.projectile_scene = PROJECTILE_SCENE
	c.world = suite
	c.hit_stop_enabled = false
	var enemies: Array = []
	c.enemy_source = func() -> Array: return enemies
	p.add_child(c)
	c.set_physics_process(false)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	suite.add_child(e)
	e.set_physics_process(false)
	e.health.max = 9999999
	e.health.current = 9999999
	e.attack = null
	enemies.append(e)
	var reach := a.stats().melee_range * 0.6 if a.stats().use_melee else 200.0
	var ev: Array = []  # [시각, 종류, 번호]
	a.melee_windup.connect(func(_d: Vector2) -> void: ev.append([t[0], "s", a.chain_step]))
	a.ranged_windup.connect(func(_d: Vector2) -> void: ev.append([t[0], "s", a.ranged_step]))
	a.melee_swung.connect(func(_d: Vector2, n: int) -> void: ev.append([t[0], "h", n]))
	a.projectile_fired.connect(func(_pr: Projectile) -> void: ev.append([t[0], "h", 1]))
	c.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void:
		if s == SkillCaster.Slot.TAP:
			ev.append([t[0], "f", 4]))
	var tick := 0
	while t[0] < seconds:
		t[0] += DT
		e.global_position = p.global_position + Vector2(reach, 0)
		e.health.current = e.health.max
		if tick % 3 == 0:
			c.combo_tap()
		a.tick(DT, enemies)
		c.tick(DT, t[0])
		tick += 1
	var rows: Array = []
	var marks := ev.filter(func(x: Array) -> bool: return x[1] != "h")
	for j in marks.size() - 4:
		var w := marks.slice(j, j + 5)
		var kinds := w.map(func(x: Array) -> String: return "%s%d" % [x[1], x[2]])
		if kinds != ["s1", "s2", "s3", "f4", "s1"]:
			continue
		var hit3: float = w[3][0]
		for x in ev:
			if x[1] == "h" and x[0] >= w[2][0] and x[0] <= w[3][0]:
				hit3 = x[0]
				break
		rows.append([w[1][0] - w[0][0], w[2][0] - w[1][0], w[3][0] - hit3, w[4][0] - w[3][0], w[4][0] - w[0][0]])
	enemies.clear()  # 남은 기술 판정이 지운 몹을 보지 않게
	c.enemy_source = func() -> Array: return []
	for n in suite.get_children():
		if n is Projectile or n is OrbitGlyphs or n is DamageZone or n == p or n == e:
			n.queue_free()
	GameTime.clock = Callable()
	var out := {"n": rows.size()}
	var names := ["g12", "g23", "hit3_to_4", "4_to_next1", "cycle"]
	for k in names.size():
		var v: Array = rows.map(func(r: Array) -> float: return r[k])
		v.sort()
		out[names[k]] = v[v.size() / 2] if not v.is_empty() else INF
	return out


func test_yi_cycle_is_as_fast_as_gwanggaeto_and_saimdang() -> void:
	var m := {}
	for id: String in HEROES:
		m[id] = measure(self, id)
		var r: Dictionary = m[id]
		print("[finisher-tempo] %-14s n=%d 1→2 %.3f 2→3 %.3f 3타 닿음→4타 %.3f 4타→다음 1타 %.3f 한 바퀴 %.3f (%.2f 타/초)" % [
			id, r["n"], r["g12"], r["g23"], r["hit3_to_4"], r["4_to_next1"], r["cycle"], 4.0 / r["cycle"]])
	var yi: Dictionary = m["yi_sun_sin"]
	assert_int(yi["n"]).is_greater(0)
	for id: String in ["gwanggaeto", "shin_saimdang"]:
		assert_float(yi["cycle"]).override_failure_message("순신 %.3f vs %s %.3f" % [yi["cycle"], id, m[id]["cycle"]]).is_less_equal(m[id]["cycle"] + 0.001)
	assert_float(yi["4_to_next1"]).is_less_equal(m["shin_saimdang"]["4_to_next1"] + 0.001)
