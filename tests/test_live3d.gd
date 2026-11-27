extends GdUnitTestSuite
## 실시간 3D 시험 (docs/research/live3d_spike.md): 동작 자르기·길이 맞추기·뿌리 고정, 굽기 작업 → 설정,
## 구운 시트 길이, 켜고 끄기 기본값·영웅별 대체. 그림 자체는 tools/live3d 도구(비교 영상·동작 띠)로 확인한다.

const Switch := preload("res://scripts/art/live3d/live3d_switch.gd")
const View3D := preload("res://scripts/player/player_view_3d.gd")
const ROOT := ^"Armature/Skeleton3D:Hips"


func _src() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	var p := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(p, ROOT)
	a.position_track_insert_key(p, 0.0, Vector3(0, 1, 0))
	a.position_track_insert_key(p, 2.0, Vector3(4, 3, 8))  # 앞으로 걸어 나가는 뿌리
	var r := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(r, ^"Armature/Skeleton3D:Spine")
	a.rotation_track_insert_key(r, 0.0, Quaternion.IDENTITY)
	a.rotation_track_insert_key(r, 2.0, Quaternion(Vector3.UP, PI * 0.5))
	return a


func test_window_follows_bake_rules() -> void:
	assert_vector(ClipSlicer.window({"start": 0.5, "end": 1.5}, 2.0)).is_equal(Vector2(0.5, 1.5))
	assert_vector(ClipSlicer.window({}, 2.0)).is_equal(Vector2(0.0, 2.0))
	assert_vector(ClipSlicer.window({"start": 1.5, "end": 0.5}, 2.0)).is_equal(Vector2(0.0, 2.0))
	assert_vector(ClipSlicer.window({"end": 9.0}, 2.0)).is_equal(Vector2(0.0, 2.0))


func test_slice_stretches_window_to_sheet_length() -> void:
	var s := ClipSlicer.slice(_src(), Vector2(0.5, 1.5), 0.25, false, ROOT, Vector3(0.1, 0, 0.2))
	assert_float(s.length).is_equal_approx(0.25, 0.0001)
	assert_int(s.loop_mode).is_equal(Animation.LOOP_NONE)
	# 끝 시각 = 원본 1.5초 자세 (Spine 회전 3/4 * 90도)
	var q := s.rotation_track_interpolate(1, 0.25)
	assert_float(q.get_angle()).is_equal_approx(PI * 0.5 * 0.75, 0.01)
	# 뿌리 수평 위치는 rest로 고정, 높이는 원본대로 (1.5초 → y = 2.5)
	var p := s.position_track_interpolate(0, 0.25)
	assert_vector(p).is_equal_approx(Vector3(0.1, 2.5, 0.2), Vector3.ONE * 0.01)


## 칸 시각표: 칸 i는 i/3초(구운 칸이 보이는 순간)에 times[i], 사이는 직선, 마지막 칸 뒤는 붙잡는다.
func test_times_warp_follows_frame_table() -> void:
	var times := [0.0, 0.2, 1.8]
	assert_float(ClipSlicer.timed_source(0.0, times, 1.0)).is_equal_approx(0.0, 0.0001)
	assert_float(ClipSlicer.timed_source(1.0 / 6.0, times, 1.0)).is_equal_approx(0.1, 0.0001)
	assert_float(ClipSlicer.timed_source(1.0 / 3.0, times, 1.0)).is_equal_approx(0.2, 0.0001)
	assert_float(ClipSlicer.timed_source(2.0 / 3.0, times, 1.0)).is_equal_approx(1.8, 0.0001)
	assert_float(ClipSlicer.timed_source(1.0, times, 1.0)).is_equal_approx(1.8, 0.0001)
	var s := ClipSlicer.slice(_src(), Vector2(0.0, 1.8), 1.0, false, ^"", Vector3.ZERO, times)
	var q := s.rotation_track_interpolate(1, 1.0 / 3.0)  # 원본 0.2초 자세 (90도 × 0.1)
	assert_float(q.get_angle()).is_equal_approx(PI * 0.5 * 0.1, 0.01)


func test_loop_slice_has_no_duplicate_end_key() -> void:
	var s := ClipSlicer.slice(_src(), Vector2(0.0, 2.0), 1.0, true)
	assert_int(s.loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(s.track_get_key_count(0)).is_equal(60)  # 60 키/초, 끝 키 = 처음 키라 뺀다
	assert_float(s.track_get_key_time(0, 59)).is_less(1.0)


func test_from_job_copies_clips_and_ink() -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/yi_sun_sin.json"))
	var d := Live3DHeroData.from_job(job)
	assert_str(d.model_path).ends_with("yi_sun_sin/animated.glb")
	assert_float(d.ortho_size).is_equal(2.0)
	assert_int(d.frame).is_equal(256)
	assert_float(float(d.ink["line_px"])).is_equal(1.6)
	var want: Dictionary = {}
	for a in job["anims"]:
		if a["key"] == "attack2":
			want = a
	var a2 := d.clip("attack2")  # 구간 값은 굽기 작업이 정본 (다시 자르기를 따라간다)
	assert_float(float(a2["start"])).is_equal(float(want["start"]))
	assert_float(float(a2["end"])).is_equal(float(want["end"]))
	assert_str(String(a2["file"])).is_equal(String(want["from"]))
	assert_array(a2.get("times", [])).is_equal(want.get("times", []))
	assert_bool(bool(d.clip("run")["loop"])).is_true()


func test_saved_data_matches_bake_job() -> void:
	var d: Live3DHeroData = load(View3D.data_path(&"yi_sun_sin"))
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/yi_sun_sin.json"))
	assert_int(d.clips.size()).is_equal((job["anims"] as Array).size() + _extra_keys("yi_sun_sin").size())
	assert_bool(d.upper_bones.has("RightArm")).is_true()
	assert_bool(d.upper_bones.has("Hips")).is_false()  # 다리·뿌리는 달리기 그대로
	assert_bool(d.clips.all(func(c: Dictionary) -> bool: return not c.has("src"))).is_true()


func test_durations_equal_baked_sheet_timing() -> void:
	var sheet: SpriteSheetSet = (load("res://data/heroes/yi_sun_sin.tres") as HeroData).sprite_sheet
	var dur := View3D.durations(sheet)
	var i := sheet.anim_names.find("attack")
	assert_float(float(dur["attack"])).is_equal_approx(sheet.frame_counts[i] / sheet.fps[i], 0.0001)
	var sf := View3D.single_frames(sheet, PlaceholderTexture2D.new())
	assert_int(sf.get_frame_count(&"attack3_5")).is_equal(1)


func test_switch_is_on_by_default() -> void:
	assert_bool(bool(ProjectSettings.get_setting(Switch.SETTING, false))).is_true()
	assert_bool(Switch.enabled()).is_true()


func test_packed_model_is_in_the_repo() -> void:
	for id in [&"yi_sun_sin", &"gwanggaeto", &"shin_saimdang", &"sejong"]:
		_check_packed(id)


func _check_packed(id: StringName) -> void:
	var d: Live3DHeroData = load(View3D.data_path(id))
	assert_bool(d.model_path.begins_with("res://assets/live3d/")).is_true()  # Meshy 원본(gitignore)이 아니라 가공 리소스
	assert_bool(ResourceLoader.exists(d.model_path)).is_true()
	assert_bool(d.rigid.is_empty()).is_true()  # 무기 고정은 가공 때 끝남 (게임이 tools/를 부르지 않게)
	for c in d.clips:
		assert_bool(ResourceLoader.exists(String(c["file"]))).is_true()


## 동작 구간의 정본은 굽기 작업 JSON: 3D 설정이 같은 start·end·loop를 쓴다 (다시 자르면 pack_model --stage=sync).
func test_clip_windows_match_bake_jobs() -> void:
	for id in ["yi_sun_sin", "gwanggaeto", "shin_saimdang", "sejong"]:
		var d: Live3DHeroData = load(View3D.data_path(StringName(id)))
		var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/%s.json" % id))
		var want := Live3DHeroData.from_job(job)
		var extra := _extra_keys(id)  # 따로 구운 동작 (뛰어넘기): 3D 구간은 판 중 쓰는 몫만 (굽기보다 좁다)
		assert_int(d.clips.size()).is_equal(want.clips.size() + extra.size())
		for k in extra:
			assert_bool(d.clip(k).is_empty()).override_failure_message("%s %s missing" % [id, k]).is_false()
		for c in want.clips:
			var got := d.clip(String(c["key"]))
			assert_bool(got.is_empty()).override_failure_message("%s %s missing" % [id, c["key"]]).is_false()
			for k in ["start", "end"]:
				assert_float(float(got.get(k, -1.0))).override_failure_message("%s %s %s" % [id, c["key"], k]) 					.is_equal(float(c.get(k, -1.0)))
			assert_bool(bool(got.get("loop", false))).is_equal(bool(c.get("loop", false)))
			assert_array(got.get("times", [])).is_equal(c.get("times", []))


## 3D 설정이 있는 영웅은 3D, 없는 영웅은 구운 그림, 설정을 끄면 예전 PlayerView 그대로.
func test_ready_heroes_get_3d_others_keep_sprites() -> void:
	assert_bool(_view(&"yi_sun_sin", true).get("rig") != null).is_true()
	var none := _view(&"gwanggaeto", true, &"no_live3d_hero")  # data/live3d/<id>.tres가 없는 영웅
	assert_bool(none.get_script() == View3D).is_true()
	assert_bool(none.get("rig") == null).is_true()
	assert_bool(none._sprite != null).is_true()  # 구운 그림
	var off := _view(&"yi_sun_sin", false)
	assert_bool(off.get_script() == View3D).is_false()
	assert_bool(off._sprite.material == null).is_true()


## 3D 영웅 → 3D가 없는 영웅으로 바꾸면 3D 화면·수묵 셰이더가 빠지고 구운 그림만 남는다.
func test_switching_to_a_hero_without_3d_drops_the_rig() -> void:
	var v := _view(&"yi_sun_sin", true)
	assert_bool(v.get("rig") != null).is_true()
	var other: HeroData = (load("res://data/heroes/gwanggaeto.tres") as HeroData).duplicate()
	other.id = &"no_live3d_hero"
	v.player.hero = other
	v.refresh()
	assert_bool(v.get("rig") == null).is_true()
	assert_bool(v._sprite.material == null).is_true()


func _view(id: StringName, live: bool, as_id: StringName = &"") -> PlayerView:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = load("res://data/heroes/%s.tres" % id)
	if as_id != &"":
		p.hero = p.hero.duplicate()
		p.hero.id = as_id
	add_child(p)
	var was: Variant = ProjectSettings.get_setting(Switch.SETTING, true)
	ProjectSettings.set_setting(Switch.SETTING, live)
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	ProjectSettings.set_setting(Switch.SETTING, was)
	return v


## 영웅의 따로 구운 동작 이름 (tools/bake/jobs/<영웅>_*.json, 예: <영웅>_jump.json의 jump_leap).
func _extra_keys(id: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://tools/bake/jobs"):
		if f.begins_with(id + "_") and f.ends_with(".json"):
			var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/" + f))
			for a in job.get("anims", []):
				out.append(String(a["key"]))
	return out
