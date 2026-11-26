extends SceneTree
## 적 공격 예고 그림새 나란히 보기 (TelegraphStyleData.look 0 (가) 지금 / 1 (나) 먹 번짐 + 붉은 테 / 2 (다) 탁한 인주):
## 실제 main 장면 한 무대에서 같은 자리에 근접 원(SLAM)·부채(CONE)·돌진 띠(CHARGE)·사격 선(SHOOT)·우두머리 큰 원(SHOCKWAVE)을
## 예고 중으로 멈춰 세우고 (Engine.time_scale 0 — 예고 시간·판정은 안 건드림) 그림새마다 찍는다.
## 위 줄: 진행 progress (기본 0.6), 아래 줄: 치기 직전 번쩍 (남은 0.05초). 칸: (가)(나)(다).
## frames > 0이면 out_dir에 진행 0→끝 칸들을 따로 남긴다 (GIF용, 칸마다 세 그림새 나란히).
## 환경 변수 HH_CROWD=1: 붐비는 판 (몹 수 D안처럼 잡몹 스물넷 + 작은 예고 여럿을 더 세운다).
## godot --path . --resolution 720x1280 -s res://tools/shots/telegraph_looks.gd -- <무대 id> <출력 png> [frames=0] [out_dir]

const LOOKS := [0, 1, 2]
const CROP := Rect2i(0, 100, 720, 980)

var main: Node
var spawner: EnemySpawner
var foes: Array = []  # [Enemy, EnemyAttackData, aim_dir, target_point]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_id = StringName(args[0])
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = false
	GameSettings.want_stage_list = false
	GameSettings.save_settings(GameSettings.settings_path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	spawner = main.get_node("EnemySpawner") as EnemySpawner
	spawner.active = false
	var player := main.get_node("Player") as Player
	player.grant_invulnerability(9999.0)
	for i in 200:
		await process_frame
	if main.is_choosing():
		main.seal_choice.pick(0)
	paused = false
	spawner.active = false
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.RUN
	for e in spawner.get_children():
		if e is Enemy:
			e.queue_free()
	player.global_position = Vector2.ZERO
	player.facing = Vector2.UP
	for i in 30:
		await process_frame
	var c0 := Vector2.ZERO  # 자리는 화면 가운데 기준 (찍을 때 카메라 가운데에 다시 놓는다 — 우두머리 등장 때 카메라가 움직인다)
	var mook: EnemyData = main.stage_by_id(main.run_stage_id()).waves.waves[0].enemies[0]
	_foe(mook, c0 + Vector2(-170, -430), _atk(EnemyAttackData.Kind.SLAM, 100.0), Vector2.DOWN, c0 + Vector2(-170, -300))
	var cone := _atk(EnemyAttackData.Kind.CONE, 190.0)
	cone.angle_degrees = 100.0
	_foe(mook, c0 + Vector2(190, -450), cone, Vector2(-0.3, 1).normalized(), Vector2.ZERO)
	var ch := _atk(EnemyAttackData.Kind.CHARGE, 0.0)
	ch.length = 400.0
	ch.width = 90.0
	_foe(mook, c0 + Vector2(-330, -120), ch, Vector2.RIGHT, Vector2.ZERO)
	var sh := _atk(EnemyAttackData.Kind.SHOOT, 0.0)
	sh.projectile_range = 480.0
	_foe(mook, c0 + Vector2(320, -20), sh, Vector2(-1, 0.55).normalized(), Vector2.ZERO)
	if OS.get_environment("HH_CROWD") == "1":
		_crowd(mook)
	var boss := spawner.spawn_boss()
	if boss:
		var bw := _atk(EnemyAttackData.Kind.SHOCKWAVE, 240.0)
		_setup(boss, c0 + Vector2(40, 250), bw, Vector2.UP, Vector2.ZERO)
	for i in 420:  # 우두머리 등장 띠가 지나가게
		await process_frame
	Engine.time_scale = 0.0
	var prog := 0.6
	var frames := int(args[2]) if args.size() > 2 else 0
	if frames > 0:
		DirAccess.make_dir_recursive_absolute(args[3])
		var times := PackedStringArray()
		for f in frames:
			var k := float(f) / float(frames - 1)
			var row: Array[Image] = []
			for look in LOOKS:
				row.append(await _shot(look, k))
			_row(row).save_png(args[3] + "/f_%03d.png" % f)
			times.append("%d" % int(k * 1000.0))
		FileAccess.open(args[3] + "/times.txt", FileAccess.WRITE).store_string("\n".join(times))
	var top: Array[Image] = []
	var bottom: Array[Image] = []
	for look in LOOKS:
		top.append(await _shot(look, prog))
		bottom.append(await _shot(look, 0.98))
	var a := _row(top)
	var b := _row(bottom)
	var out := Image.create(a.get_width(), a.get_height() * 2 + 8, false, a.get_format())
	out.fill(Color.WHITE)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, a.get_height() + 8))
	out.save_png(args[1])
	print("[telegraph-looks] %s -> %s" % [args[0], args[1]])
	Engine.time_scale = 1.0
	quit()


## 붐비는 판: 잡몹 스물넷 (가만히) + 그중 여덟은 작은 원·부채 예고 중.
func _crowd(mook: EnemyData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 24:
		var at := Vector2(rng.randf_range(-320, 320), rng.randf_range(-480, 380))
		var e := spawner.spawn_at(mook, at)
		if e == null:
			continue
		if i % 3 == 0:
			var kind := EnemyAttackData.Kind.SLAM if i % 2 == 0 else EnemyAttackData.Kind.CONE
			var d := _atk(kind, 80.0 if kind == EnemyAttackData.Kind.SLAM else 130.0)
			_setup(e, at, d, Vector2.from_angle(rng.randf() * TAU), at + Vector2(0, 60))
		else:
			_setup(e, at, null, Vector2.ZERO, Vector2.ZERO)


func _atk(kind: EnemyAttackData.Kind, radius: float) -> EnemyAttackData:
	var d := EnemyAttackData.new()
	d.kind = kind
	d.radius = radius
	d.windup = 1.0
	return d


func _foe(d: EnemyData, at: Vector2, atk: EnemyAttackData, aim: Vector2, target: Vector2) -> void:
	var e := spawner.spawn_at(d, at)
	if e:
		_setup(e, at, atk, aim, target)


func _setup(e: Enemy, at: Vector2, atk: EnemyAttackData, aim: Vector2, target: Vector2) -> void:
	e.global_position = player_pos() + at
	e.speed_mult = 0.0
	e.health.max = 1000000
	e.health.current = 1000000
	if e.attack == null and atk:
		e.attack = EnemyAttack.new(atk)
	foes.append([e, atk, aim, target, at])


func player_pos() -> Vector2:
	return (main.get_node("Player") as Node2D).global_position


func _center() -> Vector2:
	var cam := root.get_viewport().get_camera_2d()
	return cam.get_screen_center_position() if cam else player_pos()


## 모든 예고를 진행 k로 세우고 그림새 look으로 한 장.
func _shot(look: int, k: float) -> Image:
	TelegraphStyleData.default().look = look
	var c0 := _center()
	for f in foes:
		var e: Enemy = f[0]
		if not is_instance_valid(e):
			continue
		e.global_position = c0 + (f[4] as Vector2)
		if f[1] == null:
			continue  # 붐비는 판의 가만히 있는 몹
		var a := e.attack
		a.data = f[1]
		a.state = EnemyAttack.State.WINDUP
		a._timer = a.data.windup * (1.0 - k)
		a.aim_dir = f[2]
		a.aim_origin = e.global_position
		a.target_point = c0 + (f[3] as Vector2)
		e.queue_redraw()
		var rim := e.get_node_or_null(^"TelegraphRim") as CanvasItem
		if rim:
			rim.queue_redraw()
	for lane in root.find_children("*", "LaneStrike", true, false):
		(lane as CanvasItem).queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var vk := img.get_width() / 720.0
	img = img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk)))
	img.resize(CROP.size.x / 2, CROP.size.y / 2)
	return img


func _row(imgs: Array[Image]) -> Image:
	var w := imgs[0].get_width()
	var h := imgs[0].get_height()
	var out := Image.create((w + 6) * imgs.size() - 6, h, false, imgs[0].get_format())
	out.fill(Color.WHITE)
	for i in imgs.size():
		out.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i(i * (w + 6), 0))
	return out
