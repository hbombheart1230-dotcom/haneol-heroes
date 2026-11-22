extends SceneTree
## 연계 흐름 확인: 실제 main 장면 (순신 · 한산)에서 사람처럼 입력하고 영웅 둘레를 프레임마다 잘라 띠로 + 칸마다
## 영웅 동작 이름·칸 번호·그림 위치(내딛기)를 로그(<png>.txt)로 남긴다. 끊김(같은 칸 반복·자세 튐)을 숫자로 본다.
## godot --path . --resolution 720x1280 -s res://tools/shots/chain_shot.gd -- <taps|runstop|dash|moveattack> <출력 png>

const EVERY := 2
const CROP := Vector2i(300, 300)
const TAP_GAP := 0.2


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0]
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"hansan_1592"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.1)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.active = false
	var player := main.get_node("Player") as Player
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	var view := player.get_node_or_null("PlayerView") as PlayerView
	var soldier: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var at := Vector2(110, 0) if mode != "runstop" else Vector2(260, 0)
	var e := spawner.spawn_at(soldier, player.global_position + at)
	e.health.max = 99999
	e.health.current = 99999
	player.facing = Vector2.RIGHT
	await _wait(3.2)  # 무대 제목 띠가 사라질 때까지
	e.attack._cooldown = 999.0
	var t0 := Time.get_ticks_msec()
	var shots: Array[Image] = []
	var log := PackedStringArray()
	var frames := 75
	var tap_t := 0.0
	for f in frames:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		e.attack._cooldown = 999.0
		match mode:
			"taps":  # 제자리 탭 (연타 1·2·3 → 넷째 탭 해룡참)
				if t >= tap_t:
					tap_t += TAP_GAP
					caster.combo_tap()
			"runstop":  # 0.45초 달리다 멈추자마자 탭
				player.move_input = Vector2.RIGHT if t < 0.45 else Vector2.ZERO
				if t >= 0.45 and t >= tap_t:
					tap_t = maxf(tap_t, 0.45) + TAP_GAP
					caster.combo_tap()
			"moveattack":  # 탭하며 오른쪽으로 걸어감 (단추 탭 + 이동)
				player.move_input = Vector2.RIGHT * 0.6 if t < 1.2 else Vector2.ZERO
				if t >= tap_t:
					tap_t += TAP_GAP
					caster.combo_tap()
			"dash":  # 탭 두 번 → 대시 → 대시 직후 손 뗌(파도격) → 탭
				if t < 0.45 and t >= tap_t:
					tap_t += TAP_GAP
					caster.combo_tap()
				elif t >= 0.5 and t < 0.52:
					player.request_dash(Vector2.RIGHT)
				elif t >= 0.6 and t < 0.62:
					caster.try_dash_release()
				elif t >= 0.9 and t >= tap_t:
					tap_t = maxf(tap_t, 0.9) + TAP_GAP
					caster.combo_tap()
		for k in EVERY:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var c := img.get_size() / 2 - CROP / 2 + Vector2i(0, -40)
		shots.append(img.get_region(Rect2i(c, CROP)))
		var spr := view._sprite if view else null
		log.append("%4d ms  anim %-14s frame %2d  sprite_pos %6.1f,%6.1f  hold %.2f  posing %s  moving %s" % [
			Time.get_ticks_msec() - t0, view.current_anim() if view else "-", spr.frame if spr else -1,
			spr.position.x if spr else 0.0, spr.position.y if spr else 0.0, view._hold_left if view else 0.0,
			view._posing if view else false, view.is_moving() if view else false])
	var cols := 15
	var w := CROP.x / 2
	var h := CROP.y / 2
	var out := Image.create(w * cols, h * ceili(frames / float(cols)), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var s := shots[i]
		s.convert(Image.FORMAT_RGBA8)
		s.resize(w, h)
		out.blit_rect(s, Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % cols) * w, (i / cols) * h))
	out.save_png(args[1])
	var fl := FileAccess.open(args[1] + ".txt", FileAccess.WRITE)
	fl.store_string("\n".join(log))
	fl.close()
	quit()


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
