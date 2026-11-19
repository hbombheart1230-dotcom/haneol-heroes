extends GdUnitTestSuite
## 두 번째 영웅 광개토대왕: 기절, 돌격 밀치기, 기술 4종과 큰 변형, 영웅 데이터, 영웅 고르기.

const GW := preload("res://data/heroes/gwanggaeto.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HEAVY := preload("res://data/enemies/heavy.tres")  # 기술 한 방에 죽지 않게 체력 큰 적
const BOSS := preload("res://data/enemies/boss_general.tres")
const DT := 1.0 / 60.0

var player: Player
var enemies: Array = []
var ctx: SkillContext


func before_test() -> void:
	enemies = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = GW
	add_child(player)
	player.global_position = Vector2.ZERO
	ctx = SkillContext.new()
	ctx.player = player
	ctx.world = self
	ctx.projectile_scene = PROJECTILE_SCENE
	ctx.hit_stop_enabled = false
	ctx.enemy_source = func() -> Array: return enemies


func after_test() -> void:
	for c in get_children():
		if c is DamageZone or c is Projectile:
			remove_child(c)
			c.free()
	EnemyAttack.active_windups = 0


func _enemy_at(pos: Vector2, data: EnemyData = HEAVY) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = data
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	enemies.append(e)
	return e


# --- 데이터 ---

func test_hero_data_is_complete_and_distinct() -> void:
	assert_str(GW.display_name).is_equal("광개토")
	assert_int(GW.max_hp).is_greater(YI.max_hp)
	assert_float(GW.move_speed).is_less(YI.move_speed)
	assert_float(GW.dash_shove).is_greater(0.0)
	assert_object(GW.kit.tap).is_instanceof(QuakeSkill)
	assert_object(GW.kit.dash).is_instanceof(ThunderTrailSkill)
	assert_object(GW.kit.charge).is_instanceof(LightningSkill)
	assert_object(GW.kit.counter).is_instanceof(ConquerorSkill)
	var s := GW.sprite_sheet
	assert_bool(s.has_anim("idle") and s.has_anim("run") and s.has_anim("attack") and s.has_anim("dash")).is_true()


func test_pools_target_real_properties() -> void:
	var b := RunBuild.new()
	b.begin(player, null, null)
	for pool in [GW.upgrade_pool, GW.major_pool]:
		for u in (pool as UpgradePool).upgrades:
			for m in u.mods:
				var obj := b.target_of(m.target)
				assert_object(obj).is_not_null()
				assert_bool(m.property in obj).override_failure_message("%s %s.%s" % [u.id, m.target, m.property]).is_true()
	assert_int(GW.major_pool.upgrades.size()).is_equal(4)


# --- 기절 ---

func test_stun_freezes_enemy_and_cancels_windup() -> void:
	var e := _enemy_at(Vector2(100, 0))
	e.target = player
	e.set_physics_process(true)
	e.stun(0.5)
	assert_bool(e.is_stunned()).is_true()
	var p0 := e.global_position
	for i in 10:
		e._physics_process(DT)
	assert_vector(e.global_position).is_equal(p0)
	for i in 30:
		e._physics_process(DT)
	assert_bool(e.is_stunned()).is_false()


func test_boss_resists_stun() -> void:
	var b := _enemy_at(Vector2(100, 0), BOSS)
	b.stun(1.0)
	assert_float(b._stun_left).is_equal_approx(1.0 * BOSS.stun_scale, 0.001)
	assert_float(BOSS.stun_scale).is_less(1.0)


# --- 돌격 밀치기 ---

func test_dash_shoves_enemies_aside_once() -> void:
	var e := _enemy_at(Vector2(60, 30))
	player.request_dash(Vector2.RIGHT)
	assert_int(player.shove_enemies(enemies)).is_equal(1)
	assert_float(e.knockback.y).is_greater(0.0)  # 아래쪽(옆)으로 밀림
	assert_int(player.shove_enemies(enemies)).is_equal(0)  # 같은 대시에 한 번만


# --- 기술 ---

func test_quake_hits_and_stuns_and_aftershock() -> void:
	var s: QuakeSkill = GW.kit.tap.duplicate()
	var near := _enemy_at(Vector2(100, 0))
	var far := _enemy_at(Vector2(400, 0))
	var run := s.cast(ctx, 0.0)
	assert_int(run.hits).is_equal(1)
	assert_bool(near.is_stunned()).is_true()
	assert_bool(far.is_stunned()).is_false()
	s.aftershock_delay = 0.5
	var hp: int = near.health.current
	run = s.cast(ctx, 0.0)
	var after_first: int = near.health.current
	assert_int(after_first).is_less(hp)
	assert_bool(run.finished).is_false()
	for i in 40:
		run.tick(DT)
	assert_bool(run.finished).is_true()
	assert_int(near.health.current).is_less(after_first)


func test_thunder_trail_strikes_dash_path_after_delay() -> void:
	var s: ThunderTrailSkill = GW.kit.dash.duplicate()
	player.request_dash(Vector2.RIGHT)  # 시작 위치 (0, 0)
	player.global_position = Vector2(300, 0)
	var on_path := _enemy_at(Vector2(150, 20))
	var off_path := _enemy_at(Vector2(150, 200))
	var hp: int = on_path.health.current
	var run := s.cast(ctx, 0.0)
	assert_int(on_path.health.current).is_equal(hp)  # 아직 (한 박자 늦게)
	for i in 30:
		run.tick(DT)
	assert_int(on_path.health.current).is_equal(hp - s.damage)
	assert_int(off_path.health.current).is_equal(off_path.health.max)
	s.field_time = 2.0
	run = s.cast(ctx, 0.0)
	for i in 30:
		run.tick(DT)
	assert_int(get_children().filter(func(c: Node) -> bool: return c is DamageZone).size()).is_equal(1)


func test_lightning_bolts_scale_with_charge_and_chain() -> void:
	var s: LightningSkill = GW.kit.charge.duplicate()
	assert_int(s.bolt_count(0.0)).is_equal(s.min_bolts)
	assert_int(s.bolt_count(1.0)).is_equal(s.max_bolts)
	var a := _enemy_at(Vector2(100, 0))
	var b := _enemy_at(Vector2(250, 0))  # a에서 연쇄 거리(180) 안
	var c := _enemy_at(Vector2(380, 0))  # b에서 연쇄 거리 안
	s.cast(ctx, 0.0)  # 벼락 1개 → 가장 가까운 a, 연쇄 없음
	assert_int(a.health.current).is_less(a.health.max)
	assert_int(b.health.current).is_equal(b.health.max)
	assert_int(c.health.current).is_equal(c.health.max)
	s.chain_count = 2
	s.cast(ctx, 0.0)
	assert_int(b.health.current).is_less(b.health.max)  # a → b로 튐
	assert_int(c.health.current).is_less(c.health.max)


func test_lightning_skips_dead_enemies() -> void:
	# Codex f7fa7cd 회귀: 죽어서 지워지기 전인 적에게 벼락을 쓰지 않는다
	var s: LightningSkill = GW.kit.charge.duplicate()
	var dead := _enemy_at(Vector2(50, 0))
	dead.health.kill()
	var live := _enemy_at(Vector2(200, 0))
	s.cast(ctx, 0.0)  # 벼락 1개
	assert_int(live.health.current).is_less(live.health.max)


func test_quake_and_conqueror_ignore_dead_enemies() -> void:
	# Codex 27e25cb 회귀
	var dead := _enemy_at(Vector2(60, 0))
	dead.health.kill()
	assert_int((GW.kit.tap as QuakeSkill).cast(ctx, 0.0).hits).is_equal(0)
	assert_int((GW.kit.counter as ConquerorSkill).cast(ctx, 0.0).hits).is_equal(0)
	assert_vector(dead.knockback).is_equal(Vector2.ZERO)
	# Codex 7549930 회귀: 벽력돌파도 죽은 적을 세지 않는다
	player.request_dash(Vector2.RIGHT)
	player.global_position = Vector2(200, 0)
	var run := (GW.kit.dash as ThunderTrailSkill).cast(ctx, 0.0)
	for i in 30:
		run.tick(DT)
	assert_int(run.hits).is_equal(0)


func test_conqueror_wide_stun_and_field() -> void:
	var s: ConquerorSkill = GW.kit.counter.duplicate()
	var e := _enemy_at(Vector2(250, 0))
	s.field_time = 3.0
	s.cast(ctx, 0.0)
	assert_bool(e.is_stunned()).is_true()
	assert_int(e.health.current).is_equal(e.health.max - s.damage)
	assert_int(get_children().filter(func(c: Node) -> bool: return c is DamageZone).size()).is_equal(1)


# --- 영웅 고르기 ---

func test_hero_select_picks_with_one_tap() -> void:
	var sel: HeroSelect = auto_free(HeroSelect.new())
	sel.size = Vector2(720, 1280)
	add_child(sel)
	var got: Array = []
	sel.picked.connect(func(h: HeroData) -> void: got.append(h))
	sel.open([YI, GW] as Array[HeroData])
	var c := sel.slot_rect(1).get_center()
	sel.handle_touch(0, c, true)
	assert_bool(sel.handle_touch(0, c, false)).is_true()
	assert_array(got).is_equal([GW])
	assert_float(sel.slot_rect(0).position.y).is_greater(1280.0 * 0.3)  # 엄지 닿는 아래쪽


func test_main_waits_for_hero_then_runs_chosen_hero() -> void:
	GameSettings.settings_path = "user://test_settings.cfg"
	GameSettings.hero_picked = false
	GameSettings.hero_id = &""
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_bool(main.waiting_pick).is_true()
	assert_bool(get_tree().paused).is_true()
	var t: float = main.state.elapsed
	await get_tree().physics_frame
	assert_float(main.state.elapsed).is_equal(t)
	var sel: HeroSelect = main.hero_select
	var c := sel.slot_rect(1).get_center()
	sel.handle_touch(0, c, true)
	sel.handle_touch(0, c, false)
	var p: Player = main.get_node("Player")
	assert_bool(main.waiting_pick).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_str(String(p.hero.id)).is_equal("gwanggaeto")
	assert_object(p.hero).is_not_same(GW)  # 이번 판 사본
	assert_float(p.move_speed).is_equal(GW.move_speed)
	assert_int(p.health.max).is_equal(GW.max_hp)
	assert_object((p.get_node("SkillCaster") as SkillCaster).kit.tap).is_instanceof(QuakeSkill)
	assert_str(String(GameSettings.hero_id)).is_equal("gwanggaeto")
	assert_bool(main.is_change_hero_area(Vector2(10, main.get_viewport().get_visible_rect().size.y - 10))).is_true()
	get_tree().paused = false
	main.queue_free()
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()
