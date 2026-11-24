extends GdUnitTestSuite
## 강화 패 짝 (SynergyDef): 두 패를 다 가져야 켜지고, 순신 견본 "젖은 바다" — 파도격에 젖은 적에게 해일검기 1.5배.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const WET := preload("res://data/upgrades/synergies/yi_sun_sin_wet.tres")


func after_test() -> void:
	SynergyState.reset()
	SkillHitStop.reset()
	GameTime.reset()


func _pick(id: StringName) -> UpgradeDef:
	for u in YI.upgrade_pool.upgrades:
		if u.id == id:
			return u
	return null


func _enemy() -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.health.max = 99999
	e.health.current = 99999
	return e


func _ctx(skill_id: StringName) -> SkillContext:
	var ctx := SkillContext.new()
	ctx.hit_stop_enabled = false
	ctx.skill = SkillDef.new()
	ctx.skill.id = skill_id
	return ctx


func _dealt(en: Enemy, skill_id: StringName, dmg: int) -> int:
	var before := en.health.current
	_ctx(skill_id).hit(en, dmg, false)
	return before - en.health.current


func test_pool_carries_wet_synergy_needing_both_cards() -> void:
	assert_bool(YI.upgrade_pool.synergies.has(WET)).is_true()
	assert_bool(WET.met({&"pado_more": 1})).is_false()
	assert_bool(WET.met({&"haeil_big": 2})).is_false()
	assert_bool(WET.met({&"pado_more": 1, &"haeil_big": 1})).is_true()
	assert_bool(_pick(&"pado_more") != null and _pick(&"haeil_big") != null).is_true()


func test_run_build_turns_synergy_on_only_with_both() -> void:
	var b := RunBuild.new()
	b.hero = YI.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as HeroData
	SynergyState.reset()
	b.apply(_pick(&"pado_more"))
	assert_bool(SynergyState.is_active(&"yi_wet_tide")).is_false()
	b.apply(_pick(&"haeil_big"))
	assert_bool(SynergyState.is_active(&"yi_wet_tide")).is_true()
	b.begin(null, null, null)  # 다음 판: 비운다
	assert_bool(SynergyState.is_active(&"yi_wet_tide")).is_false()


func test_wet_enemy_takes_more_haeil_damage() -> void:
	var en := _enemy()
	await get_tree().process_frame
	SynergyState.refresh(YI.upgrade_pool, {&"pado_more": 1, &"haeil_big": 1})
	var plain := _dealt(en, &"haeil", 40)  # 젖기 전
	assert_int(plain).is_greater(0)
	assert_bool(WET.effect.marked(en)).is_false()
	_dealt(en, &"pado", 10)  # 파도격에 맞아 젖음
	assert_bool(WET.effect.marked(en)).is_true()
	var wet := _dealt(en, &"haeil", 40)
	assert_float(float(wet) / plain).is_equal_approx(1.5, 0.05)
	assert_int(_dealt(en, &"haeryong", 40)).is_equal(plain)  # 다른 기술은 그대로


func test_no_bonus_without_synergy() -> void:
	var en := _enemy()
	await get_tree().process_frame
	var plain := _dealt(en, &"haeil", 40)
	_dealt(en, &"pado", 10)
	assert_bool(WET.effect.marked(en)).is_false()
	assert_int(_dealt(en, &"haeil", 40)).is_equal(plain)
