class_name UiStyle
extends RefCounted
## 화면 꾸밈 공통 (하데스 참고 → 한국풍): 궁체(덕온공주체) 글자, 옻칠 판 + 금박 테두리.
## 화면 글자는 모두 한글로 쓴다 (영문 표기 없음).
## 글꼴: 국립한글박물관 덕온공주체 (공공누리 제3유형: 출처 표시, 변경 금지 → 원본 파일 그대로 넣는다, 글자 줄이기 금지).
## 제목·본문을 한 글꼴로 쓰지만, 나중에 나눌 수 있게 이름은 둘로 둔다.

const TITLE_FONT := preload("res://assets/fonts/DeogonPrincess.ttf")
const BODY_FONT := TITLE_FONT
## 출처 표시는 "만든 이들" 화면 (CreditsScreen, data/credits/credits.tres).

const LACQUER := Color(0.08, 0.06, 0.06, 0.92)
const LACQUER_RED := Color(0.32, 0.07, 0.06, 0.95)
const GOLD := Color(0.86, 0.68, 0.32)
const GOLD_DIM := Color(0.62, 0.48, 0.24)
const PAPER := Color(0.95, 0.91, 0.82)
const INK := Color(0.09, 0.09, 0.11)
const SEAL := Color(0.75, 0.14, 0.1)


## 옻칠 판: 어두운 바탕 + 금박 겹테두리 + 네 모서리 장식.
static func panel(c: CanvasItem, r: Rect2, fill: Color = LACQUER, border: Color = GOLD) -> void:
	c.draw_rect(r, fill)
	c.draw_rect(r, border, false, 3.0)
	c.draw_rect(r.grow(-7.0), Color(border, 0.45), false, 1.5)
	var k := minf(22.0, minf(r.size.x, r.size.y) * 0.2)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		c.draw_line(corner + Vector2(sx * 4, sy * k), corner + Vector2(sx * 4, sy * 4), border, 3.0)
		c.draw_line(corner + Vector2(sx * 4, sy * 4), corner + Vector2(sx * k, sy * 4), border, 3.0)
		c.draw_circle(corner + Vector2(sx * 10, sy * 10), 2.5, border)


## 금박 단추. pressed면 안쪽이 붉게 차오른다. 단추 글자는 훈민정음풍 본문 글꼴 (사용자 결정, 제목만 붓글씨).
static func button(c: CanvasItem, r: Rect2, label: String, px: int = 38, pressed: bool = false) -> void:
	panel(c, r, LACQUER_RED if pressed else LACQUER, GOLD)
	var size := int(px * 0.85)
	text(c, BODY_FONT, r.position + Vector2(0, r.size.y * 0.5 + size * 0.36), label, size, GOLD, r.size.x)


## 테두리 있는 글자 (가운데 정렬 기본). width < 0이면 왼쪽 정렬.
static func text(c: CanvasItem, font: Font, pos: Vector2, s: String, px: int, col: Color, width: float = -1.0,
		outline: Color = Color(0, 0, 0, 0.75), outline_px: int = 6) -> void:
	var align := HORIZONTAL_ALIGNMENT_LEFT if width < 0.0 else HORIZONTAL_ALIGNMENT_CENTER
	if outline_px > 0:
		c.draw_string_outline(font, pos, s, align, width, px, outline_px, Color(outline, outline.a * col.a))
	c.draw_string(font, pos, s, align, width, px, col)


## 붓으로 그은 가로 금선 (제목 아래 장식).
static func gold_rule(c: CanvasItem, center: Vector2, half_width: float, a: float = 1.0) -> void:
	c.draw_line(center - Vector2(half_width, 0), center + Vector2(half_width, 0), Color(GOLD, 0.8 * a), 2.0)
	c.draw_circle(center, 4.0, Color(GOLD, a))
