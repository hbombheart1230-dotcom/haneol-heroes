extends SceneTree
## 한산 배 세 척 밝기 비교: 지금 / 안 A (배 look 명도·채도 올림) / 안 B (A + 왜군 망령 색 덜 회색) — 같은 자리·같은 적 떼로 배마다 한 장.
## 값은 이 실행에서만 바꾼다 (데이터는 안 건드림). 적 재질이 데이터마다 한 번 만들어져 안마다 따로 실행한다.
## godot --path . --resolution 720x1280 -s res://tools/shots/look_options_shot.gd -- <out 폴더> <now|a|b>

const LOOK_A := {  # look 경로: 바꿀 값
	"res://data/stages/looks/hansan_1592.tres": {"value_mult": 0.72, "saturation": 0.8, "contrast": 1.7},
	"res://data/stages/looks/hansan_sekibune.tres": {"value_mult": 0.8, "saturation": 0.6, "contrast": 1.4, "tint_mix": 0.45},
	"res://data/stages/looks/hansan_atakebune.tres": {"value_mult": 0.82, "saturation": 1.0, "contrast": 1.3},
}
const ENEMIES := ["waegun_soldier", "waegun_gunner", "waegun_heavy", "waegun_elite", "waegun_captain", "waegun_drummer", "waegun_commander", "waegun_gunner_captain"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var opt: String = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	if opt == "b":  # 망령 색 덜: 발쪽 보라·몸 비침 줄이고 몸 조금 밝게
		for id in ENEMIES:
			var d := load("res://data/enemies/%s.tres" % id) as EnemyData
			d.ghost_color.a = 0.15
			d.body_lift = 0.1
			d.body_contrast = 1.15
	GameSettings.settings_path = OS.get_user_data_dir() + "/probe_settings_%d.cfg" % OS.get_process_id()
	var main: Node = await ShotStage.open(self, &"hansan_1592", &"yi_sun_sin")
	for i in 240:
		await process_frame
	var sp := main.get_node("EnemySpawner") as EnemySpawner
	var player := main.get_node("Player") as Player
	player.grant_invulnerability(9999.0)
	sp.active = false
	var zh: ZoneHop = null
	for n in main.find_children("*", "ZoneHop", true, false):
		zh = n
	var st: StageTheme = main.run_config.stage
	if opt != "now":  # 이 판이 실제로 쓰는 look (무대는 캐시 없이 읽혀 따로 있다)
		for l: StageLook in [st.look] + st.zones.map(func(z: ZoneData) -> StageLook: return z.look):
			if l and LOOK_A.has(l.resource_path):
				for k in LOOK_A[l.resource_path]:
					l.set(k, LOOK_A[l.resource_path][k])
			elif l:
				print("LOOK path %s" % l.resource_path)
	var soldier := load("res://data/enemies/waegun_soldier.tres") as EnemyData
	var gunner := load("res://data/enemies/waegun_gunner.tres") as EnemyData
	var heavy := load("res://data/enemies/waegun_heavy.tres") as EnemyData
	for zi in st.zones.size():
		for e in sp.get_children():
			if e is Enemy:
				e.free()
		var z: ZoneData = st.zones[zi]
		zh.plan.current = zi
		zh._apply(z, true)
		player.global_position = z.entry + Vector2(0, -300)
		var at := player.global_position
		var list: Array = []
		for k in 8:
			list.append(sp.spawn_at(soldier, at + Vector2.from_angle(TAU * k / 8.0) * 190.0))
		for k in 4:
			list.append(sp.spawn_at(gunner, at + Vector2(-210 + k * 140, -420)))
		list.append(sp.spawn_at(heavy, at + Vector2(0, 260)))
		for e in list:
			if e:
				(e as Enemy).set_physics_process(false)
				(e as Enemy).target = null
		for i in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_z%d.png" % [out, opt, zi])
		print("SHOT %s zone %d" % [opt, zi])
	quit()
