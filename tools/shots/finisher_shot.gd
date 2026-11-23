extends SceneTree
## 세종 넷째 탭 마무리(정음진): 시전 연출(vfx_cast)과 글자 고리가 어디서 펼쳐지는지 전 / 후를 나란히 찍는다.
## 전 = 고리는 적에게 가도 시전 연출은 영웅 몸에서, 후 = 둘 다 겨눈 적에게 (SkillDef.cast_point).
## godot --path . --resolution 720x1280 -s res://tools/shots/finisher_shot.gd -- <출력 png>

const HERO_AT := Vector2(360, 1000)
const FOES := [Vector2(250, 560), Vector2(470, 520)]
const CROP := Rect2i(40, 300, 640, 820)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/sejong.tres")
	var skill := hero.kit.tap as JeongeumSkill
	ShotStage.backdrop(self, load("res://data/stages/gyeongbokgung_1433.tres"))
	var foe: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var near: Vector2 = FOES[0] if HERO_AT.distance_to(FOES[0]) < HERO_AT.distance_to(FOES[1]) else FOES[1]
	var shots: Array[Image] = []
	for after in [false, true]:
		var nodes: Array[Node] = []
		nodes.append(_unit(hero.sprite_sheet, hero.sprite_scale, HERO_AT + hero.sprite_offset))
		for f in FOES:
			nodes.append(_unit(foe.sprite_sheet, foe.sprite_scale, f + foe.sprite_offset))
		var d := VfxDecals.new(feel)
		root.add_child(d)
		d.set_process(false)
		d.pieces.set_process(false)
		d.ground.set_process(false)
		d.burst(skill.vfx_cast, near if after else HERO_AT, Vector2.UP, 0)
		d.step(0.2)
		d.pieces.step(0.2)
		nodes.append(d)
		var o := OrbitGlyphs.new()  # 고리 (PR #67부터 적에게)
		o.glyphs = skill.glyphs
		o.radius = skill.radius
		o.art = skill.ring_art
		root.add_child(o)
		o.set_physics_process(false)
		o.global_position = near
		o._age = 0.8
		nodes.append(o)
		for f in 6:
			d.queue_redraw()
			d.pieces.queue_redraw()
			o.queue_redraw()
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
		for n in nodes:
			n.queue_free()
		await process_frame
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var out := Image.create((w + 8) * 2, h, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i(i * (w + 8), 0))
	out.save_png(args[0])
	quit()


func _unit(sheet: SpriteSheetSet, scale: float, at: Vector2) -> Node:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sheet.shared_sprite_frames()
	for n in s.sprite_frames.get_animation_names():
		if String(n).begins_with("idle"):
			s.animation = n
			break
	s.scale = Vector2.ONE * scale
	s.position = at
	root.add_child(s)
	return s
