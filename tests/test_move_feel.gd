extends GdUnitTestSuite
## 이동 무게감(영웅별 가속·감속), 근접 반동, 영웅 동작 자연스럽게 (방향 붙잡기·달리기 속도·자동 공격 동작).

const DT := 1.0 / 60.0
const HERO := preload("res://data/heroes/sejong.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var player: Player


func before_test() -> void:
	player = auto_free(Player.new())


func test_no_accel_time_means_instant() -> void:
	player.set_move_input(Vector2.RIGHT)
	assert_float(player.compute_velocity(DT).x).is_equal(player.move_speed)


func test_accel_and_decel_take_their_time() -> void:
	player.move_accel_time = 0.1
	player.move_decel_time = 0.05
	player.set_move_input(Vector2.RIGHT)
	var v1 := player.compute_velocity(DT)
	assert_float(v1.x).is_greater(0.0)
	assert_float(v1.x).is_less(player.move_speed)
	for i in 6:
		player.compute_velocity(DT)
	assert_float(player.compute_velocity(DT).x).is_equal_approx(player.move_speed, 0.01)
	player.set_move_input(Vector2.ZERO)
	assert_float(player.compute_velocity(DT).x).is_greater(0.0)  # 바로 서지 않음
	for i in 4:
		player.compute_velocity(DT)
	assert_vector(player.compute_velocity(DT)).is_equal(Vector2.ZERO)


func test_dash_end_skips_accel() -> void:
	player.move_accel_time = 0.5
	player.dash_glide_time = 0.0
	player.set_move_input(Vector2.RIGHT)
	player.request_dash(Vector2.RIGHT)
	for i in 20:
		player.compute_velocity(DT)
	assert_float(player.walk_velocity().x).is_equal_approx(player.move_speed, 0.01)


func test_apply_hero_reads_accel() -> void:
	player.apply_hero(HERO)
	assert_float(player.move_accel_time).is_equal(HERO.move_accel_time)
	assert_float(player.move_decel_time).is_equal(HERO.move_decel_time)


func test_recoil_moves_player_back_briefly() -> void:
	player.apply_recoil(Vector2(-4, 0))
	var moved := 0.0
	for i in 10:
		moved += player.compute_velocity(DT).x * DT
	assert_float(moved).is_equal_approx(-4.0, 0.01)


func test_melee_hit_recoils_player() -> void:
	add_child(player)
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = player
	a.data = BasicAttackData.new()
	a.data.melee_recoil = 5.0
	add_child(a)
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(60, 0)
	a.tick(DT, [e])
	assert_float(player._recoil_vel.x).is_less(0.0)


func test_sticky_direction_ignores_jitter_at_border() -> void:
	var sheet := SpriteSheetSet.new()
	# 0번(오른쪽)과 1번(오른쪽 아래) 경계 22.5° 근처에서 떨림
	var cur := sheet.dir_index_sticky(Vector2.RIGHT, -1)
	assert_int(cur).is_equal(0)
	for deg in [20.0, 25.0, 28.0, 21.0, 30.0]:
		cur = sheet.dir_index_sticky(Vector2.RIGHT.rotated(deg_to_rad(deg)), cur)
		assert_int(cur).is_equal(0)
	cur = sheet.dir_index_sticky(Vector2.RIGHT.rotated(deg_to_rad(40.0)), cur)
	assert_int(cur).is_equal(1)
	assert_int(sheet.dir_index_sticky(Vector2.ZERO, 3)).is_equal(3)


func _view() -> PlayerView:
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = HERO
	var v := PlayerView.new()
	v.player = player
	player.add_child(v)
	add_child(player)
	return v


func test_auto_swing_does_not_break_run() -> void:
	var v := _view()
	player.set_move_input(Vector2.RIGHT)
	v._on_auto_swing(Vector2.RIGHT, 1)
	assert_str(v.current_anim()).is_equal("run")
	player.set_move_input(Vector2.ZERO)
	for i in 30:
		player.compute_velocity(DT)
	v._on_auto_swing(Vector2.RIGHT, 1)
	assert_str(v.current_anim()).is_equal("attack")


func test_run_anim_speed_follows_real_speed() -> void:
	var v := _view()
	player.set_move_input(Vector2.RIGHT)
	player.compute_velocity(DT)  # 가속 시작
	assert_float(v.run_anim_speed()).is_equal(Feedback.feel_data().run_anim_min)
	for i in 30:
		player.compute_velocity(DT)
	assert_float(v.run_anim_speed()).is_equal_approx(1.0, 0.01)


func test_idle_anim_plays_slower_than_baked() -> void:
	var v := _view()
	assert_str(v.current_anim()).is_equal("idle")
	v._update_sprite(DT)
	assert_float(v._sprite.speed_scale).is_equal_approx(Feedback.feel_data().idle_anim_speed, 0.001)
	assert_float(Feedback.feel_data().idle_anim_speed).is_less(1.0)
