extends SceneTree
## 조작 안내 첫 판에서 첫 강화 패가 몇 초·어느 단계에 뜨는지 잰다 (영웅 넷 × 봇 둘: 보통 / 서툰(단계마다 3초 머뭇)).
## godot --path . --resolution 720x1280 -s res://tools/probe/tut_card_timing.gd
const ARGS_MODES := ["heavy", "slow"]
const HEROES := [&"yi_sun_sin", &"sejong"]
func _initialize() -> void:
	_run()

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	for mode in ARGS_MODES:
		for h in HEROES:
			GameSettings.settings_path = GameSettings.test_path()
			GameSettings.title_seen = true
			GameSettings.opening_seen = true
			GameSettings.hero_picked = true
			GameSettings.hero_id = h
			GameSettings.hero_stages = {}
			GameSettings.stage_picked = false
			GameSettings.tutorial_enabled = true
			GameSettings.want_stage_list = false
			GameSettings.tutorial_done = false
			GameSettings.tutorial_seen_heroes = PackedStringArray()
			GameSettings.skill_button_enabled = false
			GameSettings.save_settings()
			var m: Node = load("res://scenes/main.tscn").instantiate()
			host.add_child(m)
			await process_frame
			await physics_frame
			var d := TutorialDriver.new(host, m)
			var run: TutorialProgress = m.tutorial_director.run
			var t0 := Time.get_ticks_usec() / 1e6
			var first := ""
			var rows := []
			while not run.is_done():
				var s := d.step()
				var i := run.index
				var n := 0
				while run.index == i and not run.is_done() and n < 6:
					if mode == "slow":
						await d.seconds(2.0)
					elif mode == "heavy":  # 연타 잘하는 사람: 단계마다 톡톡 열두 번
						for k in 12:
							await d.tap()
							await d.seconds(0.15)
						if first == "" and m.seal_choice.is_open():
							first = "%.1fs 단계 %d(%s) 시도중" % [Time.get_ticks_usec() / 1e6 - t0, i, s.event]
					await d.act(s.event)
					n += 1
					if first == "" and m.seal_choice.is_open():
						first = "%.1fs 단계 %d(%s)" % [Time.get_ticks_usec() / 1e6 - t0, i, s.event]
				rows.append("%s %.0fs lv%d xp%d pend%d open%s" % [s.event, Time.get_ticks_usec() / 1e6 - t0, m.progress.level, m.progress.xp, m.progress.pending, m.seal_choice.is_open()])
			print("TIMING ", mode, h, " 첫패=", first if first != "" else "없음", " | ", " ; ".join(rows), " | 끝 stuck=", d.step() if run.index < run.data.steps.size() else "-")
			m.queue_free()
			await process_frame
	quit()
