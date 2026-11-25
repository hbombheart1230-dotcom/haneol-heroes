extends SceneTree
## 모든 강화 패 (네 영웅 보통 패 전부 + 큰 변형) 를 셋씩 S20 화면(1080×2400)에 띄워 찍는다.
## 두 번: 처음 고를 때(0단계), 모두 최고 단계 바로 앞까지 올린 뒤(큰 숫자). 패마다 값 줄 수를 찍어 낸다.
## godot --path . -s res://tools/shots/card_all_shot.gd -- <출력 폴더> [접두사]

const HEROES := [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]

var out := "user://cards_all"
var prefix := ""
var sv: SubViewport
var cur: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		prefix = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	sv = SubViewport.new()
	sv.size = Vector2i(1080, 2400)
	sv.size_2d_override = Vector2i(720, 1600)
	sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	_run()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out.path_join(prefix + name + ".png"))


func _open(hero: StringName) -> Node:
	GameSettings.hero_id = hero
	GameSettings.save_settings()
	if cur:
		paused = false
		cur.free()
	cur = load("res://scenes/main.tscn").instantiate()
	sv.add_child(cur)
	await _wait(5)
	cur.player.health.damageable = false
	return cur


func _page(m: Node, pick: Array[UpgradeDef], major: bool, stacks: Dictionary, name: String) -> void:
	m.seal_choice.open(pick, m.player.global_position, major, stacks)
	m.seal_choice.cards._age = 1.0
	for u in pick:
		var n := UpgradeReadout.lines(u, m.build, m.seal_choice.cards.steps_of(u)).size() if not major else 0
		print("%s %s values=%d" % [name, u.id, n])
	await _shot(name)
	m.seal_choice.close()


func _pages(m: Node, ups: Array, major: bool, stacks: Dictionary, tag: String) -> void:
	var i := 0
	while i < ups.size():
		var pick: Array[UpgradeDef] = []
		for j in 3:
			pick.append(ups[(i + j) % ups.size()])
		await _page(m, pick, major, stacks, "%s_%02d" % [tag, i / 3])
		i += 3


func _run() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = true
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.want_stage_list = false
	GameSettings.story_enabled = false
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false
	for h in HEROES:
		var m := await _open(h)
		var ups: Array = m.build.hero.upgrade_pool.upgrades
		await _pages(m, ups, false, {}, String(h) + "_new")
		var stacks := {}
		for u in ups:  # 최고 단계 바로 앞까지 올려 숫자를 키운다
			for s in maxi(u.max_stacks - 1, 0):
				m.build.apply(u)
			stacks[u.id] = maxi(u.max_stacks - 1, 0)
		await _pages(m, ups, false, stacks, String(h) + "_high")
		await _pages(m, m.build.hero.major_pool.upgrades, true, {}, String(h) + "_major")
	quit()
