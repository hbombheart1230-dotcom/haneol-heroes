extends SceneTree
## 순수 파랑(0,0,255 근처) 덩어리가 적에 나타나는지 찾는다 (실제 한산 판을 돌리며 몇 프레임마다 화면을 검사).
## godot --path . --resolution 720x1600 -s res://tools/probe/blue_scan.gd -- <초> [png 폴더]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := float(args[0]) if args.size() > 0 else 15.0
	ShotStage.skip_menus()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	var n := 0
	var hits := 0
	var saved := 0
	while Time.get_ticks_msec() < end:
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var cnt := _blue(img)
		n += 1
		if cnt > 150:
			hits += 1
			print("BLUE frame %d: %d px  t=%.1f" % [n, cnt, main.state.elapsed])
			if args.size() > 1 and saved < 6:
				img.save_png("%s/blue_%d.png" % [args[1], n])
				saved += 1
	print("frames=%d blue_frames=%d" % [n, hits])
	quit()


func _blue(img: Image) -> int:
	var c := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var p := img.get_pixel(x, y)
			if p.b > 0.85 and p.r < 0.15 and p.g < 0.15:
				c += 1
	return c
