class_name ResultDrawer
extends RefCounted
## 결과 화면 (하데스 참고): 어둡게 덮고 가운데 옻칠 판, 붓글씨 제목, 기록, 단추 모양 안내.
## 단추 둘: "다시 하기" (같은 전장), "전장 목록" (그 영웅의 전장 고르기). 터치 판정은 RunEnd.action_at.


static func draw(hud: Hud) -> void:
	var s := hud.size
	var state := hud.state
	hud.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.62))
	var victory := state.result == GameState.Result.VICTORY
	var title := ("우두머리 격파" if state.boss_killed else "생존 성공") if victory else "쓰러졌다"
	var panel := _panel(s)
	UiStyle.panel(hud, panel, UiStyle.LACQUER, UiStyle.GOLD)
	var cx := panel.position.x
	var w := panel.size.x
	UiStyle.text(hud, UiStyle.TITLE_FONT, Vector2(cx, panel.position.y + 110), title, 96,
		UiStyle.GOLD if victory else Color(0.9, 0.3, 0.25), w)
	UiStyle.gold_rule(hud, Vector2(panel.get_center().x, panel.position.y + 145), w * 0.34)
	var stats := "처치 %d   ·   %d:%02d" % [state.kills, floori(state.elapsed / 60.0), floori(state.elapsed) % 60]
	if hud.progress:
		stats = "경지 %d   ·   " % hud.progress.level + stats
	UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, panel.position.y + 205), stats, 30, UiStyle.PAPER, w)
	if hud.stage:
		UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, panel.position.y + 250),
			"%s · %s" % [hud.stage.year_label, hud.stage.title], 22, Color(UiStyle.PAPER, 0.7), w)
	UiStyle.button(hud, replay_rect(s), "다시 하기", 36)
	UiStyle.button(hud, list_rect(s), "전장 목록", 36)
	if victory and hud.stage:
		UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, panel.end.y - 170), "전장 목록에서 다음 전장이 열렸다", 22,
			Color(UiStyle.GOLD, 0.85), w)
	if hud.perf and hud.show_touch_debug and GameSettings.show_stats:
		UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, panel.end.y - 30), hud.perf.summary(), 18,
			Color(1, 1, 0.6, 0.8), w, Color(0, 0, 0, 0.6), 3)


## 결과 판 위쪽 끝 y (영웅 대사가 판을 가리지 않게 그 위에 뜬다).
static func panel_top(view: Vector2) -> float:
	return _panel(view).position.y


static func _panel(view: Vector2) -> Rect2:
	return Rect2(view.x * 0.5 - 300.0, view.y * 0.26, 600.0, 470.0)


## "다시 하기" 단추 (결과 판 아래 왼쪽).
static func replay_rect(view: Vector2) -> Rect2:
	var p := _panel(view)
	return Rect2(p.position.x + 30.0, p.end.y - 140.0, 255.0, 84.0)


## "전장 목록" 단추 (결과 판 아래 오른쪽, 엄지 쪽).
static func list_rect(view: Vector2) -> Rect2:
	var p := _panel(view)
	return Rect2(p.end.x - 285.0, p.end.y - 140.0, 255.0, 84.0)
