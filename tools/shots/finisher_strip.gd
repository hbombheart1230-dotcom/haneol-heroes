extends SceneTree
## 3타 → 4타(마무리) → 다음 1타 프레임 띠: 실제 한산 장면, 오른쪽에 왜군 병사. 탭을 계속 누르고 3타 시작부터 0.05초마다 한 칸.
## 칸 테두리: 노랑 = 몹이 피해를 입은 칸, 파랑 = 타·마무리가 시작한 칸, 빨강 = 마무리가 시작한 칸.
## godot --path . --resolution 720x1280 -s res://tools/shots/finisher_strip.gd -- <영웅 id> <출력 png> [칸 수=18]

const CROP := Vector2i(220, 260)
const STEP := 0.05

var _hit := false
var _start := false
var _finish := false
var _armed := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cells := int(args[2]) if args.size() > 2 else 18
	var main: Node = await ShotStage.open(self, &"hansan_1592", StringName(args[0]))
	await _wait(3.0)
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var reach := atk.stats().melee_range * 0.6 if atk.stats().use_melee else 200.0
	var e := spawner.spawn_at(load("res://data/enemies/waegun_soldier.tres"), spot + Vector2(reach, 0))
	e.health.max = 999999
	e.health.current = 999999
	e.attack = null
	e.set_physics_process(false)
	await _wait(0.5)
	e.health.damaged.connect(func(_en: Node, _ty: int, _amount: int, _i: int, _m: float, _a: int) -> void: _hit = true)
	var on_start := func(step: int) -> void:
		_start = true
		if step == 3:
			_armed = true
	atk.melee_windup.connect(func(_d: Vector2) -> void: on_start.call(atk.chain_step))
	atk.ranged_windup.connect(func(_d: Vector2) -> void: on_start.call(atk.ranged_step))
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: _finish = _finish or s == SkillCaster.Slot.TAP)
	var shots: Array[Image] = []
	var marks: Array[int] = []
	var tap_next := Time.get_ticks_msec()
	var next := 0
	while shots.size() < cells:
		e.global_position = player.global_position + Vector2(reach, 0)
		if Time.get_ticks_msec() >= tap_next:
			tap_next += 50
			caster.combo_tap()
		if _armed and next == 0:
			next = Time.get_ticks_msec()
			_hit = false
			_finish = false
		if next > 0 and Time.get_ticks_msec() >= next:
			next += int(STEP * 1000.0)
			await RenderingServer.frame_post_draw
			shots.append(_grab())
			marks.append(3 if _finish else (1 if _hit else (2 if _start else 0)))
			_hit = false
			_start = false
			_finish = false
		await process_frame
	var out := Image.create(CROP.x * cells, CROP.y, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
		if marks[i] > 0:
			var c: Color = [Color(), Color(1, 0.85, 0.2), Color(0.3, 0.6, 1), Color(1, 0.25, 0.25)][marks[i]]
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
