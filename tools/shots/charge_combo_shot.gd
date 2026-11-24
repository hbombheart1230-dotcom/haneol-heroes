extends SceneTree
## 실제 한산 장면(ShotStage)에서 순신 해일검기 모으기와 연타 글씨를 찍는다 (전·후 비교용: 예전 코드에서도 돈다).
##   charge: 오른쪽 위로 방향을 잡고 충전 0.2 / 0.6 / 1.0 — 세 칸을 세로로.
##   combo : 왜군 병사 셋 앞에서 탭 네 번 (1·2·3타 + 넷째 탭 마무리) — 칸마다 친 직후를 2×2로 (화톳불 빛 안).
##   combo_dark: 같은 것을 빛 밖 어두운 바닥에서.
## godot --path . --resolution 720x1280 -s res://tools/shots/charge_combo_shot.gd -- <charge|combo|combo_dark> <출력 png>

const CROP := Vector2i(720, 600)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self)
	await _wait(3.2)  # 무대 제목 띠가 사라질 때까지
	var shots: Array[Image] = []
	if args[0] == "charge":
		shots = await _charge(main)
	else:
		shots = await _combo(main, args[0] == "combo_dark")
	_save(shots, args[0] != "charge", args[1])
	quit()


func _charge(main: Node) -> Array[Image]:
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := player.get_node_or_null("AutoAttack")
	if atk:
		atk.set_physics_process(false)
		atk.set_process(false)
	ShotStage.move_hero(main, ShotStage.brazier_spot(main) + Vector2(0, 160))
	var out: Array[Image] = []
	for c in [0.2, 0.6, 1.0]:
		caster.cancel_input()
		await _wait(0.4)  # 앞 번쩍임이 사라지게
		var now := Time.get_ticks_usec() / 1_000_000.0
		caster.input.press(0, now, SkillInput.Source.GESTURE, caster.kit.gesture_hold_threshold)
		await physics_frame
		player.set_move_input(Vector2(1, -0.6).normalized())  # 끌어서 방향 잡기
		await physics_frame
		await physics_frame
		player.set_move_input(Vector2.ZERO)
		ShotStage.move_hero(main, player.global_position)
		now = Time.get_ticks_usec() / 1_000_000.0
		caster.input._press_time = now - caster.input._threshold - caster.input.full_charge_time * c
		await _wait(0.12 if c >= 1.0 else 0.05)
		out.append(await _grab(Vector2i(0, -120)))
	caster.cancel_input()
	return out


func _combo(main: Node, dark: bool = false) -> Array[Image]:
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	var spot := ShotStage.dark_spot(main, 700.0) if dark else ShotStage.brazier_spot(main) + Vector2(0, 160)
	ShotStage.move_hero(main, spot)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	for off in [Vector2(70, -30), Vector2(90, 40), Vector2(40, -90)]:
		var e := spawner.spawn_at(data, spot + off)
		e.set_physics_process(false)
		e._physics_process(1.0 / 60.0)
		e.global_position = spot + off
		e.health.max = 99999
		e.health.current = 99999
	await _wait(0.3)
	var out: Array[Image] = []
	for i in 4:
		var guard := 0
		while not atk.can_manual(caster.tap_gap()) and guard < 200:
			await physics_frame
			guard += 1
		if i == 3:
			await _wait(0.15)  # 3타가 닿은 뒤 마무리
		caster.combo_tap()
		await _wait(0.42 if i == 3 else 0.26)
		out.append(await _grab(Vector2i(0, -120)))
	return out


func _grab(shift: Vector2i) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var c := img.get_size() / 2 - CROP / 2 + shift
	var r := img.get_region(Rect2i(c.clamp(Vector2i.ZERO, img.get_size() - CROP), CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


## 세로로 쌓거나 (charge) 2×2 반 크기로 (combo).
func _save(shots: Array[Image], grid: bool, path: String) -> void:
	var out: Image
	if grid:
		var half := CROP / 2
		out = Image.create(CROP.x, half.y * 2, false, Image.FORMAT_RGBA8)
		for i in shots.size():
			shots[i].resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
			out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, half), Vector2i((i % 2) * half.x, (i / 2) * half.y))
	else:
		out = Image.create(CROP.x, CROP.y * shots.size(), false, Image.FORMAT_RGBA8)
		for i in shots.size():
			out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(0, CROP.y * i))
	out.save_png(path)


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
