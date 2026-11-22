extends GdUnitTestSuite
## 연타 흐름 (A·B안): 타별 박자·모양·전진·모으기, 캔슬 구간, 연타 사이 마지막 자세 유지, 같은 동작 처음부터,
## 세종 원거리 연타 (하나 → 둘 → 큰 하나), 1·2·3타가 한 연타 동작에서 이어 잘림.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0


func _player(hero: HeroData = null) -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	return p


func _attack(p: Player, d: BasicAttackData) -> AutoAttack:
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.data = d
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	add_child(a)
	a.set_physics_process(false)
	return a


func _enemy(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	return e


func test_step_values_and_step_in_limits() -> void:
	var arr := PackedFloat32Array([0.55, 0.6, 1.0])
	assert_float(ComboSteps.at(arr, 1, 9.0)).is_equal_approx(0.55, 0.0001)
	assert_float(ComboSteps.at(arr, 5, 9.0)).is_equal(1.0)  # 모자라면 마지막
	assert_float(ComboSteps.at(PackedFloat32Array(), 2, 9.0)).is_equal(9.0)
	assert_float(ComboSteps.step_in(26.0, 30.0, INF, false)).is_equal(26.0)
	assert_float(ComboSteps.step_in(40.0, 30.0, INF, false)).is_equal(30.0)  # 상한
	assert_float(ComboSteps.step_in(26.0, 30.0, 8.0, false)).is_equal(8.0)  # 적 몸 앞까지만
	assert_float(ComboSteps.step_in(26.0, 30.0, -5.0, false)).is_equal(0.0)
	assert_float(ComboSteps.step_in(26.0, 30.0, INF, true)).is_equal(0.0)  # 예고가 덮고 있으면 생략


func test_defaults_are_fast_fast_heavy() -> void:
	var d := BasicAttackData.new()
	assert_float(d.step_gap_mults[0]).is_less(d.step_gap_mults[2])
	assert_float(d.step_windup_pause[2]).is_greater(0.0)
	assert_float(d.step_arc_mults[2]).is_less(1.0)
	assert_float(d.step_range_mults[2]).is_greater(1.0)
	assert_float(d.step_trail_flip[1]).is_equal(-1.0)


## 손 평타는 앞으로 조금 나가고 (적 몸 앞에서 멈춤), 적 예고가 영웅을 덮고 있으면 나가지 않는다.
func test_manual_hit_steps_in_unless_in_danger() -> void:
	var p := _player()
	var d := BasicAttackData.new()
	var a := _attack(p, d)
	var far := _enemy(Vector2(200, 0))
	a.manual_strike(3, false, [far])
	assert_float(p._recoil_vel.length()).is_greater(0.0)
	assert_float(p._recoil_vel.normalized().x).is_greater(0.9)
	var p2 := _player()
	var a2 := _attack(p2, d)
	var e := _enemy(Vector2(60, 0))
	e.target = p2
	e.attack.state = EnemyAttack.State.WINDUP
	e.attack.aim_origin = e.global_position
	e.attack.aim_dir = Vector2.LEFT
	e.attack.target_point = Vector2.ZERO
	a2.manual_strike(1, false, [e])
	assert_float(p2._recoil_vel.length()).is_equal(0.0)


## 캔슬 구간: 칼이 닿은 직후 cancel_after초 안에는 다음 손 평타를 받지 않는다.
func test_cancel_window_after_contact() -> void:
	var p := _player()
	var d := BasicAttackData.new()
	d.melee_delay = 0.0
	d.cancel_after = 0.06
	var a := _attack(p, d)
	a.manual_strike(1, false, [_enemy(Vector2(50, 0))])
	assert_bool(a.can_manual(0.0)).is_false()
	a.tick(0.07, [])
	assert_bool(a.can_manual(0.0)).is_true()


## 3타 모양: 좁고 길다 — 1타에 맞던 옆 적을 3타는 못 맞히고, 1타가 못 닿던 먼 적을 3타는 맞힌다.
func test_third_hit_is_narrow_and_long() -> void:
	var p := _player()
	var d := BasicAttackData.new()
	d.melee_delay = 0.0
	d.step_in_enabled = false
	d.step_windup_pause = PackedFloat32Array()
	var a := _attack(p, d)
	var side := _enemy(Vector2(60, 0).rotated(deg_to_rad(55)))
	var far := _enemy(Vector2(d.melee_range * 1.1, 0))
	var hp_side := side.health.current
	var hp_far := far.health.current
	a.chain_step = 0
	a._melee(Vector2.ZERO, Vector2.RIGHT, [side, far], 1)
	assert_int(side.health.current).is_less(hp_side)
	assert_int(far.health.current).is_equal(hp_far)
	hp_side = side.health.current
	a._melee(Vector2.ZERO, Vector2.RIGHT, [side, far], 3)
	assert_int(side.health.current).is_equal(hp_side)
	assert_int(far.health.current).is_less(hp_far)


## 3타 앞 모으기만큼 피해가 늦게 들어간다.
func test_third_hit_waits_for_windup_pause() -> void:
	var p := _player()
	var d := BasicAttackData.new()
	d.melee_delay = 0.0
	d.step_in_enabled = false
	var a := _attack(p, d)
	var e := _enemy(Vector2(50, 0))
	var hp := e.health.current
	a._melee(Vector2.ZERO, Vector2.RIGHT, [e], 3)
	assert_int(e.health.current).is_equal(hp)
	assert_float(a.step_pause()).is_greater(0.0)
	for i in ceili(a.step_pause() / DT) + 1:
		a.tick(DT, [e])
	assert_int(e.health.current).is_less(hp)


## 세종식 원거리 연타: 1번 하나, 2번 둘(퍼짐), 3번 큰 하나 (피해·글자 크기 배율).
func test_ranged_steps_one_two_big() -> void:
	var p := _player()
	var d := BasicAttackData.new()
	d.release_delay = 0.0
	d.ranged_glyphs = "ㄱ"
	var a := _attack(p, d)
	var shots: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: shots.append(pr))
	a.manual_strike(1, true, [])
	assert_int(shots.size()).is_equal(1)
	a.manual_strike(2, true, [])
	assert_int(shots.size()).is_equal(3)
	assert_float(absf((shots[1] as Projectile).direction.angle_to((shots[2] as Projectile).direction))).is_greater(0.05)
	a.manual_strike(3, true, [])
	var big: Projectile = shots[3]
	assert_int(big.damage).is_greater(d.ranged_damage)
	assert_int(big.glyph_px).is_greater(d.glyph_px)


## 연타 사이: 공격 동작이 끝나도 combo_hold_time 동안 마지막 자세 (대기 자세로 튀지 않음), 그 뒤 대기.
func test_view_holds_follow_through_then_idles() -> void:
	var p := _player(YI)
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	v.play_oneshot("attack", 0.1)
	v._update_sprite(0.2)
	assert_str(v.current_anim()).is_equal("attack")
	v._update_sprite(Feedback.feel_data().combo_hold_time + 0.05)
	assert_str(v.current_anim()).is_equal("idle")


## 같은 이름 동작이 연달아 와도 처음 칸부터 다시.
func test_same_anim_restarts_from_first_frame() -> void:
	var p := _player(YI)
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	v.play_oneshot("attack", 0.4)
	v._update_sprite(DT)
	v._sprite.frame = 4
	v.play_oneshot("attack", 0.4)
	v._update_sprite(DT)
	assert_int(v._sprite.frame).is_equal(0)


## 1·2·3타는 한 연타 동작에서 이어 잘린다 (1타 끝 = 2타 시작, 순신·광개토·사임당).
func test_hits_are_contiguous_cuts_of_one_combo() -> void:
	for h in ["yi_sun_sin", "gwanggaeto", "shin_saimdang"]:
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/ai3d/heroes/%s.json" % h))
		var cut := {}
		for a in cfg["anims"]:
			cut[a["key"]] = a
		assert_str(cut["attack"]["clip_of"]).is_equal(cut["attack2"]["clip_of"])
		assert_str(cut["attack2"]["clip_of"]).is_equal(cut["attack3"]["clip_of"])
		assert_float(absf(float(cut["attack"]["end"]) - float(cut["attack2"]["start"]))).is_less(0.06)


## 대시 중에는 탭 전진을 얹지 않는다 (Codex 0f4456f).
func test_no_step_in_while_dashing() -> void:
	var p := _player()
	var d := BasicAttackData.new()
	d.step_in_enabled = true
	var a := _attack(p, d)
	a._step_in(Vector2.RIGHT * 200.0, [], 3)
	assert_float(p._recoil_left).is_greater(0.0)  # 평소엔 전진
	p._recoil_left = 0.0
	assert_bool(p.request_dash(Vector2.RIGHT)).is_true()
	a._step_in(Vector2.RIGHT * 200.0, [], 3)
	assert_float(p._recoil_left).is_equal(0.0)
