extends SceneTree
## 주인 영웅 부르기 움직이는 그림: home_summon_strip.gd와 같은 판 (우두머리 + 잡몹 셋, 실제 누름)을 seconds초 동안
## 1/15초마다 찍어 폴더에 남긴다 (frames_to_gif.py로 GIF). 고른 영웅은 0.2초마다 탭 (같이 싸우는 모습 보기).
## godot --path . --resolution 720x1280 -s res://tools/shots/home_summon_gif.gd -- <고른 영웅 id> <전장 id> <출력 폴더> [초=9]

const PRESS_AT := 0.5
const STEP := 1.0 / 15.0
const CROP := Rect2i(0, 120, 720, 900)

var main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = StringName(args[0])
	GameSettings.stage_id = StringName(args[1])
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = true
	GameSettings.enemy_hp_bars = false
	GameSettings.want_stage_list = false
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	(main.get_node("EnemySpawner") as EnemySpawner).active = false
	(main.get_node("Player") as Player).grant_invulnerability(9999.0)
	for i in 160:
		await process_frame
	if main.is_choosing():
		main.seal_choice.pick(0)
	paused = false
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	spawner.active = false
	if spawner.waves:
		spawner.waves.phase = WaveRunner.Phase.RUN
	for e in spawner.get_children():
		if e is Enemy:
			e.queue_free()
	var button: HomeSummonButton = null
	for c in main.hud.get_children():
		if c is HomeSummonButton:
			button = c
	if button == null or not button.rules.active():
		push_error("no summon on %s for %s" % [args[1], args[0]])
		quit(1)
		return
	AllyPresets.apply(button.data, OS.get_environment("HH_ALLY_PRESET"))
	print("[summon-gif] ally %s" % AllyPresets.describe(button.data))
	player.global_position = Vector2(0, 200)
	player.facing = Vector2.UP
	var boss := spawner.spawn_boss()
	boss.global_position = player.global_position + Vector2(0, -170)
	boss.speed_mult = 0.0
	for i in 3:
		var e := spawner.spawn_at(main.stage_by_id(main.run_stage_id()).waves.waves[0].enemies[0], player.global_position + Vector2((i - 1) * 140.0, -90.0))
		if e:
			e.speed_mult = 0.0
	for i in 150:  # 우두머리 등장 띠가 지나가게
		await process_frame
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	var secs := float(args[3]) if args.size() > 3 else 9.0
	DirAccess.make_dir_recursive_absolute(args[2])
	var hp0 := boss.health.current
	var t0 := Time.get_ticks_msec() / 1000.0
	var pressed := false
	var tap := 0.0
	var times := PackedStringArray()
	var k := 0
	var next := 0.0
	while Time.get_ticks_msec() / 1000.0 - t0 < secs:
		var now := Time.get_ticks_msec() / 1000.0 - t0
		if not pressed and now >= PRESS_AT:
			pressed = true
			var at := button.center()
			_touch(at, true)
			_touch(at, false)
		tap -= 1.0 / 60.0
		if caster and tap <= 0.0:
			tap = 0.2
			caster.combo_tap()
		await process_frame
		if now >= next:
			next += STEP
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var vk := img.get_width() / 720.0
			img = img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk)))
			img.resize(CROP.size.x / 2, CROP.size.y / 2)
			img.save_png(args[2] + "/f_%03d.png" % k)
			times.append("%d" % int(now * 1000.0))
			k += 1
	FileAccess.open(args[2] + "/times.txt", FileAccess.WRITE).store_string("
".join(times))
	print("[summon-gif] %s at %s home %s: boss %d -> %d (%.1f%%), frames %d" % [args[0], args[1], button.rules.home.id,
		hp0, boss.health.current, 100.0 * (hp0 - boss.health.current) / float(boss.health.max), k])
	quit()


func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = at
	ev.pressed = down
	root.push_input(ev, true)  # 게임 좌표 (720 폭) 그대로
