extends RefCounted
## 실시간 3D 동작 나무 (AnimationTree, Godot 기본 기능):
##   몸: 동작마다 입력 하나인 Transition(섞기 blend_time) → TimeSeek → TimeScale ─┐
##   윗몸: 같은 구조(섞기 upper_blend_time) ────────────────────────────────────┴→ Blend2(윗몸 뼈만) → 출력
## 서서 칠 때는 몸이 공격 동작, 달리며 칠 때는 몸 = 달리기 + 윗몸 = 공격 (Blend2 0 → 1).


static func build(model: Node, d: Live3DHeroData, lib: AnimationLibrary) -> AnimationTree:
	var t := AnimationTree.new()
	t.name = "Live3DTree"
	model.add_child(t)
	t.root_node = NodePath("..")
	t.add_animation_library(&"live", lib)
	var bt := AnimationNodeBlendTree.new()
	var keys := lib.get_animation_list()
	for branch in ["body", "upper"]:
		var tr := AnimationNodeTransition.new()
		tr.xfade_time = d.blend_time if branch == "body" else d.upper_blend_time
		tr.allow_transition_to_self = true
		for k in keys:
			tr.add_input(String(k))
		bt.add_node(branch, tr)
		for i in keys.size():
			var an := AnimationNodeAnimation.new()
			an.animation = StringName("live/%s" % keys[i])
			bt.add_node("%s_%s" % [branch, keys[i]], an)
			bt.connect_node(branch, i, "%s_%s" % [branch, keys[i]])
		bt.add_node(branch + "_seek", AnimationNodeTimeSeek.new())
		bt.connect_node(branch + "_seek", 0, branch)
		bt.add_node(branch + "_ts", AnimationNodeTimeScale.new())
		bt.connect_node(branch + "_ts", 0, branch + "_seek")
	var layer := AnimationNodeBlend2.new()
	layer.filter_enabled = true
	for bone in d.upper_bones:
		layer.set_filter_path(NodePath("%s:%s" % [d.skeleton_path, bone]), true)
	bt.add_node("layer", layer)
	bt.connect_node("layer", 0, "body_ts")
	bt.connect_node("layer", 1, "upper_ts")
	bt.connect_node("output", 0, "layer")
	t.tree_root = bt
	t.active = true
	return t
