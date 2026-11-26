class_name BoneProp
extends RefCounted
## 굽기 때 뼈에 단단히 붙이는 간단한 소품 (북). 작업의 "prop": {"bone", "pos": [x,y,z], "rot": [x,y,z 도], "radius", "depth", "color", "head_color"}.
## 모델 메시는 건드리지 않고 BoneAttachment3D에 원통 둘(몸통·가죽)을 얹는다.


static func apply(model: Node, cfg: Dictionary) -> void:
	var skel := _find_skeleton(model)
	if skel == null or skel.find_bone(String(cfg["bone"])) < 0:
		push_warning("BoneProp: 뼈를 찾지 못함 %s" % cfg.get("bone"))
		return
	var att := BoneAttachment3D.new()
	att.bone_name = String(cfg["bone"])
	skel.add_child(att)
	var root := Node3D.new()
	var p: Array = cfg.get("pos", [0, 0, 0])
	var r: Array = cfg.get("rot", [0, 0, 0])
	root.position = Vector3(p[0], p[1], p[2])
	root.rotation_degrees = Vector3(r[0], r[1], r[2])
	att.add_child(root)
	var rad := float(cfg.get("radius", 0.22))
	var depth := float(cfg.get("depth", 0.25))
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rad
	cyl.bottom_radius = rad
	cyl.height = depth
	body.mesh = cyl
	body.material_override = _mat(Color(cfg.get("color", "#6b3f22")))
	root.add_child(body)
	var head := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = rad * 0.96
	disc.bottom_radius = rad * 0.96
	disc.height = depth * 0.04
	head.mesh = disc
	head.position = Vector3(0, depth * 0.5, 0)
	head.material_override = _mat(Color(cfg.get("head_color", "#d8c49a")))
	root.add_child(head)


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
