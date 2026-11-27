extends GdUnitTestSuite
## 순신 해일검기 (사용자: "기 모을 때 방향을 잡고 쏘면 직진", "기 모으는 시간에 비례해서 강해지게"):
## 모으는 동안 잡은 방향으로 곧게 (조준 보정·유도 없음), 모은 시간 비례 피해·폭·사거리·넉백 (ChargeScaling), 마디 표시.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var enemies: Array = []


func before_test() -> void:
	enemies = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = HERO
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2.ZERO
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = HERO.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	enemies.append(e)
	return e


## 모으기 시작 → 물리 프레임 n번 (조준 따라가기).
func _charge(t: float) -> void:
	caster.on_press(0, 0.0)
	caster.tick(t, t)
	assert_int(caster.input.state).is_equal(SkillInput.State.CHARGING)
	ChargeView.tick(caster, DT)


func after_test() -> void:
	for c in get_children():
		if c is Projectile:
			remove_child(c)
			c.free()


func _fired() -> Projectile:
	for c in get_children():
		if c is Projectile and not c.is_queued_for_deletion():
			return c
	return null


## 끌어서 잡은 방향으로 곧게: 옆에 적이 있어도 그쪽으로 꺾지 않는다. 놓을 때의 작은 흔들림은 방향을 바꾸지 않는다.
func test_drag_aims_and_fires_straight() -> void:
	_enemy_at(Vector2(160, -110))  # 예전 조준 보정(±40°)이면 이쪽으로 꺾였다
	player.set_move_input(Vector2.DOWN)
	_charge(caster.input.hold_threshold + 0.5)
	player.set_move_input(Vector2.RIGHT)
	ChargeView.tick(caster, DT)
	player.set_move_input(Vector2(0.05, -0.1))  # 손 떼기 직전 작은 흔들림
	ChargeView.tick(caster, DT)
	assert_int(caster.on_release(0, caster.input.hold_threshold + 0.5)).is_equal(SkillCaster.Slot.CHARGE)
	var p := _fired()
	assert_object(p).is_not_null()
	assert_float(p.direction.angle_to(Vector2.RIGHT)).is_equal_approx(0.0, 0.001)


## 방향을 안 잡으면 모으기 시작할 때 바라보던 방향 (가장 가까운 적으로 돌리지 않는다).
func test_no_drag_uses_facing_not_nearest_enemy() -> void:
	_enemy_at(Vector2(140, 0))
	player.set_move_input(Vector2.UP)
	player.set_move_input(Vector2.ZERO)
	_charge(caster.input.hold_threshold + 0.3)
	caster.on_release(0, caster.input.hold_threshold + 0.3)
	assert_float(_fired().direction.angle_to(Vector2.UP)).is_equal_approx(0.0, 0.001)


## 바로 놓음은 예전(20·1.6배)보다 약하고, 다 모음은 예전(60·3.2배)보다 세다. 덜 모은 중간은 직선보다 약하다 (끝으로 가파른 곡선).
func test_scaling_min_weaker_max_stronger() -> void:
	var h: HaeilSkill = HERO.kit.charge
	var s := h.charge_scaling
	assert_object(s).is_not_null()
	assert_int(s.damage_at(h.min_damage, h.max_damage, 0.0)).is_less(20)
	assert_int(s.damage_at(h.min_damage, h.max_damage, 1.0)).is_greater(60)
	assert_float(s.between(h.min_scale, h.max_scale, 0.0)).is_less(1.6)
	assert_float(s.between(h.min_scale, h.max_scale, 1.0)).is_greater(3.2)
	assert_float(s.between(0.0, 1.0, 0.5)).is_less(0.5)
	var prev := -1.0
	for i in 11:  # 모을수록 사거리·넉백·연출이 줄지 않는다
		var c := i / 10.0
		var v := s.at(s.reach, c) + s.at(s.knockback, c) + s.at(s.fx, c)
		assert_float(v).is_greater_equal(prev)
		prev = v


## 다 모은 물결: 피해·폭·사거리·넉백이 다 크다. 길 표시 길이 = 물결이 실제로 가는 거리.
func test_full_charge_wave_and_path_length() -> void:
	var h: HaeilSkill = HERO.kit.charge
	var lo := caster.cast(SkillCaster.Slot.CHARGE, 0.0).get_meta(&"projectile") as Projectile
	var hi := caster.cast(SkillCaster.Slot.CHARGE, 1.0).get_meta(&"projectile") as Projectile
	var rlo := WaveRake.of(lo)  # 긁기: 피해·넉백은 타마다 나뉜다 (합으로 비교)
	var rhi := WaveRake.of(hi)
	assert_int(rhi.total_damage()).is_greater(rlo.total_damage())
	assert_float(hi.size_scale).is_greater(lo.size_scale)
	assert_float(hi.speed * hi.lifetime).is_greater(lo.speed * lo.lifetime)  # 가는 거리 (다 모으면 빨라 수명은 짧다, speed_size_power)
	assert_float(hi.speed).is_greater(lo.speed)
	assert_float(rhi.total_push()).is_greater(rlo.total_push())
	assert_int(rhi.damages.size()).is_greater(rlo.damages.size())  # 모을수록 타수도
	var front := (-0.6 + h.hit_body.end.x) * h.wave_art_size.x  # 판정 캡슐 앞 끝 (물결 가운데 앞, 크기배)
	assert_float(ChargeView.scaled(h).aim_length(1.0)).is_equal_approx(hi.speed * hi.lifetime + front * hi.size_scale, 0.5)
	assert_float(ChargeView.scaled(h).aim_length(0.0)).is_equal_approx(lo.speed * lo.lifetime + front * lo.size_scale, 0.5)
	assert_float(h.aim_width(1.0)).is_greater(h.aim_width(0.0))


## 길 폭 = 실제로 맞는 폭 (판정 캡슐 지름 × 물결 크기, 물결 몸통 = 판정). 성장 단계(시작 0.75배)에서도 그린 길과 판정이 같다.
func test_path_width_matches_wave_with_growth() -> void:
	for c in [0.0, 1.0]:
		var p := caster.cast(SkillCaster.Slot.CHARGE, c).get_meta(&"projectile") as Projectile
		var cap: Array = p.body_capsule()
		assert_float(ChargeView.aim_width(caster, c)).is_equal_approx(float(cap[2]) * 2.0 * p.size_scale, 0.01)


func test_stages() -> void:
	var s := ChargeScaling.new()
	s.stages = 3
	assert_int(s.stage_of(0.0)).is_equal(0)
	assert_int(s.stage_of(0.34)).is_equal(1)
	assert_int(s.stage_of(0.67)).is_equal(2)
	assert_int(s.stage_of(0.99)).is_equal(2)
	assert_int(s.stage_of(1.0)).is_equal(3)


## 마디를 넘으면 고리가 잠깐 커지고, 다 차면 번쩍. 마디 표시는 그려도 오류가 없다.
func test_marker_stage_pulse_and_full_flash() -> void:
	var m := ChargeMarker.new(HERO.charge_marker)
	m.tick(DT, true, 0.1, Vector2.ZERO, 0, 3)
	assert_float(m.pulse_left()).is_equal(0.0)
	m.tick(DT, true, 0.4, Vector2.ZERO, 1, 3)
	assert_float(m.pulse_left()).is_greater(0.0)
	assert_bool(m.tick(DT, true, 1.0, Vector2.ZERO, 3, 3)).is_true()
	assert_float(m.flash_left()).is_greater(0.0)
	m.tick(DT, false, 0.0, Vector2.ZERO, 0, 3)
	assert_int(m.stage()).is_equal(0)


## 길 표시를 그리는 동안 오류 없음 (실제 캔버스에서).
func test_aim_path_draws() -> void:
	player.set_move_input(Vector2.LEFT)
	_charge(caster.input.hold_threshold + 0.2)
	caster.queue_redraw()
	await get_tree().process_frame
	assert_bool(caster.aim.active).is_true()
	assert_float(caster.aim.aim_dir().x).is_less(-0.99)
	caster.cancel_input()


## 다른 셋도 모으며 조준 (2026-11-24 "모으면서도 다 싹"), 다만 끌지 않으면 예전 자동 (charge_aim_auto). 마디는 계단.
func test_other_heroes_unchanged() -> void:
	assert_bool(HERO.kit.charge.charge_aim_auto).is_false()  # 순신 해일검기는 늘 잡은 방향
	for id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_bool(h.kit.charge.charge_aim).is_true()
		assert_bool(h.kit.charge.charge_aim_auto).is_true()
		assert_bool(h.kit.charge.charge_scaling.stepped).is_true()


## 조준 길 끝 = 물결 판정(캡슐) 앞 끝이 마지막으로 닿는 곳 (독립 검토: 조준 길이 #212 캡슐 판정보다 짧았다). 강화 단계도.
func test_aim_path_ends_where_the_wave_hit_ends() -> void:
	for lv in [0, 3, 6]:
		caster.kit.charge.vfx_level = lv
		for c in [0.0, 0.5, 1.0]:
			var p := caster.cast(SkillCaster.Slot.CHARGE, c).get_meta(&"projectile") as Projectile
			caster.reset_cooldown(SkillCaster.Slot.CHARGE)
			var cap: Array = p.body_capsule()
			var reach := p.speed * p.lifetime + ((cap[1] as Vector2).x + float(cap[2])) * p.size_scale
			var drawn: float = ChargeView.scaled(caster.kit.charge).aim_length(c)
			assert_float(drawn).override_failure_message("lv%d c%.1f drawn %.0f reach %.0f" % [lv, c, drawn, reach]) 				.is_equal_approx(reach, 2.0)
			var w: float = ChargeView.aim_width(caster, c)
			assert_float(w).is_equal_approx(float(cap[2]) * 2.0 * p.size_scale, 0.5)
	caster.kit.charge.vfx_level = 0


## 물결은 꼬리(뒤 날·잔상)까지 exit_px 너머로 빠져나간 뒤 사라진다 (사용자 53582c6 "중간에 뚝 사라져 버려"). 강화 단계도.
func test_wave_flies_until_its_tail_leaves_the_screen() -> void:
	var h: HaeilSkill = caster.kit.charge
	for lv in [0, 6]:
		h.vfx_level = lv
		for c in [0.0, 1.0]:
			var p := caster.cast(SkillCaster.Slot.CHARGE, c).get_meta(&"projectile") as Projectile
			caster.reset_cooldown(SkillCaster.Slot.CHARGE)
			var tail_end := p.speed * p.lifetime - p.art_size.x * h.tail_lengths * p.size_scale  # 꼬리 끝이 간 거리
			assert_float(tail_end).override_failure_message("lv%d c%.1f tail %.0f" % [lv, c, tail_end]).is_greater_equal(h.exit_px - 1.0)
	h.vfx_level = 0
