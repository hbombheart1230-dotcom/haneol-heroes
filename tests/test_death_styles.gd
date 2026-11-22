extends GdUnitTestSuite
## 속성별 처치 모습 (DeathStyleData, DeathFx, DeathCause)과 보상 종류별 국악 소리 (RewardFx).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func test_each_hero_has_an_element() -> void:
	var d := DeathStyleData.get_default()
	assert_str(String(d.element_of(&"yi_sun_sin"))).is_equal("water")
	assert_str(String(d.element_of(&"gwanggaeto"))).is_equal("thunder")
	assert_str(String(d.element_of(&"sejong"))).is_equal("glyph")
	assert_str(String(d.element_of(&"shin_saimdang"))).is_equal("ink")
	assert_str(String(d.element_of(&"nobody"))).is_equal("")


func test_default_art_is_reused() -> void:
	var d := DeathStyleData.get_default()
	assert_int(d.water_parts.size()).is_equal(6)
	assert_int(d.ash_parts.size()).is_equal(6)
	assert_object(d.water_stain).is_not_null()
	assert_object(d.star_art).is_not_null()


func test_big_kill_is_bigger_than_small() -> void:
	var d := DeathStyleData.new()
	assert_int(d.count(6, true)).is_greater(d.count(6, false))
	assert_float(d.size_k(true)).is_greater(d.size_k(false))
	assert_float(d.time_k(true)).is_greater(d.time_k(false))
	for el in [&"water", &"thunder", &"glyph", &"ink"]:
		var small: DeathFx = auto_free(DeathFx.new(d))
		var big: DeathFx = auto_free(DeathFx.new(d))
		small.burst(Vector2.ZERO, el, false)
		big.burst(Vector2.ZERO, el, true)
		assert_int(big.bit_count() + big.mark_count()).is_greater_equal(small.bit_count() + small.mark_count())


func test_every_element_spawns_and_clears() -> void:
	var fx: DeathFx = auto_free(DeathFx.new(DeathStyleData.get_default()))
	for el in [&"water", &"thunder", &"glyph", &"ink"]:
		fx.burst(Vector2.ZERO, el, true)
	assert_int(fx.bit_count() + fx.mark_count()).is_greater(0)
	fx.step(5.0)
	assert_int(fx.bit_count()).is_equal(0)
	assert_int(fx.mark_count()).is_equal(0)


func test_pool_is_capped() -> void:
	var d := DeathStyleData.new()
	d.max_bits = 10
	d.max_marks = 3
	var fx: DeathFx = auto_free(DeathFx.new(d))
	for i in 20:
		fx.burst(Vector2.ZERO, &"water", true)
		fx.burst(Vector2.ZERO, &"thunder", true)
	assert_int(fx.bit_count()).is_less_equal(10)
	assert_int(fx.mark_count()).is_less_equal(3)


func test_big_kill_rule() -> void:
	var feel := CombatFeelData.new()
	var e: Enemy = ENEMY_SCENE.instantiate()
	add_child(auto_free(e))
	assert_bool(DeathCause.is_big(e, 10, false, feel)).is_false()  # 평타 처치: 담백하게
	assert_bool(DeathCause.is_big(e, feel.big_hit_damage, false, feel)).is_true()  # 센 피해 (기술·강타)
	assert_bool(DeathCause.is_big(e, 10, true, feel)).is_true()  # 정예·보스 마무리
	e.heavy_pending = true
	assert_bool(DeathCause.is_big(e, 10, false, feel)).is_true()  # 근접 3타 강타


func test_no_element_without_feedback() -> void:
	assert_str(String(DeathCause.element_of(null))).is_equal("")
	assert_bool(DeathCause.burst(null, null, 10, false)).is_false()


func test_kill_fx_none_style_skips_army_bits() -> void:
	var k: KillFx = auto_free(KillFx.new())
	k.death_burst(Vector2.ZERO, &"none")
	assert_int(k.bit_count()).is_equal(1)  # 먹 자국만 (연기·종이 없음)
	k.death_burst(Vector2.ZERO, &"smoke")
	assert_int(k.bit_count()).is_greater(2)


func test_reward_sounds_exist_in_bank() -> void:
	var bank: SoundBank = load("res://data/audio/sfx_bank.tres")
	for kind in [&"gugak_bang", &"gugak_buk", &"gugak_jing"]:
		assert_bool(bank.has(kind)).is_true()
	assert_float(bank.db(&"gugak_bang")).is_less(bank.db(&"hit"))  # 방울은 타격음보다 작게
	var r := RewardFx.new()
	assert_str(String(r.reward_sfx)).is_equal("gugak_bang")
	assert_float(r.sfx_gap).is_greater(0.0)
	r.free()
