extends SceneTree
## 세종 기술이 어디에 떨어지는지 전(영웅 자리) · 후(겨눈 적 자리)를 나란히 찍는다.
## 줄 = 정음진(탭)·유성(대시)·성좌진(충전)·해시계(반격), 칸 = 전 / 후. 영웅은 아래, 적 셋은 위쪽 멀리.
## godot --path . --resolution 720x1280 -s res://tools/shots/sejong_aim_shot.gd -- <출력 png>

const HERO_AT := Vector2(360, 1000)
const FOES := [Vector2(250, 600), Vector2(470, 560), Vector2(380, 430)]
const CROP := Rect2i(60, 300, 600, 820)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/sejong.tres")
	ShotStage.backdrop(self, load("res://data/stages/gyeongbokgung_1433.tres"))
	var foe: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var shots: Array[Image] = []
	var skills: Array[SkillDef] = [hero.kit.tap, hero.kit.dash, hero.kit.charge, hero.kit.counter]
	for s in skills:
		for after in [false, true]:
			var nodes: Array[Node] = []
			var p := Player.new()
			p.hero = hero
			p.facing = Vector2.UP
			root.add_child(p)
			p.global_position = HERO_AT
			nodes.append(p)
			nodes.append(_unit(hero.sprite_sheet, hero.sprite_scale, HERO_AT + hero.sprite_offset))
			var list: Array = []
			for f in FOES:
				nodes.append(_unit(foe.sprite_sheet, foe.sprite_scale, f + foe.sprite_offset))
				list.append(f)
			var near: Vector2 = list[0]
			for f in list:
				if HERO_AT.distance_to(f) < HERO_AT.distance_to(near):
					near = f
			var at := HERO_AT
			if after:
				at = HERO_AT + (near - HERO_AT).limit_length(hero.kit.target_range)
			var d := VfxDecals.new(feel)
			root.add_child(d)
			d.set_process(false)
			d.pieces.set_process(false)
			d.ground.set_process(false)
			var r := float(s.get("radius")) if "radius" in s else 0.0
			if s is ConstellationSkill:
				var cs := s as ConstellationSkill
				var dir := (near - HERO_AT).normalized()
				var pts := cs.star_points(HERO_AT, dir if after else Vector2.UP, 5, HERO_AT.distance_to(near) if after else -1.0)
				for q in pts:
					d.burst(s.vfx_impact, q, Vector2.ZERO, 0)
			elif s.vfx_impact:
				d.burst(s.vfx_impact, at, Vector2.UP, 0, r)
			d.step(0.2)
			d.pieces.step(0.2)
			nodes.append(d)
			for f in 6:
				d.queue_redraw()
				d.pieces.queue_redraw()
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
	var out := Image.create((w + 8) * 2, (h + 8) * 4, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % 2) * (w + 8), (i / 2) * (h + 8)))
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
