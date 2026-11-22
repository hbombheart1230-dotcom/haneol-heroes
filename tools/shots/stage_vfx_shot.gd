extends SceneTree
## 기술 연출(조각 등장·바늘·눈금·자국)을 시간 순서대로 한 장에 찍는다 (필름처럼 왼쪽 위 → 오른쪽 아래).
## godot --path . --resolution 720x1280 -s res://tools/shots/stage_vfx_shot.gd -- <영웅 id> <기술 칸 0~3> <출력 png> [단계]

const STAGE := {"yi_sun_sin": "hansan_1592", "gwanggaeto": "manchuria_395", "sejong": "gyeongbokgung_1433",
	"shin_saimdang": "chochungdo"}
const TIMES := [0.03, 0.08, 0.14, 0.22, 0.32, 0.45, 0.6, 0.8]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var hero: HeroData = load("res://data/heroes/%s.tres" % args[0])
	var def: SkillDef = [hero.kit.tap, hero.kit.dash, hero.kit.charge, hero.kit.counter][int(args[1])]
	var level := int(args[3]) if args.size() > 3 else 0
	var v: SkillVfxData = def.vfx_impact
	var st: StageTheme = load("res://data/stages/%s.tres" % STAGE[args[0]])
	ShotStage.backdrop(self, st)  # 실제 바닥 (floor_grade·빛 웅덩이·비네트·무대 확대)
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var cells: Array[VfxDecals] = []
	for i in TIMES.size():
		var pos := Vector2(180 + (i % 2) * 360, 160 + (i / 2) * 320)
		var d := VfxDecals.new(feel)
		d.scale = Vector2.ONE * 0.62
		d.position = pos - pos * 0.62  # 칸 안에 들어가게 줄인다 (그림 좌표는 pos 그대로)
		root.add_child(d)
		d.set_process(false)
		d.pieces.set_process(false)
		d.ground.set_process(false)
		d.burst(v, pos, Vector2.RIGHT, level)
		d.pieces.hit_mark(def.vfx_hit, pos + Vector2(90, 30), Vector2.RIGHT, level)
		var t: float = TIMES[i]
		d.step(t)
		d.pieces.step(t)
		d.ground.step(t)
		for k in v.tick_count:  # 바늘이 지난 눈금 (각자 지난 시각만큼 나이 듦)
			var tk := v.piece_sweep * k / float(v.tick_count)
			if t >= tk and t - tk < d.pieces.stage.tick_time:
				d.pieces.tick_glint(v, pos, 0.0, k, level)
				d.pieces._glints[-1]["t"] = t - tk
		cells.append(d)
	for f in 30:
		for d in cells:
			d.queue_redraw()
			d.pieces.queue_redraw()
			d.pieces._glow.queue_redraw()
			d.ground.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[2])
	quit()
