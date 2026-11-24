extends SceneTree
## 보스 단계 낙인(BossPhaseData.seal_art)이 보스 위로 떨어지는 장면을 시각별로 셋 나란히 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/seal_shot.gd -- <출력 png>


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var st: StageTheme = load("res://data/stages/hansan_1592.tres")
	ShotStage.backdrop(self, st)  # 실제 바닥 (floor_grade·빛 웅덩이·비네트·무대 확대)
	var boss: EnemyData = load("res://data/enemies/waegun_commander.tres")
	var seal: Texture2D = load("res://assets/vfx/boss_phase_seal.png")
	var fx := FxLayer.new()
	var times := [0.1, 0.2, 0.29]
	for i in times.size():
		var at := Vector2(130 + i * 230, 760)
		var s := AnimatedSprite2D.new()
		s.sprite_frames = boss.sprite_sheet.shared_sprite_frames()
		for n in s.sprite_frames.get_animation_names():
			if String(n).begins_with("idle"):
				s.animation = n
				break
		s.scale = Vector2.ONE * boss.sprite_scale
		s.position = at + boss.sprite_offset
		root.add_child(s)
		fx.add_fall(seal, at + Vector2(0, -260), at, 0.3, 180.0, 90.0)  # boss_phases.gd 와 같게 (똑바로)
		fx._fx[-1]["t"] = times[i]
	root.add_child(fx)
	fx.set_process(false)  # 준비될 때 켜지므로 붙인 뒤에 끈다 (시각 고정)
	for f in 10:
		fx.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	quit()
