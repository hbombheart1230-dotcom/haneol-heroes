class_name UpgradeCardLayout
extends RefCounted
## 강화 패 한 장의 글 자리 (순수 계산): 줄마다 글·글꼴·크기·색과 실제 글자 상자(Rect2)를 위에서부터 쌓는다.
## 글씨는 줄이지 않는다. 값 줄이 많으면 패가 길어지고(UpgradeCards가 needed_height로 키움),
## "지금 → 뒤"가 패 폭보다 넓으면 "지금" / "→ 뒤" 두 줄로 나눈다. 단계 글("새 강화")은 패 맨 아래.

enum Role { BAND, SKILL, NAME, DESC, LABEL, VALUE, LEVEL }


## 한 줄: 화면 글 그리기와 겹침 시험이 같은 값을 쓴다.
static func row(role: Role, text: String, font: Font, px: int, col: Color, left: float, width: float, base: float) -> Dictionary:
	var sw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var box := Rect2(left + (width - sw) * 0.5, base - font.get_ascent(px), sw, font.get_ascent(px) + font.get_descent(px))
	return {"role": role, "text": text, "font": font, "px": px, "color": col, "pos": Vector2(left, base), "width": width,
		"box": box}


## 아이콘 가운데와 한 변 (패 r 안).
static func icon_rect(c: UpgradeCards, r: Rect2) -> Rect2:
	var s := minf(r.size.x - 60.0, 140.0)
	var center := Vector2(r.get_center().x, r.position.y + c.band_height + 82.0)
	return Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s))


## 패 i장의 글 줄들 (r = 패 자리). 띠 글은 빼고 (띠 상자 안에 따로 그림).
static func rows(c: UpgradeCards, u: UpgradeDef, r: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var w := r.size.x
	var x := r.position.x
	var st := {"y": icon_rect(c, r).end.y + c.icon_gap}  # 람다는 지역 변수를 복사하므로 사전으로 쌓는 자리를 넘긴다
	var parts := u.title.split(" · ")
	var add := func(role: Role, text: String, font: Font, px: int, col: Color, gap_after: float) -> void:
		var base: float = st["y"] + font.get_ascent(px)
		out.append(row(role, text, font, px, col, x, w, base))
		st["y"] = base + font.get_descent(px) + gap_after
	if parts.size() > 1:  # "기술 · 강화 이름": 기술 이름은 본문 글꼴, 강화 이름만 붓글씨
		add.call(Role.SKILL, parts[0], UiStyle.BODY_FONT, c.skill_px, UiStyle.PAPER, c.row_gap)
	for line in UpgradeCards.wrap_lines(UiStyle.TITLE_FONT, parts[-1], c.name_px, w - 20.0, 2):
		add.call(Role.NAME, line, UiStyle.TITLE_FONT, c.name_px, UiStyle.GOLD, c.row_gap)
	st["y"] += c.block_gap
	var vals := c.values_of(u)
	if vals.is_empty():
		for line in UpgradeCards.wrap_lines(UiStyle.BODY_FONT, u.description.replace("\n", " "), c.desc_px, w - 24.0, 3):
			add.call(Role.DESC, line, UiStyle.BODY_FONT, c.desc_px, UiStyle.PAPER, c.row_gap)
	for v in vals:  # 값 이름은 작게, "지금 → 뒤"는 크게 금색
		add.call(Role.LABEL, v["label"], UiStyle.BODY_FONT, c.value_label_px, UiStyle.PAPER, c.row_gap)
		var both := "%s → %s" % [v["from"], v["to"]]
		var room := w - c.side_pad * 2.0
		if UiStyle.BODY_FONT.get_string_size(both, HORIZONTAL_ALIGNMENT_LEFT, -1, c.value_px).x <= room:
			add.call(Role.VALUE, both, UiStyle.BODY_FONT, c.value_px, UiStyle.GOLD, c.value_gap)
		else:  # 넓은 숫자: 글씨를 줄이지 않고 두 줄로
			add.call(Role.VALUE, String(v["from"]), UiStyle.BODY_FONT, c.value_px, UiStyle.GOLD, c.row_gap)
			add.call(Role.VALUE, "→ %s" % v["to"], UiStyle.BODY_FONT, c.value_px, UiStyle.GOLD, c.value_gap)
	var lv := c.level_text(u)
	if lv != "":
		var have := int(c.stacks.get(u.id, 0))
		var base := r.end.y - c.bottom_pad - UiStyle.BODY_FONT.get_descent(c.level_px)
		out.append(row(Role.LEVEL, lv, UiStyle.BODY_FONT, c.level_px, UiStyle.PAPER if have > 0 else UiStyle.GOLD, x, w,
			base))
	return out


## 이 패의 글이 다 들어가는 높이 (단계 글 위로 level_gap만큼 띄움).
static func needed_height(c: UpgradeCards, u: UpgradeDef, width: float) -> float:
	var r := Rect2(0, 0, width, 10000.0)
	var bottom := 0.0
	for it in rows(c, u, r):
		if it["role"] != Role.LEVEL:
			bottom = maxf(bottom, (it["box"] as Rect2).end.y)
	var lv_h := UiStyle.BODY_FONT.get_height(c.level_px) if c.level_text(u) != "" else 0.0
	return bottom + c.level_gap + lv_h + c.bottom_pad
