extends GdUnitTestSuite
## 내닫기 생김새 나누기 (사용자 A안: "치는 내닫기와 피하는 내닫기가 보기에 구분이 안 간다", 네 영웅 공통):
## 치는 = 내지르는 자세 한 칸 + 칼 궤적 + 타격 효과, 금테 없음 / 피하는 = 낮춘 자세 한 칸 + 잔상 + 금테, 궤적 없음.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang", "sejong"]
const DT := 1.0 / 60.0


func after_test() -> void:
	BossSim.reset_globals()


func _player(id: String) -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = load("res://data/heroes/%s.tres" % id)
	add_child(p)
	p.set_physics_process(false)
	return p


func _enemy(at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = at
	e.health.max = 9999
	e.health.current = 9999
	return e


## 네 영웅 모두 자세 두 개가 시트에 있는 동작·칸이고 (새 동작 없음), 서로 다르다.
func test_every_hero_has_two_existing_poses() -> void:
	for id: String in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		var d := h.dash_look
		assert_object(d).override_failure_message(id).is_not_null()
		for po: Array in [d.pose(true), d.pose(false)]:
			assert_bool(h.sprite_sheet.has_anim(String(po[0]))).override_failure_message("%s %s" % [id, po[0]]).is_true()
			assert_int(int(po[1])).is_between(0, h.sprite_sheet.frame_count(String(po[0])) - 1)
		assert_bool(d.pose(true) == d.pose(false)).override_failure_message(id).is_false()


## 순신: 적 쪽 = 치는 내닫기 (내지르는 칸, 금테 없음), 반대쪽 = 피하는 내닫기 (낮춘 칸, 금테).
func test_yi_strike_and_evade_poses_and_rim() -> void:
	var p := _player("yi_sun_sin")
	var view := PlayerView.new()
	view.player = p
	p.add_child(view)
	_enemy(Vector2(150, 0))
	await get_tree().physics_frame
	var rim := _child(view, EvadeRim) as EvadeRim
	assert_object(rim).is_not_null()
	p.request_dash(Vector2.RIGHT)
	assert_bool(DashLook.is_strike(p)).is_true()
	var sheet := p.hero.sprite_sheet
	assert_str(DashDirection.anim(p, sheet)).is_equal(String(p.hero.dash_look.strike_anim))
	assert_int(DashLook.pose_frame(p, sheet)).is_equal(p.hero.dash_look.strike_frame)
	view._update_sprite(DT)
	assert_float(view._sprite.speed_scale).is_equal(0.0)  # 그 칸에 붙잡음 (3D면 같은 시각에 멈춤)
	if view._sprite.sprite_frames.get_frame_count(view._sprite.animation) > 1:  # 구운 그림
		assert_int(view._sprite.frame).is_equal(p.hero.dash_look.strike_frame)
	assert_float(rim.strength()).is_equal(0.0)
	for i in 12:
		p._physics_process(DT)
	assert_bool(p.is_dashing()).is_false()
	for i in 40:  # 연속 대시 간격 뒤
		p._physics_process(DT)
	p.global_position = Vector2.ZERO  # 첫 대시가 몹을 지나갔다: 다시 몹 왼쪽에서 반대쪽으로
	p.request_dash(Vector2.LEFT)
	assert_bool(DashLook.is_evade(p)).is_true()
	assert_str(DashDirection.anim(p, sheet)).is_equal(String(p.hero.dash_look.evade_anim))
	assert_int(DashLook.pose_frame(p, sheet)).is_equal(p.hero.dash_look.evade_frame)
	assert_float(rim.strength()).is_equal(p.hero.dash_look.evade_rim)


## 네 영웅 모두 치는 내닫기 (사용자 승인 2026-11-24): 적 쪽 = 내지르는 칸, 반대쪽 = 피하는 칸.
func test_other_heroes_strike_toward_and_evade_away() -> void:
	for id: String in ["gwanggaeto", "shin_saimdang", "sejong"]:
		var p := _player(id)
		_enemy(p.global_position + Vector2(150, 0))
		await get_tree().physics_frame
		p.request_dash(Vector2.RIGHT)
		assert_bool(DashLook.is_strike(p)).override_failure_message(id).is_true()
		assert_int(DashLook.pose_frame(p, p.hero.sprite_sheet)).is_equal(p.hero.dash_look.strike_frame)
		var q := _player(id)
		_enemy(q.global_position + Vector2(150, 0))
		await get_tree().physics_frame
		q.request_dash(Vector2.LEFT)
		assert_bool(DashLook.is_evade(q)).override_failure_message(id).is_true()
		assert_int(DashLook.pose_frame(q, q.hero.sprite_sheet)).is_equal(q.hero.dash_look.evade_frame)


## 잔상은 피하는 내닫기에만 남고, 치는 내닫기에는 없다. 영웅 회피의 지나간 길 띠는 끈다.
func test_afterimages_only_on_evade() -> void:
	var p := _player("yi_sun_sin")
	var view := PlayerView.new()
	view.player = p
	p.add_child(view)
	_enemy(Vector2(150, 0))
	await get_tree().physics_frame
	var fx := _child(view, DashLookFx) as DashLookFx
	assert_object(fx).is_not_null()
	p.request_dash(Vector2.RIGHT)  # 치는
	for i in 6:
		p._physics_process(DT)
		fx._process(DT)
	assert_int(fx.live_count()).is_equal(0)
	if p.dash_runner:
		assert_bool(p.dash_runner.draw_path).is_false()
	for i in 12:
		p._physics_process(DT)
		fx._process(DT)
	p.global_position = Vector2.ZERO
	p.request_dash(Vector2.LEFT)  # 피하는
	for i in 5:
		view._update_sprite(DT)
		p._physics_process(DT)
		fx._process(DT)
	assert_int(fx.live_count()).is_greater(1)
	await get_tree().process_frame  # 그려도 오류 없음


func _child(n: Node, cls: Variant) -> Node:
	for c in n.get_children():
		if is_instance_of(c, cls):
			return c
	return null
