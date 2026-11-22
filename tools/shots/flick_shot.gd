extends SceneTree
## 사임당 먹 털기 1·2·3타를 시간 순서대로 찍는다 (줄 = 1타 가로 털기 / 2타 세로 털기 / 3타 원으로 뿌리기, 칸 = 시각).
## 흰 선 = 판정 모양 (그대로). godot --path . --resolution 720x1280 -s res://tools/shots/flick_shot.gd -- <출력 png>

const TIMES := [0.03, 0.08, 0.14, 0.25, 0.36]
const AT := Vector2(360, 760)
const CROP := Rect2i(90, 470, 540, 560)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/shin_saimdang.tres")
	var st: StageTheme = load("res://data/stages/chochungdo.tres")
	var bg := Sprite2D.new()
	bg.texture = load(st.background_path)
	bg.position = Vector2(360, 640)
	bg.scale = Vector2.ONE * maxf(720.0 / bg.texture.get_size().x, 1280.0 / bg.texture.get_size().y)
	root.add_child(bg)
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var d := hero.attack
	var shots: Array[Image] = []
	for s in [1, 2, 3]:
		var reach := d.melee_range * ComboSteps.at(d.step_range_mults, s, 1.0)
		var arc := d.melee_arc_degrees * ComboSteps.at(d.step_arc_mults, s, 1.0)
		for t in TIMES:
			var hero_s := AnimatedSprite2D.new()
			hero_s.sprite_frames = hero.sprite_sheet.shared_sprite_frames()
			hero_s.animation = "attack" if hero_s.sprite_frames.has_animation("attack") else hero_s.sprite_frames.get_animation_names()[0]
			hero_s.scale = Vector2.ONE * hero.sprite_scale
			hero_s.position = AT + hero.sprite_offset
			root.add_child(hero_s)
			var guide := Line2D.new()
			guide.width = 2.0
			guide.default_color = Color(1, 1, 1, 0.6)
			var a0 := -PI * 0.5 - deg_to_rad(minf(arc, 360.0)) * 0.5
			var n := 40
			if arc < 360.0:
				guide.add_point(AT)
			for i in n + 1:
				guide.add_point(AT + Vector2.from_angle(a0 + deg_to_rad(minf(arc, 360.0)) * i / n) * reach)
			if arc < 360.0:
				guide.add_point(AT)
			root.add_child(guide)
			var fx := BrushFlickFx.new(BrushFlickData.get_default(), feel.stroke_art)
			root.add_child(fx)
			fx.set_process(false)
			fx.flick(AT, Vector2.UP, reach, arc, s, d.swing_color)
			fx.step(t)
			fx.queue_redraw()
			for f in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var vk := img.get_width() / 720.0
			shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
			for nd in [hero_s, guide, fx]:
				nd.queue_free()
			await process_frame
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var cols := TIMES.size()
	var out := Image.create((w + 6) * cols, (h + 6) * 3, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % cols) * (w + 6), (i / cols) * (h + 6)))
	out.save_png(args[0])
	quit()
