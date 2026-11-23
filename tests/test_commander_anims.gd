extends GdUnitTestSuite
## 한산 대장 새 동작 (PR #109 시트): 돌진 = charge (되풀이, 예고로 칸을 고르지 않음), 충격파 = slam (맞닿는 칸까지 예고),
## 단계 전환 한 박자 = shout (BossFeelData.phase_anim, BossStaging.on_phase → EnemySprite.show_pose).

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COMMANDER := preload("res://data/enemies/waegun_commander.tres")


func after_test() -> void:
	EnemyAttack.clock = Callable()
	EnemyAttack.active_windups = 0


func _all(d: EnemyData) -> Array:
	var out: Array = d.patterns.duplicate()
	for ph: BossPhaseData in d.phases:
		out.append_array(ph.patterns)
	var i := 0
	while i < out.size():
		var a: EnemyAttackData = out[i]
		i += 1
		if a.follow_up and not out.has(a.follow_up):
			out.append(a.follow_up)
	return out


func test_charges_use_charge_and_shockwaves_use_slam() -> void:
	var sheet := COMMANDER.sprite_sheet
	for a: EnemyAttackData in _all(COMMANDER):
		if a.kind == EnemyAttackData.Kind.CHARGE:
			assert_str(String(a.anim)).is_equal("charge")
		elif a.kind == EnemyAttackData.Kind.SHOCKWAVE:
			assert_str(String(a.anim)).is_equal("slam")
		assert_bool(sheet.has_anim(String(a.anim))).is_true()
	assert_bool(sheet.is_loop("charge")).is_true()  # 돌진은 그냥 돈다
	assert_bool(sheet.is_loop("slam")).is_false()  # 땅 찍기는 예고로 칸을 고른다
	assert_bool(sheet.has_anim(String(COMMANDER.boss_feel.phase_anim))).is_true()


func test_pose_shows_for_its_time_then_ends() -> void:
	var t := [10.0]
	EnemyAttack.clock = func() -> float: return t[0]
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = COMMANDER
	add_child(auto_free(e))
	e.set_physics_process(false)
	EnemySprite.show_pose(e, &"shout", 1.8)
	assert_str(EnemySprite.pose_anim(e)).is_equal("shout")
	EnemySprite.update(e, false)
	assert_str(String(e.sprite.animation)).starts_with("shout_")
	t[0] = 12.0
	assert_str(EnemySprite.pose_anim(e)).is_equal("")
	EnemySprite.show_pose(e, &"no_such_clip", 1.0)  # 시트에 없으면 아무것도 안 한다
	assert_str(EnemySprite.pose_anim(e)).is_equal("")
