extends SceneTree
## 강화 패 화면이 한 프레임에 쓰는 그리기 호출 수 (패 화면을 연 프레임 − 닫은 프레임), 영웅 체력 띠 포함 HUD도.
## godot --path . --resolution 720x1280 -s res://tools/probe/card_calls.gd
func _initialize() -> void:
	_run()

func _calls() -> int:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)

func _run() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(720, 1280)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var cards := UpgradeCards.new()
	cards.size = Vector2(720, 1280)
	sv.add_child(cards)
	var hero: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var ups := hero.upgrade_pool.upgrades
	var choice: Array[UpgradeDef] = [ups[0], ups[1], ups[2]]
	var base := await _calls()
	cards.open(choice, false, {})
	cards._age = 1.0
	var with := await _calls()
	print("CARDS draw calls: base=%d with_cards=%d delta=%d" % [base, with, with - base])
	cards.open(choice, true, {})
	cards._age = 1.0
	with = await _calls()
	print("CARDS major: delta=%d" % (with - base))
	quit()
