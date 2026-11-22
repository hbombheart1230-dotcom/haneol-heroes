extends SceneTree
## 큰 기술 이펙트가 화면을 얼마나 덮는지 실제 화면 크기로 찍는다 (가운데 영웅, 둘레에 적, 판정 고리).
## godot --path . --resolution 720x1280 -s res://tools/shots/fx_cover_shot.gd -- <영웅 id> <기술 칸 0~3> <출력 png> <단계> <시각 초> [before]
## before: 화면 덮기 상한·강화 배율 상한을 끈 예전 모습 (비교용).

const STAGE := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
const ENEMY := {"yi_sun_sin": "waegun_soldier", "gwanggaeto": "jurchen_soldier", "sejong": "waegun_soldier",
	"shin_saimdang": "cc_mantis"}
const FIT := ["CounterSlashSkill", "HaeryongSkill", "SundialSkill", "QuakeSkill", "ConquerorSkill", "MeteorSkill",
	"PlumBlossomSkill"]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % args[0])
	var def: SkillDef = [hero.kit.tap, hero.kit.dash, hero.kit.charge, hero.kit.counter][int(args[1])]
	var level := int(args[3])
	var t := float(args[4])
	var before := args.size() > 5 and args[5] == "before"
	var v: SkillVfxData = def.vfx_impact.duplicate()
	var stage := SkillStageFeel.get_default()
	if before:
		stage.screen_cap = 0.0
		stage.fit_grow = 99.0
		stage.big_from = 99.0
		v.max_size_mult = 99.0
	var r := 0.0
	if def is CanvasSkill:
		r = (def as CanvasSkill).max_radius
	elif def.get_script().get_global_name() in FIT:
		r = float(def.get("radius"))
	var st: StageTheme = load("res://data/stages/%s.tres" % STAGE[args[0]])
	ShotStage.backdrop(self, st)  # 실제 바닥 (floor_grade·빛 웅덩이·비네트·무대 확대)
	var center := Vector2(360, 700)
	var en: EnemyData = load("res://data/enemies/%s.tres" % ENEMY[args[0]])
	for i in 6:
		_unit(en.sprite_sheet, en.sprite_scale, center + Vector2.from_angle(TAU * i / 6.0 + 0.4) * (r * 0.75 if r > 0 else 150.0))
	_unit(hero.sprite_sheet, hero.sprite_scale, center)
	if r > 0.0:  # 판정 (그대로): 얇은 흰 고리
		var ring := Line2D.new()
		ring.width = 3.0
		ring.default_color = Color(1, 1, 1, 0.7)
		for i in 65:
			ring.add_point(center + Vector2.from_angle(TAU * i / 64.0) * r)
		root.add_child(ring)
	var d := VfxDecals.new(load("res://data/feel/combat_feel.tres"))
	root.add_child(d)
	d.set_process(false)
	d.pieces.set_process(false)
	d.ground.set_process(false)
	d.burst(v, center, Vector2.RIGHT, level, r)
	d.step(t)
	d.pieces.step(t)
	d.ground.step(t)
	for f in 20:
		d.queue_redraw()
		d.pieces.queue_redraw()
		d.pieces._glow.queue_redraw()
		d.pieces.ink_node().queue_redraw()
		d._glow.queue_redraw()
		d.ground.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[2])
	quit()


func _unit(sheet: SpriteSheetSet, scale: float, at: Vector2) -> void:
	if sheet == null:
		return
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sheet.shared_sprite_frames()
	for n in s.sprite_frames.get_animation_names():
		if String(n).begins_with("idle"):
			s.animation = n
			break
	s.scale = Vector2.ONE * scale
	s.position = at + Vector2(0, -30)
	root.add_child(s)
