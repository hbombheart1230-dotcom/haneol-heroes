extends SceneTree
## 강화 패 고르기 화면 (1080×2400, 실제 판 위): 네 영웅 패 셋(누르기·내닫기·모으기 하나씩), 순신 큰 변형 셋.
## 뒤 판에는 연타 글씨·피해 숫자·영웅 대사를 띄운 채로 연다 (패 화면이 이것들을 가리는지).
## godot --path . -s res://tools/shots/card_screen_shot.gd -- <출력 폴더> [접두사]

const HEROES := [&"yi_sun_sin", &"gwanggaeto", &"sejong", &"shin_saimdang"]

var out := "user://cards"
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
	print("shot ", name)


## 한 영웅의 판을 열고, 싸우던 글자를 띄운 뒤 패 화면을 연다.
func _open(hero: StringName, major: bool) -> void:
	GameSettings.hero_id = hero
	GameSettings.save_settings()
	if cur:
		paused = false
		cur.free()
	cur = load("res://scenes/main.tscn").instantiate()
	sv.add_child(cur)
	await _wait(5)
	var m := cur
	m.player.health.damageable = false
	m.state.elapsed = 20.0
	var combo: ComboCounter = m.get_node("HUD/ComboCounter")
	combo.add_hits(9)
	var p: Vector2 = m.player.global_position
	if Feedback.instance and Feedback.instance.fx:
		for i in 4:
			Feedback.instance.fx.add_number(p + Vector2(60 + i * 40, -80 - i * 20), 37 + i * 11, i % 3)
	m.hero_lines.say(HeroLines.Case.ENTER_OWN)
	await _wait(2)
	var pool: UpgradePool = m.build.hero.major_pool if major else m.build.hero.upgrade_pool
	var ups := pool.upgrades
	var pick: Array[UpgradeDef] = []
	if major:
		pick = [ups[0], ups[1], ups[2]]
	else:
		var seen := {}
		for u in ups:  # 기술마다 하나씩 (누르기·내닫기·모으기)
			var slot: StringName = u.mods[0].target if not u.mods.is_empty() else &""
			if slot in [&"tap", &"dash", &"charge"] and not seen.has(slot):
				seen[slot] = true
				pick.append(u)
	var stacks := {pick[0].id: 1}
	for u in pick:
		if int(stacks.get(u.id, 0)) > 0:
			m.build.apply(u)
	m.seal_choice.open(pick, p, major, stacks)
	m.seal_choice.cards._age = 1.0


func _run() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = true
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.want_stage_list = false
	GameSettings.story_enabled = true
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.stage_picked = false
	for h in HEROES:
		await _open(h, false)
		await _shot("cards_" + String(h))
	await _open(&"yi_sun_sin", true)
	await _shot("cards_major_yi_sun_sin")
	quit()
