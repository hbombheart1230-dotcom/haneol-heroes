extends "res://tools/bake/bake_sprites.gd"
## 발 미끄러짐 재기: 이동 동작에서 땅에 닿은 발이 뒤로 가는 속도(m/s, 재생 1배)를 재고,
## 게임 이동 속도(px/s)에 맞는 fps를 알려 준다 (발이 땅에 붙어 보이는 재생 속도).
## godot --path . -s res://tools/bake/stride.gd -- --job=<이름> --speed=<px/s> --scale=<sprite_scale> [--anim=run]
## 결과 줄: STRIDE <작업> ground=<m/s> game=<m/s> rate=<배> fps_now=<지금> fps_fit=<맞는 fps>


func _initialize() -> void:
	_measure()  # 코루틴: 샘플마다 한 프레임 기다린다


func _measure() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var job: Dictionary = {}
	for j in _all_jobs():
		if j["name"] == args.get("job", ""):
			job = j
	var anim: Dictionary = {}
	for a in job.get("anims", []):
		if a["key"] == args.get("anim", "run"):
			anim = a
	if anim.is_empty():
		push_error("job/anim not found")
		quit(1)
		return
	var ap := _setup(job)
	var name := import_anim(ap, anim["from"], anim["src"], anim["key"]) if anim.has("from") else find_anim(ap, anim["src"])
	var a: Animation = ap.get_animation(name)
	var win := BakeTip.window(anim, a.length)
	var feet := [_skel.find_bone("LeftFoot"), _skel.find_bone("RightFoot")]
	if feet.has(-1):
		push_error("no foot bones: %s" % _skel.get_concatenated_bone_names())
		quit(1)
		return
	var n := 120
	var dt := (win.y - win.x) / n
	var pos: Array = []  # 샘플마다 [왼발, 오른발] 위치 (뿌리 고정)
	for i in n + 1:
		ap.play(name)
		ap.seek(win.x + dt * i, true)
		ap.pause()
		_lock_root(job)
		await process_frame  # 동작이 뼈에 적용되는 것은 다음 처리 때
		var g := _skel.global_transform
		pos.append([g * _skel.get_bone_global_pose(feet[0]).origin, g * _skel.get_bone_global_pose(feet[1]).origin])
	var speeds := ground_speeds(pos, dt)
	var ground := median(speeds)
	var px_per_m := float(job["frame"]) / float(job["ortho_size"]) * float(args.get("scale", "1.0"))
	var game := float(args.get("speed", "100")) / px_per_m
	var rate := game / maxf(ground, 0.001)
	var frames := int(anim["frames"])
	var fit := frames / ((win.y - win.x) / rate)
	print("STRIDE %s ground=%.2f game=%.2f rate=%.2f fps_now=%.1f fps_fit=%.1f" % [job["name"], ground, game, rate, float(anim["fps"]), fit])
	quit()


## 샘플마다 더 낮은 발(땅에 닿은 발)의 앞뒤 속도 크기. 발이 땅 근처(가장 낮은 높이 + 3cm)일 때만.
static func ground_speeds(pos: Array, dt: float) -> PackedFloat32Array:
	var low := INF
	for p in pos:
		low = minf(low, minf(p[0].y, p[1].y))
	var out := PackedFloat32Array()
	for i in range(1, pos.size()):
		var k := 0 if pos[i][0].y <= pos[i][1].y else 1
		if pos[i][k].y > low + 0.03:
			continue
		var d: Vector3 = pos[i][k] - pos[i - 1][k]
		out.append(Vector2(d.x, d.z).length() / dt)
	return out


static func median(v: PackedFloat32Array) -> float:
	if v.is_empty():
		return 0.0
	var s := Array(v)
	s.sort()
	return float(s[s.size() / 2])
