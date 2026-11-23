class_name ClipRetarget
extends RefCounted
## 다른 .glb의 동작을 이 모델에 입힐 때 (굽기 "from", clip_sheet --file): 뼈 이름은 같고 뼈대 노드·크기가 다른 경우.
## Meshy 웹 뼈대(MeshyRig, 72관절)는 뼈대 노드가 SmartRigArmature/Skeleton3D, API 뼈대(24관절)는 Armature/Skeleton3D.
## - 뼈 트랙 경로의 뼈대 노드를 이 모델 것으로 바꾼다 (없는 뼈의 트랙은 Godot이 무시한다).
## - 뿌리 뼈 위치는 두 뼈대의 쉬는 자세 높이 비로 늘이거나 줄인다 (그대로면 엉덩이 높이가 달라 주저앉거나 뜬다).
## 회전은 그대로 옮긴다: 쉬는 자세의 뼈 축이 같은 Meshy 뼈대끼리만 맞다 (docs/research/meshy_web_glb.md).


static func apply(anim: Animation, ap: AnimationPlayer, src_scene: Node) -> void:
	var root := ap.get_node_or_null(ap.root_node)
	var dsts := root.find_children("*", "Skeleton3D", true, false) if root else []
	if dsts.is_empty():
		return
	var dst: Skeleton3D = dsts[0]
	var skel_path := String(root.get_path_to(dst))
	var ratio := root_ratio(dst, src_scene)
	var root_name := dst.get_bone_name(0) if dst.get_bone_count() > 0 else ""
	for i in anim.get_track_count():
		var path := anim.track_get_path(i)
		if path.get_subname_count() == 0 or String(path.get_name(path.get_name_count() - 1)) != dst.name:
			continue
		var bone := String(path.get_concatenated_subnames())
		anim.track_set_path(i, NodePath(skel_path + ":" + bone))
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D and bone == root_name and not is_equal_approx(ratio, 1.0):
			for k in anim.track_get_key_count(i):
				var v: Vector3 = anim.track_get_key_value(i, k)
				anim.track_set_key_value(i, k, v * ratio)


## 이 모델 뿌리 뼈 쉬는 높이 ÷ 원본 뼈대의 같은 뼈 쉬는 높이 (못 찾으면 1).
static func root_ratio(dst: Skeleton3D, src_scene: Node) -> float:
	var srcs := src_scene.find_children("*", "Skeleton3D", true, false) if src_scene else []
	if srcs.is_empty() or dst.get_bone_count() == 0:
		return 1.0
	var s: Skeleton3D = srcs[0]
	var sb := s.find_bone(dst.get_bone_name(0))
	if sb < 0 or absf(s.get_bone_rest(sb).origin.y) < 0.001:
		return 1.0
	return dst.get_bone_rest(0).origin.y / s.get_bone_rest(sb).origin.y
