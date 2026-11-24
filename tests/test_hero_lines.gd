extends GdUnitTestSuite
## 영웅 머리 위 한 줄 대사: 경우별로 맞는 줄, 원정이면 원정 줄, 다른 문구가 떠 있으면 기다림, 꺼짐 조건(이야기 끔·조작 안내 중).

const HEROES: Array[StringName] = [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]

var main: Node


func before_test() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.want_stage_list = false
	GameSettings.story_enabled = true
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false


func after_test() -> void:
	if main:
		main.queue_free()
		main = null
	get_tree().paused = false
	GameSettings.stage_picked = false
	GameSettings.story_enabled = true
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.hero_id = &"yi_sun_sin"


func _run(hero: StringName, stage: StringName = &"") -> HeroLineView:
	GameSettings.hero_id = hero
	if stage != &"":
		GameSettings.stage_picked = true
		GameSettings.stage_id = stage
	GameSettings.save_settings()  # 장면이 뜰 때 설정 파일을 다시 읽는다
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_bool(main.waiting_pick).is_false()
	return main.hero_lines


func _after_title(v: HeroLineView) -> void:
	main.state.elapsed = Hud.STAGE_TITLE_TIME + 0.1
	v.step(0.016)
	v.step(v.settle_time)  # 문구가 사라지고 조금 더 기다린 뒤


func test_every_hero_has_all_six_lines() -> void:
	for id in HEROES:
		var l := HeroLines.for_hero(id)
		assert_object(l).is_not_null()
		assert_int(l.lines.size()).is_equal(HeroLines.Case.size())
		for c in HeroLines.Case.values():
			assert_str(l.line(c)).is_not_empty()
	assert_str(HeroLines.for_hero(&"yi_sun_sin").line(HeroLines.Case.ENTER_OWN)).is_equal("이 바다를 잊게 두지 않겠다")
	assert_str(HeroLines.for_hero(&"shin_saimdang").line(HeroLines.Case.SUMMON)).is_equal("매화여, 피어나라!")


func test_enter_waits_for_stage_title_then_own_line() -> void:
	var v := await _run(&"yi_sun_sin")
	main.state.elapsed = 1.0
	v.step(1.0)
	assert_str(v.text).is_empty()  # 무대 시작 문구가 떠 있는 동안은 기다린다
	_after_title(v)
	assert_str(v.text).is_equal("이 바다를 잊게 두지 않겠다")
	v.step(v.show_time + 0.1)
	assert_float(v.alpha()).is_equal(0.0)  # 2초쯤 떴다 흐려짐


func test_expedition_uses_away_line() -> void:
	var v := await _run(&"yi_sun_sin", &"manchuria_395")
	_after_title(v)
	assert_str(v.text).is_equal("이곳의 기억도 지키겠다")


func test_boss_line_waits_for_banner() -> void:
	var v := await _run(&"gwanggaeto")
	_after_title(v)
	var banner: Node = main.get_node("HUD/BossBanner")
	banner._t = 0.0
	banner._len = 3.0
	v.queue(HeroLines.Case.BOSS)
	v.step(0.016)
	assert_str(v.text).is_not_equal("네 깃발을 꺾으러 왔다")  # 등장 띠가 떠 있는 동안 기다림
	banner._t = 5.0
	v.step(0.016)
	assert_str(v.text).is_not_equal("네 깃발을 꺾으러 왔다")  # 띠가 흐려지는 끝자락은 더 기다림
	v.step(v.settle_time)
	assert_str(v.text).is_equal("네 깃발을 꺾으러 왔다")


func test_defeat_line_sits_above_result_panel() -> void:
	var v := await _run(&"sejong")
	_after_title(v)
	main.state.player_died()
	v.step(v.settle_time)
	assert_str(v.text).is_equal("아직 쓸 글이 남았다…")
	var vp := main.get_viewport().get_visible_rect().size
	assert_float(v.line_pos().y).is_equal(ResultDrawer.panel_top(vp) - 30.0)


func test_no_lines_when_story_off() -> void:
	GameSettings.story_enabled = false
	var v := await _run(&"shin_saimdang")
	_after_title(v)
	assert_str(v.text).is_empty()


func test_no_lines_during_tutorial() -> void:
	GameSettings.tutorial_enabled = true
	GameSettings.tutorial_done = false
	var v := await _run(&"yi_sun_sin")
	assert_bool(main.tutorial_director != null and main.tutorial_director.running()).is_true()
	_after_title(v)
	v.queue(HeroLines.Case.BOSS)
	v.step(0.016)
	assert_str(v.text).is_empty()


func test_line_steers_clear_of_combo_number() -> void:
	var v := await _run(&"yi_sun_sin")
	_after_title(v)
	var combo: ComboCounter = main.get_node("HUD/ComboCounter")
	combo.add_hits(4)
	var c := combo.text_rect()
	assert_float(c.size.x).is_greater(0.0)
	var vp := main.get_viewport().get_visible_rect().size
	var at := v.avoid_combo(c.get_center(), vp)  # 머리 위가 하필 연타 글씨 자리일 때
	var w := UiStyle.TITLE_FONT.get_string_size(v.text, HORIZONTAL_ALIGNMENT_LEFT, -1, v.font_px).x
	var line := Rect2(at.x - w * 0.5, at.y - v.font_px, w, v.font_px * 1.3)
	assert_bool(line.grow_individual(v.combo_reach, 0, v.combo_reach, 0).intersects(c)).is_false()  # 한 줄처럼 붙지 않게
	assert_float(line.position.y).is_greater_equal(v.top_margin)  # 우두머리 띠 아래
	var far := v.avoid_combo(Vector2(vp.x * 0.5, c.end.y + 300.0), vp)
	assert_float(far.y).is_equal_approx(c.end.y + 300.0, 0.01)  # 멀면 그대로 머리 위


func test_combo_number_cleared_when_run_ends() -> void:
	for won in [false, true]:
		var v := await _run(&"sejong")
		var combo: ComboCounter = main.get_node("HUD/ComboCounter")
		combo.add_hits(3)
		assert_int(combo.shown()).is_equal(3)
		if won:
			main.state.boss_defeated()
		else:
			main.state.player_died()
		assert_bool(main.state.is_playing()).is_false()
		assert_int(combo.shown()).is_equal(0)  # 결과 판 위에 남지 않는다
		assert_float(combo.text_rect().size.x).is_equal(0.0)
		main.queue_free()
		main = null
		get_tree().paused = false
		await get_tree().process_frame
