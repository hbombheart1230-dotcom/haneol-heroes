extends SceneTree
## 영웅 하나의 직선 기술 띠·원거리 탄·회피 자취(·세종 유성 낙하)를 무대 그림 위에 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/line_shot.gd -- <영웅 id> <출력 png>

const STAGE := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % args[0])
	var st: StageTheme = load("res://data/stages/%s.tres" % STAGE[args[0]])
	ShotStage.backdrop(self, st)  # 실제 바닥 (floor_grade·빛 웅덩이·비네트·무대 확대)
	var fx := FxLayer.new()
	root.add_child(fx)
	fx.set_process(false)
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var decals := VfxDecals.new(feel)
	fx.add_child(decals)
	decals.set_process(false)
	# 1) 직선 기술 띠 (돌진 칸)
	var line: SkillDef = hero.kit.dash
	if line.vfx_impact and line.vfx_impact.strip:
		decals.strip_for(line.vfx_impact, Vector2(80, 260), Vector2(640, 260), 0)
	elif line is MeteorSkill:  # 세종: 유성이 떨어지는 중간
		fx.add_fall((line as MeteorSkill).fall_art, Vector2(680, -300), Vector2(360, 330), 1.0, 220.0, 135.0)
		fx._fx[0]["t"] = 0.6
	# 2) 원거리 탄 (해일검기 물결 + 기본 탄)
	var pscene := preload("res://scenes/projectile.tscn")
	var ys := [600.0]
	if hero.kit.charge is HaeilSkill and (hero.kit.charge as HaeilSkill).wave_art:
		ys.append(470.0)
	for i in ys.size():
		var pr: Projectile = pscene.instantiate()
		pr.direction = Vector2.RIGHT
		pr.speed = 0.0
		pr.lifetime = 99.0
		if i == 0:
			pr.art = hero.attack.proj_art
			pr.art_size = hero.attack.proj_size
			pr.glyph = hero.attack.ranged_glyphs.substr(0, 1) if hero.attack.ranged_glyphs != "" else ""
			pr.glyph_px = hero.attack.glyph_px
			pr.trail_color = hero.attack.proj_trail_color
			pr.trail_len = hero.attack.proj_trail_len
		else:
			pr.art = (hero.kit.charge as HaeilSkill).wave_art
			pr.art_size = (hero.kit.charge as HaeilSkill).wave_art_size
			pr.size_scale = 2.0
		pr.position = Vector2(420, ys[i])
		root.add_child(pr)
	# 3) 회피 자취
	var ds := hero.dash_style
	if ds.path_strip:
		decals.strip(ds.path_strip, Vector2(160, 900), Vector2(560, 900), ds.path_width, ds.path_time, ds.path_time * 0.3)
	else:
		fx.add_slash(Vector2(160, 900), Vector2(560, 900), ds.path_width * 0.35, 1.0, ds.path_color)
	decals.step(0.15)
	for f in 30:
		decals.queue_redraw()
		fx.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()
