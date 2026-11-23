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
	var a2 := d.clip("attack2")
	assert_float(float(a2["start"])).is_equal(0.85)
	assert_float(float(a2["end"])).is_equal(1.6)
	assert_str(String(a2["file"])).ends_with("animated_extra2.glb")
	assert_bool(bool(d.clip("run")["loop"])).is_true()


func test_saved_data_matches_bake_job() -> void:
	var d: Live3DHeroData = load(View3D.data_path(&"yi_sun_sin"))
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/yi_sun_sin.json"))
	assert_int(d.clips.size()).is_equal((job["anims"] as Array).size())
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
	for id in [&"yi_sun_sin", &"gwanggaeto"]:
		_check_packed(id)


func _check_packed(id: StringName) -> void:
	var d: Live3DHeroData = load(View3D.data_path(id))
	assert_bool(d.model_path.begins_with("res://assets/live3d/")).is_true()  # Meshy 원본(gitignore)이 아니라 가공 리소스
	assert_bool(ResourceLoader.exists(d.model_path)).is_true()
	assert_bool(d.rigid.is_empty()).is_true()  # 무기 고정은 가공 때 끝남 (게임이 tools/를 부르지 않게)
	for c in d.clips:
		assert_bool(ResourceLoader.exists(String(c["file"]))).is_true()


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
