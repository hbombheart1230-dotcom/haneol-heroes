extends GdUnitTestSuite
## 영웅 피격·소리·흔들림 (docs/research/game_feel_benchmark.md R3·C2·D1·D2·S3).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/jurchen_soldier.tres")
const HERO := preload("res://data/heroes/sejong.tres")
const BANK := preload("res://data/audio/sfx_bank.tres")


func after_test() -> void:
	Feedback.instance = null
	GameTime.reset()


func _react() -> HitReactionData:
	return load("res://data/feel/combat_feel.tres").reaction_data()


func _player() -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = HERO
	add_child(p)
	return p


func _enemy(pos: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	return e


func test_invuln_scales_with_damage() -> void:
	var d := _react()
	assert_float(HurtResponse.invuln_for(1, 100, 0.6, d)).is_equal_approx(0.6 * lerpf(d.invuln_min_ratio, 1.0, 0.01 / d.invuln_full_hp_frac), 0.001)
	assert_float(HurtResponse.invuln_for(50, 100, 0.6, d)).is_equal_approx(0.6, 0.001)
	assert_float(HurtResponse.invuln_for(0, 100, 0.6, d)).is_equal_approx(0.6 * d.invuln_min_ratio, 0.001)


func test_breathe_impulse_falls_off() -> void:
	var d := _react()
	assert_float(HurtResponse.breathe_impulse(0.0, d)).is_equal(d.breathe_impulse)
	assert_float(HurtResponse.breathe_impulse(d.breathe_radius, d)).is_equal_approx(d.breathe_impulse * 0.5, 0.01)
	assert_float(HurtResponse.breathe_impulse(d.breathe_radius + 1.0, d)).is_equal(0.0)


## C2: 맞으면 둘레 적이 바깥으로 밀리고 (잡몹은 경직), 먼 적은 그대로. 무적은 피해 비례.
func test_hurt_pushes_nearby_enemies_and_emits() -> void:
	var p := _player()
	var near := _enemy(Vector2(40, 0))
	var far := _enemy(Vector2(400, 0))
	var got := [0]
	p.hurt.connect(func(a: int) -> void: got[0] = a)
	assert_bool(p.apply_hit(5)).is_true()
	assert_int(got[0]).is_equal(5)
	assert_float(near.knockback.x).is_greater(0.0)
	assert_bool(near.reaction.is_staggered()).is_true()
	assert_vector(far.knockback).is_equal(Vector2.ZERO)
	assert_float(p.hurt_time_left()).is_less(p.hurt_invuln_time)  # 작은 피해는 짧게
	assert_float(p.hurt_elapsed()).is_equal_approx(0.0, 0.0001)


## R3: 맞은 순간 붉게, 무적 동안 깜빡임, 무적이 끝나면 원래 색.
func test_hero_hurt_tint_flashes_then_blinks() -> void:
	var p := _player()
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	var d := _react()
	p.apply_hit(30)
	assert_object(v.hurt_tint(Color.WHITE)).is_equal(d.hero_flash_color)
	var seen_dim := false
	while p.hurt_time_left() > 0.0:
		p.apply_contact_damage(0.01, 0)  # 무적 시간만 흐르게
		if p.hurt_time_left() > 0.0 and p.hurt_elapsed() >= d.hero_flash_time and v.hurt_tint(Color.WHITE).a < 1.0:
			seen_dim = true
	assert_bool(seen_dim).is_true()
	assert_object(v.hurt_tint(Color.WHITE)).is_equal(Color.WHITE)
	assert_str(v.current_anim()).is_not_equal("hit")


func test_hurt_vignette_fades_in_real_time() -> void:
	var vg: HurtVignette = auto_free(HurtVignette.new())
	add_child(vg)
	assert_float(vg.strength()).is_equal(0.0)
	vg.flash()
	var d := _react()
	assert_float(vg.strength()).is_equal_approx(d.vignette_alpha, 0.001)
	vg.step(d.vignette_time * 0.5)
	assert_float(vg.strength()).is_equal_approx(d.vignette_alpha * 0.5, 0.001)
	vg.step(d.vignette_time)
	assert_float(vg.strength()).is_equal(0.0)


## S3: 같은 종류 최대 수, 빈 재생기, 낮은 우선순위부터 끊기, 모두 더 중요하면 안 냄.
func test_voices_priority_and_caps() -> void:
	var v := SfxVoices.new(3)
	var playing := [false, false, false]
	assert_int(v.pick(&"hit", 1, 2, 0.0, playing)).is_equal(0)
	playing[0] = true
	assert_int(v.pick(&"hit", 1, 2, 0.1, playing)).is_equal(1)
	playing[1] = true
	assert_int(v.pick(&"hit", 1, 2, 0.2, playing)).is_equal(0)  # 명중음 2개 꽉 → 가장 오래된 명중음 다시 씀
	assert_int(v.pick(&"hurt", 4, 0, 0.3, playing)).is_equal(2)
	playing[2] = true
	assert_int(v.pick(&"die", 2, 0, 0.4, playing)).is_equal(1)  # 가장 낮은(명중) 중 오래된 것
	assert_int(v.pick(&"hit", 1, 2, 0.5, playing)).is_equal(0)
	var w := SfxVoices.new(1)
	assert_int(w.pick(&"hurt", 4, 0, 0.0, [false])).is_equal(0)
	assert_int(w.pick(&"hit", 1, 0, 0.1, [true])).is_equal(-1)  # 피격음을 명중음이 끊지 않는다


func test_bank_has_priorities_and_new_hurt() -> void:
	assert_int(BANK.prio(&"hurt")).is_greater(BANK.prio(&"hit"))
	assert_int(BANK.prio(&"counter")).is_greater(BANK.prio(&"hit"))
	assert_int(BANK.max_of(&"hit")).is_greater(0)
	assert_int((BANK.sounds[&"hurt"] as Array).size()).is_greater_equal(2)
	for s in BANK.sounds[&"hurt"]:
		assert_str((s as AudioStream).resource_path).contains("hurt_")


## D1: 작은 흔들림이 사라지지 않게 지수 < 2. 기술 흔들림은 데이터에서.
func test_shake_curve_and_skill_trauma_from_data() -> void:
	var f: Feedback = auto_free(Feedback.new())
	f.sfx_enabled = false
	add_child(f)
	f.trauma = 0.35
	var biggest := 0.0
	for i in 40:
		biggest = maxf(biggest, f.shake_offset().length())
	assert_float(biggest).is_greater(pow(0.35, 2.0) * f.max_shake)  # 예전 trauma² 보다 큼
	assert_float(f.skill_trauma_for(SkillCaster.Slot.COUNTER, 0)).is_equal(f.feel.counter_trauma)
	assert_float(f.skill_trauma_for(SkillCaster.Slot.TAP, 2)).is_equal(f.feel.skill_trauma)
	assert_float(f.skill_trauma_for(SkillCaster.Slot.TAP, 0)).is_equal(f.feel.skill_trauma_miss)


## D2: 진동은 Android 권장대로 짧게 (탭 10–20ms, 강한 것 30–50ms).
func test_haptics_are_short() -> void:
	var d: CombatFeelData = load("res://data/feel/combat_feel.tres")
	assert_int(d.haptic_impact_ms).is_less_equal(20)
	assert_int(d.haptic_hurt_ms).is_less_equal(50)
	assert_int(d.haptic_finisher_ms).is_less_equal(50)
