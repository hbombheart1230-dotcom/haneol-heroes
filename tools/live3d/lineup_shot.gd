extends SceneTree
## 영웅 넷을 한 줄(같은 발 높이)에 게임 크기(sprite_scale · sprite_offset × 무대 확대 1.09)로 세운다.
## 위 = 실시간 3D (수묵 셰이더), 아래 = 구운 그림. 화면 키 비율을 눈으로 맞출 때.
## 창 모드: godot --path . -s res://tools/live3d/lineup_shot.gd -- <출력 png>

const PlayerView3D := preload("res://scripts/player/player_view_3d.gd")
const Rig := preload("res://scripts/art/live3d/live3d_rig.gd")
const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang", "sejong"]
const ZOOM := 1.09


func _initialize() -> void:
	_run()


func _run() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.3, 0.34)
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	for i in HEROES.size():
		var hero: HeroData = load("res://data/heroes/%s.tres" % HEROES[i])
		var feet := [Vector2(100 + i * 170, 520), Vector2(100 + i * 170, 900)]
		var line := Line2D.new()
		line.points = PackedVector2Array([feet[0] + Vector2(-80, 0), feet[0] + Vector2(80, 0)])
		line.width = 1.0
		root.add_child(line)
		var path := PlayerView3D.data_path(StringName(HEROES[i]))
		if ResourceLoader.exists(path):
			var live: Live3DHeroData = load(path)
			var r: Node = Rig.new()
			root.add_child(r)
			r.setup(live, PlayerView3D.durations(hero.sprite_sheet))
			r.play_body("idle", true, 0.0, 0.0)
			var s := Sprite2D.new()
			s.texture = r.texture()
			var mat := ShaderMaterial.new()
			mat.shader = load("res://shaders/ink_live.gdshader")
			for k in live.ink:
				mat.set_shader_parameter(k, live.ink[k])
			s.material = mat
			s.scale = Vector2.ONE * hero.sprite_scale * ZOOM
			s.position = feet[0] + hero.sprite_offset * ZOOM
			root.add_child(s)
		var b := AnimatedSprite2D.new()
		b.sprite_frames = hero.sprite_sheet.build_sprite_frames()
		b.animation = &"idle_2"
		b.scale = Vector2.ONE * hero.sprite_scale * ZOOM
		b.position = feet[1] + hero.sprite_offset * ZOOM
		root.add_child(b)
		var l := Label.new()
		l.text = HEROES[i]
		l.position = feet[1] + Vector2(-70, 20)
		root.add_child(l)
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(0, 200, 720, 760)).save_png(OS.get_cmdline_user_args()[0])
	quit()
