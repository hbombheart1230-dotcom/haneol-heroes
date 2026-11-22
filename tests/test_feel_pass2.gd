extends GdUnitTestSuite
## 타격감 2차 (docs/research/game_feel_pass2.md): 잘라 굽기·맞닿는 프레임 (W1), 피해 시점 맞추기 (W2),
## 적 공격 소리 (E1), 무기 끝 (T2), 찌르기 판정·무기 길이 (E3·E4), 수치 (보스 경직·조총).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const GUNNER := preload("res://data/enemies/waegun_gunner.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	Feedback.instance = null
	EnemyAttack.active_windups = 0


func test_bake_window_and_strike_frame() -> void:
	var win := BakeTip.window({"start": 0.5, "end": 1.5}, 3.0)
	assert_vector(win).is_equal(Vector2(0.5, 1.5))
	assert_vector(BakeTip.window({}, 2.0)).is_equal(Vector2(0.0, 2.0))
	assert_vector(BakeTip.window({"start": 2.0, "end": 1.0}, 3.0)).is_equal(Vector2(0.0, 3.0))  # 이상하면 전체
	assert_float(BakeTip.frame_time(win, 0, 6, false)).is_equal(0.5)
	assert_float(BakeTip.frame_time(win, 5, 6, false)).is_equal_approx(1.5, 0.0001)
	assert_int(BakeTip.strike_frame({"strike": 1.3}, win, 6, false)).is_equal(4)  # 0.5 + 0.2 × 4 = 1.3
	assert_int(BakeTip.strike_frame({}, win, 6, false)).is_equal(-1)
	assert_bool(BakeTip.wants_tips("attack2")).is_true()
	assert_bool(BakeTip.wants_tips("run")).is_false()


## 칸마다 시각(times): 치켜든 자세·맞닿는 순간을 고른 간격 대신 직접. 칸 수가 다르면 무시. yaw는 도 → 라디안.
func test_bake_times_and_yaw() -> void:
	var anim := {"times": [1.45, 1.65, 1.8, 2.1, 2.3, 2.6], "strike": 2.1, "yaw": 180}
	var win := BakeTip.window(anim, 3.0)
	assert_float(BakeTip.sample_time(anim, win, 2, 6, false)).is_equal(1.8)
	assert_int(BakeTip.strike_frame(anim, win, 6, false)).is_equal(3)
	assert_float(BakeTip.sample_time(anim, win, 2, 5, false)).is_equal_approx(1.5, 0.0001)  # 칸 수 불일치 → 고른 간격
	assert_float(BakeTip.yaw_offset(anim)).is_equal_approx(PI, 0.0001)
	assert_float(BakeTip.yaw_offset({})).is_equal(0.0)


## 손에서 앞쪽으로 걸어 마지막 불투명 픽셀 (작은 틈은 건너뜀).
func test_find_tip_walks_to_weapon_end() -> void:
	var img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	for x in range(50, 80):
		if x != 60 and x != 61:  # 2px 틈 (손잡이 장식)
			img.set_pixel(x, 50, Color.WHITE)
	var tip := BakeTip.find_tip(img, Vector2(50, 50), Vector2.RIGHT)
	assert_vector(tip).is_equal(Vector2(79, 50) - Vector2(50, 50))


func test_enemy_frame_follows_windup_and_recovery() -> void:
	# 6프레임, 맞닿는 프레임 3
	assert_int(AttackTiming.enemy_frame(false, 0.0, 0.0, 3, 6)).is_equal(0)
	assert_int(AttackTiming.enemy_frame(false, 0.5, 0.0, 3, 6)).is_equal(1)
	assert_int(AttackTiming.enemy_frame(false, 0.99, 0.0, 3, 6)).is_equal(2)  # 예고 끝까지 맞닿기 직전
	assert_int(AttackTiming.enemy_frame(true, 1.0, 0.0, 3, 6)).is_equal(3)   # 피해 순간 = 맞닿는 프레임
	assert_int(AttackTiming.enemy_frame(true, 1.0, 0.99, 3, 6)).is_equal(5)
	assert_int(AttackTiming.enemy_frame(false, 0.7, 0.0, 0, 6)).is_equal(0)
	assert_int(AttackTiming.enemy_frame(true, 1.0, 0.5, 9, 6)).is_equal(5)   # 범위 밖이면 끝 프레임


func test_melee_delay_from_strike_frame() -> void:
	assert_float(AttackTiming.melee_delay(0.2, 3, 16.0, 0.05, 0.15)).is_equal(0.2)   # 데이터가 이김
	assert_float(AttackTiming.melee_delay(-1.0, 2, 16.0, 0.05, 0.15)).is_equal(0.125)
	assert_float(AttackTiming.melee_delay(-1.0, 5, 16.0, 0.05, 0.15)).is_equal(0.15)  # 위로 자름
	assert_float(AttackTiming.melee_delay(-1.0, 0, 16.0, 0.05, 0.15)).is_equal(0.05)
	assert_vector(AttackTiming.tip_offset(Vector2.INF, Vector2(0, -40), Vector2.ONE, Vector2(9, 9))).is_equal(Vector2(9, 9))
	assert_vector(AttackTiming.tip_offset(Vector2(10, 0), Vector2(0, -40), Vector2(2, 2), Vector2.ZERO)).is_equal(Vector2(20, -40))


func test_sheet_strike_and_tip_fallbacks() -> void:
	var s := SpriteSheetSet.new()
	s.anim_names = PackedStringArray(["attack", "run"])
	s.frame_counts = PackedInt32Array([6, 6])
	s.strike_frames = PackedInt32Array([4, -1])
	s.tips = [PackedVector2Array([Vector2(1, 2)]), PackedVector2Array()] as Array[PackedVector2Array]
	assert_int(s.strike_frame("attack")).is_equal(4)
	assert_int(s.strike_frame("run")).is_equal(3)  # 기록 없음: 60%
	assert_vector(s.tip("attack", 0, 0)).is_equal(Vector2(1, 2))
	assert_vector(s.tip("run", 0, 0)).is_equal(Vector2.INF)
	assert_vector(s.tip("attack", 3, 2)).is_equal(Vector2.INF)  # 범위 밖


## 영웅 근접: 휘두르기 시작(melee_windup)과 칼이 닿는 순간(melee_swung·피해)이 melee_delay만큼 떨어진다.
func test_hero_melee_damage_waits_for_contact() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var aa: AutoAttack = auto_free(AutoAttack.new())
	aa.player = p
	aa.data = BasicAttackData.new()
	aa.data.melee_delay = 0.1
	add_child(aa)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(40, 0)
	var hp := e.health.current
	var events := []
	aa.melee_windup.connect(func(_d: Vector2) -> void: events.append("windup"))
	aa.melee_swung.connect(func(_d: Vector2, _n: int) -> void: events.append("swung"))
	aa.tick(DT, [e])
	assert_array(events).is_equal(["windup"])
	assert_int(e.health.current).is_equal(hp)  # 아직 안 맞음
	for i in 8:
		aa.tick(DT, [e])
	assert_array(events).is_equal(["windup", "swung"])
	assert_int(e.health.current).is_less(hp)


## 죽으면 휘두르던 칼은 버리고 새 공격도 시작하지 않는다 (Codex 535304c).
func test_dead_hero_neither_finishes_nor_starts_attacks() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var aa: AutoAttack = auto_free(AutoAttack.new())
	aa.player = p
	aa.data = BasicAttackData.new()
	aa.data.melee_delay = 0.1
	add_child(aa)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(40, 0)
	var hp := e.health.current
	var windups := [0]
	aa.melee_windup.connect(func(_d: Vector2) -> void: windups[0] += 1)
	aa.tick(DT, [e])
	assert_int(windups[0]).is_equal(1)
	h.damage(99999)
	for i in 60:
		aa.tick(DT, [e])
	assert_int(e.health.current).is_equal(hp)  # 휘두르던 칼이 닿지 않음
	assert_int(windups[0]).is_equal(1)  # 새로 휘두르지도 않음


func test_attack_sfx_defaults_and_overrides() -> void:
	var d := EnemyAttackData.new()
	d.kind = EnemyAttackData.Kind.CONE
	assert_str(String(EnemyActions.sfx_for(d, true))).is_equal("e_windup")
	assert_str(String(EnemyActions.sfx_for(d, false))).is_equal("e_swing")
	var g: EnemyAttackData = GUNNER.attack
	assert_str(String(EnemyActions.sfx_for(g, true))).is_equal("e_windup")  # 공통 예고 규칙: 예고음 하나 (하데스 슬라이스)
	assert_str(String(EnemyActions.sfx_for(g, false))).is_equal("e_gun")
	var bank: SoundBank = load("res://data/audio/sfx_bank.tres")
	for k in [&"e_windup", &"e_swing", &"e_heavy", &"e_gun_windup", &"e_gun", &"e_bow"]:
		assert_bool(bank.has(k)).is_true()
	assert_int(bank.prio(&"e_gun")).is_less(bank.prio(&"hurt"))


func test_thrust_is_a_narrow_line() -> void:
	var a := EnemyAttack.new(SOLDIER.attack)
	a.aim_origin = Vector2.ZERO
	a.aim_dir = Vector2.RIGHT
	assert_int(SOLDIER.attack.kind).is_equal(EnemyAttackData.Kind.THRUST)
	assert_bool(a.contains(Vector2(SOLDIER.attack.length - 5.0, 0))).is_true()
	assert_bool(a.contains(Vector2(60, SOLDIER.attack.width))).is_false()  # 옆은 안 맞음
	assert_float(SOLDIER.reach_px).is_greater(0.0)


func test_tuning_numbers() -> void:
	var ai := Enemy.ai_data()
	assert_float(ai.boss_stagger_frac).is_between(0.2, 0.25)
	assert_float(ai.boss_stagger_growth).is_equal(2.0)
	assert_float(GUNNER.attack.windup).is_between(0.9, 1.0)
	assert_object(GUNNER.attack.fire_vfx).is_not_null()
	var gw: HeroData = load("res://data/heroes/gwanggaeto.tres")
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	assert_float(gw.attack.melee_range).is_greater(yi.attack.melee_range)  # 창이 길다
	assert_float(gw.attack.melee_arc_degrees).is_less(yi.attack.melee_arc_degrees)  # 대신 좁다
	for h in [gw, yi]:
		assert_float(h.attack.melee_delay).is_less(0.0)  # 시트의 맞닿는 프레임에서 자동


## 무기 끝이 기록된 시트면 적 탄은 그 자리에서 나간다 (기록이 없으면 몸 앞).
func test_enemy_weapon_tip_falls_back_to_body_edge() -> void:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(100, 100)
	var tip := EnemySprite.weapon_tip(e, "nope", Vector2.RIGHT)
	assert_vector(tip).is_equal_approx(Vector2(100 + e.body_radius * e.size_mult, 100), Vector2(0.01, 0.01))
