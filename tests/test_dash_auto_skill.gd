extends GdUnitTestSuite
## 내닫아 치기 (사용자 2026-11-24 "내닫고 떼기가 헷갈린다"): 적 쪽으로 튕겨 내닫기가 적에 닿으면 둘째 기술이 저절로,
## 빈 곳으로 튕기면 그냥 피하기. 손 떼기·내닫는 중 탭은 둘째 기술이 아니다. 쿨타임이면 돌진 타격만 (DashDirection).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HEAVY := preload("res://data/enemies/heavy.tres")
const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var ctrl: TouchController
var enemies: Array = []
var casts: Array = []


func before_test() -> void:
	enemies = []
	casts = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2.ZERO
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = HERO.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: casts.append(s))
	ctrl = auto_free(TouchController.new())
	ctrl.player = player
	ctrl.skill_caster = caster


func after_test() -> void:
	for c in get_children():
		if c is Projectile or c is DamageZone or c is WaveRake:
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


## 오른쪽으로 튕기며 손 떼기 → 내닫기를 frames틱 돌린다.
func _flick_right(frames: int = 30) -> void:
	_touch(Vector2(300, 900), 0.0, true)
	_touch(Vector2(420, 900), 0.06, false)
	assert_bool(player.is_dashing()).is_true()
	for i in frames:
		player._physics_process(DT)
		caster.tick(DT, 0.06 + DT * (i + 1))


func test_dash_through_enemy_casts_second_skill_by_itself() -> void:
	_enemy_at(Vector2(120, 0))
	_touch(Vector2(300, 900), 0.0, true)
	_touch(Vector2(420, 900), 0.06, false)
	assert_array(casts).is_empty()  # 손 떼기는 둘째 기술이 아니다
	for i in 30:
		player._physics_process(DT)
		caster.tick(DT, 0.06 + DT * (i + 1))
	assert_array(casts).is_equal([SkillCaster.Slot.DASH])  # 닿는 순간 한 번
	assert_bool(player.is_invulnerable() or not player.is_dashing()).is_true()


func test_dash_into_empty_space_is_just_an_evade() -> void:
	_enemy_at(Vector2(0, 400))  # 내닫는 길 밖
	_flick_right()
	assert_array(casts).is_empty()
	assert_bool(caster.is_ready(SkillCaster.Slot.DASH)).is_true()


func test_on_cooldown_only_the_dash() -> void:
	_enemy_at(Vector2(120, 0))
	caster.cast(SkillCaster.Slot.DASH)
	casts.clear()
	_flick_right()
	assert_array(casts).is_empty()


func test_tap_during_dash_is_not_the_second_skill() -> void:
	_flick_right(2)
	assert_int(caster.preview_slot()).is_equal(SkillCaster.Slot.TAP)
	assert_bool(caster.try_dash_release()).is_false()


## 방향 원뿔 (dash_auto_cone_deg): 켜면 내닫는 쪽 앞 적만, 끄면(0) 길에 닿기만 하면.
func test_cone_option_limits_to_enemies_ahead() -> void:
	var beside := _enemy_at(Vector2(0, 50))  # 내닫는 자리 바로 옆
	player.request_dash(Vector2.RIGHT)
	player.velocity = Vector2.RIGHT * 300.0
	assert_object(DashAutoSkill.touched(player, enemies, DT, 30.0, 0.0)).is_same(beside)
	assert_object(DashAutoSkill.touched(player, enemies, DT, 30.0, 60.0)).is_null()


func test_all_four_heroes_use_dash_auto() -> void:
	for id in ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]:
		assert_bool((load("res://data/heroes/%s.tres" % id) as HeroData).kit.dash_auto).override_failure_message(id).is_true()


## 순신만 (메인 결정 ②): 저절로 나간 파도격은 0.5배, 쿨타임 4.5초 — 내닫기만 마구 해도 떼거리에서 연타보다 빠르지 않게
## (test_dash_direction 잡몹 떼 기준, #166·#167을 합친 int/next-h에서 다시 맞춤: 0.8·3.5는 n6 s1에서 7.2초 vs 9.6초). 다른 영웅은 피해 그대로.
func test_yi_auto_dash_skill_is_damped() -> void:
	assert_float(HERO.kit.dash_auto_damage_mult).is_equal_approx(0.5, 0.001)
	assert_float(HERO.kit.dash.cooldown).is_equal_approx(4.5, 0.001)
	for id in ["gwanggaeto", "sejong", "shin_saimdang"]:
		assert_float((load("res://data/heroes/%s.tres" % id) as HeroData).kit.dash_auto_damage_mult).is_equal(1.0)
	var e := _enemy_at(Vector2(120, 0))
	_flick_right()
	assert_array(casts).is_equal([SkillCaster.Slot.DASH])
	for i in 60:
		caster.tick(DT, 1.0 + DT * i)
	var full: PadoSkill = HERO.kit.dash
	assert_int(e.health.max - e.health.current).is_less(full.hit_count * full.damage_per_hit)


## 광개토는 내닫는 쪽 90도 안의 적에만 (test_cover_sim: 경복궁 가림막 뒤에서 피하는 내닫기가 벽력돌파를 써 버려 받은 피해 0.86 → 0.51).
func test_gwanggaeto_auto_only_toward_enemies() -> void:
	assert_float((load("res://data/heroes/gwanggaeto.tres") as HeroData).kit.dash_auto_cone_deg).is_equal_approx(90.0, 0.001)
	for id in ["yi_sun_sin", "sejong", "shin_saimdang"]:
		assert_float((load("res://data/heroes/%s.tres" % id) as HeroData).kit.dash_auto_cone_deg).override_failure_message(id).is_equal(0.0)


## 한 틱 걸음이 속도 × delta보다 길어도 (내닫기 첫 박차기) 지나친 적을 놓치지 않는다: 지난 틱 자리(첫 틱은 내닫기 시작 자리)부터 본다.
func test_long_step_does_not_skip_enemy() -> void:
	var e := _enemy_at(Vector2(120, 0))
	player.request_dash(Vector2.RIGHT)
	player.velocity = Vector2.RIGHT * 300.0
	player.global_position = Vector2(400, 0)  # 한 틱에 400px: 속도 × delta(5px)로는 못 본다
	assert_object(DashAutoSkill.touched(player, enemies, DT, 30.0, 0.0)).is_null()
	assert_object(DashAutoSkill.touched(player, enemies, DT, 30.0, 0.0, Vector2.ZERO)).is_same(e)
