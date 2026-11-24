extends SceneTree
## 해룡참 고리 프레임 재기: 실제 한산 장면에서 해룡참을 바로 쏘고, 처음 프레임들마다
##  - 판정 끝 (반경 + 왜군 몸) = 주황 원
##  - 물결 조각 그림의 칠해진 바깥 끝 (조각마다 튀어나왔다 자리 잡는 크기 포함, 가장 바깥 조각)
##  - FxLayer 붓 고리(add_ring)의 칠해진 선
## 을 로그로 찍고, 몇 장을 한 줄로 붙여 저장한다. 강화 단계(vfx_level)별 판정·그림 끝도 같이 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/haeryong_ring_strip.gd -- <출력 png> [vfx_level=0]

const CROP := Vector2i(520, 520)
const SHOTS := [0, 2, 4, 6, 9, 14, 22]


class Overlay extends Node2D:
	var r := 0.0
	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(1, 0.45, 0.1, 0.9), 2.0)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var level := int(args[1]) if args.size() > 1 else 0
	var main: Node = await ShotStage.open(self, &"hansan_1592", &"yi_sun_sin")
	await _wait(2.0)
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	player.grant_invulnerability(9999.0)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var foe := spawner.spawn_at(load("res://data/enemies/waegun_soldier.tres"), spot + Vector2(400, 0))
	foe.set_physics_process(false)
	var edge := SkillContext.edge_of(foe)
	var tap: SkillDef = caster.kit.tap
	var pieces: VfxPieces = Feedback.instance.decals.pieces
	var vw := FxCoverage.view_width(Feedback.instance.decals)
	for lv in [0, 1, 3, 6, 9]:
		tap.vfx_level = lv
		var r: float = SkillGrowthData.get_default().scaled_def(tap).get("radius")
		var fit: float = r + float(tap.get("ring_edge_px"))
		var pl := FxCoverage.plan(tap.vfx_impact, lv, fit, pieces.stage, vw)
		var painted := float(pl["size"]) * tap.vfx_impact.art_fill * 0.5
		print("[ring-lv] level %d: radius %.0f reach %.0f | art raw %.0f -> capped %.0f, painted edge %.0f (%.2f of reach), grows to x%.2f"
			% [lv, r, r + edge, float(pl["raw"]), float(pl["size"]), painted, painted / (r + edge), float(pl["grow"])])
	tap.vfx_level = level
	var r0: float = SkillGrowthData.get_default().scaled_def(tap).get("radius")
	var ring_frac := _ring_frac(Feedback.feel_data().ring_art)
	print("[ring] brush ring art painted at %.3f of half size" % ring_frac)
	var ov := Overlay.new()
	ov.r = r0 + edge
	ov.z_index = 100
	main.add_child(ov)
	ov.global_position = player.global_position
	caster.cast(SkillCaster.Slot.TAP)
	var shots: Array[Image] = []
	for f in SHOTS[-1] + 1:
		await RenderingServer.frame_post_draw
		var line := "[ring-f] f%02d reach %.0f hero %s ring %s" % [f, r0 + edge, player.global_position - ov.global_position, (pieces._sets[0]["pos"] - ov.global_position) if pieces._sets.size() > 0 else Vector2.ZERO]
		for st in pieces._sets:
			var pe := _piece_edges(st, pieces.stage.piece_settle)
			line += " | pieces painted %.0f..%.0f" % [pe.x, pe.y]
		for fx in Feedback.instance.fx._fx:
			if fx["kind"] == "ring":
				var k := float(fx["t"]) / float(fx["dur"])
				line += " | brush ring line %.0f" % (float(fx["r"]) * (float(fx.get("from", 0.35)) + (1.0 - float(fx.get("from", 0.35))) * k) * 1.15 * ring_frac)
		print(line)
		if SHOTS.has(f):
			shots.append(_grab(player))
	var strip := Image.create(CROP.x * shots.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		strip.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	strip.save_png(args[0])
	quit()


## 조각 묶음 하나의 칠해진 바깥 끝 (가장 안쪽·바깥 조각), VfxPieces._draw_set과 같은 셈.
func _piece_edges(st: Dictionary, settle: float) -> Vector2:
	var d: SkillVfxData = st["data"]
	var t := float(st["t"])
	var k := t / float(st["life"])
	var size := float(st["size"]) * lerpf(1.0, float(st["grow"]), 1.0 - pow(1.0 - k, 2.0))
	var lo := INF
	var hi := 0.0
	for i in d.piece_count:
		var p := VfxPieces.piece_progress(t, i, d.piece_count, d.piece_sweep, settle)
		if p <= 0.0:
			continue
		var ease := 1.0 - pow(1.0 - p, 3.0)
		var e := size * d.art_fill * 0.5 * (1.0 + d.piece_pop * (1.0 - ease)) + d.piece_push * (1.0 - ease)
		lo = minf(lo, e)
		hi = maxf(hi, e)
	return Vector2(lo if lo < INF else 0.0, hi)


func _ring_frac(t: Texture2D) -> float:
	if t == null:
		return 0.0
	var im := t.get_image()
	if im.is_compressed():
		im.decompress()
	var c := Vector2(im.get_width(), im.get_height()) * 0.5
	var best := 0.0
	var best_k := 0.0
	for s in 50:
		var k := 0.5 + s * 0.01
		var sum := 0.0
		for a in 64:
			sum += im.get_pixelv((c + Vector2.from_angle(a * TAU / 64.0) * c.x * k).floor()).a
		if sum > best:
			best = sum
			best_k = k
	return best_k


func _grab(player: Node2D) -> Image:
	var img := root.get_texture().get_image()
	var at := Vector2i(player.get_global_transform_with_canvas().origin * Vector2(img.get_size()) / root.get_visible_rect().size)
	var c := (at - CROP / 2).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
