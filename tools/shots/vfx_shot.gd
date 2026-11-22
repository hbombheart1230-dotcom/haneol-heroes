extends SceneTree
## 영웅 하나의 기술 이펙트를 무대 그림 위에 늘어놓고 찍는다 (전후 비교용).
## godot --path . --resolution 720x1280 -s res://tools/shots/vfx_shot.gd -- <영웅 id> <before|after> <출력 png> [기술 칸 0~3]
## before = 영웅 공통 입자만 (이전 방식), after = 기술별 그림. 기술 칸을 주면 그 기술 하나: 위 = 강화 0단계, 아래 = 최대 단계.

const STAGE := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # 루트가 준비된 뒤에 노드를 붙여야 set_process(false)가 남는다
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % args[0])
	var after := args[1] == "after"
	var st: StageTheme = load("res://data/stages/%s.tres" % STAGE[args[0]])
	ShotStage.backdrop(self, st)  # 실제 바닥 (floor_grade·빛 웅덩이·비네트·무대 확대)
	var fx := FxLayer.new()
	root.add_child(fx)
	fx.set_process(false)
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var decals := VfxDecals.new(feel)
	fx.add_child(decals)
	var parts := SkillVfx.new(feel)
	fx.add_child(parts)
	if args.size() > 5 and args[5] == "nomat": decals.material = null
	if args.size() > 5 and args[5] == "noparts": parts.visible = false
	if args.size() > 6: (decals.material as ShaderMaterial).set_shader_parameter(args[6], float(args[7]))
	decals.set_process(false)  # 시간은 아래에서 직접 (창 띄우는 첫 프레임이 길어 다 사라지지 않게)
	parts.set_process(false)
	var skills := [hero.kit.tap, hero.kit.dash, hero.kit.charge, hero.kit.counter]
	if args[1] == "dash" and hero.dash_style:  # 회피: 출발 → 자취 → 도착 (아래로 내려가며)
		var ds := hero.dash_style
		decals.burst(ds.start_vfx, Vector2(360, 300), Vector2.DOWN)
		parts.burst(ds.start_vfx, Vector2(360, 300), Vector2.DOWN)
		for k in 8:
			parts.burst(ds.trail_vfx, Vector2(360, 380 + k * 60), Vector2.UP)
		decals.burst(ds.end_vfx, Vector2(360, 950), Vector2.DOWN)
		parts.burst(ds.end_vfx, Vector2(360, 950), Vector2.DOWN)
		skills = []
	elif args.size() > 3:
		var d1: SkillDef = skills[int(args[3])]
		var v1: SkillVfxData = d1.vfx_impact if d1.vfx_impact and d1.vfx_impact.decal else d1.vfx_cast
		if not after:
			v1 = load("res://data/vfx/%s_impact.tres" % args[0])
		for row in 2:
			var p1 := Vector2(360, 330 + row * 620)
			decals.burst(v1, p1, Vector2.RIGHT, row * 6)
			parts.burst(v1, p1, Vector2.RIGHT, row * 6)
			if v1.has_bolt():
				fx.add_bolt(p1 + Vector2(0, -300), p1, v1.bolt_width, 1.0, v1.bolt_color, v1.bolt_segments, v1.bolt_jitter)
		skills = []
	for i in skills.size():
		var d: SkillDef = skills[i]
		if d == null:
			continue
		var v: SkillVfxData = d.vfx_impact if d.vfx_impact and d.vfx_impact.decal else d.vfx_cast
		if not after:
			v = load("res://data/vfx/%s_impact.tres" % args[0])
		for row in (2 if after else 1):
			var pos := Vector2(180 + (i % 2) * 360, 200 + (i / 2) * 330 + row * 660 * (1 if after else 0))
			var level := 0 if row == 0 else 6
			decals.burst(v, pos, Vector2.RIGHT, level)
			parts.burst(v, pos, Vector2.RIGHT, level)
			if v.has_bolt():
				fx.add_bolt(pos + Vector2(0, -300), pos, v.bolt_width, 1.0, v.bolt_color, v.bolt_segments, v.bolt_jitter)
	var t := float(args[4]) if args.size() > 4 else 0.12
	decals.step(t)
	parts.step(t)
	for f in 30:  # 잡음 텍스처(스레드 생성)·셰이더가 준비될 때까지
		decals.queue_redraw()
		decals._glow.queue_redraw()
		parts.queue_redraw()
		fx.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[2])
	quit()
