extends SceneTree
## 적 구운 그림 ↔ 실시간 3D 나란히 (한산 대장): 같은 적 데이터로 두 마리를 세우고 (왼쪽 = 구운 그림, 오른쪽 = 3D)
## 같은 상태를 손으로 넣어 EnemySprite.update로 고르게 한 뒤 화면을 찍어 줄마다 쌓는다 (어두운 한산 바닥색 위).
## 줄: 대기 · 걷기 · 공격 예고 0 · 예고 반 · 예고 끝(= 맞닿는 칸, 피해 순간) · 회복 반 · 쓸기 예고 끝 · 맞음.
## 창 모드(GPU): godot --path . --resolution 720x1280 -s res://tools/live3d/enemy_compare_shot.gd -- <출력.png> [적 id]

const Switch := preload("res://scripts/art/live3d/live3d_switch.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CELL := Vector2i(300, 300)
const BG := Color(0.2, 0.21, 0.22)

var _left: Enemy
var _right: Enemy
var _target: Node2D


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://enemy_live3d_strip.png"
	var id: String = args[1] if args.size() > 1 else "waegun_commander"
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(4000, 4000)
	bg.position = Vector2(-2000, -2000)
	root.add_child(bg)
	var cam := Camera2D.new()
	cam.position = Vector2(0, -60)
	root.add_child(cam)
	_target = Node2D.new()
	_target.position = Vector2(0, 600)  # 아래(화면 쪽)를 본다
	root.add_child(_target)
	_left = _spawn(id, false, Vector2(-150, 0))
	_right = _spawn(id, true, Vector2(150, 0))
	for k in 3:  # _ready (공격·반응이 생긴다)
		await process_frame
	var rows: Array[Image] = []
	var labels := ["idle", "run", "attack 0", "attack 0.5", "attack strike", "recover 0.5", "attack2 strike", "hit"]
	for i in labels.size():
		for e in [_left, _right]:
			_pose(e, i)
		for k in 6:  # 3D 화면이 새 자세로 그려질 때까지
			for e in [_left, _right]:
				_pose(e, i)
			await process_frame
		var shot := root.get_viewport().get_texture().get_image()
		var c := Vector2i(shot.get_width() / 2, shot.get_height() / 2 + 30)
		rows.append(shot.get_region(Rect2i(c.x - CELL.x, c.y - CELL.y / 2 - 40, CELL.x * 2, CELL.y)))
		print("[enemy-compare] ", labels[i])
	var strip := Image.create(CELL.x * 2, CELL.y * rows.size(), false, rows[0].get_format())
	for i in rows.size():
		strip.blit_rect(rows[i], Rect2i(Vector2i.ZERO, rows[i].get_size()), Vector2i(0, CELL.y * i))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("[enemy-compare] saved ", out, " ", strip.save_png(out))
	quit()


func _spawn(id: String, live: bool, at: Vector2) -> Enemy:
	var was: Variant = ProjectSettings.get_setting(Switch.SETTING, true)
	ProjectSettings.set_setting(Switch.SETTING, live)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = load("res://data/enemies/%s.tres" % id)
	e.position = at
	root.add_child(e)
	ProjectSettings.set_setting(Switch.SETTING, was)
	e.set_physics_process(false)
	e.target = _target
	return e


## 상태 i를 넣고 그림을 고르게 한다 (판정·이동은 굴리지 않는다).
func _pose(e: Enemy, i: int) -> void:
	var a := e.attack
	a.state = EnemyAttack.State.READY
	e.velocity = Vector2.ZERO
	a.aim_dir = Vector2.DOWN
	var busy := false
	match i:
		1:
			e.velocity = Vector2(0, 60)
		2, 3, 4:
			_use(a, &"attack")
			a.state = EnemyAttack.State.WINDUP
			a._timer = a.data.windup * (1.0 - [0.0, 0.5, 1.0][i - 2])
			busy = true
		5:
			_use(a, &"attack")
			a.state = EnemyAttack.State.RECOVER
			a._recover_total = maxf(a.data.recovery, 0.1)
			a._timer = a._recover_total * 0.5
			busy = true
		6:
			_use(a, &"attack2")
			a.state = EnemyAttack.State.WINDUP
			a._timer = 0.0
			busy = true
		7:
			if e.sprite.animation.begins_with("hit") == false:
				EnemySprite.start_hit(e)
			e.reaction.anim_left = 0.2
	EnemySprite.update(e, busy)


## 패턴 중 그 동작을 쓰는 공격으로.
func _use(a: EnemyAttack, anim: StringName) -> void:
	for p in a.patterns:
		if (p as EnemyAttackData).anim == anim:
			a.data = p
			return
