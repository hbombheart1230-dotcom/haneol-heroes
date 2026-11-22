extends GdUnitTestSuite
## 던파식 타격감 (docs/research/dnf_benchmark.md): 근접 우선 (A1), 잡몹 끊김·반격 (B1·B2),
## 영웅 멈춤·3타째 강타 (B3·B4), 뒤치기·넘어짐 (B5·B8), 피해 숫자 (B6), 무기 소리 (B9).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const HEAVY := preload("res://data/enemies/waegun_heavy.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0


func _player_at(pos: Vector2) -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	p.global_position = pos
	return p


func _enemy(data: EnemyData, pos: Vector2, target: Node2D = null) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = data
	e.target = target
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	return e


func _attack(p: Player, d: BasicAttackData) -> AutoAttack:
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.data = d
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	add_child(a)
	return a


## 적을 예고 중으로 (실제 tick 없이).
func _windup(e: Enemy, aim: Vector2) -> void:
	e.attack.state = EnemyAttack.State.WINDUP
	e.attack._timer = 0.5
	e.attack.aim_dir = aim


func test_hit_bonus_flags_and_mult() -> void:
	var d := ImpactFeelData.new()
	assert_int(HitBonus.flags(true, Vector2.RIGHT, Vector2.RIGHT, 120.0)).is_equal(HitBonus.COUNTER)
	assert_int(HitBonus.flags(false, Vector2.RIGHT, Vector2.LEFT, 120.0)).is_equal(HitBonus.BACK)
	assert_int(HitBonus.flags(false, Vector2.RIGHT, Vector2.UP, 120.0)).is_equal(HitBonus.NONE)  # 옆은 뒤가 아님
	assert_int(HitBonus.flags(true, Vector2.RIGHT, Vector2.LEFT, 120.0)).is_equal(HitBonus.COUNTER | HitBonus.BACK)
	assert_float(HitBonus.mult(HitBonus.COUNTER, d)).is_equal_approx(1.5, 0.0001)
	assert_float(HitBonus.mult(HitBonus.COUNTER | HitBonus.BACK, d)).is_equal_approx(d.bonus_mult_cap, 0.0001)  # 1.875 → 상한
	assert_str(HitBonus.label(HitBonus.COUNTER | HitBonus.BACK, d)[0]).is_equal("반격!")
	assert_str(HitBonus.label(HitBonus.BACK, d)[0]).is_equal("뒤치기!")
	assert_str(HitBonus.label(HitBonus.NONE, d)[0]).is_equal("")


func test_labels_are_in_the_font() -> void:
	var d: ImpactFeelData = Feedback.feel_data().impact_data()
	for text in [d.counter_label, d.back_label, "0123456789"]:
		for i in text.length():
			assert_bool(UiStyle.TITLE_FONT.has_char(text.unicode_at(i))).is_true()


func test_hero_hitstop_lengths() -> void:
	var d := ImpactFeelData.new()
	assert_float(d.hero_hitstop(0, false)).is_equal(0.0)
	assert_float(d.hero_hitstop(1, false)).is_equal_approx(0.04, 0.0001)
	assert_float(d.hero_hitstop(3, false)).is_equal_approx(0.06, 0.0001)
	assert_float(d.hero_hitstop(20, false)).is_equal_approx(0.08, 0.0001)
	assert_float(d.hero_hitstop(1, true)).is_equal_approx(0.1, 0.0001)


func test_chain_steps_wrap_and_reset() -> void:
	var d := BasicAttackData.new()
	assert_int(AutoAttack.next_chain_step(0, INF, d)).is_equal(1)
	assert_int(AutoAttack.next_chain_step(1, 0.5, d)).is_equal(2)
	assert_int(AutoAttack.next_chain_step(2, 0.5, d)).is_equal(3)
	assert_int(AutoAttack.next_chain_step(3, 0.5, d)).is_equal(1)  # 강타 뒤 다시 1타
	assert_int(AutoAttack.next_chain_step(2, 2.0, d)).is_equal(1)  # 끊기면 처음부터
	d.chain_len = 0
	assert_int(AutoAttack.next_chain_step(1, 0.1, d)).is_equal(1)


## A1: 근접 사거리 × engage_mult 안이면 원거리를 참다가, engage_hold_max가 지나면 쏜다.
func test_melee_first_holds_ranged_then_gives_up() -> void:
	var p := _player_at(Vector2.ZERO)
	var d := BasicAttackData.new()
	d.engage_mult = 1.8
	d.engage_hold_max = 0.3
	var a := _attack(p, d)
	var e := _enemy(SOLDIER, Vector2(d.melee_range * 1.5, 0))
	var shots := [0]
	a.projectile_fired.connect(func(_p: Projectile) -> void: shots[0] += 1)
	for i in 10:  # 약 0.17초: 참는다
		a.tick(DT, [e])
	assert_int(shots[0]).is_equal(0)
	for i in 20:
		a.tick(DT, [e])
	assert_int(shots[0]).is_equal(1)


func test_ranged_hero_does_not_hold() -> void:
	var p := _player_at(Vector2.ZERO)
	var d := BasicAttackData.new()  # engage_mult 1 (세종)
	var a := _attack(p, d)
	var e := _enemy(SOLDIER, Vector2(d.melee_range * 1.5, 0))
	var shots := [0]
	a.projectile_fired.connect(func(_p: Projectile) -> void: shots[0] += 1)
	a.tick(DT, [e])
	assert_int(shots[0]).is_equal(1)


## B4·B8: 연계 3타째는 피해·넉백 배율 + 잡몹 넘어짐. 중장병(슈퍼아머)은 안 넘어진다.
func test_third_hit_is_heavy_and_knocks_down_trash() -> void:
	var p := _player_at(Vector2.ZERO)
	var d := BasicAttackData.new()
	d.melee_interval = 0.1
	d.chain_window = 1.0
	d.melee_damage = 5  # 셋 다 맞아도 살아 있게 (병사 체력 30)
	var a := _attack(p, d)
	var e := _enemy(SOLDIER, Vector2(50, 0))
	var armored := _enemy(HEAVY, Vector2(50, 20))
	var hp := e.health.current
	for i in 3:
		a.tick(0.11, [e, armored])
		assert_bool(e.reaction.is_down()).is_equal(i == 2)
	assert_bool(a.last_heavy).is_true()
	var expected := d.melee_damage * 2 + roundi(d.melee_damage * d.heavy_damage_mult)
	assert_int(hp - e.health.current).is_equal(expected)
	assert_bool(armored.reaction.is_down()).is_false()
	assert_float(e._freeze_left).is_greater_equal(Feedback.feel_data().impact_data().heavy_freeze - 0.001)  # 강타 멈춤


## B1: 슈퍼아머 없는 잡몹은 예고 중 맞으면 끊기고 경직, 다음 예고는 rearm 동안 끊기지 않는다.
func test_trash_windup_is_interrupted_once() -> void:
	var p := _player_at(Vector2(-60, 0))
	var e := _enemy(SOLDIER, Vector2.ZERO, p)
	var im := Feedback.feel_data().impact_data()
	_windup(e, Vector2.LEFT)
	e.health.damage(1)
	assert_int(e.attack.state).is_equal(EnemyAttack.State.READY)
	assert_float(e.reaction.stagger_left).is_greater_equal(im.interrupt_stagger - 0.001)
	_windup(e, Vector2.LEFT)
	assert_bool(e.attack.can_interrupt()).is_false()  # 막 끊긴 뒤
	e.health.damage(1)
	assert_int(e.attack.state).is_equal(EnemyAttack.State.WINDUP)


func test_super_armor_is_not_interrupted() -> void:
	var p := _player_at(Vector2(-60, 0))
	var e := _enemy(HEAVY, Vector2.ZERO, p)
	assert_bool(HEAVY.super_armor).is_true()
	_windup(e, Vector2.LEFT)
	e.health.damage(1)
	assert_int(e.attack.state).is_equal(EnemyAttack.State.WINDUP)


## B2·B5: 예고 중 맞히면 ×counter_mult, 등 뒤에서면 ×back_mult도.
func test_counter_and_back_attack_damage() -> void:
	var im := Feedback.feel_data().impact_data()
	var p := _player_at(Vector2(-60, 0))
	var e := _enemy(SOLDIER, Vector2.ZERO, p)
	e.attack._armor_left = 99.0  # 끊기지 않게 해 배율만 본다
	e.health.max = 500
	e.health.current = 500
	_windup(e, Vector2.LEFT)  # 영웅 쪽을 본다: 반격만
	e._update_damage_mult()
	var hp := e.health.current
	e.health.damage(16)
	assert_int(hp - e.health.current).is_equal(roundi(16 * im.counter_mult))
	_windup(e, Vector2.RIGHT)  # 영웅에게 등을 보인 채 예고: 반격 + 뒤치기
	e._update_damage_mult()
	hp = e.health.current
	e.health.damage(16)
	assert_int(hp - e.health.current).is_equal(roundi(16 * minf(im.counter_mult * im.back_mult, im.bonus_mult_cap)))


func test_knockdown_state_lifts_lies_and_rearms() -> void:
	var d := ImpactFeelData.new()
	var r := HitReaction.new(null, HitReaction.Tier.TRASH)
	assert_bool(r.knock_down(d)).is_true()
	r.tick(d.down_lift_time * 0.5)
	assert_float(r.down_lift()).is_equal_approx(d.down_lift_px, 0.01)  # 꼭대기
	assert_float(absf(r.down_tilt(d.down_tilt_deg))).is_greater(0.0)
	r.tick(d.down_time)
	assert_bool(r.is_down()).is_false()
	assert_bool(r.knock_down(d)).is_false()  # 일어난 직후는 다시 안 넘어짐
	r.tick(d.down_rearm + 0.01)
	assert_bool(r.knock_down(d)).is_true()
	assert_bool(HitReaction.new(null, HitReaction.Tier.ELITE).knock_down(d)).is_false()


func test_down_enemy_does_not_attack() -> void:
	var p := _player_at(Vector2(-40, 0))
	var e := _enemy(SOLDIER, Vector2.ZERO, p)
	assert_bool(EnemyHits.knock_down(e)).is_true()
	e.attack._cooldown = 0.0
	e._physics_process(DT)
	assert_int(e.attack.state).is_equal(EnemyAttack.State.READY)


func test_number_styles_and_weapon_sounds() -> void:
	assert_int(EnemyHits.number_style(5, true)).is_equal(2)
	assert_int(EnemyHits.number_style(Feedback.feel_data().big_hit_damage, false)).is_equal(1)
	assert_int(EnemyHits.number_style(5, false)).is_equal(0)
	var bank: SoundBank = load("res://data/audio/sfx_bank.tres")
	for k in [&"w_sword", &"w_spear", &"w_brush", &"w_scroll", &"w_heavy"]:
		assert_bool(bank.has(k)).is_true()
	var melee_heroes := ["yi_sun_sin", "gwanggaeto", "shin_saimdang"]
	for h in melee_heroes:
		var hd: HeroData = load("res://data/heroes/%s.tres" % h)
		assert_float(hd.attack.engage_mult).is_greater(1.0)
		assert_bool(bank.has(hd.attack.melee_hit_sfx)).is_true()
	var sejong: HeroData = load("res://data/heroes/sejong.tres")
	assert_float(sejong.attack.engage_mult).is_equal(1.0)  # 원거리 영웅은 참지 않는다


## 한얼 맞춤 상한: 흔들림이 겹쳐도 trauma_cap을 넘지 않고, 숫자는 max_numbers까지, 글자는 label_min_gap 간격.
func test_stacking_caps() -> void:
	assert_float(ImpactFx.capped_trauma(0.0, 0.3, 0.55)).is_equal_approx(0.3, 0.0001)
	assert_float(ImpactFx.capped_trauma(0.4, 0.3, 0.55)).is_equal_approx(0.15, 0.0001)
	assert_float(ImpactFx.capped_trauma(0.9, 0.3, 0.55)).is_equal(0.0)
	var fx: FxLayer = auto_free(FxLayer.new())
	add_child(fx)
	var im := Feedback.feel_data().impact_data()
	for i in im.max_numbers + 10:
		fx.add_number(Vector2.ZERO, i)
	assert_int(fx.number_count()).is_equal(im.max_numbers)
	assert_float(im.finisher_flash_color.r).is_less(1.0)  # 흰 섬광이 아니라 한지색


func test_label_throttle() -> void:
	var fb: Feedback = auto_free(Feedback.new())
	fb.fx = auto_free(FxLayer.new())
	add_child(fb.fx)
	ImpactFx._last_label = -INF
	assert_bool(ImpactFx.hit_label(fb, Vector2.ZERO, HitBonus.COUNTER)).is_true()
	assert_bool(ImpactFx.hit_label(fb, Vector2.ZERO, HitBonus.BACK)).is_false()  # 너무 자주
	assert_bool(ImpactFx.hit_label(fb, Vector2.ZERO, HitBonus.NONE)).is_false()
	ImpactFx._last_label = -INF
