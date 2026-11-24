extends SceneTree
## 마무리 준비 표시 네 영웅: 실제 한산 장면에서 1·2·3타를 이은 직후 (다음 탭 = 4타) 영웅 둘레를 한 칸씩.
## godot --path . --resolution 720x1280 -s res://tools/shots/finisher_cue_shot.gd -- <출력 png>

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const CROP := Vector2i(360, 360)


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := Image.create(CROP.x * HEROES.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in HEROES.size():
		var main: Node = await ShotStage.open(self, &"hansan_1592", StringName(HEROES[i]))
		await _wait(3.0)
		var player := main.get_node("Player") as Player
		player.grant_invulnerability(9999.0)
		var caster := player.get_node("SkillCaster") as SkillCaster
		ShotStage.move_hero(main, ShotStage.brazier_spot(main) + Vector2(0, 200))
		(main.get_node("EnemySpawner") as EnemySpawner).active = false
		caster.reset_cooldown(SkillCaster.Slot.TAP)
		var t_end := Time.get_ticks_msec() + 4000
		while not TapChain.finisher_armed(caster) and Time.get_ticks_msec() < t_end:
			caster.combo_tap()
			await _wait(0.08)
		await _wait(0.25)  # 켜지는 번쩍임이 가라앉은 뒤
		print("[cue] %s armed=%s shown=%s" % [HEROES[i], TapChain.finisher_armed(caster), caster.finisher_cue.shown])
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var c := (img.get_size() / 2 - CROP / 2 + Vector2i(0, -40)).clamp(Vector2i.ZERO, img.get_size() - CROP)
		var r := img.get_region(Rect2i(c, CROP))
		r.convert(Image.FORMAT_RGBA8)
		out.blit_rect(r, Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
		main.queue_free()
		await _wait(0.3)
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
