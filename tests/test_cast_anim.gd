extends GdUnitTestSuite
## 기술 시전 동작: 기술마다 영웅 시트의 제 동작 (cast_*), 맞닿는 칸 바로 앞에서 시작, 연타 자세 유지·3타 멈춤보다 우선,
## 충전 중엔 모으는 자세, 시트에 없으면 예전처럼 attack.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const DT := 1.0 / 60.0


## 영웅 + 기술 + 그림 (기술 신호가 그림에 이어지게 SkillCaster를 먼저 붙인다).
func _rig(hero: HeroData) -> Array:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	var c := SkillCaster.new()
	c.name = "SkillCaster"
	c.player = p
	c.projectile_scene = PROJECTILE_SCENE
	c.world = self
	c.enemy_source = func() -> Array: return []
	p.add_child(c)
	add_child(p)
	c.set_physics_process(false)
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	v.set_physics_process(false)
	return [p, c, v]


func test_start_frame_is_just_before_strike() -> void:
	assert_int(CastAnim.start_frame(5, 20.0, 0.06, 8)).is_equal(3)  # 0.06초 × 20 = 1.2칸 → 두 칸 앞
	assert_int(CastAnim.start_frame(1, 20.0, 0.2, 8)).is_equal(0)  # 앞으로 넘치면 첫 칸
	assert_int(CastAnim.start_frame(5, 20.0, -1.0, 8)).is_equal(0)  # 음수 = 처음부터 (휘감기)
	assert_int(CastAnim.start_frame(-1, 20.0, 0.06, 8)).is_equal(0)


func test_missing_anim_falls_back_to_attack() -> void:
	var c := CastAnim.of(null, YI.sprite_sheet)
	assert_str(c.anim).is_equal("attack")
	assert_float(c.seconds).is_equal(CastAnim.FALLBACK_TIME)
	var d := SkillDef.new()
	d.cast_anim = &"no_such_anim"
	assert_str(CastAnim.of(d, YI.sprite_sheet).anim).is_equal("attack")


## 네 영웅 모두 기술 넷이 제 시전 동작을 갖고, 그 동작이 시트에 구워져 있다 (서로 다른 동작).
func test_every_hero_skill_has_its_own_baked_cast_anim() -> void:
	for id in HEROES:
		var hd: HeroData = load("res://data/heroes/%s.tres" % id)
		var seen := {}
		for slot in ["tap", "dash", "charge", "counter"]:
			var d: SkillDef = hd.kit.get(slot)
			assert_str(String(d.cast_anim)).override_failure_message("%s %s" % [id, slot]).is_equal("cast_" + slot)
			assert_bool(hd.sprite_sheet.has_anim(String(d.cast_anim))).override_failure_message(id + " " + slot).is_true()
			var c := CastAnim.of(d, hd.sprite_sheet)
			assert_float(c.seconds).is_between(0.1, 0.8)
			seen[c.anim] = true
		assert_int(seen.size()).is_equal(4)


## 3타 직후 마무리(해룡참): 연타 자세·3타 멈춤을 끊고 cast_tap을 첫 칸부터, 끝나면 자세 유지 뒤 대기.
func test_finisher_overrides_combo_hold_and_hitstop() -> void:
	var r := _rig(YI)
	var c: SkillCaster = r[1]
	var v: PlayerView = r[2]
	v.play_oneshot("attack3", 0.05)
	v._update_sprite(0.1)  # 3타 끝 → 마지막 자세 유지 중
	v._hitstop_left = 0.2
	assert_str(v.current_anim()).is_equal("attack3")
	c.cast(SkillCaster.Slot.TAP)
	assert_float(v._hitstop_left).is_equal(0.0)
	v._update_sprite(DT)
	assert_str(v.current_anim()).is_equal("cast_tap")
	assert_int(v._sprite.frame).is_equal(0)  # 해룡참 = 처음부터 (cast_lead < 0)
	assert_float(v._sprite.speed_scale).is_greater(0.0)
	v._update_sprite(CastAnim.of(YI.kit.tap, YI.sprite_sheet).seconds + 0.01)
	assert_str(v.current_anim()).is_equal("cast_tap")  # 마무리 자세 잠깐 유지
	v._update_sprite(Feedback.feel_data().combo_hold_time + 0.05)
	assert_str(v.current_anim()).is_equal("idle")


## 파도격: 맞닿는 칸 바로 앞 칸부터 (피해는 누르는 순간).
func test_dash_skill_starts_near_strike_frame() -> void:
	var r := _rig(YI)
	var v: PlayerView = r[2]
	(r[1] as SkillCaster).cast(SkillCaster.Slot.DASH)
	v._update_sprite(DT)
	assert_str(v.current_anim()).is_equal("cast_dash")
	var strike := YI.sprite_sheet.strike_frame("cast_dash")
	assert_int(v._sprite.frame).is_between(maxi(strike - 2, 0), strike)


## 충전: 모으는 동안 cast_charge 첫 칸에 멈춤, 떼면 그 동작이 맞닿는 칸 앞에서 이어진다.
## 3D(PlayerView3D)와 구운 그림 둘 다 (hh/art/live3d). 3D는 칸 대신 동작 시각으로 맞닿는 칸 앞부터 튼다.
func test_charge_holds_gather_pose_then_releases() -> void:
	for live in [true, false]:
		_charge_case(live)


func _charge_case(live: bool) -> void:
	var was: Variant = ProjectSettings.get_setting("hh/art/live3d", true)
	ProjectSettings.set_setting("hh/art/live3d", live)
	var r := _rig(YI)
	ProjectSettings.set_setting("hh/art/live3d", was)
	var c: SkillCaster = r[1]
	var v: PlayerView = r[2]
	c.on_press(0, 0.0)
	c.tick(DT, c.kit.hold_threshold + 0.05)
	assert_bool(c.is_charging()).is_true()
	v._update_sprite(DT)
	assert_str(v.current_anim()).is_equal("cast_charge")
	assert_int(v._sprite.frame).is_equal(0)
	assert_float(v._sprite.speed_scale).is_equal(0.0)
	c.on_release(0, c.kit.hold_threshold + 0.5)
	v._update_sprite(DT)
	assert_str(v.current_anim()).is_equal("cast_charge")
	var rig: Node = v.get("rig")
	assert_bool(rig != null).is_equal(live)
	if rig:
		assert_str(rig.body_anim()).is_equal("cast_charge")
		assert_float(rig.last_seek()).is_greater(0.0)
		assert_float(rig.body_speed()).is_greater(0.0)
	else:
		assert_int(v._sprite.frame).is_greater(0)
	assert_float(v._sprite.speed_scale).is_greater(0.0)
