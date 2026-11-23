extends GdUnitTestSuite
## 연타 글씨 (사용자: "연타를 1타 2타 3타 4타 이렇게 콤보 넣는 글씨 띄웠으면"): 손 평타가 닿을 때 1·2·3, 넷째 탭 마무리에 4,
## 타수가 오를수록 크게, 연타가 끊기면 사라짐, 설정으로 끔.

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


## 타수가 오를수록 크게, 마무리(4타)가 가장 크다.
func test_sizes_grow_and_finish_is_biggest() -> void:
	var d: ComboTextData = load(ComboCounter.DATA_PATH)
	assert_int(d.labels.size()).is_equal(4)
	for i in range(1, d.sizes.size()):
		assert_int(d.sizes[i]).is_greater(d.sizes[i - 1])
	assert_str(d.labels[3]).is_equal("4타")


## 연타가 끊기면 (streak 0) 옅어져 사라지고, 마무리는 잠깐 머문 뒤 사라진다.
func test_fades_when_combo_breaks() -> void:
	var r := _rig(YI)
	var c: SkillCaster = r[2]
	var cc := _counter(c)
	c.combo.on_hit(3, 3)
	c.combo_count.emit(1)
	assert_int(cc.shown()).is_equal(1)
	cc._process(0.1)
	assert_float(cc.alpha()).is_equal(1.0)  # 아직 이어지는 중
	c.combo.tick(5.0, YI.kit.combo_window)  # 끊김
	for i in 30:
		cc._process(DT)
	assert_int(cc.shown()).is_equal(0)
	c.combo_count.emit(4)
	assert_int(cc.shown()).is_equal(4)
	cc._process(0.3)
	assert_float(cc.alpha()).is_equal(1.0)  # 마무리는 finish_hold 동안 머문다
	for i in 90:
		cc._process(DT)
	assert_int(cc.shown()).is_equal(0)


func test_setting_turns_it_off() -> void:
	var cc := _counter()
	GameSettings.combo_text = false
	cc.show_count(2)
	assert_int(cc.shown()).is_equal(0)
	GameSettings.combo_text = true
	cc.show_count(2)
	assert_int(cc.shown()).is_equal(2)
	assert_bool(SettingsScreen.ROWS.has(&"combo_text")).is_true()


## 실제 장면에서 그려도 오류 없음.
func test_draws_in_tree() -> void:
	var cc := _counter()
	for n in [1, 2, 3, 4]:
		cc.show_count(n)
		await get_tree().process_frame
	assert_int(cc.shown()).is_equal(4)


## 사용자 A안: 글 뒤 먹 띠 없음 (회색 상자로 보였다), 한지색 글 + 먹 테두리 = 피해 숫자와 같은 색.
func test_outline_only_like_damage_numbers() -> void:
	var d: ComboTextData = load(ComboCounter.DATA_PATH)
	var im := ImpactFeelData.new()
	assert_float(d.stroke_mult).is_equal(0.0)
	assert_bool(d.color.is_equal_approx(im.number_color)).is_true()
	assert_bool(Color(d.outline, 1.0).is_equal_approx(Color(im.number_outline_color, 1.0))).is_true()
	assert_int(d.outline_px).is_greater(0)
