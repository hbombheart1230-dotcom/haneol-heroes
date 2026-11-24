extends SceneTree
## 초충도 풀숲 연속 장면 띠: 영웅이 풀숲에 숨으면 적이 들어간 자리로 몰려와 두리번거리고, 나와서 치면 금빛 "기습".
## godot --path . --resolution 720x1280 -s res://tools/shots/grass_strip.gd -- <영웅 id> <출력 png>

const TIMES := [0.3, 1.2, 2.2, 3.0, 3.3, 3.6, 4.2, 5.0]
const CROP := Rect2i(0, 160, 720, 960)

var main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := args[0]
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings.cfg"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.stage_picked = true
	GameSettings.tutorial_done = true
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.hero_id = StringName(hero)
	GameSettings.stage_id = &"chochungdo"
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = false
	GameSettings.want_stage_list = false  # 전장 목록을 열지 않고 바로 판
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	(main.get_node("EnemySpawner") as EnemySpawner).active = false
	(main.get_node("Player") as Player).grant_invulnerability(9999.0)
	for i in 160:
		await process_frame
	if main.is_choosing():  # 판 앞 몇 초 사이 레벨이 올라 고르기가 열렸으면 첫 카드
		main.seal_choice.pick(0)
	paused = false
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	var arena := main.get_node("Arena") as Arena
	spawner.active = false
	for e in spawner.get_children():
		if e is Enemy:
			e.queue_free()
	var grass: GrassHide = arena.hazards.get_child(0) if arena.hazards.get_child_count() > 0 else null
	if grass == null:
		push_error("no grass")
		quit(1)
		return
	var c := Vector2(grass.data.patches[2].x, grass.data.patches[2].y)
	player.global_position = c
	player.grant_invulnerability(9999.0)
	var st: StageTheme = load("res://data/stages/chochungdo.tres")
	var d: EnemyData = st.waves.waves[0].enemies[0] if st.waves else st.spawn_table[0]
	var foes: Array[Enemy] = []
	for i in 5:
		var e := spawner.spawn_at(d, c + Vector2.from_angle(TAU * i / 5.0 - 0.4) * 330.0)
		if e:
			foes.append(e)
	var caster := player.get_node("SkillCaster") as SkillCaster
	var t0 := Time.get_ticks_msec() / 1000.0
	var tapped := false
	var shots: Array[Image] = []
	for t in TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			var now := Time.get_ticks_msec() / 1000.0 - t0
			if now < 3.0:
				player.global_position = c
				player.set_move_input(Vector2.ZERO)
			elif not tapped:
				var target: Enemy = null
				for e in foes:
					if is_instance_valid(e) and (target == null or e.global_position.distance_to(c) < target.global_position.distance_to(c)):
						target = e
				if target:
					var out := c + (target.global_position - c).normalized() * (grass.data.patches[2].z + 30.0)
					player.global_position = out
					player.facing = (target.global_position - out).normalized()
					await physics_frame
					caster.combo_tap()
				tapped = true
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
	print("[grass-strip] %s" % str(grass.report()))
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var out_img := Image.create((w + 6) * 4, (h + 6) * 2, false, shots[0].get_format())
	out_img.fill(Color.WHITE)
	for i in shots.size():
		shots[i].resize(w, h)
		out_img.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * (w + 6), (i / 4) * (h + 6)))
	out_img.save_png(args[1])
	quit()
