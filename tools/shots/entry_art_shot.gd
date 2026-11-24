extends SceneTree
## 입장(타이틀) 화면과 이야기 마지막 장면을 화면 크기별로 찍는다 (SubViewport로 정확한 크기).
## godot --path . -s res://tools/shots/entry_art_shot.gd -- <출력 폴더> <머리글자> [가로x세로 ...]
## 예: ... -- C:/out after 1080x2400 720x1280

func _initialize() -> void:
	_run()


func _snap(vp: SubViewport, path: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png(path)


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var dir := args[0]
	var tag := args[1]
	var sizes: Array = args.slice(2) if args.size() > 2 else ["1080x2400"]
	for sz in sizes:
		var wh := String(sz).split("x")
		var size := Vector2i(int(wh[0]), int(wh[1]))
		var vp := SubViewport.new()
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var title := TitleScreen.new()
		title.size = Vector2(size)
		vp.add_child(title)
		title.open()
		await _snap(vp, "%s/%s_title_%s.png" % [dir, tag, sz])
		title.queue_free()
		var story := StoryIntro.new()
		story.size = Vector2(size)
		vp.add_child(story)
		var data: IntroData = load("res://data/intro/story_intro.tres")
		story.open(data)
		var last := data.slides.size() - 1
		var start := 0.0
		for i in last:
			start += data.slides[i].duration
		story.t = start + 3.5  # 마지막 장면, 글이 다 나온 뒤
		await _snap(vp, "%s/%s_story_last_%s.png" % [dir, tag, sz])
		story.queue_free()
		vp.queue_free()
	quit()
