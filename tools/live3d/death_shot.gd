extends SceneTree
## 쓰러지는 죽음(EnemyDeathPose) 캡처: 적을 세우고 죽인 뒤 판 시각을 넘기며 쓰러짐 → 누워 있기 → 사라짐을 한 줄로.
## 창 모드: godot --path . -s res://tools/live3d/death_shot.gd -- <출력 png> <적 id>...

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CELL := 420
## 처치부터의 순간 (쓰러짐 비율 0~1, 그다음 누워 있기, 사라짐 절반).
const MARKS := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

var _now := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	GameTime.clock = func() -> int: return _now
	var args := OS.get_cmdline_user_args()
	var ids := args.slice(1)
	var cols := MARKS.size() + 2
	var out := Image.create(cols * CELL, ids.size() * CELL, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.2, 0.27, 0.3))
	var vp := SubViewport.new()  # 창 크기·늘이기와 상관없이 한 칸
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.27, 0.3)
	bg.size = Vector2(CELL, CELL)
	vp.add_child(bg)
	for r in ids.size():
		var e: Enemy = ENEMY_SCENE.instantiate()
		e.data = load("res://data/enemies/%s.tres" % ids[r])
		e.position = Vector2(CELL * 0.5, CELL * 0.62)
		vp.add_child(e)
		for k in 4:
			await process_frame
		e.set_physics_process(false)
		_now = 1000
		e.health.kill()
		var pose := EnemyDeathPose.of(e)
		var hold := EnemyDeathPose.hold_time(e.data)
		var fall := hold - e.data.death_rest
		var times: Array = MARKS.map(func(m: float) -> float: return fall * m)
		times.append(hold - 0.01)  # 누워 있기 끝
		times.append(hold + e.data.death_fade * 0.5)  # 사라지는 중
		for c in times.size():
			_now = 1000 + int(float(times[c]) * 1000.0)
			pose._process(0.0)
			for k in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			out.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, r * CELL))
		e.queue_free()
		await process_frame
	out.save_png(args[0])
	GameTime.clock = Callable()
	quit()
