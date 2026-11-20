extends GdUnitTestSuite
## 무대 2~4 (경복궁·초충도·한산도): 데이터 완결성, 무대 고르기 화면, 고른 무대가 판에 들어가는지.

const IDS := ["manchuria_395", "gyeongbokgung_1433", "chochungdo", "hansan_1592"]


func _stage(id: String) -> StageTheme:
	return load("res://data/stages/%s.tres" % id) as StageTheme


func test_new_stages_are_complete() -> void:
	for id in IDS:  # Codex d695035: 1무대도 자기 군대를 데이터로 (장면 기본값에 기대지 않게)
		var st := _stage(id)
		assert_str(String(st.id)).is_equal(id)
		assert_str(st.title).is_not_empty()
		assert_str(st.subtitle).is_not_empty()
		assert_str(st.hero_hint).is_not_empty()
		assert_object(st.card_art).is_not_null()
		assert_int(st.prop_textures.size()).is_greater(10)
		assert_int(st.spawn_table.size()).is_equal(3)
		assert_int(st.spawn_weights.size()).is_equal(3)
		assert_int(st.unlock_times.size()).is_equal(3)
		assert_object(st.elite).is_not_null()
		assert_object(st.boss).is_not_null()
		for e: EnemyData in st.spawn_table + [st.elite, st.boss]:
			assert_object(e.sprite_sheet).is_not_null()
			assert_str(e.display_name).is_not_empty()
			assert_float(e.sprite_scale).is_greater(0.0)


func test_enemy_ids_are_unique_across_stages() -> void:
	var seen := {}
	for id in IDS.slice(1):
		var st := _stage(id)
		for e: EnemyData in st.spawn_table + [st.elite, st.boss]:
			assert_bool(seen.has(e.id)).is_false()
			seen[e.id] = true
	assert_int(seen.size()).is_equal(15)


func test_stage_select_picks_with_one_tap_only_on_same_card() -> void:
	var sel: StageSelect = auto_free(StageSelect.new())
	sel.size = Vector2(720, 1280)
	add_child(sel)
	var got: Array = []
	sel.picked.connect(func(s: StageTheme) -> void: got.append(s))
	var list: Array[StageTheme] = []
	for id in IDS:
		list.append(_stage(id))
	sel.open(list)
	for i in 4:
		assert_bool(Rect2(Vector2.ZERO, sel.size).encloses(sel.slot_rect(i))).is_true()
	sel.handle_touch(0, sel.slot_rect(0).get_center(), true)
	assert_bool(sel.handle_touch(0, sel.slot_rect(1).get_center(), false)).is_false()  # 끌어서 다른 카드
	assert_array(got).is_empty()
	var c := sel.slot_rect(3).get_center()
	sel.handle_touch(0, c, true)
	assert_bool(sel.handle_touch(0, c, false)).is_true()
	assert_array(got).is_equal([list[3]])
	assert_bool(sel.is_open()).is_false()


func test_main_waits_for_stage_then_uses_its_army() -> void:
	GameSettings.settings_path = "user://test_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = false
	GameSettings.save_settings()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_bool(main.waiting_pick).is_true()
	var sel: StageSelect = main.stage_select
	assert_bool(sel.is_open()).is_true()
	var c := sel.slot_rect(3).get_center()
	sel.handle_touch(0, c, true)
	sel.handle_touch(0, c, false)
	var hansan := _stage("hansan_1592")
	assert_bool(main.waiting_pick).is_false()
	assert_object(main.run_config.stage).is_same(hansan)
	assert_object(main.spawner.boss_data).is_same(hansan.boss)
	assert_object(main.spawner.elite_data).is_same(hansan.elite)
	assert_array(main.spawner.spawn_table).is_equal(hansan.spawn_table)
	assert_str(String(GameSettings.stage_id)).is_equal("hansan_1592")
	get_tree().paused = false
	main.queue_free()
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()


# --- 차례대로 열기 ---

func _all() -> Array[StageTheme]:
	var list: Array[StageTheme] = []
	for id in IDS:
		list.append(_stage(id))
	return list


func test_unlock_flags_follow_cleared_order() -> void:
	var list := _all()
	assert_array(StageUnlock.flags(list, PackedStringArray(), false)).is_equal([true, false, false, false])
	assert_array(StageUnlock.flags(list, PackedStringArray(["manchuria_395"]), false)).is_equal([true, true, false, false])
	assert_array(StageUnlock.flags(list, PackedStringArray(["chochungdo"]), false)).is_equal([true, false, false, true])
	assert_array(StageUnlock.flags(list, PackedStringArray(), true)).is_equal([true, true, true, true])


func test_mark_cleared_saves_once() -> void:
	GameSettings.settings_path = "user://test_settings.cfg"
	GameSettings.cleared_stages = PackedStringArray()
	assert_bool(GameSettings.mark_cleared(&"manchuria_395")).is_true()
	assert_bool(GameSettings.mark_cleared(&"manchuria_395")).is_false()
	GameSettings.save_settings()
	GameSettings.cleared_stages = PackedStringArray()
	GameSettings.load_settings()
	assert_array(Array(GameSettings.cleared_stages)).is_equal(["manchuria_395"])
	GameSettings.cleared_stages = PackedStringArray()
	GameSettings.save_settings()


func test_locked_stage_card_is_not_pickable() -> void:
	var sel: StageSelect = auto_free(StageSelect.new())
	sel.size = Vector2(720, 1280)
	add_child(sel)
	var got: Array = []
	sel.picked.connect(func(s: StageTheme) -> void: got.append(s))
	sel.open(_all(), [true, false, false, false] as Array[bool])
	var c := sel.slot_rect(1).get_center()
	sel.handle_touch(0, c, true)
	assert_bool(sel.handle_touch(0, c, false)).is_false()
	assert_array(got).is_empty()
	assert_str(sel.notice).contains("만주 벌판")
	assert_bool(sel.is_open()).is_true()


func test_each_stage_run_uses_its_own_army() -> void:
	GameSettings.settings_path = "user://test_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_picked = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = true
	for id in IDS:
		GameSettings.stage_id = StringName(id)
		GameSettings.save_settings()  # Main이 시작할 때 설정 파일을 다시 읽는다
		var main: Node = load("res://scenes/main.tscn").instantiate()
		add_child(main)
		await get_tree().process_frame
		var st := _stage(id)
		assert_array(main.spawner.spawn_table).is_equal(st.spawn_table)
		assert_object(main.spawner.boss_data).is_same(st.boss)
		assert_object(main.spawner.elite_data).is_same(st.elite)
		get_tree().paused = false
		main.free()
	GameSettings.stage_id = &"manchuria_395"
	GameSettings.save_settings()
