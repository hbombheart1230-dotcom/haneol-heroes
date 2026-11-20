class_name ResultDrawer
extends RefCounted
## 결과 화면 (하데스 참고): 어둡게 덮고 가운데 옻칠 판, 붓글씨 제목, 기록, 단추 모양 안내.
## 터치 판정은 Main이 한다 (아무 곳 = 다시 시작·이겼으면 다음 전장, 아래 띠 = 영웅 바꾸기, Hud.CHANGE_HERO_BAND).


static func draw(hud: Hud) -> void:
	var s := hud.size
	var state := hud.state
	hud.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.62))
	var victory := state.result == GameState.Result.VICTORY
	var title := ("보스 격파" if state.boss_killed else "생존 성공") if victory else "쓰러졌다"
	var panel := Rect2(s.x * 0.5 - 300.0, s.y * 0.26, 600.0, 470.0)
	UiStyle.panel(hud, panel, UiStyle.LACQUER, UiStyle.GOLD)
	var cx := panel.position.x
	var w := panel.size.x
	UiStyle.text(hud, UiStyle.TITLE_FONT, Vector2(cx, panel.position.y + 110), title, 96,
		UiStyle.GOLD if victory else Color(0.9, 0.3, 0.25), w)
	UiStyle.gold_rule(hud, Vector2(panel.get_center().x, panel.position.y + 145), w * 0.34)
	var stats := "처치 %d   ·   %d:%02d" % [state.kills, floori(state.elapsed / 60.0), floori(state.elapsed) % 60]
	if hud.progress:
		stats = "단계 %d   ·   " % hud.progress.level + stats
	UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, panel.position.y + 205), stats, 30, UiStyle.PAPER, w)
	if hud.stage:
		UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, panel.position.y + 250),
			"%s · %s" % [hud.stage.year_label, hud.stage.title], 22, Color(UiStyle.PAPER, 0.7), w)
	var btn := Rect2(panel.get_center().x - 150.0, panel.end.y - 150.0, 300.0, 84.0)
	if victory and hud.next_stage:
		UiStyle.button(hud, btn, "다음 전장 ›", 42)
		UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, btn.position.y - 16),
			"%s · %s" % [hud.next_stage.year_label, hud.next_stage.title], 22, Color(UiStyle.GOLD, 0.85), w)
	else:
		UiStyle.button(hud, btn, "다시 시작", 42)
	if hud.perf and hud.show_touch_debug:
		UiStyle.text(hud, UiStyle.BODY_FONT, Vector2(cx, panel.end.y - 30), hud.perf.summary(), 18,
			Color(1, 1, 0.6, 0.8), w, Color(0, 0, 0, 0.6), 3)
	if hud.can_change_hero:
		var band := Rect2(0, s.y - Hud.CHANGE_HERO_BAND, s.x, Hud.CHANGE_HERO_BAND)
		var b := Rect2(band.get_center() - Vector2(170, 42), Vector2(340, 84))
		UiStyle.button(hud, b, "영웅 바꾸기", 38)
