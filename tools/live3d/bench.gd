extends SceneTree
## 실시간 3D 성능 비교 (시험): 영웅 1 + 적 8 상당 = 같은 순신 모델 9개를 띄워 프레임 시간·그리기 호출·메모리를 잰다.
## 창 모드(GPU)로: godot --path . -s res://tools/live3d/bench.gd -- <mode> [count] [frames]
##   baked     : 구운 시트 AnimatedSprite2D 9개 (지금 방식)
##   viewports : 인스턴스마다 SubViewport 256px + 수묵 셰이더 (이 시험이 고른 방식 b)
##   noink     : viewports에서 수묵 셰이더만 뺀 것 (셰이더 비용 분리)
##   shared    : 화면 크기 SubViewport 하나에 모델 9개 (방식 c) + 화면 전체 수묵 한 번
## 결과는 한 줄 JSON (BENCH {...}).

const PlayerView3D := preload("res://scripts/player/player_view_3d.gd")
const Rig := preload("res://scripts/art/live3d/live3d_rig.gd")

var _vps: Array[RID] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var mode: String = a[0] if a.size() > 0 else "viewports"
	var count := int(a[1]) if a.size() > 1 else 9
	var frames := int(a[2]) if a.size() > 2 else 600
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(720, 1280))
	root.size = Vector2i(720, 1280)
	var hero: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var live: Live3DHeroData = load("res://data/live3d/yi_sun_sin.tres")
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.2, 0.25)
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var vmem0 := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var t_setup := Time.get_ticks_usec()
	var rigs: Array = []
	if mode == "shared":
		rigs = _shared(live, hero, count)
	else:
		for i in count:
			var at := Vector2(140 + (i % 3) * 220, 260 + (i / 3) * 330)
			if mode == "baked":
				var s := AnimatedSprite2D.new()
				s.sprite_frames = hero.sprite_sheet.shared_sprite_frames()
				s.play(&"run_%d" % (i % 8))
				s.position = at
				s.scale = Vector2.ONE * hero.sprite_scale
				root.add_child(s)
			else:
				var r: Node = Rig.new()
				root.add_child(r)
				r.setup(live, PlayerView3D.durations(hero.sprite_sheet))
				r.play_body("run", true, i * 0.05, 1.0)
				r.set_facing(Vector2.from_angle(i * 0.7), 1.0)
				var s := Sprite2D.new()
				s.texture = r.texture()
				s.position = at
				s.scale = Vector2.ONE * hero.sprite_scale
				if mode == "viewports":
					var mat := ShaderMaterial.new()
					mat.shader = load("res://shaders/ink_live.gdshader")
					for k in live.ink:
						mat.set_shader_parameter(k, live.ink[k])
					s.material = mat
				root.add_child(s)
				rigs.append(r)
				_vps.append(r.viewport.get_viewport_rid())
	t_setup = Time.get_ticks_usec() - t_setup
	_vps.append(root.get_viewport_rid())
	for v in _vps:
		RenderingServer.viewport_set_measure_render_time(v, true)
	for i in 120:
		await process_frame
	var sum_dt := 0.0
	var worst := 0.0
	var cpu := 0.0
	var gpu := 0.0
	var draws := 0.0
	var prev := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - prev) / 1000.0
		prev = now
		sum_dt += dt
		worst = maxf(worst, dt)
		cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var g := 0.0
		for v in _vps:
			g += RenderingServer.viewport_get_measured_render_time_gpu(v)
		gpu += g
	var res := {"mode": mode, "count": count, "frame_ms": sum_dt / frames, "worst_ms": worst,
		"process_ms": cpu / frames, "gpu_ms": gpu / frames, "draw_calls": draws / frames,
		"static_mem_mb": (Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1048576.0,
		"video_mem_mb": (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) - vmem0) / 1048576.0,
		"setup_ms": t_setup / 1000.0, "gpu_name": RenderingServer.get_video_adapter_name()}
	print("BENCH ", JSON.stringify(res))
	quit()


## 방식 c: 화면 크기 SubViewport 하나, 세계 하나, 카메라 하나에 모델 여럿 (2D 좌표 → 3D 바닥 좌표로 옮긴다고 가정).
func _shared(live: Live3DHeroData, hero: HeroData, count: int) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.transparent_bg = true
	vp.own_world_3d = true
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = live.ortho_size * 1280.0 / live.frame / hero.sprite_scale
	cam.transform = Transform3D(Basis.looking_at(live.cam_target - live.cam_pos, Vector3.UP), live.cam_pos)
	world.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var out: Array = []
	for i in count:
		var r: Node = Rig.new()
		root.add_child(r)
		r.setup(live, PlayerView3D.durations(hero.sprite_sheet))
		var model := r.pivot.get_child(0) as Node3D
		r.pivot.remove_child(model)  # 자기 화면 대신 공유 세계로
		var p := Node3D.new()
		world.add_child(p)
		p.position = Vector3(-2.2 + (i % 3) * 2.2, 0, -2.5 + (i / 3) * 2.5)
		p.rotation.y = i * 0.7
		p.add_child(model)
		r.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		r.play_body("run", true, i * 0.05, 1.0)
		out.append(r)
	var s := Sprite2D.new()
	s.texture = vp.get_texture()
	s.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ink_live.gdshader")
	for k in live.ink:
		mat.set_shader_parameter(k, live.ink[k])
	s.material = mat
	root.add_child(s)
	_vps.append(vp.get_viewport_rid())
	return out
