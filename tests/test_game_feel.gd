extends GdUnitTestSuite
## 2단계 타격감: 화면 흔들림, 데미지 숫자, 임시 효과음, 피격 반응.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func after_test() -> void:
	Feedback.instance = null


func _feedback() -> Feedback:
	var f: Feedback = auto_free(Feedback.new())
	f.camera = auto_free(Camera2D.new())
	add_child(f.camera)
	f.fx = auto_free(FxLayer.new())
	add_child(f.fx)
	f.sfx_enabled = false
	add_child(f)
	return f


func test_synth_makes_every_sound() -> void:
	for kind in SfxSynth.DURATIONS.keys():
		var s := SfxSynth.make(kind)
		assert_object(s).is_instanceof(AudioStreamWAV)
		assert_int(s.data.size()).is_equal(int(float(SfxSynth.DURATIONS[kind]) * SfxSynth.RATE) * 2)


func test_static_calls_are_safe_without_instance() -> void:
	Feedback.instance = null
	Feedback.enemy_hit(Vector2.ZERO, 10)
	Feedback.enemy_died(null, Vector2.ZERO, 0)
	Feedback.player_hurt()
	assert_object(Feedback.instance).is_null()


func test_trauma_shakes_camera_then_settles() -> void:
	var f := _feedback()
	f.add_trauma(1.0)
	f._process(0.016)
	assert_float(f.camera.offset.length()).is_greater(0.0)
	for i in 60:
		f._process(0.016)
	assert_float(f.trauma).is_equal(0.0)
	assert_vector(f.camera.offset).is_equal(Vector2.ZERO)


func test_counter_shakes_harder_than_tap() -> void:
	var f := _feedback()
	f._on_skill_cast(SkillCaster.Slot.TAP, 3)
	var tap := f.trauma
	f.trauma = 0.0
	f._on_skill_cast(SkillCaster.Slot.COUNTER, 3)
	assert_float(f.trauma).is_greater(tap)


func test_enemy_hit_shows_damage_number() -> void:
	var f := _feedback()
	var before := f.fx.count()
	Feedback.enemy_hit(Vector2(10, 10), 25)
	assert_int(f.fx.count()).is_equal(before + 1)


func test_enemy_damage_routes_to_feedback() -> void:
	var f := _feedback()
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.health.damage(7)
	assert_int(f.fx.count()).is_equal(1)


func test_player_hurt_adds_trauma() -> void:
	var f := _feedback()
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	assert_bool(p.apply_hit(10)).is_true()
	assert_float(f.trauma).is_greater(0.3)


func test_melee_hit_pushes_enemy_back() -> void:
	var p: Player = auto_free(Player.new())
	add_child(p)
	p.global_position = Vector2.ZERO
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	add_child(a)
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(60, 0)
	a.tick(0.016, [e])
	assert_float(e.knockback.x).is_greater(0.0)


func test_sound_throttle_skips_rapid_repeats() -> void:
	var f := _feedback()
	f.sfx_enabled = true
	f.play(&"hit")
	var first: float = f._last_played[&"hit"]
	f.play(&"hit")
	assert_float(f._last_played[&"hit"]).is_equal(first)
