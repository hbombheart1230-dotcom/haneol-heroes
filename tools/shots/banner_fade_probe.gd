extends SceneTree
## 중간 우두머리 등장 띠가 다 빠지는지 재기: 실제 판에서 중간 우두머리를 부르고, 띠가 그려질 때마다 그 순간 투명도를 적는다.
## 띠가 끝난 뒤 마지막으로 그려진 투명도가 0이 아니면 그 그림이 화면에 남는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/banner_fade_probe.gd -- [무대 id] [끝 무렵 끊김 ms] [기술 멈춤 1/0]

var _last_a := -1.0
var _draws := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	var main: Node = await ShotStage.open(self, StringName(a[0] if a.size() > 0 else "hansan_1592"), &"yi_sun_sin")
	var hitch_ms := int(a[1]) if a.size() > 1 else 0
	var slow := a.size() > 2 and a[2] == "1"
	for i in 240:
		await process_frame
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	(main.get_node("Player") as Player).grant_invulnerability(9999.0)
	var b := main.get_node("HUD/BossBanner") as BossBanner
	b.draw.connect(func() -> void:
		_draws += 1
		_last_a = minf(clampf(b._t / 0.3, 0.0, 1.0), clampf((b._len - b._t) / 0.5, 0.0, 1.0)) if b.banner_visible() else 0.0)
	sp.spawn_elite()
	var t0 := Time.get_ticks_msec()
	while b.banner_visible():
		await process_frame
		var sc = main.get("seal_choice")
		if sc and sc.is_open():
			sc.pick(0)
		if slow and b._t > 1.0 and b._t < 1.4:
			Engine.time_scale = 0.05  # 기술 멈춤 흉내
		else:
			Engine.time_scale = 1.0
		if hitch_ms > 0 and b._len - b._t < 0.25:
			OS.delay_msec(hitch_ms)  # 폰 끊김 흉내 (마지막 몇 장이 길게)
	for i in 30:
		await process_frame
	print("BANNER done after %d ms, draws %d, last drawn alpha %.3f" % [Time.get_ticks_msec() - t0, _draws, _last_a])
	quit()
