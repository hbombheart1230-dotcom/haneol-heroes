extends SceneTree
## 사임당 풀벌레(SummonCritter) 그림을 실제 크기로 무대 위에 찍는다 (위: 지금 데이터, 아래: 시험 그림).
## godot --path . --resolution 720x1280 -s res://tools/shots/critter_shot.gd -- <출력 png> [시험 방아깨비 png]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var st: StageTheme = load("res://data/stages/chochungdo.tres")
	ShotStage.backdrop(self, st)  # 실제 바닥 (floor_grade·빛 웅덩이·비네트·무대 확대)
	var hero: HeroData = load("res://data/heroes/shin_saimdang.tres")
	var skill := hero.kit.tap as CritterSkill
	var trial: Texture2D = null
	if args.size() > 1:
		trial = ImageTexture.create_from_image(Image.load_from_file(args[1]))
	var ages := [0.1, 0.25, 1.0, 1.05]
	for row in 3:
		for i in ages.size():
			var c := SummonCritter.new()
			c.kind = SummonCritter.Kind.BUTTERFLY if row == 0 else SummonCritter.Kind.GRASSHOPPER
			c.art = skill.butterfly_art if row == 0 else (skill.grasshopper_art if row == 1 else trial)
			c.art_size = skill.critter_size
			c.position = Vector2(130 + i * 150, 420 + row * 220)
			root.add_child(c)
			c.set_physics_process(false)
			c._age = ages[i]
			c.queue_redraw()
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = hero.sprite_sheet.shared_sprite_frames()
	for n in sprite.sprite_frames.get_animation_names():
		if String(n).begins_with("idle"):
			sprite.animation = n
			break
	sprite.scale = Vector2.ONE * hero.sprite_scale
	sprite.position = Vector2(360, 300) + hero.sprite_offset
	root.add_child(sprite)
	for f in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	quit()
