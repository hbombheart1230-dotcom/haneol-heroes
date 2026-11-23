extends SceneTree
## 텍스처 크기 비교: 가공 모델(1024)과 Meshy 원본 텍스처(2048)를 같은 자세로 찍어 한 장으로 + 비디오 메모리.
## 창 모드: godot --path . -s res://tools/live3d/tex_compare.gd -- <이름> <원본 텍스처 res 경로> <출력 png>
## 칸: [게임 크기 256px 1024 | 2048] [2배 512px 1024 | 2048] (수묵 전 원래 렌더).

const PlayerView3D := preload("res://scripts/player/player_view_3d.gd")
const Rig := preload("res://scripts/art/live3d/live3d_rig.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var live: Live3DHeroData = load("res://data/live3d/%s.tres" % a[0])
	var hero: HeroData = load("res://data/heroes/%s.tres" % a[0])
	var big: Texture2D = load(a[1])
	var cells: Array[Image] = []
	var vmem := {}
	for frame in [256, 512]:
		for use_big in [false, true]:
			var d := live.duplicate() as Live3DHeroData
			d.frame = frame
			var v0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
			var r: Node = Rig.new()
			root.add_child(r)
			r.setup(d, PlayerView3D.durations(hero.sprite_sheet))
			if use_big:
				for mi in r.pivot.find_children("*", "MeshInstance3D", true, false):
					var m := ((mi as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
					m.albedo_texture = big
					(mi as MeshInstance3D).material_override = m
			r.play_body("idle", true, 0.4, 0.0)
			r.set_facing(Vector2(0.4, 1.0), 10.0)
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = r.viewport.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			cells.append(img)
			if frame == 256:
				vmem["2048" if use_big else "1024"] = (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - v0) / 1048576.0
			r.queue_free()
			await process_frame
	var w := 0
	for c in cells:
		w += c.get_width()
	var out := Image.create(w, 512, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.85, 0.82, 0.75))
	var x := 0
	for c in cells:
		out.blend_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(x, 512 - c.get_height()))
		x += c.get_width()
	out.save_png(a[2])
	print("TEXMEM ", JSON.stringify(vmem))
	quit()
