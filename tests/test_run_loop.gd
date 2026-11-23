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


# --- 강화 카드 고르기 ---

func _seal(p: Player) -> SealChoice:
	var sc: SealChoice = auto_free(SealChoice.new())
	sc.player = p
	add_child(sc)
	return sc


func _tap(sc: SealChoice, i: int) -> void:
	var c := sc.cards.card_rect(i).get_center()
	sc.cards.handle_touch(0, c, true)
	sc.cards.handle_touch(0, c, false)


func test_cards_pause_and_pick_by_tapping() -> void:
	var parts := _player_with_build()
	var sc := _seal(parts[0])
	sc.cards.size = Vector2(720, 1280)
	var picked: Array = []
	sc.chosen.connect(func(u: UpgradeDef, major: bool) -> void: picked.append([u, major]))
	var ups: Array[UpgradeDef] = [_up(&"a", []), _up(&"b", []), _up(&"c", [])]
	sc.open(ups, Vector2.ZERO, false, {})
	assert_bool(sc.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()  # 카드를 고르는 동안 게임이 멈춘다
	_tap(sc, 2)
	assert_int(picked.size()).is_equal(0)  # 열린 직후 누름은 무시 (싸우다 잘못 누름)
	sc.cards.step(sc.cards.input_delay)
	_tap(sc, 2)
	assert_int(picked.size()).is_equal(1)
	assert_object(picked[0][0]).is_same(ups[2])
	assert_bool(picked[0][1]).is_false()
	assert_bool(sc.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_press_on_one_card_release_on_another_picks_nothing() -> void:
	var parts := _player_with_build()
	var sc := _seal(parts[0])
	sc.cards.size = Vector2(720, 1280)
	var picked: Array = []
	sc.chosen.connect(func(u: UpgradeDef, _m: bool) -> void: picked.append(u))
	sc.open([_up(&"a", []), _up(&"b", []), _up(&"c", [])] as Array[UpgradeDef], Vector2.ZERO, true, {})
	sc.cards.step(1.0)
	sc.cards.handle_touch(0, sc.cards.card_rect(0).get_center(), true)
	sc.cards.handle_touch(0, sc.cards.card_rect(1).get_center(), false)
	assert_int(picked.size()).is_equal(0)
	assert_bool(sc.is_open()).is_true()  # 시간 제한 없음
	sc.close()
	assert_bool(get_tree().paused).is_false()


func test_cards_keep_an_already_paused_game_paused() -> void:
	var parts := _player_with_build()
	var sc := _seal(parts[0])
	get_tree().paused = true
	sc.open([_up(&"a", [])] as Array[UpgradeDef], Vector2.ZERO, false, {})
	sc.close()
	assert_bool(get_tree().paused).is_true()
	get_tree().paused = false


func test_cards_fit_and_draw_long_text() -> void:
	var parts := _player_with_build()
	var sc := _seal(parts[0])
	sc.cards.size = Vector2(720, 1280)
	var long := _up(&"a", [])
	long.title = "뇌진격 · 아주 아주 무거운 검"
	long.description = "기본 공격 피해 +40% 그리고 적을 더 멀리 밀어낸다"
	sc.open([long, _up(&"b", []), _up(&"c", [])] as Array[UpgradeDef], Vector2.ZERO, false, {long.id: 1})
	for i in 3:
		var r := sc.cards.card_rect(i)
		assert_bool(Rect2(Vector2.ZERO, sc.cards.size).encloses(r)).is_true()
	assert_int(UpgradeCards.wrap_lines(UiStyle.BODY_FONT, long.description, 22, 180.0, 3).size()).is_less_equal(3)
	sc.cards.queue_redraw()
	await get_tree().process_frame
	sc.close()


# --- 큰 변형 (정예 보상) ---

const MAJOR := preload("res://data/upgrades/yi_sun_sin_major.tres")
const ELITE := preload("res://data/enemies/elite_warrior.tres")


func test_major_pool_targets_and_changes_behaviour_flags() -> void:
	var parts := _player_with_build()
	var b: RunBuild = parts[1]
	var p: Player = parts[0]
	assert_object(HERO.major_pool).is_same(MAJOR)
	assert_int(MAJOR.upgrades.size()).is_equal(4)
	for u in MAJOR.upgrades:
		assert_int(u.max_stacks).is_equal(1)
		assert_bool(b.apply(u)).is_true()
	assert_float(p.hero.kit.tap.whirl_time).is_greater(0.0)
	assert_float(p.hero.kit.dash.end_burst_radius).is_greater(0.0)
	assert_int(p.hero.kit.charge.extra_waves).is_equal(2)
	assert_int(p.hero.kit.counter.radial_blades).is_equal(8)
	assert_float(HERO.kit.tap.whirl_time).is_equal(0.0)  # 원본은 그대로


func test_elite_data_and_spawner_schedule() -> void:
	assert_bool(ELITE.is_elite).is_true()
	assert_bool(ELITE.is_boss).is_false()
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	var s: EnemySpawner = auto_free(EnemySpawner.new())
	s.enemy_scene = preload("res://scenes/enemy.tscn")
	s.target = target
	s.max_alive = 0
	s.elite_data = ELITE
	s.elite_times = PackedFloat32Array([1.0, 2.0])
	add_child(s)
	var got: Array = []
	s.elite_spawned.connect(func(e: Enemy) -> void: got.append(e))
	s.tick(0.5)
	assert_int(got.size()).is_equal(0)
	s.tick(0.6)
	assert_int(got.size()).is_equal(1)
	s.tick(5.0)
	assert_int(got.size()).is_equal(2)
	s.tick(5.0)
	assert_int(got.size()).is_equal(2)


# --- 판 규칙 ---

func test_run_has_no_time_victory() -> void:
	var g := GameState.new(0.0)
	g.tick(10000.0)
	assert_bool(g.is_playing()).is_true()
	g.boss_defeated()
	assert_int(g.result).is_equal(GameState.Result.VICTORY)


func test_main_scene_level_up_shows_cards_and_pauses() -> void:
	_skip_hero_select()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	assert_float(main.state.survive_time).is_equal(0.0)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	assert_float(spawner.boss_time).is_equal(RUN.boss_time)
	assert_object(spawner.elite_data).is_same(ELITE)
	var enemy: Enemy = spawner.spawn_one()
	main.progress.add_xp(main.progress.xp_to_next() - enemy.data.xp)
	enemy.health.kill()
	await get_tree().physics_frame
	var sc: SealChoice = main.seal_choice
	assert_bool(sc.is_open()).is_false()  # 물결 무대: 싸움 중 레벨업은 숨 고르기까지 쌓아 둔다
	main._on_breather(false)
	assert_bool(sc.is_open()).is_true()
	assert_bool(sc.major).is_false()
	assert_bool(get_tree().paused).is_true()  # 카드를 고르는 동안 멈춘다
	var u: UpgradeDef = sc.choices[0]
	sc.pick(0)
	assert_bool(sc.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(main.progress.stacks.get(u.id, 0)).is_equal(1)  # 적립 카드 1장 = 1단계 (LevelRules.plan)
	assert_int(main.progress.pending).is_equal(0)
	# 정예 처치 → 금빛 큰 변형 인장 (이것도 숨 고르기에)
	var elite: Enemy = spawner.spawn_elite()
	elite.health.kill()
	await get_tree().physics_frame
	assert_bool(sc.is_open()).is_false()
	main._on_breather(false)
	assert_bool(sc.is_open()).is_true()
	assert_bool(sc.major).is_true()
	main.state.player_died()
	await get_tree().physics_frame
	assert_bool(sc.is_open()).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	get_tree().paused = false
	main.queue_free()


## 메인 씬 테스트: 영웅 고르기 화면 없이 이순신으로, 실제 설정 파일은 건드리지 않는다.
func _skip_hero_select() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.hero_picked = true
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.intro_seen = true
	GameSettings.tutorial_done = true
	GameSettings.hero_clears = {}
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()


## 실제 시간으로 기다린다 (ignore_time_scale 타이머는 느린 시간에서 일찍 끝난다).
func _wait_real(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
