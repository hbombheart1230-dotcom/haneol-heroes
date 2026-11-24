extends SceneTree
## 다른 뼈대(예: Meshy 웹 자동 뼈대)의 동작을 지금 영웅 뼈대(API 뼈대)로 옮긴다 (같은 메시·같은 기본 자세에 심은 두 뼈대).
## 뼈 이름이 같아도 기본 자세의 축이 달라(최대 178°) 트랙을 그대로 쓰면 꼬인다 → 모델 공간에서 "기본 자세에서 돈 만큼"을
## 뼈마다 옮긴다: 목표 전역 회전 = (원본 전역 회전 × 원본 기본 전역 회전⁻¹) × 목표 기본 전역 회전.
## 엉덩이 위치는 몸(메시) 키 비율로. 결과: assets/live3d/<영웅>/anims/<접두>_<동작>.res (원본 동작 전체, 자르기는 게임이).
## godot --headless --path . -s res://tools/live3d/retarget_clip.gd -- <영웅> <원본 .glb> [접두=web] [fps=30]

const Lib := preload("res://scripts/art/live3d/live3d_library.gd")


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var hero: String = a[0]
	var prefix: String = a[2] if a.size() > 2 else "web"
	var fps := float(a[3]) if a.size() > 3 else 30.0
	var dst_path := "res://assets/live3d/%s/model.scn" % hero
	if not ResourceLoader.exists(dst_path):  # 3D가 없는 적: 굽기 원본 모델에 맞춘다
		dst_path = "res://assets/models/meshy/%s/animated.glb" % hero
	var dst_root: Node = (load(dst_path) as PackedScene).instantiate()
	var src_root: Node = (load(a[1]) as PackedScene).instantiate()
	var dst := dst_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var src := src_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := src_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var src_path := String(src_root.get_path_to(src))
	for name in ap.get_animation_list():
		if name == &"RESET":
			continue
		var out := retarget(ap.get_animation(name), src_path, src, _model_xf(src_root, src), dst, _model_xf(dst_root, dst), fps)
		var path := "res://assets/live3d/%s/anims/%s_%s.res" % [hero, prefix, Lib.norm(name)]
		print(path, " ", ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS), " len ", out.length)
	src_root.free()
	dst_root.free()
	quit()


## 장면 뿌리 → 뼈대 노드까지의 변환 (Armature 노드의 회전·크기 포함).
static func _model_xf(root: Node, sk: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = sk
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func retarget(anim: Animation, src_path: String, src: Skeleton3D, src_xf: Transform3D,
		dst: Skeleton3D, dst_xf: Transform3D, fps: float) -> Animation:
	var out := Animation.new()
	out.length = anim.length
	var src_rest := _global_rests(src)
	var dst_rest := _global_rests(dst)
	var sq := src_xf.basis.get_rotation_quaternion()
	var dq := dst_xf.basis.get_rotation_quaternion()
	var tracks := {}  # 목표 뼈 → 회전 트랙 번호
	for b in dst.get_bone_count():
		if src.find_bone(dst.get_bone_name(b)) >= 0:
			var t := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(t, NodePath("Armature/Skeleton3D:%s" % dst.get_bone_name(b)))
			tracks[b] = t
	var hip_t := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hip_t, NodePath("Armature/Skeleton3D:Hips"))
	var hs := src.find_bone("Hips")
	var hd := dst.find_bone("Hips")
	var k := mesh_height(dst) / maxf(mesh_height(src), 0.0001)  # 몸 크기 비 (자동 뼈대마다 엉덩이 높이가 달라 메시 키로)
	var n := maxi(ceili(anim.length * fps), 1)
	for i in n + 1:
		var t := minf(i / fps, anim.length)
		var pose := _global_pose(anim, src_path, src, t)
		var g := {}  # 목표 뼈 → 뼈대 공간 전역 회전
		for b in dst.get_bone_count():
			var sb := src.find_bone(dst.get_bone_name(b))
			var p := dst.get_bone_parent(b)
			var parent_g: Quaternion = g[p] if p >= 0 else Quaternion.IDENTITY
			if sb < 0:  # 원본에 없는 뼈: 기본 자세 그대로 부모를 따라간다
				g[b] = parent_g * dst.get_bone_rest(b).basis.get_rotation_quaternion()
				continue
			var delta: Quaternion = (sq * pose[sb].basis.get_rotation_quaternion()) \
				* (sq * src_rest[sb].basis.get_rotation_quaternion()).inverse()  # 모델 공간에서 돈 만큼
			g[b] = dq.inverse() * delta * dq * dst_rest[b].basis.get_rotation_quaternion()
			out.rotation_track_insert_key(tracks[b], t, (parent_g.inverse() * g[b]).normalized())
		var move: Vector3 = sq * ((pose[hs] as Transform3D).origin - (src_rest[hs] as Transform3D).origin) * src_xf.basis.get_scale().x  # 모델 공간 이동
		var local: Vector3 = dq.inverse() * (move * k) / dst_xf.basis.get_scale().x
		out.position_track_insert_key(hip_t, t, dst.get_bone_rest(hd).origin + local)
	return out


## 뼈대가 움직이는 메시의 키 (모델 공간, m).
static func mesh_height(sk: Skeleton3D) -> float:
	var root := sk.owner if sk.owner else sk.get_parent()
	var h := 0.0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		h = maxf(h, ((mi as MeshInstance3D).get_aabb().size.y))
	return h


static func _global_rests(sk: Skeleton3D) -> Array:
	var out: Array = []
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		out.append((out[p] as Transform3D) * sk.get_bone_rest(b) if p >= 0 else sk.get_bone_rest(b))
	return out


## 시각 t의 원본 뼈대 전역 자세 (트랙이 없는 뼈는 기본 자세).
static func _global_pose(anim: Animation, src_path: String, sk: Skeleton3D, t: float) -> Array:
	var local: Array = []
	for b in sk.get_bone_count():
		local.append(sk.get_bone_rest(b))
	for i in anim.get_track_count():
		var path := String(anim.track_get_path(i))
		if not path.begins_with(src_path + ":"):
			continue
		var b := sk.find_bone(path.get_slice(":", 1))
		if b < 0:
			continue
		var xf: Transform3D = local[b]
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				xf.basis = Basis(anim.rotation_track_interpolate(i, t)).scaled(xf.basis.get_scale())
			Animation.TYPE_POSITION_3D:
				xf.origin = anim.position_track_interpolate(i, t)
		local[b] = xf
	var out: Array = []
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		out.append((out[p] as Transform3D) * local[b] if p >= 0 else local[b])
	return out
