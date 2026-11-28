extends GdUnitTestSuite
## 판(main)이 물려 받은 RunConfig는 캐시된 공유 자원이다. 무대를 입힐 때(StageApply) 쓰는 stage가 자원에 남아
## 다음 판·다음 시험으로 새지 않는다 (조각 실행에서 test_audio가 앞 스위트가 만든 판 때문에 실패했다).

const DEFAULT_RUN := preload("res://data/runs/default_run.tres")


func test_main_does_not_write_the_shared_run_config() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.title_seen = true
	GameSettings.opening_seen = true
	GameSettings.hero_picked = true
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.stage_picked = true
	var before: StageTheme = DEFAULT_RUN.stage
	var other: StageTheme = load("res://data/stages/hansan_1592.tres") if before.resource_path.contains("manchuria") else load("res://data/stages/manchuria_395.tres")
	GameSettings.stage_id = StringName(other.resource_path.get_file().get_basename())
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_object(main.run_config.stage).is_same(other)  # 이 판은 고른 무대
	assert_object(DEFAULT_RUN.stage).is_same(before)  # 공유 자원은 그대로
	assert_bool(main.run_config != DEFAULT_RUN).is_true()  # 판 몫 사본
	get_tree().paused = false
	main.queue_free()
	GameSettings.stage_picked = false
