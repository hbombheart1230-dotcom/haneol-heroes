extends SceneTree
## 계속 닿는 기술(장판)의 틱을 시간 순서대로 찍는다: 위 줄 = 전 (틱마다 아무 표시 없음), 아래 줄 = 후 (틱마다 가벼운 섬광,
## 마지막 틱은 3타급 큰 섬광). 칸 = 1틱 · 1틱 직후 · 2틱 · 2틱 직후 · 마지막 틱 · 마지막 틱 직후.
## godot --path . --resolution 720x1280 -s res://tools/shots/tick_shot.gd -- <출력 png>

const AT := Vector2(360, 700)
const FOES := [Vector2(290, 690), Vector2(420, 660), Vector2(370, 760)]
const CROP := Rect2i(170, 500, 380, 360)
const TIMES := [[0, 0.02], [0, 0.08], [1, 0.02], [1, 0.08], [2, 0.02], [2, 0.1]]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	ShotStage.backdrop(self, load("res://data/stages/manchuria_395.tres"))
	var foe: EnemyData = load("res://data/enemies/jurchen_soldier.tres")
	var hero: HeroData = load("res://data/heroes/gwanggaeto.tres")
	var col := Color(hero.attack.swing_color, 1.0)
	var shots: Array[Image] = []
	for after in [false, true]:
		for f in TIMES:
			var nodes: Array[Node] = []
			var z := DamageZone.new()
			z.radius = 130.0
			z.color = hero.kit.counter.fx_color
			root.add_child(z)
			z.global_position = AT
			z.set_physics_process(false)
			nodes.append(z)
			for p in FOES:
				nodes.append(_unit(foe.sprite_sheet, foe.sprite_scale, p + foe.sprite_offset))
			if after:
				var l := HitImpactLayer.new(HitImpact.data())
				root.add_child(l)
				l.set_process(false)
				var step := 3 if int(f[0]) == 2 else SkillHitFeelData.get_default().tick_step
				for p in FOES:
					var c: Vector2 = p - (p - AT).normalized() * 18.0 + Vector2(0, foe.sprite_offset.y * 0.6)
					l.add(c, p - AT, step, col)
				l._process(float(f[1]))
				nodes.append(l)
			for i in 5:
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
	var out := Image.create((w + 6) * TIMES.size(), (h + 6) * 2, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % TIMES.size()) * (w + 6), (i / TIMES.size()) * (h + 6)))
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
