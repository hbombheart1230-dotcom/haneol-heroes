extends GdUnitTestSuite
## 쿨타임 중 모으기 (사용자 7ce32eb 결정 (c)): 모으기 기술이 아직 쿨타임일 때 꾹 누르면 고리는 흐리게, 고리 아래에 남은 시간
## (숫자만), 입자·다 찬 번쩍임은 없고, 떼면 아무것도 안 나간다 (그대로). 네 영웅 공통. 붉은 인주색(적 위험 전용) 안 씀.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const DT := 1.0 / 60.0

var player: Player
var caster: SkillCaster
var started: Array = []


func _setup(id: String) -> void:
	started = []
	var hero: HeroData = load("res://data/heroes/%s.tres" % id)
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = hero
	add_child(player)
	player.set_physics_process(false)
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = hero.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.hit_stop_enabled = false
	caster.enemy_source = func() -> Array: return []
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: started.append(s))


func after_test() -> void:
	for c in get_children():
		if c is Projectile:
			remove_child(c)
			c.free()


## 꾹 눌러 full초 모은다 (물리 프레임마다 표시 진행). 반환: 다 찬 번쩍임이 났는지.
func _hold(seconds: float) -> bool:
	caster.on_press(0, 0.0)
	var t := 0.0
	var flashed := false
	while t < seconds:
		t += DT
		caster.tick(DT, t)
		ChargeView.tick(caster, DT)
		flashed = flashed or caster._marker().flash_left() > 0.0
	return flashed


func test_wait_text_is_numbers_only() -> void:
	assert_str(ChargeMarker.wait_text(3.2)).is_equal("4")
	assert_str(ChargeMarker.wait_text(1.0)).is_equal("1")
	assert_str(ChargeMarker.wait_text(0.44)).is_equal("0.4")
	assert_str(ChargeMarker.wait_text(0.01)).is_equal("0.1")
	var re := RegEx.create_from_string("^[0-9.]+$")
	for left in [5.0, 2.5, 0.9, 0.05]:
		assert_object(re.search(ChargeMarker.wait_text(left))).is_not_null()


## 쿨타임 중: 흐린 고리 + 남은 시간, 번쩍임 없음, 떼면 안 나감. 다 기다린 뒤엔 보통 모으기.
func test_holding_on_cooldown_shows_wait_and_release_does_nothing() -> void:
	for id in HEROES:
		_setup(id)
		caster.cast(SkillCaster.Slot.CHARGE)  # 막 썼다 → 쿨타임
		started.clear()
		var flashed := _hold(caster.input.hold_threshold + 1.6)  # 다 찰 만큼
		var m := caster._marker()
		assert_bool(caster.is_charging()).is_true()
		assert_bool(m.waiting()).override_failure_message(id + " not waiting").is_true()
		assert_float(m.wait).is_equal_approx(caster.cooldown_left(SkillCaster.Slot.CHARGE), 0.05)
		assert_bool(flashed).override_failure_message(id + " full flash while on cooldown").is_false()
		assert_int(caster.on_release(0, caster.input.hold_threshold + 1.6)).is_equal(SkillCaster.Slot.NONE)
		assert_array(started).is_empty()
		caster.reset_cooldown(SkillCaster.Slot.CHARGE)
		flashed = _hold(caster.input.hold_threshold + 1.6)
		assert_bool(caster._marker().waiting()).is_false()
		assert_bool(flashed).override_failure_message(id + " no full flash when ready").is_true()
		assert_int(caster.on_release(0, caster.input.hold_threshold + 1.6)).is_equal(SkillCaster.Slot.CHARGE)


## 글자·흐림 색: 한지색 + 먹 테두리, 붉은 인주색 아님 (적 위험 전용).
func test_wait_colors_avoid_seal_red() -> void:
	for id in HEROES:
		var md: ChargeMarkerData = (load("res://data/heroes/%s.tres" % id) as HeroData).charge_marker
		assert_float(md.wait_dim).is_between(0.1, 0.6)
		for col in [md.wait_color, md.wait_outline]:
			assert_bool(col.r - col.g > 0.3).override_failure_message(id + " red text").is_false()
