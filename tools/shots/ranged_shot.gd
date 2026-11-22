extends SceneTree
## 영웅 하나의 원거리 평타 한 발을 시간 순서대로 찍는다 (왼쪽 줄 = 전, 오른쪽 줄 = 후, 위 → 아래 시간 순).
## 줄: 쏜 직후 · 조금 뒤 · 날아가는 중 · 맞은 순간 · 맞고 조금 뒤 · 맞고 더 뒤. 칸마다 한 장씩 찍어 이어 붙인다.
## godot --path . --resolution 720x1280 -s res://tools/shots/ranged_shot.gd -- <영웅 id> <출력 png> [연타 번호 1~3]

const STAGE := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const K := 1.4  # 세계 → 화면 배율 (영웅~적 구간이 화면 너비를 채우게)
const HERO := Vector2(50, 200)
const FOE := Vector2(400, 200)
const CROP := Rect2i(0, 60, 720, 300)  # 찍은 화면에서 잘라 쓰는 칸 (화면 px)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % args[0])
	var step := int(args[2]) if args.size() > 2 else 1
	var st: StageTheme = load("res://data/stages/%s.tres" % STAGE[args[0]])
	var bg := Sprite2D.new()
	bg.texture = load(st.background_path)
	bg.position = Vector2(360, 640)
	bg.scale = Vector2.ONE * maxf(720.0 / bg.texture.get_size().x, 1280.0 / bg.texture.get_size().y)
	root.add_child(bg)
	var foe: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var d := hero.attack
	var rf := RangedFeelData.get_default()
	var col := Color(d.proj_trail_color, 1.0)
	var k := ComboSteps.at(d.ranged_step_scale, step, 1.0)
	var shots: Array[Image] = []
	for after in [false, true]:
		var speed := d.ranged_speed * (rf.speed_mult if after else 1.0)
		var from := HERO + Vector2(d.release_offset.x, -d.release_offset.y)
		var hit_t := (FOE.x - 20.0 - from.x) / speed
		for t in [0.03, 0.08, hit_t * 0.55, hit_t, hit_t + 0.05, hit_t + 0.12]:
			var cell := Node2D.new()
			cell.scale = Vector2.ONE * K
			root.add_child(cell)
			_unit(cell, hero.sprite_sheet, hero.sprite_scale, HERO + hero.sprite_offset)
			_unit(cell, foe.sprite_sheet, foe.sprite_scale, FOE + foe.sprite_offset)
			if t < hit_t:
				var p := PROJECTILE_SCENE.instantiate() as Projectile
				p.direction = Vector2.RIGHT
				p.art = d.proj_art
				p.art_size = d.proj_size * k
				p.glyph_px = roundi(d.glyph_px * k)
				p.trail_color = d.proj_trail_color
				p.trail_len = d.proj_trail_len
				p.glyph = d.ranged_glyphs.substr(0, 1) if d.ranged_glyphs != "" else ""
				p.position = from + Vector2.RIGHT * speed * t
				cell.add_child(p)
				p.set_physics_process(false)
				p.monitoring = false
				if after:
					RangedFeel.add_glow(p, rf, col)
			if after:
				var fx := RangedFxLayer.new(rf)
				var hit := HitImpactLayer.new(HitImpact.data())
				for n in [hit, fx]:  # 게임처럼 부서지는 탄이 섬광 위
					n.z_as_relative = true
					n.z_index = 1 if n == hit else 2
					cell.add_child(n)
					n.set_process(false)
				fx.muzzle(from, Vector2.RIGHT, step, col)
				fx.step(t)
				if t >= hit_t:
					var at := FOE + Vector2(-20.0, foe.sprite_offset.y * HitImpact.data().body_height_ratio)
					fx.burst(at, Vector2.RIGHT, step, col, d.proj_art, p_size(d, k), d.ranged_glyphs.substr(0, 1))
					hit.add(at, Vector2.RIGHT, step, col)
					fx.step(t - hit_t)
					hit._process(t - hit_t)
			for f in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var vk := img.get_width() / 720.0  # 창이 줄었으면 같은 비율로
			shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
			cell.queue_free()
			await process_frame
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var out := Image.create(w * 2 + 8, (h + 6) * 6, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i / 6) * (w + 8), (i % 6) * (h + 6)))
	out.save_png(args[1])
	quit()


static func p_size(d: BasicAttackData, k: float) -> Vector2:
	return d.proj_size * k if d.proj_art else Vector2.ONE * d.glyph_px * k


func _unit(parent: Node, sheet: SpriteSheetSet, scale: float, at: Vector2) -> void:
	if sheet == null:
		return
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sheet.shared_sprite_frames()
	for n in s.sprite_frames.get_animation_names():
		if String(n).begins_with("idle"):
			s.animation = n
			break
	s.scale = Vector2.ONE * scale
	s.position = at
	parent.add_child(s)
