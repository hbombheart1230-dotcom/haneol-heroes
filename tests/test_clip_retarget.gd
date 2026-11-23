extends GdUnitTestSuite
## 다른 뼈대 파일의 동작 입히기 (tools/bake/clip_retarget.gd): Meshy 웹 뼈대(SmartRigArmature)의 동작을
## API 뼈대(Armature) 모델에 — 뼈 트랙 경로를 바꾸고, 뿌리 뼈 위치는 쉬는 자세 높이 비로.


func _rig(armature: String, hips_y: float) -> Node3D:
	var root := Node3D.new()
	var arm := Node3D.new()
	arm.name = armature
	root.add_child(arm)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	arm.add_child(sk)
	sk.add_bone("Hips")
	sk.set_bone_rest(0, Transform3D(Basis(), Vector3(0, hips_y, 0)))
	sk.add_bone("Spine")
	sk.set_bone_parent(1, 0)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.root_node = NodePath("..")
	return root


func test_tracks_move_to_target_skeleton_and_hips_scale() -> void:
	var dst := _rig("Armature", 1.0)
	var src := _rig("SmartRigArmature", 0.8)
	add_child(auto_free(dst))
	add_child(auto_free(src))
	var a := Animation.new()
	var p := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(p, ^"SmartRigArmature/Skeleton3D:Hips")
	a.position_track_insert_key(p, 0.0, Vector3(0.1, 0.8, 0.2))
	var r := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(r, ^"SmartRigArmature/Skeleton3D:Spine")
	a.rotation_track_insert_key(r, 0.0, Quaternion(Vector3.UP, 0.5))
	ClipRetarget.apply(a, dst.get_node("AnimationPlayer"), src)
	assert_str(String(a.track_get_path(p))).is_equal("Armature/Skeleton3D:Hips")
	assert_str(String(a.track_get_path(r))).is_equal("Armature/Skeleton3D:Spine")
	assert_vector(a.track_get_key_value(p, 0)).is_equal_approx(Vector3(0.125, 1.0, 0.25), Vector3.ONE * 0.001)  # × 1.0/0.8
	assert_float((a.track_get_key_value(r, 0) as Quaternion).get_angle()).is_equal_approx(0.5, 0.001)  # 회전은 그대로


func test_same_rig_is_unchanged() -> void:
	var dst := _rig("Armature", 1.0)
	add_child(auto_free(dst))
	var a := Animation.new()
	var p := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(p, ^"Armature/Skeleton3D:Hips")
	a.position_track_insert_key(p, 0.0, Vector3(0, 1, 0))
	ClipRetarget.apply(a, dst.get_node("AnimationPlayer"), dst)
	assert_str(String(a.track_get_path(p))).is_equal("Armature/Skeleton3D:Hips")
	assert_vector(a.track_get_key_value(p, 0)).is_equal(Vector3(0, 1, 0))
