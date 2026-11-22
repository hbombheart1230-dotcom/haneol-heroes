extends SceneTree
## 레벨업 강화 카드 화면을 영웅마다 찍는다: 일반 강화는 셋씩, 큰 변형도 셋씩 (모든 강화 그림이 한 번씩 나온다).
## godot --path . --resolution 720x1280 -s res://tools/shots/upgrade_cards_shot.gd -- <출력 폴더>
## 출력: <영웅>_<n>.png, <영웅>_major_<n>.png

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


func _initialize() -> void:
	_run()


var sv: SubViewport


func _shot(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(path)


func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://"
	sv = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.42, 0.34)
	bg.size = Vector2(720, 1280)
	sv.add_child(bg)
	var cards := UpgradeCards.new()
	cards.size = Vector2(720, 1280)
	sv.add_child(cards)
	await process_frame
	for key: String in HEROES:
		var hero: HeroData = load("res://data/heroes/%s.tres" % key)
		for major in [false, true]:
			var pool: UpgradePool = hero.major_pool if major else hero.upgrade_pool
			var ups := pool.upgrades
			var page := 0
			for i in range(0, ups.size(), 3):
				var choice: Array[UpgradeDef] = []
				for j in range(i, mini(i + 3, ups.size())):
					choice.append(ups[j])
				if choice.size() < 3 and ups.size() >= 3:  # 마지막 쪽도 카드 셋 (앞에서 채운다)
					for j in range(0, 3 - choice.size()):
						choice.push_front(ups[i - 1 - j])
				var stacks := {choice[0].id: 1}
				cards.open(choice, major, stacks)
				cards._age = 1.0
				await _shot(dir.path_join("%s%s_%d.png" % [key, "_major" if major else "", page]))
				page += 1
	quit()
