extends SceneTree
## 3타 → 4타(마무리) → 다음 1타 움직이는 미리보기: finisher_strip과 같은 장면(한산, 오른쪽 왜군 병사, 0.05초마다 탭)을
## 3타 시작부터 seconds초 동안 그린 프레임마다 찍어 <출력 폴더>/f_000.png… 와 times.txt(시각 ms, 표시)로 남긴다.
## GIF는 tools/shots/frames_to_gif.py가 times.txt의 실제 간격으로 만든다.
## 표시: h = 몹이 피해를 입음, s = 타 시작, f = 마무리 시작.
## godot --path . --resolution 720x1280 -s res://tools/shots/finisher_gif.gd -- <영웅 id> <출력 폴더> [초=1.2] [시작 타=3]
## 시작 타 1이면 1·2·3·4타 전체 (초 1.4 안팎). [적 거리 px]: 주면 적을 그 거리에 한 번만 두고 따라 붙이지 않는다 (연타 전진 보기).

const CROP := Vector2i(300, 300)

var _hit := false
var _start := false
var _finish := false
var _armed := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[2]) if args.size() > 2 else 1.2
	var from_step := int(args[3]) if args.size() > 3 else 3
	var fixed_px := float(args[4]) if args.size() > 4 else 0.0
	DirAccess.make_dir_recursive_absolute(args[1])
	var main: Node = await ShotStage.open(self, &"hansan_1592", StringName(args[0]))
	await _wait(6.0)  # 물결 알림 띠가 지나간 뒤
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var reach := atk.stats().melee_range * 0.6 if atk.stats().use_melee else 200.0
	if fixed_px > 0.0:
		reach = fixed_px
	var e := spawner.spawn_at(load("res://data/enemies/waegun_soldier.tres"), spot + Vector2(reach, 0))
	e.health.max = 999999
	e.health.current = 999999
	e.attack = null
	e.set_physics_process(false)
	await _wait(0.5)
	e.health.damaged.connect(func(_en: Node, _ty: int, _amount: int, _i: int, _m: float, _a: int) -> void: _hit = true)
	atk.melee_windup.connect(func(_d: Vector2) -> void:
		_start = true
		if atk.chain_step == from_step and (from_step != 1 or caster.combo.streak <= 1):
			_armed = true)
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: _finish = _finish or s == SkillCaster.Slot.TAP)
	var tap_next := Time.get_ticks_msec()
	var t0 := 0
	var lines: PackedStringArray = []
	var shots: Array[Image] = []
	while true:
		if fixed_px <= 0.0:
			e.global_position = player.global_position + Vector2(reach, 0)
		if Time.get_ticks_msec() >= tap_next:
			tap_next += 50
			caster.combo_tap()
		if _armed and t0 == 0:
			t0 = Time.get_ticks_msec()
			_hit = false
			_finish = false
			_start = true
		if t0 > 0:
			var now := Time.get_ticks_msec() - t0
			if now > seconds * 1000.0:
				break
			await RenderingServer.frame_post_draw
			shots.append(_grab())  # 저장은 끝나고 (찍는 동안 프레임이 늘어지지 않게)
			lines.append("%d %s%s%s" % [now, "h" if _hit else "", "s" if _start else "", "f" if _finish else ""])
			_hit = false
			_start = false
			_finish = false
		await process_frame
	for i in shots.size():
		shots[i].save_png("%s/f_%03d.png" % [args[1], i])
	var f := FileAccess.open("%s/times.txt" % args[1], FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	quit()


func _grab() -> Image:
	var img := root.get_texture().get_image()
	var c := (img.get_size() / 2 - CROP / 2 + Vector2i(40, -60)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
