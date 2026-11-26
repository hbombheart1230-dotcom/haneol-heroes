class_name RigidWeapon
extends RefCounted
## 손에 든 무기를 손뼈에만 묶는다 (굽기 전에 모델에 적용).
## Meshy 자동 뼈대는 무기를 몸의 일부로 보고 가까운 뼈(다리·팔뚝)에 나눠 묶어서, 긴 창·붓이 걸을 때 구겨진다.
## 굽기 설정의 "rigid": {"bone": "RightHand", "boxes": [[x0, y0, z0, x1, y1, z1], ...]} —
## 기본 자세(rest)에서 상자 안에 있는 꼭짓점을 그 뼈 하나에 100% 묶는다. 상자는 메시 좌표(m).
## 숫자 7개 [x0, y0, z0, x1, y1, z1, r]는 캡슐(두 점을 잇는 선에서 r 안): 비스듬한 창 자루만 골라 묶는다
## (상자는 자루 옆의 소매·발까지 잡아 손에 붙여 버렸다 — 왜군 병사 창이 꺾이고 떨어지던 원인, 2026-11-23).


## 상자 안이면 true.
static func inside(p: Vector3, boxes: Array) -> bool:
	for b in boxes:
		if b.size() >= 7:
			if in_capsule(p, Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), float(b[6])):
				return true
		elif p.x >= float(b[0]) and p.y >= float(b[1]) and p.z >= float(b[2]) \
				and p.x <= float(b[3]) and p.y <= float(b[4]) and p.z <= float(b[5]):
			return true
	return false


## 선분 a–b에서 거리 r 안인지.
static func in_capsule(p: Vector3, a: Vector3, b: Vector3, r: float) -> bool:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t) <= r


## 스킨에서 이 뼈를 가리키는 묶음 번호 (없으면 -1).
static func bind_index(skin: Skin, skel: Skeleton3D, bone: String) -> int:
	for i in skin.get_bind_count():
		var n := String(skin.get_bind_name(i))
		if n == "" and skel:
			n = skel.get_bone_name(skin.get_bind_bone(i))
		if n == bone:
			return i
	return -1


## 한 표면의 뼈·가중치 배열을 고친다. 고친 꼭짓점 수를 돌려준다.
static func rebind(verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array,
		boxes: Array, bind: int) -> int:
	if verts.is_empty() or bind < 0:
		return 0
	var per := bones.size() / verts.size()
	var n := 0
	for i in verts.size():
		if not inside(verts[i], boxes):
			continue
		n += 1
		for j in per:
			bones[i * per + j] = bind if j == 0 else 0
			weights[i * per + j] = 1.0 if j == 0 else 0.0
	return n


## 상자 안 꼭짓점을 한 점으로 모아 그 부분을 안 보이게 한다 (손에 든 창 지우기). 모은 꼭짓점 수.
static func hide_verts(verts: PackedVector3Array, boxes: Array, point: Vector3) -> int:
	var n := 0
	for i in verts.size():
		if inside(verts[i], boxes):
			verts[i] = point
			n += 1
	return n


## 모델의 모든 스킨 메시에 적용. 고친 꼭짓점 수.
static func apply(model: Node, cfg: Dictionary) -> int:
	var boxes: Array = cfg.get("boxes", [])
	var bone := String(cfg.get("bone", "RightHand"))
	var total := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var src := mi.mesh as ArrayMesh
		if src == null or mi.skin == null:
			continue
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var bind := bind_index(mi.skin, skel, bone)
		if bind < 0:
			continue
		var out := ArrayMesh.new()
		for s in src.get_surface_count():
			var arr := src.surface_get_arrays(s)
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if cfg.get("hide", false):  # 무기를 묶는 대신 지운다
				var hp: Array = cfg.get("hide_point", [0, 1.0, 0])
				var hv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				total += hide_verts(hv, boxes, Vector3(hp[0], hp[1], hp[2]))
				arr[Mesh.ARRAY_VERTEX] = hv
			else:
				total += rebind(arr[Mesh.ARRAY_VERTEX], bones, weights, boxes, bind)
			arr[Mesh.ARRAY_BONES] = bones
			arr[Mesh.ARRAY_WEIGHTS] = weights
			var eight := bones.size() == (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 8
			out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr, [], {},
				Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0)
			out.surface_set_material(s, src.surface_get_material(s))
		mi.mesh = out
	return total
