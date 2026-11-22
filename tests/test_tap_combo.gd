extends GdUnitTestSuite
## 탭 연타 (A안): 제자리 탭 = 평타 한 타 (근접 1·2·3타), 넷째 탭 = tap 기술 마무리 (피해 배율·짧은 쿨타임),
## 너무 빠른 탭은 기억, 연계는 시간 안에만, 반격·대시 연계 우선은 그대로, 세종은 원거리 연사.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SEJONG := preload("res://data/heroes/sejong.tres")
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var attack: AutoAttack
var casts: Array = []
var swings: Array = []
var shots := [0]
var now: float = 0.0


func _setup(hero: HeroData) -> void:
	casts = []
	swings = []
	shots = [0]
	now = 0.0
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	attack = AutoAttack.new()
	attack.name = "AutoAttack"
	attack.player = player
	attack.data = hero.attack.duplicate()
	attack.data.melee_delay = 0.0  # 칼이 닿는 지연 없이 바로 (판정만 본다)
	attack.data.release_delay = 0.0
	attack.projectile_scene = PROJECTILE_SCENE
	attack.projectile_parent = self
	player.add_child(attack)
	add_child(player)
	attack.set_physics_process(false)
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = hero.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return []
	caster.hit_stop_enabled = false
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_cast.connect(func(s: SkillCaster.Slot, _h: int) -> void: casts.append(s))
	caster.auto_attack()  # 자동 평타 신호 연결
	attack.melee_windup.connect(func(_d: Vector2) -> void: swings.append(attack.chain_step))
	attack.projectile_fired.connect(func(_p: Projectile) -> void: shots[0] += 1)


func _wait(seconds: float) -> void:
	var n := ceili(seconds / DT)
	for i in n:
		now += DT
		attack.tick(DT, [])
		caster.tick(DT, now)


func _tap() -> void:
	caster.gesture_down(0, Vector2(100, 100), now)
	_wait(DT)
	caster.gesture_up(0, now)


func test_combo_logic() -> void:
	var c := TapCombo.new()
	assert_int(c.decide(3, true, true)).is_equal(TapCombo.Action.HIT)
	assert_int(c.on_hit(3, 3)).is_equal(1)
	assert_int(c.on_hit(3, 3)).is_equal(2)
	assert_int(c.on_hit(3, 3)).is_equal(3)
	assert_int(c.decide(3, true, true)).is_equal(TapCombo.Action.FINISH)
	assert_int(c.decide(3, true, false)).is_equal(TapCombo.Action.HIT)  # 마무리 쿨타임 중: 평타
	assert_int(c.on_hit(3, 3)).is_equal(1)  # 동작은 다시 1타
	assert_int(c.decide(3, false, false)).is_equal(TapCombo.Action.BUFFERED)
	c.tick(2.0, 1.2)
	assert_int(c.streak).is_equal(0)  # 연계 끊김


func test_finisher_def_scales_damage_only() -> void:
	var d: SkillDef = YI.kit.tap
	var s := TapCombo.scaled_def(d, 0.6)
	assert_object(s).is_not_same(d)
	assert_int(s.get("damage")).is_equal(roundi(int(d.get("damage")) * 0.6))
	assert_float(s.get("radius")).is_equal(d.get("radius"))
	assert_float(s.cooldown).is_equal(d.cooldown)
	assert_int(d.get("damage")).is_equal(25)  # 원본(강화 대상)은 그대로
	assert_object(TapCombo.scaled_def(d, 1.0)).is_same(d)


## 탭 셋 = 근접 1·2·3타 (셋째 강타), 넷째 = 해룡참 마무리, 쿨타임은 절반.
func test_four_taps_hit_hit_heavy_finisher() -> void:
	_setup(YI)
	assert_float(caster.tap_gap()).is_equal_approx(YI.attack.melee_interval * YI.attack.step_gap_mults[0], 0.001)
	for i in 3:
		_tap()
		_wait(caster.tap_gap() + 0.12)  # 타별 박자 (빠름·빠름·묵직) + 3타 모으기
	assert_array(swings).is_equal([1, 2, 3])
	assert_array(casts).is_empty()
	_tap()
	assert_array(casts).is_equal([SkillCaster.Slot.TAP])
	assert_float(caster.cooldown_ratio(SkillCaster.Slot.TAP)).is_less_equal(YI.kit.combo_finisher_cd_ratio + 0.01)


## 너무 빠른 탭은 기억했다가 나가고, 그래도 손 평타는 최소 간격보다 빨리 나가지 않는다.
func test_fast_taps_are_buffered_and_rate_capped() -> void:
	_setup(YI)
	_tap()
	_wait(caster.tap_gap() - 0.15)
	_tap()  # 아직 이르다: 기억
	assert_int(swings.size()).is_equal(1)
	assert_bool(caster.combo.has_buffer()).is_true()
	_wait(0.2)
	assert_int(swings.size()).is_equal(2)
	for i in 20:  # 미친 듯이 연타해도
		_tap()
	assert_int(swings.size()).is_less_equal(2 + ceili(21 * DT / caster.tap_gap()) + 1)


func test_combo_breaks_after_window() -> void:
	_setup(YI)
	_tap()
	_wait(caster.tap_gap() + 0.12)
	_tap()
	_wait(YI.kit.combo_window + 0.1)
	_tap()
	assert_int(caster.combo.streak).is_equal(1)  # 처음부터
	assert_int(swings[-1]).is_equal(1)


## 반격 시간은 여전히 최우선 (연타 중이어도).
func test_counter_still_wins() -> void:
	_setup(YI)
	_tap()
	_wait(caster.tap_gap() + 0.12)
	caster.on_evade()
	_tap()
	assert_array(casts).is_equal([SkillCaster.Slot.COUNTER])


## 세종: 탭 = 글자 던지기 연사, 넷째 = 정음진.
func test_sejong_taps_throw_then_finish() -> void:
	_setup(SEJONG)
	assert_bool(SEJONG.kit.ranged_taps).is_true()
	for i in 3:
		_tap()
		_wait(caster.tap_gap() + 0.12)
	assert_int(shots[0]).is_greater_equal(0)  # 적이 없으면 던지는 동작만 (헛손)
	assert_int(caster.combo.streak).is_equal(3)
	_tap()
	assert_array(casts).is_equal([SkillCaster.Slot.TAP])


func test_whiff_swing_without_enemies_counts() -> void:
	_setup(YI)
	_tap()
	assert_int(swings.size()).is_equal(1)
	assert_int(caster.combo.streak).is_equal(1)


func test_auto_hits_do_not_count_by_default() -> void:
	_setup(YI)
	assert_bool(YI.kit.combo_auto_counts).is_false()
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(40, 0)
	attack.tick(DT, [e])  # 자동 근접
	assert_int(swings.size()).is_equal(1)
	assert_int(caster.combo.streak).is_equal(0)
