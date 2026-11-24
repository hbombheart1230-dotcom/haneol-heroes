extends SceneTree
## 순신 4타(해룡참) 한 장 + 프레임 기록: 실제 한산 장면, 탭을 계속 눌러 1·2·3·4타. 4타가 나간 뒤 매 프레임 영웅 동작
## 이름·칸을 찍고, 칼이 닿는 순간(시작 + cast_lead) 한 장에 판정 원을 겹친다.
## 노랑 = 기술 반경(성장 반영), 주황 = 적 몸까지 닿는 범위(반경 + 몸 반지름). 적은 둘레 여러 거리에.
## godot --path . --resolution 720x1280 -s res://tools/shots/finisher_ring_shot.gd -- <출력 png> [멈춤 칸 수=0]

const CROP := Vector2i(720, 720)


class Overlay extends Node2D:
	var radii: Array = []
	var colors: Array = []
	func _draw() -> void:
		for i in radii.size():
			draw_arc(Vector2.ZERO, radii[i], 0.0, TAU, 96, colors[i], 3.0)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self, &"hansan_1592", &"yi_sun_sin")
	await _wait(3.0)
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var view := player.get_node("PlayerView") as PlayerView
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	player.grant_invulnerability(9999.0)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.active = false
	var foes: Array[Enemy] = []
	var dists := [60.0, 140.0, 175.0, 200.0, 225.0, 250.0]
	for i in dists.size():
		var e := spawner.spawn_at(load("res://data/enemies/waegun_soldier.tres"), spot)
		e.health.max = 999999
		e.health.current = 999999
		e.attack = null
		e.set_physics_process(false)
		foes.append(e)
	var def: SkillDef = SkillGrowthData.get_default().scaled_def(caster.kit.tap)
	var r: float = def.get("radius")
	var edge := SkillContext.edge_of(foes[1])
	print("[ring] radius(data)=%.0f radius(grown)=%.0f edge=%.1f reach=%.0f" % [caster.kit.tap.get("radius"), r, edge, r + edge])
	var ring_tex: Texture2D = Feedback.feel_data().ring_art
	print("[ring] brush ring art: painted ring at %.2f of half size (drawn r*2.3 → line at %.2f r)" % [_ring_frac(ring_tex), _ring_frac(ring_tex) * 1.15])
	var started := [-1.0]
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void:
		if s == SkillCaster.Slot.TAP and started[0] < 0.0:
			started[0] = Time.get_ticks_msec() / 1000.0)
	var tap_next := Time.get_ticks_msec()
	var t_end := Time.get_ticks_msec() + 6000
	var shot_at := -1.0
	var lead := float(caster.kit.tap.cast_lead) / maxf(caster.kit.tap.cast_speed, 0.05)
	var img: Image
	var log := []
	while Time.get_ticks_msec() < t_end:
		for i in foes.size():  # 오른쪽 위로 부채꼴로 늘어선 적 (판정 경계 앞뒤)
			foes[i].global_position = player.global_position + Vector2.from_angle(-0.9 + i * 0.36) * dists[i]
		var now := Time.get_ticks_msec() / 1000.0
		if Time.get_ticks_msec() >= tap_next and started[0] < 0.0:
			tap_next += 50
			caster.combo_tap()
		if started[0] >= 0.0:
			log.append("%.3f cur=%s spr=%s f%d sp%.2f stop%.3f left%.3f ts%.2f" % [now - started[0], view.current_anim(), view._sprite.animation, view._sprite.frame, view._sprite.speed_scale, view._hitstop_left, view._oneshot_left, Engine.time_scale])
			if img == null and now - started[0] >= lead + float(OS.get_environment("RING_LATE") if OS.has_environment("RING_LATE") else "0"):
				var ov := Overlay.new()
				ov.radii = [r, r + edge]
				ov.colors = [Color(1, 0.9, 0.1), Color(1, 0.45, 0.1)]
				ov.z_index = 100
				main.add_child(ov)
				ov.global_position = player.global_position
				await RenderingServer.frame_post_draw
				img = _grab()
				ov.queue_free()
			if now - started[0] > 0.7:
				break
		await process_frame
	print("[ring] frames after 4타 start:\n" + "\n".join(log))
	if img:
		img.save_png(args[0])
	quit()


## 붓 고리 그림에서 칠이 가장 진한 반지름 (반 폭 대비).
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
			var p := c + Vector2.from_angle(a * TAU / 64.0) * c.x * k
			sum += im.get_pixelv(p.floor()).a
		if sum > best:
			best = sum
			best_k = k
	return best_k


func _grab() -> Image:
	var img := root.get_texture().get_image()
	var c := (img.get_size() / 2 - CROP / 2).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
