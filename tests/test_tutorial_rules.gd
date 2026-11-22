extends GdUnitTestSuite
## 조작 안내 규칙: 영웅·물결·단추에 맞는 설명, 기술 단계는 쿨타임 없이 시작, 물결 무대에서도 강화 카드가 나온다.

const DATA := preload("res://data/tutorial/controls.tres")
const PRACTICE := preload("res://data/tutorial/practice_enemy.tres")
const DUMMY := preload("res://data/tutorial/practice_dummy.tres")


func _step(ev: StringName) -> TutorialStep:
	for s in DATA.steps:
		if s.event == ev:
			return s
	return null


func _main(hero: StringName) -> Node:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.hero_id = hero
	GameSettings.hero_stages = {}
	GameSettings.stage_picked = false
	GameSettings.tutorial_enabled = true
	GameSettings.tutorial_done = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	return main


func _cleanup(main: Node) -> void:
	if main.tutorial_director and main.tutorial_director.run:
		main.tutorial_director.run.skip()
	get_tree().paused = false
	main.queue_free()
	GameSettings.tutorial_done = true
	GameSettings.hero_id = &"yi_sun_sin"  # 다음 묶음이 설정 파일에서 다시 읽어도 기본 영웅
	GameSettings.hero_clears = {}
	GameSettings.save_settings()


func test_combo_text_differs_by_hero_role() -> void:
	var s := _step(&"combo")
	var melee := s.text_for(&"yi_sun_sin", false, false)
	assert_str(melee).is_equal(s.hint)
	assert_str(s.text_for(&"gwanggaeto", false, false)).is_equal(melee)  # 근접
	assert_str(s.text_for(&"sejong", false, false)).contains("글자")  # 원거리
	assert_str(s.text_for(&"shin_saimdang", false, false)).contains("붓")  # 중거리
	assert_str(s.text_for(&"sejong", true, true)).contains("글자")  # 단추·물결 설명이 없으면 영웅별 그대로


func test_text_priority_is_wave_then_button_then_hero() -> void:
	var up := _step(&"upgrade")
	assert_str(up.text_for(&"yi_sun_sin", false, true)).is_equal(up.wave_hint)
	assert_str(up.text_for(&"yi_sun_sin", false, false)).is_equal(up.hint)
	var fin := _step(&"skill_tap")
	assert_str(fin.text_for(&"sejong", true, false)).is_equal(fin.button_hint)


func test_wave_hint_matches_wave_data() -> void:
	var hansan: StageTheme = load("res://data/stages/hansan_1592.tres")
	assert_bool(hansan.waves.one_pick_per_break).is_true()
	assert_int(hansan.waves.pick_stacks).is_equal(2)  # 설명의 "한 번에 두 단계"
	assert_str(_step(&"upgrade").wave_hint).contains("두 단계")


func test_practice_partners() -> void:
	assert_bool(PRACTICE.super_armor).is_true()  # 대시 기술에 맞아도 예고가 끊기지 않는다 (회피를 배울 수 있게)
	assert_float(PRACTICE.stun_scale).is_equal(0.0)
	assert_object(DUMMY.attack).is_null()
	assert_int(DUMMY.contact_damage).is_equal(0)
	assert_int(DUMMY.xp).is_equal(0)
	assert_float(DUMMY.move_speed).is_equal(0.0)


func test_skill_steps_start_without_cooldown() -> void:
	var main := _main(&"shin_saimdang")
	await get_tree().process_frame
	var sc := main.player.get_node("SkillCaster") as SkillCaster
	var run: TutorialProgress = main.tutorial_director.run
	TutorialDriver.skip_to(run, &"combo")
	sc.cast(SkillCaster.Slot.TAP)  # 연타 단계에서 단추 등으로 첫째 기술을 써 버림
	sc.cast(SkillCaster.Slot.DASH)
	assert_bool(sc.is_ready(SkillCaster.Slot.TAP)).is_false()
	run.notify(&"combo")
	assert_str(String(run.current().event)).is_equal("skill_tap")
	assert_bool(sc.is_ready(SkillCaster.Slot.TAP)).is_true()  # 마무리 단계는 바로 쓸 수 있다
	run.notify(&"skill_tap")
	assert_bool(sc.is_ready(SkillCaster.Slot.DASH)).is_true()
	_cleanup(main)


func test_combo_step_advances_on_a_full_hand_chain() -> void:
	var main := _main(&"yi_sun_sin")
	await get_tree().process_frame
	var sc := main.player.get_node("SkillCaster") as SkillCaster
	var run: TutorialProgress = main.tutorial_director.run
	TutorialDriver.skip_to(run, &"combo")
	sc.combo.on_hit(sc.kit.combo_hits, 3)
	sc.combo.on_hit(sc.kit.combo_hits, 3)
	main.tutorial_director.tick(0.016)
	assert_str(String(run.current().event)).is_equal("combo")  # 두 타로는 아직
	sc.combo.on_hit(sc.kit.combo_hits, 3)
	main.tutorial_director.tick(0.016)
	assert_str(String(run.current().event)).is_equal("skill_tap")
	_cleanup(main)


func test_wave_stage_still_offers_practice_cards() -> void:
	var main := _main(&"yi_sun_sin")
	await get_tree().process_frame
	assert_object(main.spawner.waves).is_not_null()  # 한산은 물결 모드
	assert_bool(main.tutorial_overlay.waves).is_true()
	main.break_picks = 0  # 숨 고르기 몫이 없어도
	TutorialDriver.skip_to(main.tutorial_director.run, &"upgrade")
	assert_bool(main.seal_choice.is_open()).is_true()
	main.seal_choice.pick(0)
	assert_bool(main.tutorial_director.run.is_done()).is_true()
	_cleanup(main)


func test_overlay_knows_the_hero() -> void:
	var main := _main(&"sejong")
	await get_tree().process_frame
	assert_str(String(main.tutorial_overlay.hero_id)).is_equal("sejong")
	_cleanup(main)


func test_counter_banner_does_not_cover_the_counter_prompt() -> void:
	var p := TutorialProgress.new(DATA)
	var o: TutorialOverlay = auto_free(TutorialOverlay.new())
	o.size = Vector2(720, 1280)
	add_child(o)
	o.open(p)
	TutorialDriver.skip_to(p, &"skill_counter")
	var prompt_y := 1280.0 * 0.72  # SkillButtonDrawer 반격 신호 (아이콘 위 ~140px ~ 막대 아래 ~30px)
	var b := o.banner_rect()
	assert_bool(b.end.y < prompt_y - 160.0).is_true()
	assert_bool(b.position.y > o.skip_rect().end.y).is_true()
	TutorialDriver.skip_to(p, &"upgrade")
	assert_float(o.banner_rect().position.y).is_greater(prompt_y - 200.0)  # 다른 단계는 아래쪽 그대로
