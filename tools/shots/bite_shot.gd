extends SceneTree
## 칼이 닿는 순간(피해가 들어간 프레임) 화면을 1·2·3타 세 칸으로: 멈춘 장면에서 칼이 몹 위에 있는지 비교 (전·후, 예전 코드에서도 돈다).
## 실제 한산 장면(ShotStage), 순신 오른쪽에 왜군 병사 둘. 위 줄 = 이펙트를 가린 몸 자세 (칼 위치), 아래 줄 = 실제 화면.
## godot --path . --resolution 720x1280 -s res://tools/shots/bite_shot.gd -- <출력 png>

const CROP := Vector2i(400, 400)
const OUT := Vector2i(400, 400)

var _want := false
var _shots: Array[Image] = []
var _bottom: Array[Image] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = await ShotStage.open(self)
	await _wait(3.2)
	var player := main.get_node("Player") as Player
	var caster := player.get_node("SkillCaster") as SkillCaster
	var atk := caster.auto_attack()
	var spot := ShotStage.brazier_spot(main) + Vector2(0, 200)
	ShotStage.move_hero(main, spot)
	player.facing = Vector2.RIGHT
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var data: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	for off in [Vector2(78, -6), Vector2(96, 34)]:
		var e := spawner.spawn_at(data, spot + off)
		e.global_position = spot + off
		e.health.max = 99999
		e.health.current = 99999
		e.attack = null
	await _wait(0.4)
	atk.melee_swung.connect(func(_d: Vector2, hits: int) -> void: _want = hits > 0)
	for i in 3:
		var guard := 0
		while not atk.can_manual(caster.tap_gap()) and guard < 200:
			await physics_frame
			guard += 1
		_want = false
		caster.combo_tap()
		var wait := 0
		while not _want and wait < 120:
			await physics_frame
			wait += 1
		var fx := Feedback.instance.fx if Feedback.instance else null
		if fx:
			fx.visible = false  # 위 줄: 닿는 섬광·검기를 가리고 몸 자세만
		_set_trails(false)
		await RenderingServer.frame_post_draw  # 피해가 들어간 바로 그 프레임 (멈춤이 걸린 그림)
		_shots.append(_grab(player))
		if fx:
			fx.visible = true
		_set_trails(true)
		await RenderingServer.frame_post_draw  # 같은 멈춤 안의 다음 프레임: 실제 화면
		_bottom.append(_grab(player))
		await _wait(0.5)
	var out := Image.create(OUT.x * 3, OUT.y * 2, false, Image.FORMAT_RGBA8)
	for i in _shots.size():
		out.blit_rect(_shots[i], Rect2i(Vector2i.ZERO, OUT), Vector2i(OUT.x * i, 0))
		out.blit_rect(_bottom[i], Rect2i(Vector2i.ZERO, OUT), Vector2i(OUT.x * i, OUT.y))
	out.save_png(args[0])
	quit()


func _grab(player: Player) -> Image:
	var img := root.get_texture().get_image()
	var k := img.get_size().x / 720.0  # 카메라가 영웅을 화면 가운데에 둔다
	var at := Vector2i(Vector2(img.get_size()) * 0.5 + Vector2(55, -45) * k)
	var c := (at - CROP / 2).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	r.resize(OUT.x, OUT.y)
	return r


func _set_trails(on: bool) -> void:
	for n in root.find_children("*", "SwingTrail", true, false):
		(n as CanvasItem).visible = on


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
