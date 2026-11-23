extends SceneTree
## 순신 1타 → 2타 프레임 띠 (박자 전·후): 실제 한산 장면, 오른쪽에 왜군 병사. 탭을 계속 누르고 1타 시작부터 0.05초마다 한 칸씩 찍는다.
## 칸 테두리: 노랑 = 칼이 닿은 칸, 파랑 = 다음 타가 시작한 칸. "before"면 같은 판에서 예전 값 (swing_speed 1.25, 다음 타 간격 0.625·0.656).
## 다른 영웅도 (넷째 인자, before는 순신만 예전 값): -- after <출력 png> 14 gwanggaeto
## godot --path . --resolution 720x1280 -s res://tools/shots/tempo_strip.gd -- <before|after> <출력 png> [칸 수=12] [영웅=yi_sun_sin]

const CROP := Vector2i(220, 260)
const STEP := 0.05

var _hit := false
var _start := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cells := int(args[2]) if args.size() > 2 else 12
	var hero := StringName(args[3]) if args.size() > 3 else &"yi_sun_sin"
	var main: Node = await ShotStage.open(self, &"hansan_1592", hero)
	await _wait(3.0)
	var player := main.get_node("Player") as Player
	if args[0] == "before" and hero == &"yi_sun_sin":
		player.hero = player.hero.duplicate()
		player.hero.blade_bite = player.hero.blade_bite.duplicate()
		player.hero.blade_bite.swing_speed = 1.25
		player.hero.attack = player.hero.attack.duplicate()
		player.hero.attack.step_gap_mults = PackedFloat32Array([0.9375, 0.625, 0.656])
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	atk.data = player.hero.attack
	process_frame.connect(func() -> void: atk.hold_auto(0.5))
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var e := spawner.spawn_at(load("res://data/enemies/waegun_soldier.tres"), spot + Vector2(100, 0))
	e.health.max = 999999
	e.health.current = 999999
	e.attack = null
	e.set_physics_process(false)
	await _wait(0.5)
	atk.melee_swung.connect(func(_d: Vector2, hits: int) -> void: _hit = _hit or hits > 0)
	atk.melee_windup.connect(func(_d: Vector2) -> void: _start = true)
	atk.ranged_windup.connect(func(_d: Vector2) -> void: _start = true)
	atk.projectile_fired.connect(func(_p: Projectile) -> void: _hit = true)
	caster.combo_tap()
	_start = false
	var shots: Array[Image] = []
	var marks: Array[int] = []
	var next := Time.get_ticks_msec()
	var tap_next := next
	while shots.size() < cells:
		e.global_position = player.global_position + Vector2(100, 0)
		if Time.get_ticks_msec() >= tap_next:
			tap_next += 50
			caster.combo_tap()
		if Time.get_ticks_msec() >= next:
			next += int(STEP * 1000.0)
			await RenderingServer.frame_post_draw
			shots.append(_grab())
			marks.append(1 if _hit else (2 if _start else 0))
			_hit = false
			_start = false
		await process_frame
	var out := Image.create(CROP.x * cells, CROP.y, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
		if marks[i] > 0:
			var c := Color(1, 0.85, 0.2) if marks[i] == 1 else Color(0.3, 0.6, 1)
			for k in 4:
				out.fill_rect(Rect2i(CROP.x * i + k, 0, 1, CROP.y), c)
				out.fill_rect(Rect2i(CROP.x * i, k, CROP.x, 1), c)
	out.save_png(args[1])
	quit()


func _grab() -> Image:
	var img := root.get_texture().get_image()
	var c := (img.get_size() / 2 - CROP / 2 + Vector2i(20, -50)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
