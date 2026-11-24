extends GdUnitTestSuite
## 모으며 조준 넓히기 (사용자 2026-11-24 "모으면서도 다 싹"): 광개토 낙뢰·세종 성좌진·사임당 화폭을 실제 터치로 꾹 눌러 모으고 끌면
## 그 방향·자리가 중심, 끌지 않으면 예전 자동. 모으는 중 걷지 않고 (#125) 조준 표시는 성장 배율이 든 판정 그대로 (#95).

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const HEAVY := preload("res://data/enemies/heavy.tres")
const HEROES := ["gwanggaeto", "sejong", "shin_saimdang"]
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var ctrl: TouchController
var enemies: Array = []


func _setup(id: String) -> void:
	enemies = []
	var hero: HeroData = load("res://data/heroes/%s.tres" % id)
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = hero
	add_child(player)
	player.global_position = Vector2.ZERO
	player.facing = Vector2.RIGHT
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = hero.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)
	ctrl = auto_free(TouchController.new())
	ctrl.player = player
	ctrl.skill_caster = caster


func after_test() -> void:
	for c in get_children():
		if c is Projectile or c is WaveRake or c is DamageZone:
			remove_child(c)
			c.free()
	EnemyAttack.active_windups = 0


func _enemy_at(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = HEAVY
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	e.health.max = 9999
	e.health.current = 9999
	enemies.append(e)
	return e


func _touch(p: Vector2, t: float, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = pressed
	ctrl.handle_event(e, t)


func _drag(p: Vector2, t: float) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	ctrl.handle_event(e, t)


func _step(t: float) -> void:
	caster.tick(DT, t)
	ChargeView.tick(caster, DT)  # 게임에선 SkillCaster._physics_process가 (조준 따라가기)
	ctrl._physics_process(DT)
	player.compute_velocity(DT)


## 꾹 눌러 모으고 (drag면 왼쪽으로 끌며) 놓는다. 그 뒤 박자 타격까지 돌린다.
func _charge_and_release(drag: bool) -> void:
	var at := Vector2(400, 900)
	_touch(at, 0.0, true)
	var t := 0.0
	for i in 24:
		t += DT
		_step(t)
	assert_bool(caster.is_charging()).is_true()
	if drag:
		for i in 30:
			t += DT
			at = Vector2(400 - i * 5, 900)
			_drag(at, t)
			_step(t)
			assert_vector(player.walk_velocity()).is_equal(Vector2.ZERO)  # 끌기는 조준만 (#125)
		assert_bool(caster.aim.steered).is_true()
	else:
		for i in 30:
			t += DT
			_step(t)
		assert_bool(caster.aim.steered).is_false()
	_touch(at, t + DT, false)
	for i in 90:
		for n in get_children():
			if n is WaveRake and not n.is_queued_for_deletion():
				(n as WaveRake)._physics_process(DT)
		caster.tick(DT, t + DT * (i + 2))


func _hurt(e: Enemy) -> bool:
	return e.health.current < e.health.max


## 낙뢰: 끌면 끈 쪽 자리 둘레 적부터, 끌지 않으면 예전처럼 영웅에 가장 가까운 적부터 (벼락 1개 = 덜 모음).
func test_lightning_drag_picks_the_dragged_spot() -> void:
	_setup("gwanggaeto")
	var near_right := _enemy_at(Vector2(90, 0))
	var left := _enemy_at(Vector2(-240, 0))
	_charge_and_release(true)
	assert_bool(_hurt(left)).is_true()
	assert_bool(_hurt(near_right)).is_false()
	_setup("gwanggaeto")
	near_right = _enemy_at(Vector2(90, 0))
	left = _enemy_at(Vector2(-240, 0))
	_charge_and_release(false)
	assert_bool(_hurt(near_right)).is_true()  # 예전 자동


## 성좌진: 끌면 끈 쪽으로 별자리, 끌지 않으면 예전처럼 앞쪽 (조준 보정).
func test_constellation_drag_turns_the_stars() -> void:
	_setup("sejong")
	var left := _enemy_at(Vector2(-80, 0))
	var right := _enemy_at(Vector2(80, 0))
	_charge_and_release(true)
	assert_bool(_hurt(left)).is_true()
	assert_bool(_hurt(right)).is_false()


## 화폭: 끌면 화폭 가운데가 끈 쪽으로 옮겨 간다, 끌지 않으면 영웅 자리.
func test_canvas_drag_moves_the_scroll() -> void:
	_setup("shin_saimdang")
	var skill: CanvasSkill = player.hero.kit.charge
	var far_left := _enemy_at(Vector2(-skill.steer_offset - 40.0, 0))
	var near_right := _enemy_at(Vector2(60, 0))
	_charge_and_release(true)
	assert_bool(far_left.is_stunned()).is_true()
	assert_bool(near_right.is_stunned()).is_false()
	_setup("shin_saimdang")
	far_left = _enemy_at(Vector2(-skill.steer_offset - 40.0, 0))
	near_right = _enemy_at(Vector2(60, 0))
	_charge_and_release(false)
	assert_bool(near_right.is_stunned()).is_true()
	assert_bool(far_left.is_stunned()).is_false()


## 조준 표시는 성장 배율이 든 사본으로 그린다 (발동과 같은 SkillGrowthData.scaled_def): 원 반경·선 폭 = 판정.
func test_aim_shape_uses_grown_values() -> void:
	for id in HEROES:
		var d: SkillDef = (load("res://data/heroes/%s.tres" % id) as HeroData).kit.charge.duplicate()
		d.vfx_level = 6  # 큰 단계 (판정 1.3배)
		var k := SkillGrowthData.get_default().size_at(d.vfx_level)
		var s := ChargeView.scaled(d)
		if d is LightningSkill:
			assert_float((s as LightningSkill).steer_radius).is_equal_approx((d as LightningSkill).steer_radius * k, 0.01)
		elif d is ConstellationSkill:
			assert_float((s as ConstellationSkill).line_width).is_equal_approx((d as ConstellationSkill).line_width * k, 0.01)
		elif d is CanvasSkill:
			assert_float((s as CanvasSkill).radius_for(1.0)).is_equal_approx((d as CanvasSkill).max_radius * k, 0.01)


## 그리기: 끌기 전엔 표시 없음 (자동), 끈 뒤엔 기술 모양 (오류 없이 실제 캔버스에서).
func test_aim_draws_after_drag() -> void:
	for id in HEROES:
		_setup(id)
		var at := Vector2(400, 900)
		_touch(at, 0.0, true)
		var t := 0.0
		for i in 24:
			t += DT
			_step(t)
		for i in 20:
			t += DT
			_drag(Vector2(400 - i * 6, 900), t)
			_step(t)
		caster.queue_redraw()
		await get_tree().process_frame
		assert_bool(caster.aim.steered).override_failure_message(id).is_true()
		caster.cancel_input()
