extends "res://tools/bake/bake_sprites.gd"
## 동작 미리보기: 굽기 작업의 동작 하나를 실제 모델로 여러 시각에 찍어 한 줄로 저장한다 (from·to·strike 고르기용).
## godot --path . -s res://tools/bake/clip_sheet.gd -- --job=<이름> --anim=<키> --out=<png> [--samples=16] [--dir=1] [--src=<동작 이름>]
##   [--yaw=<도>] (몸을 더 돌림, 기본 = 작업의 yaw) [--from=<초> --to=<초>] (그 구간만 촘촘히) [--size=<px>] (칸 크기, 크게 보기) [--file=<res://...glb>] (작업에 없는 추가 동작 파일)
## 출력 png 옆에 <png>.txt로 시각(초) 목록과 동작 길이를 쓴다. --src를 주면 작업의 src 대신 그 동작 (Meshy 후보 비교).


func _initialize() -> void:
	_run()


func _run() -> void:
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
		if a["key"] == args.get("anim", "attack"):
			anim = a
	if anim.is_empty():
		push_error("job/anim not found")
		quit(1)
		return
	if args.has("size"):
		job["frame"] = int(args["size"])
	var ap := _setup(job)
	var src: String = args.get("src", anim["src"])
	var file: String = args.get("file", anim.get("from", ""))
	var name := import_anim(ap, file, src, anim["key"]) if file != "" else find_anim(ap, src)
	var a: Animation = ap.get_animation(name)
	var n := int(args.get("samples", "16"))
	var d := int(args.get("dir", "1"))
	var sd := Vector2.from_angle(d * TAU / DIRS)
	_pivot.rotation.y = atan2(sd.x, sd.y) + deg_to_rad(float(args.get("yaw", str(anim.get("yaw", 0.0)))))
	var frame := int(job["frame"])
	var strip := Image.create(frame * n, frame, false, Image.FORMAT_RGBA8)
	var times := PackedStringArray()
	for i in n:
		var t0 := float(args.get("from", "0"))
		var t1 := minf(float(args.get("to", str(a.length))), a.length)
		var t := t0 + (t1 - t0) * i / float(maxi(n - 1, 1))
		ap.play(name)
		ap.seek(t, true)
		ap.pause()
		_lock_root(job)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(img, Rect2i(0, 0, frame, frame), Vector2i(i * frame, 0))
		times.append("%.2f" % t)
	var out: String = args.get("out", "user://clip.png")
	strip.save_png(out)
	var f := FileAccess.open(out + ".txt", FileAccess.WRITE)
	f.store_string("length %.2f\n%s\n" % [a.length, " ".join(times)])
	f.close()
	print("CLIP ", name, " length ", a.length)
	quit()
