class_name StageCardDrawer
extends RefCounted
## 전장 패 하나 (StageSelect가 그린다): 왼쪽 무대 그림(StageTheme.card_art, 없으면 먹 동그라미), 연도·이름·한 줄,
## 오른쪽 상태 도장 — 이김(인주색 도장), 출전(금빛 단추), 잠김(어둡게 + 자물쇠 대신 "잠김"), 곧 열림(이름 없이도 성립).
## 아래 기록 한 줄 (그 영웅의 가장 높은 경지 · 가장 빨리 이긴 시간, GameSettings.stage_records).
## glow ≥ 0이면 처음 하는 사람용으로 패 테두리가 금빛으로 숨 쉬고 "여기서 시작".

const INK_RED := Color(0.66, 0.12, 0.1)


static func draw(c: CanvasItem, r: Rect2, owner: HeroData, player: HeroData, p: CampaignProgress, i: int,
		s: CampaignProgress.State, pressed: bool, glow: float = -1.0) -> void:
	var slot: CampaignSlot = owner.campaign.slots[i]
	var st := p.stage_of(slot.id)
	var lit := s == CampaignProgress.State.OPEN or s == CampaignProgress.State.CLEARED
	if glow >= 0.0:
		for k in 3:
			c.draw_rect(r.grow(4.0 + k * 4.0), Color(UiStyle.GOLD, (0.35 - k * 0.1) * (0.4 + 0.6 * glow)), false, 4.0)
	UiStyle.panel(c, r, UiStyle.LACQUER_RED if pressed and lit else UiStyle.LACQUER, UiStyle.GOLD if lit else UiStyle.GOLD_DIM)
	var art := Rect2(r.position + Vector2(14, 14), Vector2(r.size.y - 28, r.size.y - 28))
	if st and st.card_art:
		var tex := st.card_art
		var ts := tex.get_size()
		var side := minf(ts.x, ts.y)
		var src := Rect2((ts.x - side) * 0.5, (ts.y - side) * 0.5, side, side)
		c.draw_texture_rect_region(tex, art, src, Color(1, 1, 1) if lit else Color(0.32, 0.3, 0.3))
	else:  # 아직 그림 없는 전장: 먹 동그라미
		c.draw_rect(art, Color(0.12, 0.1, 0.09))
		c.draw_arc(art.get_center(), art.size.x * 0.32, 0.0, TAU, 40, Color(Ink.PAPER, 0.18), 10.0)
	c.draw_rect(art, UiStyle.GOLD if lit else UiStyle.GOLD_DIM, false, 2.0)
	var x := art.end.x + 22.0
	var year := st.year_label if st else slot.year_label
	var title := st.title if st else slot.title
	var col := UiStyle.GOLD if lit else Color(UiStyle.PAPER, 0.45)
	UiStyle.text(c, UiStyle.BODY_FONT, Vector2(x, r.position.y + 50), "%d번째 전장%s" % [i + 1, "  ·  " + year if year != "" else ""],
		20, Color(UiStyle.PAPER, 0.7 if lit else 0.4), -1, Color(0, 0, 0, 0.6), 3)
	UiStyle.text(c, UiStyle.TITLE_FONT, Vector2(x, r.position.y + 112), title if title != "" else "· · ·", 50, col, -1)
	if st and st.subtitle != "":
		UiStyle.text(c, UiStyle.BODY_FONT, Vector2(x, r.position.y + 148), st.subtitle.split("\n")[0], 19,
			Color(UiStyle.PAPER, 0.75 if lit else 0.35), -1, Color(0, 0, 0, 0.6), 3)
	var rec := record_line(player, slot.id)
	if rec != "":
		UiStyle.text(c, UiStyle.BODY_FONT, Vector2(x, r.position.y + 182), rec, 19, Color(UiStyle.GOLD, 0.8), -1,
			Color(0, 0, 0, 0.6), 3)
	_draw_state(c, Rect2(r.end.x - 140, r.position.y + 40, 120, r.size.y - 80), s)
	if glow >= 0.0:
		UiStyle.text(c, UiStyle.BODY_FONT, Vector2(r.end.x - 140, r.position.y + 36), "여기서 시작", 20,
			Color(UiStyle.GOLD, 0.6 + 0.4 * glow), 120, Color(0, 0, 0, 0.7), 4)


## 기록 한 줄: "가장 높은 경지 7 · 가장 빨리 3:52" (없으면 "").
static func record_line(player: HeroData, id: StringName) -> String:
	var r: Dictionary = GameSettings.record_of(player.id, id) if player else {}
	if r.is_empty() or int(r.get("level", 0)) <= 0:
		return ""
	var out := "가장 높은 경지 %d" % int(r["level"])
	var t := float(r.get("time", 0.0))
	if t > 0.0:
		out += "  ·  가장 빨리 %d:%02d" % [floori(t / 60.0), floori(t) % 60]
	return out


static func _draw_state(c: CanvasItem, r: Rect2, s: CampaignProgress.State) -> void:
	var ctr := r.get_center()
	match s:
		CampaignProgress.State.CLEARED:  # 인주 도장
			c.draw_rect(Rect2(ctr - Vector2(46, 46), Vector2(92, 92)), Color(INK_RED, 0.9))
			c.draw_rect(Rect2(ctr - Vector2(40, 40), Vector2(80, 80)), Color(Ink.PAPER, 0.85), false, 3.0)
			UiStyle.text(c, UiStyle.TITLE_FONT, ctr + Vector2(-46, 15), "이김", 40, Ink.PAPER, 92, Color(0, 0, 0, 0.0), 0)
		CampaignProgress.State.OPEN:
			UiStyle.button(c, Rect2(ctr - Vector2(60, 34), Vector2(120, 68)), "출전 〉", 32)
		CampaignProgress.State.LOCKED:
			UiStyle.text(c, UiStyle.BODY_FONT, ctr + Vector2(-60, 10), "잠김", 30, Color(UiStyle.PAPER, 0.45), 120,
				Color(0, 0, 0, 0.6), 3)
		CampaignProgress.State.COMING:
			UiStyle.text(c, UiStyle.BODY_FONT, ctr + Vector2(-60, 10), "곧 열림", 26, Color(UiStyle.PAPER, 0.45), 120,
				Color(0, 0, 0, 0.6), 3)
