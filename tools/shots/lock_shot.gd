extends SceneTree
## 연타 중 처음 때린 몹에 붙기 (ComboLock) 전·후: 실제 한산 장면, 순신 둘레에 왜군 병사 셋 (오른쪽이 처음, 왼쪽·위가 연타 중 더 가까워짐).
## 1·2·3타와 넷째 탭이 닿은 칸을 한 줄로. "off"면 같은 판에서 붙기를 끄고 (예전: 타마다 가장 가까운 몹).
## godot --path . --resolution 720x1280 -s res://tools/shots/lock_shot.gd -- <on|off> <출력 png>

const CROP := Vector2i(400, 400)

var _hit := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self)
	await _wait(3.2)
	var player := main.get_node("Player") as Player
	if args[0] == "off":
		player.hero = player.hero.duplicate()
		player.hero.combo_lock = null
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var soldiers: Array = []
	for off in [Vector2(85, 0), Vector2(-120, 20), Vector2(10, -125)]:
		var e := spawner.spawn_at(data, spot + off)
		e.global_position = spot + off
		e.health.max = 99999
		e.health.current = 99999
		e.attack = null
		soldiers.append(e)
	await _wait(0.3)
	atk.melee_swung.connect(func(_d: Vector2, hits: int) -> void: _hit = hits > 0)
	caster.skill_started.connect(func(_s: SkillCaster.Slot, _def: SkillDef) -> void: _hit = true)
	var shots: Array[Image] = []
	for i in 4:
		var guard := 0
		while not atk.can_manual(caster.tap_gap()) and guard < 200:
			await physics_frame
			guard += 1
		if i == 1:  # 2타 앞: 왼쪽 병사를 더 가깝게 (예전이면 이쪽으로 돈다)
			(soldiers[1] as Node2D).global_position = player.global_position + Vector2(-70, 10)
		if i == 3:
			await _wait(0.15)
		_hit = false
		caster.combo_tap()
		var w := 0
		while not _hit and w < 120:
			await physics_frame
			w += 1
		await RenderingServer.frame_post_draw
		shots.append(_grab())
		await _wait(0.2)
	var out := Image.create(CROP.x * 4, CROP.y, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	out.save_png(args[1])
	quit()


func _grab() -> Image:
	var img := root.get_texture().get_image()
	var c := (img.get_size() / 2 - CROP / 2 + Vector2i(0, -40)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
