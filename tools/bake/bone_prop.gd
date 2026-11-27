class_name BoneProp
extends RefCounted
## 굽기 때 뼈에 단단히 붙이는 간단한 소품 (북·북채). 작업의 "prop": 항목 하나 또는 목록.
## 항목: {"shape": "drum"|"stick", "bone", "pos": [x,y,z], "rot": [x,y,z 도], ...}. 길이 단위는 메시 뼈대 단위(Meshy 뼈대는 cm).
##  drum : radius, depth, color, head_color, rope_color — 몸통(나무 결)·가죽 면·밧줄 테두리 둘.
##  stick: radius, length, color — 북채 (뼈에서 위(+Y)로 뻗음).
## 모델 메시는 건드리지 않고 BoneAttachment3D에 원통을 얹는다.


static func apply(model: Node, cfg) -> void:
	var items: Array = cfg if cfg is Array else [cfg]
	var skel := _find_skeleton(model)
	for item in items:
		if skel == null or skel.find_bone(String(item["bone"])) < 0:
			push_warning("BoneProp: 뼈를 찾지 못함 %s" % item.get("bone"))
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = String(item["bone"])
		skel.add_child(att)
		var root := Node3D.new()
		var p: Array = item.get("pos", [0, 0, 0])
		var r: Array = item.get("rot", [0, 0, 0])
		root.position = Vector3(p[0], p[1], p[2])
		root.rotation_degrees = Vector3(r[0], r[1], r[2])
		att.add_child(root)
		if String(item.get("shape", "drum")) == "stick":
			_stick(root, item)
		else:
			_drum(root, item)


static func _drum(root: Node3D, c: Dictionary) -> void:
	var rad := float(c.get("radius", 24.0))
	var depth := float(c.get("depth", 30.0))
	_cyl(root, rad, depth, Vector3.ZERO, _wood(Color(c.get("color", "#7a4a26"))))
	_cyl(root, rad * 0.97, depth * 0.04, Vector3(0, depth * 0.5, 0), _mat(Color(c.get("head_color", "#e2d2a8"))))
	var rope := _mat(Color(c.get("rope_color", "#8a2a22")))
	for y in [-0.36, 0.36]:  # 위·아래 밧줄 테
		_cyl(root, rad * 1.03, depth * 0.07, Vector3(0, depth * y, 0), rope)


static func _stick(root: Node3D, c: Dictionary) -> void:
	var len := float(c.get("length", 45.0))
	_cyl(root, float(c.get("radius", 1.4)), len, Vector3(0, len * 0.5, 0), _mat(Color(c.get("color", "#a9814f"))))


static func _cyl(parent: Node3D, rad: float, h: float, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rad
	cyl.bottom_radius = rad
	cyl.height = h
	m.mesh = cyl
	m.position = at
	m.material_override = mat
	parent.add_child(m)


## 나무 결: 한 방향으로 길게 늘인 잡음 무늬 (엔진 기본 FastNoiseLite — 새로 받은 결 없음).
static func _wood(base: Color) -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 64
	t.height = 512
	t.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, base.darkened(0.35))
	grad.set_color(1, base.lightened(0.15))
	t.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.roughness = 0.85
	return m


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null
