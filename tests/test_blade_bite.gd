extends GdUnitTestSuite
## 무기가 몹에 박히는 느낌 (역경직, 사용자 A안 다섯 가지): 접점 장면에서 멈춤, 떨림, 풀리며 빨라짐·밀림, 소리 두 겹, 검기.
## 휘두름 한 번에 멈춤 한 번, 멈춤 중 대시는 풀릴 때, 연타 간격 안에 들어간다 (순신만).

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()
	SkillHitStop.reset()
	BladeBite.reset()


func _rig(hero: HeroData = YI, count: int = 1) -> Array:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	p.contact = SheetContact.new(hero.sprite_sheet, hero.blade_bite.clip_contact if hero.blade_bite else {})
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = hero.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	var enemies: Array = []
	for i in count:
		var e: Enemy = ENEMY_SCENE.instantiate()
		e.data = SOLDIER
		add_child(auto_free(e))
		e.set_physics_process(false)
		e.global_position = Vector2(70, -30 + i * 30)
		e.health.max = 9999
		e.health.current = 9999
		enemies.append(e)
	return [p, a, enemies]


## 1. 피해 시점 = 클립의 접점 시각 ÷ swing_speed (예전에는 0.15초로 잘려 칼이 닿기 전 장면 = 세 타 모두 2번 칸에서 멈췄다).
## 순신 1·2타는 시트 맞닿는 칸이 칼을 든 칸이라 데이터로 칼이 몸에 닿는 칸 (1타 4번 0.25초, 2타 5번 0.3125초).
func test_damage_lands_on_contact_frame() -> void:
	var r := _rig()
	var a: AutoAttack = r[1]
	var sheet := YI.sprite_sheet
	var over := YI.blade_bite.clip_contact
	for anim in ["attack", "attack2", "attack3"]:
		a.chain_step = 1 if anim == "attack" else int(anim.right(1))
		var i := sheet.anim_names.find(anim)
		var want: float = over[StringName(anim)] if over.has(StringName(anim)) else sheet.strike_frame(anim) / sheet.fps[i]
		var speed := YI.blade_bite.swing_speed  # 평타 동작을 이 배율로 틀어 칼이 일찍 닿는다 (그림도 같은 배율)
		assert_float(a.melee_delay()).is_equal_approx(want / speed, 0.0001)
		assert_int(int(a.melee_delay() * speed * sheet.fps[i] + 0.001)).is_greater_equal(3)  # 칼을 든 앞 칸(0~2)에서 멈추지 않는다
	a.chain_step = 1
	# 사용자 판 피드백 (순신 연타가 두 영웅보다 약하다): 1·2타가 광개토·사임당과 같은 0.15초에 닿는다 (예전 0.19초)
	assert_float(a.melee_delay()).is_less_equal(Feedback.feel_data().melee_delay_max)  # 사용자: 순신 1·2타 사이 정적 → 휘두르기 조금 더 빠르게 (1.35, 0.14초)


## 다른 영웅은 그대로 (데이터가 없으면 꺼짐).
func test_other_heroes_off() -> void:
	for id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_object(h.blade_bite).is_null()
	assert_object(YI.blade_bite).is_not_null()


## 2. 휘두름 한 번에 멈춤 한 번: 세 마리를 같이 베어도 영웅·몹 모두 같은 길이 (1타 0.02초), 몹은 고르게 떤다.
func test_one_stop_per_swing_for_hero_and_all_hit() -> void:
	var r := _rig(YI, 3)
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	a.manual_strike(3, false, r[2])  # 쾌검: 박힘은 3타에만 (1·2타 0)
	for i in 60:
		if p.bite.active():
			break
		a.tick(DT, r[2])
	assert_bool(p.bite.active()).is_true()
	assert_float(p.bite.left()).is_equal_approx(YI.blade_bite.stop_for(3), 0.0001)
	assert_bool(BladeBite.is_biting()).is_true()
	for e in r[2]:
		var en: Enemy = e
		assert_float(en._freeze_left).is_greater_equal(YI.blade_bite.stop_for(3) - 0.0001)  # 박힘보다 긴 피해 멈춤이면 그쪽 (max)
		assert_float(en._bite_px).is_equal(YI.blade_bite.jitter_px)
	assert_float(absf(p.bite.jitter().x)).is_equal(YI.blade_bite.jitter_px)


func test_heavy_third_hit_stops_longer() -> void:
	assert_float(YI.blade_bite.stop_for(3)).is_greater(YI.blade_bite.stop_for(1))
	assert_float(YI.blade_bite.stop_for(3)).is_equal_approx(0.06, 0.001)  # 쾌검 (사용자 2026-11-24): 1·2타 멈춤 없음, 3타·4타만 살짝
	assert_float(YI.blade_bite.stop_for(1)).is_equal(0.0)
	assert_float(YI.blade_bite.stop_for(2)).is_equal(0.0)
	assert_float(YI.blade_bite.finisher_stop).is_equal_approx(0.06, 0.001)


## 쾌검: 1·2타는 칼이 박히지 않고 지나간다 (멈춤 없이 다음 타로). 그림도 일반 역경직으로 돌아가 멈추지 않는다.
func test_light_hits_do_not_bite() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	var view := PlayerView.new()
	view.player = p
	p.add_child(view)
	view.set_physics_process(false)
	var stops: Array = []
	a.melee_swung.connect(func(_d: Vector2, _n: int) -> void: stops.append(view._hitstop_left))
	a.manual_strike(1, false, r[2])
	for i in 30:
		a.tick(DT, r[2])
	assert_bool(p.bite.active()).is_false()
	assert_array(stops).is_not_empty()
	assert_float(float(stops[0])).is_equal(0.0)


## 3. 멈춤 → 밀림: 멈춘 동안 몹은 제자리, 풀린 뒤에 밀린다. 영웅 동작은 멈춤 0 → 풀림 빠르게 → 평소.
func test_push_after_stop_and_release_speedup() -> void:
	var r := _rig()
	var p: Player = r[0]
	var a: AutoAttack = r[1]
	var e: Enemy = r[2][0]
	a.manual_strike(3, false, r[2])
	while not p.bite.active():
		a.tick(DT, r[2])
	var at := e.global_position
	assert_float(p.bite.anim_speed()).is_equal(0.0)
	await get_tree().physics_frame
	e._physics_process(DT)
	assert_vector(e.global_position).is_equal(at)  # 멈춘 동안 밀리지 않는다
	var released := [false]
	p.bite.released.connect(func() -> void: released[0] = true)
	var speed := 1.0
	for i in 10:
		p.compute_velocity(DT)
		e._physics_process(DT)
		if released[0]:
			speed = p.bite.anim_speed()  # 풀린 그 프레임 (박힘이 짧으면 빠른 구간도 짧다: release_time)
			break
	assert_bool(released[0]).is_true()
	assert_float(speed).is_equal(YI.blade_bite.release_speed)
	for i in 6:
		e._physics_process(DT)
	assert_float(e.global_position.distance_to(at)).is_greater(1.0)  # 풀린 뒤 밀림


## 풀리며 빨라짐이 멈춘 시간을 그대로 되찾는다 → 한 번 휘두르는 길이가 늘지 않는다.
func test_release_wins_back_the_stop() -> void:
	var b := YI.blade_bite
	for s in [1, 2, 3]:
		var stop := b.stop_for(s)
		assert_float(b.release_time(stop) * (b.release_speed - 1.0)).is_equal_approx(stop, 0.001)


## 연타 리듬 측정: 타마다 (접점 + 멈춤)이 다음 탭 간격 안 → 멈춤을 간격에 더하지 않아도 칼이 먼저 박히고 풀린다.
func test_stop_fits_inside_tap_gap() -> void:
	var r := _rig()
	var a: AutoAttack = r[1]
	var d := YI.attack
	for step in [1, 2, 3]:
		a.chain_step = step
		var next: int = step % d.chain_len + 1
		var gap := d.melee_interval * ComboSteps.at(d.step_gap_mults, next, YI.kit.tap_min_gap_mult)
		var busy := a.melee_delay() + a.step_pause() + YI.blade_bite.stop_for(step)
		assert_float(busy).is_less(gap)


## 조작감: 멈춘 중 대시는 기억했다가 풀릴 때 바로.
func test_dash_buffered_until_release() -> void:
	var r := _rig()
	var p: Player = r[0]
	p.bite.start(YI.blade_bite, 0.05)
	assert_bool(p.request_dash(Vector2.LEFT)).is_true()
	assert_bool(p.is_dashing()).is_false()
	assert_bool(p.bite.dash_pending()).is_true()
	for i in 4:
		p.compute_velocity(DT)
	assert_bool(p.is_dashing()).is_true()
	assert_float(p.get_dash_direction().x).is_less(-0.9)


## 게임 시간이 멈춘 중(기술·처치 멈춤)엔 칼 멈춤을 겹쳐 걸지 않는다.
func test_no_bite_on_top_of_global_stop() -> void:
	var p: Player = _rig()[0]
	GameTime.stop(get_tree(), 0.2)
	assert_bool(p.bite.start(YI.blade_bite, 0.05)).is_false()


## 넷째 탭 마무리: 기술 명중 멈춤이 finisher_stop 하나로 (간격 규칙과 피해 공식 대신).
func test_finisher_stop_forced() -> void:
	SkillHitStop.force_next(0.1)
	SkillHitStop.request(get_tree(), 15)
	await get_tree().process_frame
	assert_bool(GameTime.is_stopped()).is_true()
	var left := GameTime._stop_until_ms - Time.get_ticks_msec()
	assert_int(left).is_between(60, 110)
