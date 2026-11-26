extends GdUnitTestSuite
## 주인 영웅 부르기 규칙 (HomeSummonRules)과 단추 (HomeSummonButton): 누가 주인인지, 횟수, 피해 배율, 누름.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const STAGES := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
## 화면 글에 외래어를 쓰지 않는다 (hh-korean-wording).
const LOANWORDS := ["스킬", "버튼", "보스", "레벨", "카드", "소환", "웨이브", "튜토리얼"]


## 단추가 쓰는 Main 자리만 갖춘 가짜 (실제 main 장면 없이 누름을 본다).
class FakeMain:
	extends Node
	var player: Player
	var spawner: EnemySpawner
	var heroes: Array = []
	var state := GameState.new(0.0)
	var waiting_pick := false
	var tutorial_director: TutorialDirector
	var hud: Control
	var stage: StageTheme
	var stage_id: StringName

	func run_stage_id() -> StringName:
		return stage_id

	func stage_by_id(_id: StringName) -> StageTheme:
		return stage


func _heroes() -> Array:
	var out: Array = []
	for id in HEROES:
		out.append(load("res://data/heroes/%s.tres" % id))
	return out


func _by_id(hs: Array, id: String) -> HeroData:
	return hs[HEROES.find(id)]


func test_home_hero_is_the_stage_owner_only_away() -> void:
	var hs := _heroes()
	for me in HEROES:
		for owner in HEROES:
			var home := HomeSummonRules.home_hero(hs, _by_id(hs, me), StringName(STAGES[owner]))
			if owner == me:
				assert_object(home).is_null()  # 자기 전장: 부를 주인이 없다
			else:
				assert_str(String(home.id)).is_equal(owner)


func test_each_home_hero_uses_its_full_charge_skill() -> void:
	var hs := _heroes()
	var want := {"yi_sun_sin": "해일검기", "gwanggaeto": "낙뢰", "sejong": "성좌진", "shin_saimdang": "화폭 펼치기"}
	for owner in HEROES:
		var me := "sejong" if owner != "sejong" else "yi_sun_sin"
		var r := HomeSummonRules.new()
		assert_bool(r.begin(hs, _by_id(hs, me), StringName(STAGES[owner]))).is_true()
		assert_str(r.skill().display_name).is_equal(want[owner])
	assert_float(HomeSummonData.get_default().charge).is_equal(1.0)


## 충전은 시간으로 (사용자 2026-11-26 "시간에 따라 충전되는 형태로"): 판 시작 때 한 번 차 있고, 쓰면 recharge_time초에 다시 한 번,
## 최대 한 번 보관. 우두머리 덤은 없다 (charges_boss 0).
func test_charges_refill_by_time() -> void:
	var r := HomeSummonRules.new()
	var hs := _heroes()
	var t := r.data.recharge_time
	assert_float(t).is_equal(60.0)
	assert_bool(r.begin(hs, _by_id(hs, "sejong"), &"hansan_1592")).is_true()
	assert_int(r.charges).is_equal(1)
	assert_float(r.fill()).is_equal(1.0)
	assert_bool(r.tick(t)).is_false()  # 이미 다 참 (최대 한 번)
	assert_bool(r.use()).is_true()
	assert_bool(r.use()).is_false()
	assert_bool(r.on_boss()).is_false()  # 우두머리 덤 없음
	assert_bool(r.tick(t * 0.5)).is_false()
	assert_float(r.fill()).is_equal_approx(0.5, 0.001)
	assert_bool(r.tick(t * 0.5 + 0.01)).is_true()
	assert_int(r.charges).is_equal(1)
	assert_int(r.data.charges_max).is_equal(1)


func test_own_stage_has_no_summon() -> void:
	var r := HomeSummonRules.new()
	var hs := _heroes()
	assert_bool(r.begin(hs, _by_id(hs, "yi_sun_sin"), &"hansan_1592")).is_false()
	assert_int(r.charges).is_equal(0)
	assert_bool(r.on_boss()).is_false()
	assert_bool(r.use()).is_false()


func test_damage_follows_the_boss_hp_scale() -> void:
	var base := EnemyData.new()
	base.max_hp = 1000
	var big := EnemyData.new()
	big.max_hp = 1900
	assert_float(HomeSummonRules.boss_factor(big, base)).is_equal_approx(1.9, 0.0001)
	assert_float(HomeSummonRules.boss_factor(null, base)).is_equal(1.0)
	var r := HomeSummonRules.new()
	var hs := _heroes()
	r.begin(hs, _by_id(hs, "gwanggaeto"), &"hansan_1592")
	assert_float(r.damage_scale(big, base, 1.0)).is_equal_approx(r.entry.damage_scale * 1.9, 0.0001)
	assert_float(r.damage_scale(big, base, 1.5)).is_equal_approx(r.entry.damage_scale * 1.9 / 1.5, 0.0001)  # 성장은 빼고


func test_screen_text_has_no_loanwords() -> void:
	var d := HomeSummonData.get_default()
	for s in [d.hint_text, d.hint_more_text]:
		for w in LOANWORDS:
			assert_bool(s.contains(w)).override_failure_message("%s in %s" % [w, s]).is_false()


func _button(me: String, stage_owner: String) -> HomeSummonButton:
	var m := FakeMain.new()
	m.heroes = _heroes()
	m.stage = load("res://data/stages/%s.tres" % STAGES[stage_owner])
	m.stage_id = StringName(STAGES[stage_owner])
	m.player = Player.new()
	var h := Health.new()
	h.name = "Health"
	m.player.add_child(h)
	m.player.hero = _by_id(m.heroes, me)
	var caster := SkillCaster.new()
	caster.name = "SkillCaster"
	caster.player = m.player
	caster.enemy_source = func() -> Array: return []
	caster.hit_stop_enabled = false
	m.player.add_child(caster)
	m.spawner = EnemySpawner.new()
	m.spawner.boss_data = m.stage.boss
	m.add_child(m.spawner)
	m.add_child(m.player)
	m.hud = Control.new()
	m.add_child(m.hud)
	add_child(m)
	m.spawner.set_physics_process(false)
	m.player.set_physics_process(false)
	var b := HomeSummonButton.attach(m)
	b.begin()
	return b


func after_test() -> void:
	for c in get_children():
		if c is FakeMain:
			c.free()
	var scene := get_tree().current_scene if get_tree().current_scene else get_tree().root
	for c in scene.get_children():
		if c is SkillCutin:
			c.free()
	BossSim.reset_globals()
	SkillCutin.reset()


func test_button_press_summons_once_and_is_consumed() -> void:
	var b := _button("sejong", "yi_sun_sin")
	assert_bool(b.shown()).is_true()
	assert_str(b.hint).contains("순신")
	var c := b.center()
	var got := [0]
	b.summoned.connect(func(h: HeroData) -> void:
		got[0] += 1
		assert_str(String(h.id)).is_equal("yi_sun_sin"))
	assert_bool(b.handle_touch(0, c + Vector2(300, 0), true)).is_false()  # 단추 밖은 영웅 조작으로
	assert_bool(b.handle_touch(0, c, true)).is_true()
	assert_bool(b.handle_touch(0, c, false)).is_true()
	assert_int(got[0]).is_equal(1)
	assert_int(b.rules.charges).is_equal(0)
	assert_bool(b.handle_touch(0, c, true)).is_true()  # 다 써도 단추 위 누름은 먹는다 (영웅이 엉뚱하게 움직이지 않게)
	b.handle_touch(0, c, false)
	assert_int(got[0]).is_equal(1)
	assert_object(b.ally).is_not_null()  # 같이 싸우는 주인 영웅 (AllyHero)
	assert_bool(b.ally.body.is_invulnerable()).is_true()  # 불려 온 영웅은 맞지 않는다
	assert_object(b.ally.body.walk_area).is_equal(b.main.player.walk_area)  # 걸을 수 있는 곳 (#216) 그대로
	b.rules.tick(b.data.recharge_time + 0.1)  # 시간이 지나면 다시 찬다
	assert_int(b.rules.charges).is_equal(1)


func test_button_hidden_on_own_stage_and_during_tutorial_or_pick() -> void:
	var own := _button("yi_sun_sin", "yi_sun_sin")
	assert_bool(own.shown()).is_false()
	assert_bool(own.handle_touch(0, own.center(), true)).is_false()
	var b := _button("gwanggaeto", "sejong")
	assert_bool(b.shown()).is_true()
	b.main.waiting_pick = true
	assert_bool(b.shown()).is_false()
	b.main.waiting_pick = false
	b.main.state.player_died()
	assert_bool(b.shown()).is_false()


## 영웅 묶음 아래, 물결 점(x 200~)보다 왼쪽, 연타 글씨(ComboTextData.anchor, 글 높이 약 70px)보다 아래. 긴 화면에서도.
func test_button_sits_below_the_badge_and_the_combo_text() -> void:
	var d := HomeSummonData.get_default()
	var combo := load("res://data/ui/combo_text.tres") as ComboTextData
	for vp in [Vector2(720, 1280), Vector2(720, 1600), Vector2(720, 1440)]:
		var c := d.button_center(vp)
		assert_float(c.y - d.button_radius - 7.0).is_greater(HeroBadge.BOTTOM)
		assert_float(c.y - d.button_radius - 7.0).is_greater(vp.y * combo.anchor.y + 10.0)
		assert_float(c.x + d.button_radius + 7.0).is_less(150.0)


## 잘못 눌림 (독립 검토 ①): 단추에서 시작해 움직이면 영웅 움직이기로 넘기고 부르지 않는다. 꾹 눌렀다 떼도 부르지 않는다.
func test_drag_from_the_button_moves_and_holding_does_not_summon() -> void:
	var b := _button("sejong", "yi_sun_sin")
	var c := b.center()
	var d := b.data
	assert_bool(b.handle_touch(0, c, true, 10.0)).is_true()
	assert_bool(b.handle_drag(0, c + Vector2(d.tap_slop * 0.5, 0))).is_false()  # 작은 흔들림은 단추 위 그대로
	assert_bool(b.handle_drag(0, c + Vector2(d.tap_slop + 4.0, 0))).is_true()  # 넘김
	assert_bool(b.handle_touch(0, c + Vector2(d.tap_slop + 4.0, 0), false, 10.2)).is_false()  # 떼기도 영웅 조작 몫
	assert_int(b.rules.charges).is_equal(1)
	b.handle_touch(0, c, true, 20.0)
	b.handle_touch(0, c, false, 20.0 + d.tap_max_time + 0.1)  # 꾹 눌렀다 뗌
	assert_int(b.rules.charges).is_equal(1)
	b.handle_touch(0, c, true, 30.0)
	b.handle_touch(0, c, false, 30.1)  # 톡
	assert_int(b.rules.charges).is_equal(0)


## 피해 배율은 겨눈 적의 체력 배율 (독립 검토 ②): 최종 우두머리·중간 우두머리 배율이 달라도, 졸병이면 1.
func test_summon_scale_follows_the_targeted_enemy() -> void:
	var base := EnemyData.new()
	base.max_hp = 1000
	base.is_boss = true
	var hero := HeroData.new()
	hero.boss_hp_mult = 1.5
	var scaled := BossHpScale.for_hero(base, hero)
	assert_float(HomeSummonRules.hp_factor(scaled)).is_equal_approx(1.5, 0.001)
	var curve := load("res://data/difficulty/curve.tres") as DifficultyCurve
	var tiered := curve.scaled(scaled, 1)
	assert_float(HomeSummonRules.hp_factor(tiered)).is_equal_approx(1.5 * curve.hp(1), 0.01)  # 배율 전 체력은 원본 그대로
	var trash := EnemyData.new()
	trash.max_hp = 26
	assert_float(HomeSummonRules.hp_factor(trash)).is_equal(1.0)
	assert_float(HomeSummonRules.hp_factor(null)).is_equal(1.0)
	var r := HomeSummonRules.new()
	r.begin(_heroes(), _by_id(_heroes(), "sejong"), &"hansan_1592")
	assert_float(r.damage_scale_for(scaled, 1.0)).is_equal_approx(r.entry.damage_scale * 1.5, 0.001)
