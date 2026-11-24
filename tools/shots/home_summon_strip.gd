extends SceneTree
## 주인 영웅 부르기 연속 장면 띠: 원정 전장에서 우두머리를 앞에 두고 왼쪽 위 단추를 누른다 (실제 main 장면, 실제 누름).
## godot --path . --resolution 720x1280 -s res://tools/shots/home_summon_strip.gd -- <고른 영웅 id> <전장 id> <출력 png>
## 예: sejong hansan_1592 out.png (순신 해일검기)

const TIMES := [0.15, 0.55, 0.75, 1.0, 1.35, 1.8, 2.4, 3.2]
const PRESS_AT := 0.5
const CROP := Rect2i(0, 0, 720, 1000)

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
	var auto := player.get_node_or_null("AutoAttack")
	if auto:
		auto.process_mode = Node.PROCESS_MODE_DISABLED  # 부른 기술 피해만 재게 영웅 자동 공격은 끈다
	var hp0 := boss.health.current
	var t0 := Time.get_ticks_msec() / 1000.0
	var pressed := false
	var shots: Array[Image] = []
	for t in TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			if not pressed and Time.get_ticks_msec() / 1000.0 - t0 >= PRESS_AT:
				pressed = true
				var at := button.center()
				_touch(at, true)
				_touch(at, false)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
	print("[summon-strip] %s at %s home %s: boss %d -> %d (%.1f%%), charges %d" % [args[0], args[1], button.rules.home.id,
		hp0, boss.health.current, 100.0 * (hp0 - boss.health.current) / float(boss.health.max), button.rules.charges])
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var out := Image.create((w + 6) * 4, (h + 6) * 2, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		shots[i].resize(w, h)
		out.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * (w + 6), (i / 4) * (h + 6)))
	out.save_png(args[2])
	quit()


func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = at
	ev.pressed = down
	root.push_input(ev, true)  # 게임 좌표 (720 폭) 그대로
