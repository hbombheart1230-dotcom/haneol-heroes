extends GdUnitTestSuite
## 연타 글씨 (사용자: "연타를 1타 2타 3타 4타 이렇게 콤보 넣는 글씨 띄웠으면", 뒤에 "어느 것으로든 맞히면 계속 올라가게"):
## 탭 연타 수(combo_count)는 1·2·3, 마무리 4 그대로 (점수), 글씨는 모든 명중마다 오르고 연타 유지 시간 뒤 바로 0, 설정으로 끔.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SEJONG := preload("res://data/heroes/sejong.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()
	GameSettings.combo_text = true
	for n in get_children():  # 마무리 기술이 남긴 투사체·글자 (다음 테스트의 프레임에서 사라진 적을 찾지 않게)
		if n is Projectile or n is OrbitGlyphs or n is DamageZone:
			remove_child(n)
			n.free()


func _rig(hero: HeroData, enemy_at := Vector2(80, 0)) -> Array:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	var a := AutoAttack.new()
	a.name = "AutoAttack"
	a.player = p
	a.data = hero.attack
	a.projectile_scene = PROJECTILE_SCENE
	a.projectile_parent = self
	p.add_child(a)
	a.set_physics_process(false)
	var c := SkillCaster.new()
	c.name = "SkillCaster"
	c.player = p
	c.kit = hero.kit
	c.projectile_scene = PROJECTILE_SCENE
	c.world = self
	var enemies: Array = []
	c.enemy_source = func() -> Array: return enemies
	p.add_child(c)
	c.set_physics_process(false)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = enemy_at
	e.health.max = 9999
	e.health.current = 9999
	enemies.append(e)
	return [p, a, c, enemies]


## 네 번 탭: 닿을 때마다 1·2·3, 마무리 4.
func _four_taps(r: Array) -> Array:
	var a: AutoAttack = r[1]
	var c: SkillCaster = r[2]
	var got: Array = []
	c.combo_count.connect(func(n: int) -> void: got.append(n))
	var t := 0.0
	for i in 4:
		var guard := 0
		while not a.can_manual(c.tap_gap()) and guard < 240:
			t += DT
			a.tick(DT, r[3])
			c.tick(DT, t)
			guard += 1
		c.combo_tap()
	for i in 60:
		t += DT
		a.tick(DT, r[3])
		c.tick(DT, t)
	return got


func test_melee_taps_count_one_to_four() -> void:
	assert_array(_four_taps(_rig(YI))).is_equal([1, 2, 3, 4])


## 헛친 평타는 세지 않는다 (맞을 때마다).
func test_whiff_does_not_count() -> void:
	var r := _rig(YI, Vector2(2000, 0))
	var c: SkillCaster = r[2]
	var got: Array = []
	c.combo_count.connect(func(n: int) -> void: got.append(n))
	c.combo_tap()
	for i in 40:
		(r[1] as AutoAttack).tick(DT, r[3])
		c.tick(DT, i * DT)
	assert_array(got).is_empty()


## 원거리 평타 영웅 (세종 글자 던지기)도 세어진다.
func test_ranged_taps_count() -> void:
	var got := _four_taps(_rig(SEJONG, Vector2(200, 0)))
	assert_array(got).contains([1, 2, 3])
	assert_int(got[got.size() - 1]).is_equal(4)


func _counter(c: SkillCaster = null) -> ComboCounter:
	var cc: ComboCounter = auto_free(ComboCounter.new())
	cc.caster = c
	add_child(cc)
	cc.size = Vector2(720, 1280)
	return cc


## 어떤 명중이든 (칼·내닫기 타격·기술: Feedback.enemy_hit 피해 > 0) 하나씩 오르고 4타에서 멈추지 않는다.
func test_any_hit_counts_past_four() -> void:
	var cc := _counter()
	for i in 6:
		Feedback.enemy_hit(Vector2.ZERO, 5)
		cc._process(DT)
	assert_int(cc.count()).is_equal(6)
	assert_int(cc.shown()).is_equal(6)
	Feedback.enemy_hit(Vector2.ZERO, 0)  # 막힌 타 (피해 0)는 세지 않는다
	cc._process(DT)
	assert_int(cc.count()).is_equal(6)


## 연타 유지 시간 동안 못 맞히면 숫자는 바로 0, 글은 옅어져 사라지고 다음 명중은 1타부터.
func test_resets_to_zero_after_break_time() -> void:
	var r := _rig(YI)
	var cc := _counter(r[2])
	Feedback.enemy_hit(Vector2.ZERO, 5)
	Feedback.enemy_hit(Vector2.ZERO, 5)
	cc._process(DT)
	assert_float(cc.break_time()).is_equal(YI.kit.combo_window)
	cc._process(YI.kit.combo_window - 0.1)
	assert_int(cc.count()).is_equal(2)  # 아직 이어지는 중
	cc._process(0.2)
	assert_int(cc.count()).is_equal(0)  # 칼같이 0
	for i in 30:
		cc._process(DT)
	assert_int(cc.shown()).is_equal(0)
	Feedback.enemy_hit(Vector2.ZERO, 5)
	cc._process(DT)
	assert_int(cc.shown()).is_equal(1)


## 다단 타격이 몰아쳐도 한 타마다 오르되 매번 튀지 않고, 글자 크기는 상한에서 멈춘다 (화면을 덮지 않게).
func test_multi_hit_counts_each_without_covering_screen() -> void:
	var d: ComboTextData = load(ComboCounter.DATA_PATH)
	var cc := _counter()
	Feedback.enemy_hit(Vector2.ZERO, 5)
	cc._process(DT)
	cc._process(d.pop_time)  # 첫 튐이 끝난 뒤
	Feedback.enemy_hit(Vector2.ZERO, 5)
	Feedback.enemy_hit(Vector2.ZERO, 5)
	cc._process(DT)
	assert_int(cc.count()).is_equal(3)
	assert_float(cc._age).is_greater(d.pop_time)  # 다시 튀지 않았다
	assert_int(ComboCounter.size_for(2, false, d)).is_greater(ComboCounter.size_for(1, false, d))
	assert_int(ComboCounter.size_for(50, false, d)).is_equal(d.size_max)
	assert_int(d.size_max).is_less(ComboCounter.size_for(1, true, d) + 1)
	assert_str(d.label_format % 12).is_equal("12타")


## 넷째 탭 마무리 동안은 인주색 (finish_hold), 그 뒤 다시 한지색.
func test_finisher_tints_while_counting_on() -> void:
	var d: ComboTextData = load(ComboCounter.DATA_PATH)
	var r := _rig(YI)
	var c: SkillCaster = r[2]
	var cc := _counter(c)
	Feedback.enemy_hit(Vector2.ZERO, 5)
	c.combo_count.emit(YI.kit.combo_hits + 1)
	cc._process(DT)
	assert_bool(cc.finishing()).is_true()
	cc._process(d.finish_hold)
	assert_bool(cc.finishing()).is_false()


func test_setting_turns_it_off() -> void:
	var cc := _counter()
	GameSettings.combo_text = false
	Feedback.enemy_hit(Vector2.ZERO, 5)
	cc._process(DT)
	assert_int(cc.shown()).is_equal(0)
	GameSettings.combo_text = true
	Feedback.enemy_hit(Vector2.ZERO, 5)
	cc._process(DT)
	assert_int(cc.shown()).is_equal(2)
	assert_bool(SettingsScreen.ROWS.has(&"combo_text")).is_true()


## 실제 장면에서 그려도 오류 없음.
func test_draws_in_tree() -> void:
	var cc := _counter()
	for n in 5:
		Feedback.enemy_hit(Vector2.ZERO, 5)
		await get_tree().process_frame
	assert_int(cc.shown()).is_equal(5)


## 사용자 A안: 글 뒤 먹 띠 없음 (회색 상자로 보였다), 한지색 글 + 먹 테두리 = 피해 숫자와 같은 색.
func test_outline_only_like_damage_numbers() -> void:
	var d: ComboTextData = load(ComboCounter.DATA_PATH)
	var im := ImpactFeelData.new()
	assert_float(d.stroke_mult).is_equal(0.0)
	assert_bool(d.color.is_equal_approx(im.number_color)).is_true()
	assert_bool(Color(d.outline, 1.0).is_equal_approx(Color(im.number_outline_color, 1.0))).is_true()
	assert_int(d.outline_px).is_greater(0)
