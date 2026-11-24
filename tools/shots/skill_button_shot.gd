extends SceneTree
## 기술 단추 모습 (영웅별): 켬 — 평소/쿨타임 중/꾹 모으는 중/반격 시간, 끔 — 작은 쿨타임 원 셋. 1080x2400 전투 화면 통째로.
## godot --path . -s res://tools/shots/skill_button_shot.gd -- <출력 폴더>
## 파일: <영웅>_<상태>.png (상태: on_idle, on_cd, on_charge, on_counter, off_cd)

const HEROES := [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]
var sv: SubViewport


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	for hero in HEROES:
		GameSettings.settings_path = GameSettings.test_path()
		GameSettings.title_seen = true
		GameSettings.opening_seen = true
		GameSettings.hero_picked = true
		GameSettings.hero_id = hero
		GameSettings.hero_stages = {}
		GameSettings.stage_picked = false
		GameSettings.tutorial_enabled = false
		GameSettings.tutorial_done = true
		GameSettings.story_enabled = false
		sv = SubViewport.new()
		sv.size = Vector2i(1080, 2400)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(sv)
		var main: Node = load("res://scenes/main.tscn").instantiate()
		sv.add_child(main)
		await _frames(30)
		var sc := main.player.get_node("SkillCaster") as SkillCaster
		var tc := main.get_node("TouchController") as TouchController
		tc.skill_button_enabled = true
		await _frames(3)
		await _shot(dir, hero, "on_idle")
		sc._cd[SkillCaster.Slot.TAP] = sc.kit.tap.cooldown * 0.6
		await _frames(2)
		await _shot(dir, hero, "on_cd")
		sc._cd[SkillCaster.Slot.TAP] = 0.0
		sc.input.press(0, Time.get_ticks_usec() / 1_000_000.0 - 0.6, SkillInput.Source.BUTTON, 0.2)
		sc.input.update(Time.get_ticks_usec() / 1_000_000.0)
		await _frames(2)
		await _shot(dir, hero, "on_charge")
		sc.input.reset()
		sc._counter_left = sc.kit.counter_window
		await _frames(2)
		await _shot(dir, hero, "on_counter")
		sc._counter_left = 0.0
		tc.skill_button_enabled = false
		sc._cd[SkillCaster.Slot.TAP] = sc.kit.tap.cooldown * 0.5
		sc._cd[SkillCaster.Slot.CHARGE] = sc.kit.charge.cooldown * 0.3
		await _frames(2)
		await _shot(dir, hero, "off_cd")
		main.queue_free()
		sv.queue_free()
		await _frames(2)
	quit()


func _shot(dir: String, hero: StringName, state: String) -> void:
	sv.get_texture().get_image().save_png("%s/%s_%s.png" % [dir, hero, state])
