extends GdUnitTestSuite
## 3단계 런 루프: 경험치·레벨업, 성장 선택지, 이번 판 전용 수치 사본, 선택 화면, 보스 처치 승리.

const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const POOL := preload("res://data/upgrades/yi_sun_sin.tres")
const RUN := preload("res://data/runs/default_run.tres")


func _mod(target: StringName, prop: StringName, op: StatMod.Op, value: float) -> StatMod:
	var m := StatMod.new()
	m.target = target
	m.property = prop
	m.op = op
	m.value = value
	return m


func _up(id: StringName, mods: Array[StatMod], max_stacks: int = 3) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = id
	u.mods = mods
	u.max_stacks = max_stacks
	return u


func _player_with_build() -> Array:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	var caster := SkillCaster.new()
	caster.name = "SkillCaster"
	caster.player = p
	p.add_child(caster)
	var attack := AutoAttack.new()
	attack.name = "AutoAttack"
	attack.player = p
	p.add_child(attack)
	p.hero = HERO
	add_child(p)
	var b := RunBuild.new()
	b.begin(p, caster, attack)
	return [p, b, caster, attack]


# --- 수치 변화 ---

func test_stat_mod_add_and_mul_keep_types() -> void:
	assert_float(_mod(&"t", &"p", StatMod.Op.MUL, 1.25).apply_to(170.0)).is_equal(212.5)
	assert_int(_mod(&"t", &"p", StatMod.Op.MUL, 1.4).apply_to(25)).is_equal(35)
	assert_int(_mod(&"t", &"p", StatMod.Op.ADD, 1.0).apply_to(3)).is_equal(4)
	# 작은 정수에 작은 배율이어도 최소 1은 오른다
	assert_int(_mod(&"t", &"p", StatMod.Op.MUL, 1.1).apply_to(3)).is_equal(4)


# --- 경험치·레벨 ---

func test_xp_levels_up_and_queues_choices() -> void:
	var cfg := RunConfig.new()
	cfg.xp_base = 5
	cfg.xp_growth = 4
	var r := RunProgress.new(cfg)
	assert_int(r.xp_to_next()).is_equal(5)
	assert_int(r.add_xp(4)).is_equal(0)
	assert_int(r.add_xp(1)).is_equal(1)
	assert_int(r.level).is_equal(2)
	assert_int(r.xp_to_next()).is_equal(9)
	assert_int(r.add_xp(30)).is_equal(2)  # 9 + 13 = 22, 남은 8
	assert_int(r.level).is_equal(4)
	assert_int(r.xp).is_equal(8)
	assert_int(r.pending).is_equal(3)
	r.record_choice(_up(&"a", []))
	assert_int(r.pending).is_equal(2)
	assert_int(r.stacks[&"a"]).is_equal(1)


func test_pool_roll_is_unique_and_skips_maxed() -> void:
	var pool := UpgradePool.new()
	pool.upgrades = [_up(&"a", [], 1), _up(&"b", []), _up(&"c", []), _up(&"d", [])]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var got := pool.roll(rng, {&"a": 1}, 3)
		assert_int(got.size()).is_equal(3)
		var ids := got.map(func(u: UpgradeDef) -> StringName: return u.id)
		assert_bool(ids.has(&"a")).is_false()
		assert_int(ids.size()).is_equal(3)
		assert_bool(ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]).is_true()
	assert_int(pool.roll(rng, {&"a": 1, &"b": 3, &"c": 3, &"d": 3}, 3).size()).is_equal(0)


# --- 이번 판 전용 사본 ---

func test_build_copies_hero_and_never_touches_the_tres() -> void:
	var parts := _player_with_build()
	var p: Player = parts[0]
	var b: RunBuild = parts[1]
	var caster: SkillCaster = parts[2]
	var attack: AutoAttack = parts[3]
	assert_object(p.hero).is_not_same(HERO)
	assert_object(caster.kit).is_same(p.hero.kit)
	assert_object(attack.data).is_same(p.hero.attack)
	assert_object(p.hero.sprite_sheet).is_same(HERO.sprite_sheet)  # 외부 리소스는 공유
	var before: float = HERO.kit.tap.radius
	assert_bool(b.apply(_up(&"w", [_mod(&"tap", &"radius", StatMod.Op.MUL, 1.25)]))).is_true()
	assert_float(p.hero.kit.tap.radius).is_equal(before * 1.25)
	assert_float(HERO.kit.tap.radius).is_equal(before)


func test_hero_upgrades_refresh_player() -> void:
	var parts := _player_with_build()
	var p: Player = parts[0]
	var b: RunBuild = parts[1]
	p.health.current = 40
	b.apply(_up(&"v", [_mod(&"hero", &"max_hp", StatMod.Op.ADD, 25.0)]))
	assert_int(p.health.max).is_equal(HERO.max_hp + 25)
	assert_int(p.health.current).is_equal(65)
	b.apply(_up(&"d", [_mod(&"hero", &"dash_recharge_time", StatMod.Op.MUL, 0.5),
		_mod(&"hero", &"max_dash_charges", StatMod.Op.ADD, 1.0)]))
	assert_float(p.dash.recharge_time).is_equal_approx(HERO.dash_recharge_time * 0.5, 0.0001)
	assert_int(p.dash.max_charges).is_equal(HERO.max_dash_charges + 1)
	b.apply(_up(&"s", [_mod(&"hero", &"move_speed", StatMod.Op.MUL, 1.1)]))
	assert_float(p.move_speed).is_equal_approx(HERO.move_speed * 1.1, 0.001)


func test_kit_upgrades_reach_cached_input_timing() -> void:
	var parts := _player_with_build()
	var b: RunBuild = parts[1]
	var caster: SkillCaster = parts[2]
	b.apply(_up(&"f", [_mod(&"kit", &"full_charge_time", StatMod.Op.MUL, 0.5)]))
	assert_float(caster.input.full_charge_time).is_equal_approx(HERO.kit.full_charge_time * 0.5, 0.0001)


func test_every_yi_upgrade_targets_a_real_property() -> void:
	var parts := _player_with_build()
	var b: RunBuild = parts[1]
	assert_int(POOL.upgrades.size()).is_greater_equal(10)
	var seen := {}
	for u in POOL.upgrades:
		assert_bool(seen.has(u.id)).is_false()
		seen[u.id] = true
		assert_str(u.title).is_not_empty()
		for m in u.mods:
			var obj := b.target_of(m.target)
			assert_object(obj).is_not_null()
			assert_bool(m.property in obj).override_failure_message("%s.%s" % [m.target, m.property]).is_true()
	assert_object(HERO.upgrade_pool).is_same(POOL)


# --- 선택 화면 ---

func test_panel_needs_a_fresh_tap_on_one_card() -> void:
	var panel: LevelUpPanel = auto_free(LevelUpPanel.new())
	panel.size = Vector2(720, 1280)
	add_child(panel)
	var picked: Array = []
	panel.chosen.connect(func(u: UpgradeDef) -> void: picked.append(u))
	var ups: Array[UpgradeDef] = [_up(&"a", []), _up(&"b", []), _up(&"c", [])]
	panel.open(ups, 2, {})
	var c1 := panel.card_rect(1).get_center()
	assert_bool(panel.handle_touch(0, c1, false)).is_false()  # 열리자마자 떼기는 무시
	panel._process(0.5)
	panel.handle_touch(0, c1, true)
	assert_bool(panel.handle_touch(0, panel.card_rect(2).get_center(), false)).is_false()  # 다른 카드에서 뗌
	assert_bool(panel.is_open()).is_true()
	panel.handle_touch(1, c1, true)
	assert_bool(panel.handle_touch(1, c1, false)).is_true()
	assert_array(picked).is_equal([ups[1]])
	assert_bool(panel.is_open()).is_false()
	# 카드는 화면 아래쪽 절반 안 (오른엄지)
	assert_float(panel.card_rect(0).position.y).is_greater(1280.0 * 0.45)


func test_panel_accepts_mouse_click_and_never_picks_twice() -> void:
	var panel: LevelUpPanel = auto_free(LevelUpPanel.new())
	panel.size = Vector2(720, 1280)
	add_child(panel)
	var picked: Array = []
	panel.chosen.connect(func(u: UpgradeDef) -> void: picked.append(u))
	panel.open([_up(&"a", []), _up(&"b", []), _up(&"c", [])] as Array[UpgradeDef], 2, {})
	panel._process(0.5)
	var c := panel.card_rect(0).get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = c
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	panel._input(down)
	panel.handle_touch(0, c, true)  # 같은 클릭이 터치로도 들어옴
	panel._input(up)
	panel.handle_touch(0, c, false)
	assert_int(picked.size()).is_equal(1)


# --- 판 규칙 ---

func test_run_has_no_time_victory() -> void:
	var g := GameState.new(0.0)
	g.tick(10000.0)
	assert_bool(g.is_playing()).is_true()
	g.boss_defeated()
	assert_int(g.result).is_equal(GameState.Result.VICTORY)


func test_main_scene_level_up_pauses_and_applies_choice() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	assert_float(main.state.survive_time).is_equal(0.0)
	assert_float((main.get_node("EnemySpawner") as EnemySpawner).boss_time).is_equal(RUN.boss_time)
	var enemy: Enemy = (main.get_node("EnemySpawner") as EnemySpawner).spawn_one()
	main.progress.add_xp(main.progress.xp_to_next() - enemy.data.xp)
	enemy.health.kill()
	await get_tree().process_frame
	var panel: LevelUpPanel = main.level_up_panel
	assert_bool(panel.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	var t: float = main.state.elapsed
	for i in 5:
		await get_tree().physics_frame
	assert_float(main.state.elapsed).is_equal(t)  # 고르는 동안 시간 멈춤
	var player: Player = main.get_node("Player")
	var u: UpgradeDef = panel.choices[0]
	panel._process(1.0)
	var c := panel.card_rect(0).get_center()
	panel.handle_touch(0, c, true)
	panel.handle_touch(0, c, false)
	assert_bool(get_tree().paused).is_false()
	assert_int(main.progress.stacks.get(u.id, 0)).is_equal(1)
	assert_object(player.hero).is_not_same(HERO)
	get_tree().paused = false
	main.queue_free()
