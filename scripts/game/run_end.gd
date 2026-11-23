class_name RunEnd
extends RefCounted
## 판이 끝났을 때 (Main에서 나눔): 기록 남기기, 결과 화면 단추 ("다시 하기" · "전장 목록") 처리.
## 이기면 그 영웅의 이긴 전장(GameSettings.hero_cleared)에 넣어 다음 전장이 열리고, 처음 이긴 전장이면
## 난이도 단계(hero_clears)가 하나 오른다 (같은 전장을 다시 이겨도 오르지 않는다).


## 판 끝 기록: 이김·경지·시간. 저장까지.
static func record(main: Node, won: bool) -> void:
	var st: StageTheme = main.run_config.stage if main.run_config else null
	var hero: HeroData = main.player.hero if main.player else null
	if st == null or hero == null:
		return
	var level: int = main.progress.level if main.progress else 0
	if won:
		GameSettings.mark_cleared(st.id)
		if GameSettings.mark_hero_cleared(hero.id, st.id):  # 처음 이긴 전장: 다음 전장이 열리고 난이도 단계 +1
			var hid := String(hero.id)
			GameSettings.hero_clears[hid] = int(GameSettings.hero_clears.get(hid, 0)) + 1
	GameSettings.record_run(hero.id, st.id, level, won, main.state.elapsed)
	GameSettings.save_settings()


## 결과 화면에서 누른 곳: &"replay" (같은 전장 다시), &"list" (전장 목록), &"" (아무것도 아님).
static func action_at(view: Vector2, pos: Vector2) -> StringName:
	if ResultDrawer.replay_rect(view).has_point(pos):
		return &"replay"
	if ResultDrawer.list_rect(view).has_point(pos):
		return &"list"
	return &""


## 결과 화면 단추 처리. 무언가 했으면 true.
static func press(main: Node, action: StringName) -> bool:
	match action:
		&"replay":
			if main.run_config and main.run_config.stage:
				GameSettings.stage_id = main.run_config.stage.id
				GameSettings.stage_picked = true
			GameSettings.want_stage_list = false
		&"list":
			GameSettings.back_to_stage_list()
		_:
			return false
	main.restart()
	return true
