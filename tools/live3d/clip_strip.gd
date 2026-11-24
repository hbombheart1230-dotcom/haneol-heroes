extends SceneTree
## 동작 하나를 구운 그림(위)과 실시간 3D(아래)로 시간 순서대로 찍는다 (게임 화면이 가리는 사망 등 확인용).
## 창 모드: godot --path . -s res://tools/live3d/clip_strip.gd -- <영웅 id> <동작> <출력 png> [칸 수=8]

const PlayerView3D := preload("res://scripts/player/player_view_3d.gd")
const Rig := preload("res://scripts/art/live3d/live3d_rig.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % a[0])
	var live: Live3DHeroData = load("res://data/live3d/%s.tres" % a[0])
	var anim: String = a[1]
	var n := int(a[3]) if a.size() > 3 else 8
	var sheet := hero.sprite_sheet
	var secs: float = PlayerView3D.durations(sheet).get(anim, 1.0)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.25, 0.3)
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	var r: Node = Rig.new()
	root.add_child(r)
	r.setup(live, PlayerView3D.durations(sheet))
	var spr := Sprite2D.new()
	spr.texture = r.texture()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ink_live.gdshader")
	for k in live.ink:
		mat.set_shader_parameter(k, live.ink[k])
	spr.material = mat
	spr.position = Vector2(128, 384)
	root.add_child(spr)
	var baked := AnimatedSprite2D.new()
	baked.sprite_frames = sheet.build_sprite_frames()
	baked.position = Vector2(128, 128)
	root.add_child(baked)
	r.set_facing(Vector2(0.3, 1.0), 10.0)
	var out := Image.create(256 * n, 512, false, Image.FORMAT_RGBA8)
	for i in n:
		var t := secs * i / float(maxi(n - 1, 1))
		r.play_body(anim, true, t, 0.0)
		baked.animation = StringName("%s_2" % anim)
		baked.frame = mini(roundi(t * sheet.fps[sheet.anim_names.find(anim)]), sheet.frame_count(anim) - 1)
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(0, 0, 256, 512), Vector2i(i * 256, 0))
	out.save_png(a[2])
	quit()
