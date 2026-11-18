extends GdUnitTestSuite
## 한 손 제스처 스킬 + 버튼 켜기/끄기 설정 + 버튼 판정 범위.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
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
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = HERO.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_cast.connect(func(s: SkillCaster.Slot, _h: int) -> void: casts.append(s))
	ctrl = auto_free(TouchController.new())  # 트리에 넣지 않음 (설정 파일 미사용)
	ctrl.player = player
	ctrl.skill_caster = caster


func _down(i: int, p: Vector2, t: float) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = true
	ctrl.handle_event(e, t)


func _up(i: int, p: Vector2, t: float) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = false
	ctrl.handle_event(e, t)


func _drag(i: int, p: Vector2, t: float) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	ctrl.handle_event(e, t)


func _step(t: float) -> void:
	caster.tick(DT, t)
	ctrl._physics_process(DT)
	player.compute_velocity(DT)


func _cleanup_projectiles() -> void:
	for c in get_children():
		if c is Projectile:
			c.queue_free()


func test_tap_in_place_is_tap_skill() -> void:
	_down(0, Vector2(400, 900), 0.0)
	_up(0, Vector2(403, 902), 0.1)
	assert_array(casts).is_equal([SkillCaster.Slot.TAP])
	assert_bool(player.is_dashing()).is_false()


func test_drag_is_move_not_skill() -> void:
	_down(0, Vector2(400, 900), 0.0)
	var t := 0.0
	for i in 30:
		t += DT
		_drag(0, Vector2(400, 900 + i * 3), t)
		_step(t)
	assert_float(player.move_input.y).is_greater(0.5)
	_up(0, Vector2(400, 990), t + DT)
	assert_array(casts).is_empty()


func test_flick_then_tap_is_dash_skill() -> void:
	_down(0, Vector2(300, 900), 0.0)
	_up(0, Vector2(420, 900), 0.06)  # 오른쪽 플릭
	assert_bool(player.is_dashing()).is_true()
	assert_array(casts).is_empty()  # 플릭 자체는 스킬 아님
	_step(0.07)
	_down(0, Vector2(430, 900), 0.15)
	_up(0, Vector2(431, 900), 0.22)
	assert_bool(caster.is_ready(SkillCaster.Slot.DASH)).is_false()  # 즉시 발동
	for i in 20:  # 연타가 끝나면 발동 완료 신호
		caster.tick(DT, 0.22 + DT * i)
	assert_array(casts).is_equal([SkillCaster.Slot.DASH])


func test_tap_after_link_window_is_tap_skill() -> void:
	_down(0, Vector2(300, 900), 0.0)
	_up(0, Vector2(420, 900), 0.06)
	var t := 0.06
	for i in 50:  # 약 0.83초: 대시 0.16 + 연계 0.45 지남
		t += DT
		_step(t)
	_down(0, Vector2(430, 900), t)
	_up(0, Vector2(430, 900), t + 0.08)
	assert_array(casts).is_equal([SkillCaster.Slot.TAP])


func test_hold_in_place_charges_then_move_and_release_fires_charge() -> void:
	_down(0, Vector2(400, 900), 0.0)
	var t := 0.0
	for i in 24:  # 0.4초 정지 → 충전 시작 (임계 0.3)
		t += DT
		_step(t)
	assert_bool(caster.is_gesture_charging()).is_true()
	assert_vector(player.move_input).is_equal(Vector2.ZERO)
	for i in 20:  # 충전한 채 왼쪽으로 이동
		t += DT
		_drag(0, Vector2(400 - i * 6, 900), t)
		_step(t)
	assert_float(player.move_input.x).is_less(-0.5)
	assert_bool(caster.is_gesture_charging()).is_true()
	_up(0, Vector2(280, 900), t + DT)
	assert_array(casts).is_equal([SkillCaster.Slot.CHARGE])
	assert_bool(player.is_dashing()).is_false()  # 놓을 때 플릭 대시 없음
	_cleanup_projectiles()


func test_fast_release_while_charging_does_not_dash() -> void:
	_down(0, Vector2(400, 900), 0.0)
	caster.tick(0.35, 0.35)
	assert_bool(caster.is_gesture_charging()).is_true()
	_drag(0, Vector2(440, 900), 0.37)
	_up(0, Vector2(560, 900), 0.40)  # 플릭처럼 빠르게 놓기
	assert_bool(player.is_dashing()).is_false()
	assert_array(casts).is_equal([SkillCaster.Slot.CHARGE])
	_cleanup_projectiles()


func test_mid_drag_flick_still_dashes_and_no_skill() -> void:
	_down(0, Vector2(300, 900), 0.0)
	var t := 0.0
	var x := 300.0
	for i in 5:
		t += DT
		x += 30.0
		_drag(0, Vector2(x, 900), t)
	assert_bool(player.is_dashing()).is_true()
	_up(0, Vector2(x, 900), t + DT)
	assert_array(casts).is_empty()


func test_gestures_disabled_tap_does_nothing() -> void:
	ctrl.gestures_enabled = false
	_down(0, Vector2(400, 900), 0.0)
	_up(0, Vector2(400, 900), 0.1)
	assert_array(casts).is_empty()


# --- 버튼 설정 ---

func test_button_off_by_default_touch_there_moves() -> void:
	assert_bool(ctrl.skill_button_enabled).is_false()
	var btn := ctrl.skill_button_center()
	_down(0, btn, 0.0)
	assert_bool(ctrl.touch_input.is_active()).is_true()
	assert_bool(caster.input.is_from(SkillInput.Source.BUTTON)).is_false()


func test_button_hit_area_larger_than_visual() -> void:
	ctrl.skill_button_enabled = true
	var edge := ctrl.skill_button_center() + Vector2(ctrl.skill_button_radius * 1.2, 0)
	assert_bool(ctrl.is_on_skill_button(edge)).is_true()
	var outside := ctrl.skill_button_center() + Vector2(ctrl.skill_button_radius * 1.4, 0)
	assert_bool(ctrl.is_on_skill_button(outside)).is_false()


func test_toggle_area_switches_button() -> void:
	var p := ctrl.toggle_rect().get_center()
	_down(0, p, 0.0)
	assert_bool(ctrl.skill_button_enabled).is_true()
	assert_bool(ctrl.touch_input.is_active()).is_false()
	_up(0, p, 0.05)
	_down(1, p, 0.2)
	assert_bool(ctrl.skill_button_enabled).is_false()
	GameSettings.skill_button_enabled = false


func test_button_press_overrides_pending_gesture() -> void:
	ctrl.skill_button_enabled = true
	_down(0, Vector2(200, 900), 0.0)  # 이동 손가락 (제스처 판정 전)
	_down(1, ctrl.skill_button_center(), 0.05)
	assert_bool(caster.input.is_from(SkillInput.Source.BUTTON)).is_true()
	_up(1, ctrl.skill_button_center(), 0.1)
	assert_array(casts).is_equal([SkillCaster.Slot.TAP])
	_up(0, Vector2(200, 900), 0.15)  # 이동 손가락을 떼도 추가 발동 없음
	assert_array(casts).is_equal([SkillCaster.Slot.TAP])


func test_settings_save_and_load() -> void:
	# user://는 샌드박스에서 쓰기 불가일 수 있어 프로젝트 캐시 폴더를 쓴다.
	var path := "res://.godot/hh_test_settings_%d.cfg" % Time.get_ticks_usec()
	GameSettings.skill_button_enabled = true
	assert_int(GameSettings.save_settings(path)).is_equal(OK)
	GameSettings.skill_button_enabled = false
	GameSettings.load_settings(path)
	assert_bool(GameSettings.skill_button_enabled).is_true()
	GameSettings.skill_button_enabled = false
	DirAccess.remove_absolute(path)


# --- Codex edeb579 회귀 ---

func test_dead_player_releasing_pending_gesture_never_casts() -> void:
	_down(0, Vector2(300, 900), 0.0)
	player.health.damage(player.health.max)
	assert_bool(player.is_dead()).is_true()
	_up(0, Vector2(300, 900), 0.1)
	assert_array(casts).is_empty()


func test_dead_player_charge_release_never_casts() -> void:
	_down(0, Vector2(300, 900), 0.0)
	caster.tick(0.35, 0.35)
	assert_bool(caster.is_gesture_charging()).is_true()
	player.health.damage(player.health.max)
	_up(0, Vector2(300, 900), 0.5)
	assert_array(casts).is_empty()
	assert_bool(caster.input.is_down()).is_false()


func test_second_finger_on_toggle_does_not_toggle_back() -> void:
	var p := ctrl.toggle_rect().get_center()
	_down(0, p, 0.0)
	_down(1, p, 0.01)
	assert_bool(ctrl.skill_button_enabled).is_true()
	_up(1, p, 0.05)
	_up(0, p, 0.06)
	_down(2, p, 0.3)  # 손을 다 뗀 뒤 다시 누르면 정상 전환
	assert_bool(ctrl.skill_button_enabled).is_false()
	GameSettings.skill_button_enabled = false
