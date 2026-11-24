extends SceneTree
## 쿨타임 중 모으기 (흐린 고리 + 남은 시간): 네 영웅을 자기 무대에서 모으기 기술을 막 쓴 뒤 다시 꾹 눌러 1.2초 모은 장면,
## 맨 오른쪽은 비교용으로 쿨타임이 끝난 보통 모으기 (순신). 한 줄로 붙여 저장한다.
## godot --path . --resolution 720x1280 -s res://tools/shots/charge_wait_shot.gd -- <출력 png>

const CROP := Vector2i(420, 480)
const CASES := [["yi_sun_sin", "hansan_1592", true], ["gwanggaeto", "manchuria_395", true],
	["sejong", "gyeongbokgung_1433", true], ["shin_saimdang", "chochungdo", true], ["yi_sun_sin", "hansan_1592", false]]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out: Array[Image] = []
	for c in CASES:
		var main: Node = await ShotStage.open(self, StringName(c[1]), StringName(c[0]))
		await _wait(1.5)
		var player := main.get_node("Player") as Player
		player.grant_invulnerability(9999.0)
		var caster := player.get_node("SkillCaster") as SkillCaster
		if c[2]:
			caster.cast(SkillCaster.Slot.CHARGE)
			await _wait(1.0)  # 컷인·발동이 지나가게
		else:
			caster.reset_cooldown(SkillCaster.Slot.CHARGE)
		caster.on_press(7, Time.get_ticks_usec() / 1_000_000.0)
		await _wait(1.2)
		await RenderingServer.frame_post_draw
		out.append(_grab(player))
		print("[wait-shot] %s waiting=%s left=%.1f" % [c[0], caster._marker().waiting(), caster.cooldown_left(SkillCaster.Slot.CHARGE)])
		caster.cancel_input()
		main.queue_free()
		await process_frame
		await process_frame
	var strip := Image.create(CROP.x * out.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in out.size():
		strip.blit_rect(out[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	strip.save_png(OS.get_cmdline_user_args()[0])
	quit()


func _grab(player: Node2D) -> Image:
	var img := root.get_texture().get_image()
	var at := Vector2i(player.get_global_transform_with_canvas().origin * Vector2(img.get_size()) / root.get_visible_rect().size)
	var c := (at - CROP / 2 + Vector2i(0, 60)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
