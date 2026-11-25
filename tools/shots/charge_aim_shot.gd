extends SceneTree
## 4번(모으기) 조준 표시 찍기: 실제 무대에서 꾹 눌러 오른쪽으로 끌며 hold초 모은 장면을 영웅별·강화 단계별로 한 줄에 붙인다.
## godot --path . --resolution 720x1280 -s res://tools/shots/charge_aim_shot.gd -- <출력 png> [hold초=1.4]

const CASES := [["yi_sun_sin", "hansan_1592", 0], ["yi_sun_sin", "hansan_1592", 6], ["gwanggaeto", "manchuria_395", 0],
	["shin_saimdang", "chochungdo", 0]]
const CROP := Vector2i(640, 640)


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var hold := float(args[1]) if args.size() > 1 else 1.4
	var out: Array[Image] = []
	for c in CASES:
		var main: Node = await ShotStage.open(self, StringName(c[1]), StringName(c[0]))
		await _wait(1.2)
		var player := main.get_node("Player") as Player
		player.grant_invulnerability(9999.0)
		var caster := player.get_node("SkillCaster") as SkillCaster
		caster.kit.charge.vfx_level = int(c[2])
		caster.reset_cooldown(SkillCaster.Slot.CHARGE)
		caster.on_press(7, Time.get_ticks_usec() / 1_000_000.0)
		var end := Time.get_ticks_msec() + int(hold * 1000.0)
		while Time.get_ticks_msec() < end:
			player.set_move_input(Vector2.RIGHT)  # 오른쪽으로 끌어 조준
			await process_frame
		await RenderingServer.frame_post_draw
		out.append(_grab(player))
		print("[aim-shot] %s lv%d charging=%s" % [c[0], c[2], caster.is_charging()])
		caster.cancel_input()
		main.queue_free()
		await process_frame
		await process_frame
	var strip := Image.create(CROP.x * out.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in out.size():
		strip.blit_rect(out[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	strip.save_png(args[0])
	quit()


func _grab(player: Node2D) -> Image:
	var img := root.get_texture().get_image()
	var at := Vector2i(player.get_global_transform_with_canvas().origin * Vector2(img.get_size()) / root.get_visible_rect().size)
	var c := (at - Vector2i(CROP.x / 5, CROP.y / 2)).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var r := img.get_region(Rect2i(c, CROP))
	r.convert(Image.FORMAT_RGBA8)
	return r


func _wait(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
