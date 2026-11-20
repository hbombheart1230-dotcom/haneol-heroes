extends GdUnitTestSuite
## 무대 4개 데이터 완결성, 이긴 무대 기록, 무대마다 자기 군대로 판이 도는지.

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


func _all() -> Array[StageTheme]:
	var list: Array[StageTheme] = []
	for id in IDS:
		list.append(_stage(id))
	return list


func test_mark_cleared_saves_once() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.cleared_stages = PackedStringArray()
	assert_bool(GameSettings.mark_cleared(&"manchuria_395")).is_true()
	assert_bool(GameSettings.mark_cleared(&"manchuria_395")).is_false()
	GameSettings.save_settings()
	GameSettings.cleared_stages = PackedStringArray()
	GameSettings.load_settings()
	assert_array(Array(GameSettings.cleared_stages)).is_equal(["manchuria_395"])
	GameSettings.cleared_stages = PackedStringArray()
	GameSettings.save_settings()


func test_each_stage_run_uses_its_own_army() -> void:
	GameSettings.settings_path = GameSettings.test_path()
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
