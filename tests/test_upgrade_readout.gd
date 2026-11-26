extends GdUnitTestSuite
## 강화 패 가독성: 종류 띠 낱말(우리말)·색, 값 "지금 → 고른 뒤"가 패 데이터와 이번 판 수치로 맞게, 큰 변형은 설명,
## 패 화면이 떠 있는 동안 전투 글자(연타·대사·피해 숫자)를 숨기고 닫으면 되돌린다.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]

var main: Node


func after_test() -> void:
	if main:
		main.queue_free()
		main = null
	get_tree().paused = false
	FxLayer.numbers_hidden = false


func _build(hero: String) -> RunBuild:
	var b := RunBuild.new()
	b.hero = (load("res://data/heroes/%s.tres" % hero) as HeroData).duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	return b


func _up(b: RunBuild, id: StringName) -> UpgradeDef:
	for u in b.hero.upgrade_pool.upgrades:
		if u.id == id:
			return u
	return null


func test_values_follow_data_and_current_build() -> void:
	var b := _build("yi_sun_sin")
	var g := SkillGrowthData.get_default()
	var u := _up(b, &"haeryong_wide")
	var r0: float = b.hero.kit.tap.radius
	var lv: int = b.hero.kit.tap.vfx_level
	var l := UpgradeReadout.lines(u, b, 1)  # 범위는 실제로 커지는 비율 (모습 단계 배율 포함)
	assert_int(l.size()).is_equal(1)
	assert_str(l[0]["label"]).is_equal("범위")
	assert_str(l[0]["text"]).is_equal(UpgradeReadout.pct(r0 * g.size_at(lv), r0 * 1.25 * g.size_at(lv + 1)))
	b.apply(u)  # 한 번 고른 뒤에는 지금 값이 오른다
	var l2 := UpgradeReadout.lines(u, b, 2)  # 두 단계 한 번에
	assert_str(l2[0]["text"]).is_equal(UpgradeReadout.pct(r0 * 1.25 * g.size_at(lv + 1), r0 * pow(1.25, 3) * g.size_at(lv + 3)))
	var more := UpgradeReadout.lines(_up(b, &"pado_more"), b, 1)  # 정수 더하기
	assert_str("%s → %s" % [more[0]["from"], more[0]["to"]]).is_equal("%d → %d" % [b.hero.kit.dash.hit_count, b.hero.kit.dash.hit_count + 1])
	assert_str(more[1]["label"]).is_equal("폭")  # 연타 패도 기술 모습 단계를 올려 폭이 같이 커진다
	var deep := UpgradeReadout.lines(_up(b, &"haeryong_deep"), b, 1)  # 1번 피해는 4타 마무리 실제 값
	var dmg: int = b.hero.kit.tap.damage
	var m: float = b.hero.kit.combo_finisher_mult
	assert_str(deep[0]["from"]).is_equal(str(roundi(dmg * m)))
	assert_str(deep[0]["to"]).is_equal(str(roundi(roundi(dmg * 1.4) * m)))


## 죽은 쿨타임 패를 바꾼 4타 마무리 피해 패 (순신·광개토): 마무리 배율을 올리고 패에는 마무리 한 번 피해.
func test_finisher_cards_raise_the_fourth_hit() -> void:
	for pair in [["yi_sun_sin", &"haeryong_finish"], ["gwanggaeto", &"quake_finish"]]:
		var b := _build(pair[0])
		var u := _up(b, pair[1])
		assert_object(u).is_not_null()
		var kit := b.hero.kit
		var before := kit.combo_finisher_mult
		var l := UpgradeReadout.lines(u, b, 1)
		assert_int(l.size()).is_equal(1)
		assert_str(l[0]["label"]).is_equal("마무리 피해")
		assert_str(l[0]["from"]).is_equal(str(roundi(kit.tap.damage * before)))
		b.apply(u)
		assert_float(kit.combo_finisher_mult).is_equal_approx(before * 1.15, 0.0001)
		assert_int(kit.tap.vfx_level).is_equal(0)  # 판정·그림 크기는 건드리지 않는다
		assert_bool(UpgradeEffect.useful(b, u)).is_true()


func test_major_cards_fall_back_to_description() -> void:
	var b := _build("yi_sun_sin")
	for u in b.hero.major_pool.upgrades:
		assert_int(UpgradeReadout.lines(u, b, 1).size()).is_equal(0)


func test_every_normal_card_has_a_korean_kind_word_and_numbers() -> void:
	var d := UpgradeReadout.data()
	var hangul := RegEx.create_from_string("^[가-힣 ]+$")
	for h in HEROES:
		var b := _build(h)
		for u in b.hero.upgrade_pool.upgrades:
			var w := d.word(UpgradeReadout.kind(u))
			assert_bool(hangul.search(w) != null).override_failure_message("%s: 띠 낱말 '%s'" % [u.id, w]).is_true()
			assert_int(UpgradeReadout.lines(u, b, 1).size()).override_failure_message("%s: 값 줄 없음" % u.id).is_greater(0)
	for kd in d.kind_colors:  # 순적색(적 위험 전용) 피함: 붉은 띠는 초록·파랑이 있어야
		var c: Color = d.kind_colors[kd]
		assert_bool(c.r > 0.75 and c.g < 0.3 and c.b < 0.3).is_false()


func test_battle_text_hidden_while_cards_open() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.want_stage_list = false
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var combo: ComboCounter = main.get_node("HUD/ComboCounter")
	combo.add_hits(5)
	assert_bool(combo.visible).is_true()
	assert_object(main.seal_choice.cards.build).is_same(main.build)
	var ups: Array[UpgradeDef] = [main.build.hero.upgrade_pool.upgrades[0]]
	main.seal_choice.open(ups, Vector2.ZERO, false, {})
	assert_bool(combo.visible).is_false()
	assert_bool(main.hero_lines.visible).is_false()
	assert_bool(FxLayer.numbers_hidden).is_true()
	main.seal_choice.close()
	assert_bool(combo.visible).is_true()
	assert_bool(main.hero_lines.visible).is_true()
	assert_bool(FxLayer.numbers_hidden).is_false()
