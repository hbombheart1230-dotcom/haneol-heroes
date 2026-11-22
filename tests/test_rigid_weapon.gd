extends GdUnitTestSuite
## 굽기 도구: 손에 든 무기를 손뼈에만 묶기 (tools/bake/rigid_weapon.gd). 창·붓이 다리 뼈에 묶여 구겨지던 문제.


func test_only_vertices_inside_the_boxes_are_bound_to_the_hand() -> void:
	var verts := PackedVector3Array([Vector3(-0.4, 0.2, 0.2), Vector3(0.0, 1.0, 0.0), Vector3(-0.45, 1.5, 0.2)])
	var bones := PackedInt32Array([20, 21, 0, 0, 3, 2, 0, 0, 14, 15, 0, 0])
	var weights := PackedFloat32Array([0.6, 0.4, 0, 0, 0.7, 0.3, 0, 0, 0.9, 0.1, 0, 0])
	var boxes := [[-0.5, 0.0, 0.1, -0.35, 0.9, 0.3], [-0.6, 1.2, 0.0, -0.3, 2.0, 0.4]]
	var n := RigidWeapon.rebind(verts, bones, weights, boxes, 15)
	assert_int(n).is_equal(2)
	assert_array(Array(bones.slice(0, 4))).is_equal([15, 0, 0, 0])  # 창 아래쪽: 다리 뼈 → 손뼈
	assert_array(Array(weights.slice(0, 4))).is_equal([1.0, 0.0, 0.0, 0.0])
	assert_array(Array(bones.slice(4, 8))).is_equal([3, 2, 0, 0])  # 몸통은 그대로
	assert_float(weights[4]).is_equal_approx(0.7, 0.001)
	assert_array(Array(bones.slice(8, 12))).is_equal([15, 0, 0, 0])


func test_no_boxes_or_missing_bone_changes_nothing() -> void:
	var verts := PackedVector3Array([Vector3.ZERO])
	var bones := PackedInt32Array([1, 2, 0, 0])
	var weights := PackedFloat32Array([0.5, 0.5, 0, 0])
	assert_int(RigidWeapon.rebind(verts, bones, weights, [], 3)).is_equal(0)
	assert_int(RigidWeapon.rebind(verts, bones, weights, [[-1, -1, -1, 1, 1, 1]], -1)).is_equal(0)
	assert_array(Array(bones)).is_equal([1, 2, 0, 0])


func test_long_weapon_heroes_have_rigid_boxes_in_their_bake_jobs() -> void:
	for h in ["gwanggaeto", "shin_saimdang"]:
		var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/%s.json" % h))
		assert_bool(job.has("rigid")).is_true()
		assert_str(String(job["rigid"]["bone"])).is_equal("RightHand")
		assert_int((job["rigid"]["boxes"] as Array).size()).is_greater(0)
