extends GdUnitTestSuite
## 예열 보강 (FxWarmup3D, MAX_DEPTH 8): 판에 나오는 3D 적을 제목 띠 동안 한 번 그리고 지우며,
## 무리 우두머리의 단계 그림(낙인)까지 따라가 모은다.

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]


func _stage(id: String) -> StageTheme:
	return load("res://data/stages/%s.tres" % id) as StageTheme


func test_live_enemies_are_the_ones_with_3d_data() -> void:
	var ids := FxWarmup3D.live_enemies(_stage("hansan_1592")).map(func(d: EnemyData) -> String: return String(d.id))
	assert_array(ids).contains(["waegun_commander"])
	for id in STAGES:
		for d in FxWarmup3D.live_enemies(_stage(id)):
			assert_object(EnemySprite3D.live_data(d)).override_failure_message("%s %s" % [id, d.id]).is_not_null()


func test_run_draws_once_then_frees() -> void:
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)
	var n := FxWarmup3D.run(host, _stage("hansan_1592"), 2)
	assert_int(n).is_equal(FxWarmup3D.live_enemies(_stage("hansan_1592")).size())
	assert_int(host.get_child_count()).is_equal(n)
	for i in 5:
		await get_tree().process_frame
	assert_int(host.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion()).size()).is_equal(0)


func test_deeper_walk_collects_more_on_every_stage() -> void:
	var keep := FxWarmup.max_depth
	for id in STAGES:
		FxWarmup.max_depth = 6
		var a: Dictionary = FxWarmup.collect(FxWarmup.roots(null, _stage(id)))
		FxWarmup.max_depth = 8
		var b: Dictionary = FxWarmup.collect(FxWarmup.roots(null, _stage(id)))
		print("[warmup] %s depth 6 → 8: textures %d → %d, vfx %d → %d" % [id, a["textures"].size(), b["textures"].size(), a["vfx"].size(), b["vfx"].size()])
		assert_int(b["textures"].size()).override_failure_message(id).is_greater_equal(a["textures"].size())
	FxWarmup.max_depth = keep
	assert_int(FxWarmup.max_depth).is_greater_equal(8)


## 제목 띠 안에서 드는 시간 (보고용, 3D 갈래를 켠 것과 끈 것): 띠 길이(3.2초)는 그대로이고 그 안의 한 프레임 비용만 는다.
func test_warmup_time_with_and_without_3d() -> void:
	var hero := load("res://data/heroes/yi_sun_sin.tres") as HeroData
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)
	FxWarmup.skip = PackedStringArray(["3d"])
	FxWarmup.run(host, hero, _stage("hansan_1592"))
	var without := FxWarmup.last_ms
	FxWarmup.skip = PackedStringArray()
	FxWarmup.run(host, hero, _stage("hansan_1592"))
	var with3d := FxWarmup.last_ms
	print("[warmup] hansan warm-up ms: without 3d %.1f, with 3d %.1f" % [without, with3d])
	for i in 5:
		await get_tree().process_frame
	assert_float(with3d).is_less(1500.0)
