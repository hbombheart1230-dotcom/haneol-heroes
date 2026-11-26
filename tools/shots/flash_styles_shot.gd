extends SceneTree
## 맞은 순간 몸 색 비교안 (HitReactionData.hit_flash_style)을 실제 한산 장면에서 한 장에 (ShotStage):
## 위 = 화톳불 빛 웅덩이 안, 아래 = 빛 밖 어두운 바닥. 칸마다 왜군 병사 —
## 맞기 전 · 0 흰 번쩍임 · 1 붉은 실루엣 · 2 먹빛 + 인주 테두리 · 3 흰 번쩍임 + 인주 테두리 · 4 한지색 + 먹 테두리.
## godot --path . --resolution 720x1280 -s res://tools/shots/flash_styles_shot.gd -- <출력 png> [무대 id]

const DT := 1.0 / 60.0
const NAMES := ["before", "0 white", "1 red", "2 ink+seal", "3 white+seal", "4 hanji+ink"]
const CROP := Vector2i(720, 600)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self, StringName(args[1]) if args.size() > 1 else &"hansan_1592")
	var player := main.get_node("Player") as Player
	for n in ["AutoAttack", "SkillCaster"]:
		var c := player.get_node_or_null(n)
		if c:
			c.set_physics_process(false)
			c.set_process(false)
	await _wait(3.2)  # 무대 제목 띠가 사라질 때까지
	var spots := [ShotStage.brazier_spot(main), ShotStage.dark_spot(main, 700.0)]
	var shots: Array[Image] = []
	var enemies: Array = []
	for spot in spots:
		for e in enemies:
			e.queue_free()
		enemies = _place(main, spot)
		await _wait(0.4)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var c := img.get_size() / 2 - CROP / 2 + Vector2i(0, -200)
		shots.append(img.get_region(Rect2i(c.clamp(Vector2i.ZERO, img.get_size() - CROP), CROP)))
	var out := Image.create(CROP.x, CROP.y * shots.size(), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		shots[i].convert(Image.FORMAT_RGBA8)
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(0, CROP.y * i))
	out.save_png(args[0])
	quit()


## 영웅을 spot 아래에 두고 spot 둘레에 병사 여섯 (3 × 2)을 세워 칸마다 몸 색을 고정한다.
func _place(main: Node, spot: Vector2) -> Array:
	ShotStage.move_hero(main, spot + Vector2(0, 360))  # 영웅은 아래, 병사들이 빛 웅덩이 한가운데
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var rd := Feedback.feel_data().reaction_data()
	var keep := rd.hit_flash_style
	var out: Array = []
	for i in NAMES.size():
		var at := spot + Vector2(-200 + (i % 3) * 200, -20 + (i / 3) * 180)
		var e := spawner.spawn_at(data, at)
		e.set_physics_process(false)
		e._physics_process(DT)
		e.global_position = at
		if i > 0:
			rd.hit_flash_style = i - 1
			var m := e.sprite.material as ShaderMaterial
			m.set_shader_parameter(&"flash", rd.flash_white if rd.blinks() else 1.0)
			m.set_shader_parameter(&"flash_color", rd.flash_body())
			m.set_shader_parameter(&"flash_rim", rd.flash_rim())
		var l := Label.new()
		l.text = NAMES[i]
		l.position = Vector2(-60, 24)
		l.add_theme_font_size_override(&"font_size", 20)
		l.add_theme_color_override(&"font_color", Color(1, 1, 0.8))
		l.add_theme_constant_override(&"outline_size", 4)
		l.add_theme_color_override(&"font_outline_color", Color.BLACK)
		e.add_child(l)
		out.append(e)
	rd.hit_flash_style = keep
	return out


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
