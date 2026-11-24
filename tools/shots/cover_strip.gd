extends SceneTree
## 경복궁 엄폐 연속 장면 띠: 영웅이 기둥 뒤에 서고 맞은편 궁수들이 쏜다 → 화살이 막히고 금이 가다 깨진다.
## 순신이면 해일검기를 기둥 쪽으로 쏴서 막히는 것도 본다.
## godot --path . --resolution 720x1280 -s res://tools/shots/cover_strip.gd -- <영웅 id> <출력 png>

const TIMES := [0.3, 1.0, 1.8, 2.6, 3.4, 4.2, 5.0, 6.0]
const CROP := Rect2i(0, 160, 720, 960)
const ARCHER := "res://data/enemies/jurchen_archer.tres"

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
	GameSettings.stage_id = &"gyeongbokgung_1433"
	GameSettings.tutorial_enabled = false
	GameSettings.story_enabled = false
	GameSettings.enemy_hp_bars = false
	GameSettings.save_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 200:
		await process_frame
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	var arena := main.get_node("Arena") as Arena
	spawner.active = false
	for e in spawner.get_children():
		if e is Enemy:
			e.queue_free()
	var cover: StoneCover = arena.hazards.get_child(0) if arena.hazards.get_child_count() > 0 else null
	if cover == null:
		push_error("no cover")
		quit(1)
		return
	var pillar := cover.state.at[1]
	player.global_position = pillar + Vector2(0, 150)
	player.grant_invulnerability(9999.0)
	var d: EnemyData = load(ARCHER)
	for i in 3:
		var e := spawner.spawn_at(d, pillar + Vector2((i - 1) * 40.0, -420.0))
		if e:
			e.speed_mult = 0.0
	var caster := player.get_node("SkillCaster") as SkillCaster
	var t0 := Time.get_ticks_msec() / 1000.0
	var shots: Array[Image] = []
	var fired := false
	for t in TIMES:
		while Time.get_ticks_msec() / 1000.0 - t0 < t:
			player.global_position = pillar + Vector2(0, 150)
			player.facing = Vector2.UP
			if hero == "yi_sun_sin" and not fired and t >= 3.4:
				fired = true
				caster.aim.active = true
				caster.aim.dir = Vector2.UP
				caster.reset_cooldown(SkillCaster.Slot.CHARGE)
				caster.cast(SkillCaster.Slot.CHARGE, 1.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var vk := img.get_width() / 720.0
		shots.append(img.get_region(Rect2i(Vector2i(Vector2(CROP.position) * vk), Vector2i(Vector2(CROP.size) * vk))))
	print("[cover-strip] blocked enemy %d hero %d broken %d hits %s" % [cover.blocked_enemy, cover.blocked_hero,
		cover.broken_count, str(cover.state.hits)])
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var out := Image.create((w + 6) * 4, (h + 6) * 2, false, shots[0].get_format())
	out.fill(Color.WHITE)
	for i in shots.size():
		shots[i].resize(w, h)
		out.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * (w + 6), (i / 4) * (h + 6)))
	out.save_png(args[1])
	quit()
