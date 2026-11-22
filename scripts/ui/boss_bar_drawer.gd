class_name BossBarDrawer
extends RefCounted
## 화면 위 보스 체력 막대 (Hud가 부른다): 이름, 막대, 방금 깎인 만큼 옅게 남는 자국, 단계 문턱 눈금,
## 지금 단계 점 (●●○), 단계 전환 무적 동안은 막대가 금빛으로 바래 "지금은 안 들어간다"를 보인다.
## 줌 1.09 · 어두운 달빛 바닥에서 읽히게 막대를 두껍게, 테두리와 글자 그림자를 진하게.

const FILL := Color(0.86, 0.2, 0.12)
const FILL_TOP := Color(1.0, 0.62, 0.45, 0.55)
const CHIP := Color(0.98, 0.9, 0.7, 0.85)
const INVULN := Color(0.78, 0.66, 0.4)
const TICK := Color(0.98, 0.84, 0.45)
const BAR_H := 22.0
const PIP_R := 6.0


## chip = 자국이 남은 비율 (Hud가 천천히 줄인다).
static func draw(c: CanvasItem, b: Enemy, chip: float, width: float) -> void:
	var r := Rect2(70, 178, width - 140, BAR_H)
	UiStyle.panel(c, r.grow(8.0), UiStyle.LACQUER, UiStyle.GOLD)
	var pct := b.health.percent()
	if chip > pct:
		c.draw_rect(Rect2(r.position, Vector2(r.size.x * chip, r.size.y)), CHIP)
	var guard := b.phase_invuln > 0.0
	var fill := INVULN if guard else FILL
	if guard:  # 전환 무적: 금빛으로 맥박
		fill = fill.lerp(Color.WHITE, 0.25 + 0.25 * sin(Time.get_ticks_msec() / 90.0))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * pct, r.size.y)), fill)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * pct, 5)), FILL_TOP)
	var phases: Array = b.data.phases if b.data else []
	for ph in phases:
		var x := r.position.x + r.size.x * (ph as BossPhaseData).hp_frac
		var passed := pct <= (ph as BossPhaseData).hp_frac
		var col := Color(TICK, 0.45 if passed else 1.0)
		c.draw_line(Vector2(x, r.position.y - 6), Vector2(x, r.end.y + 6), Color(0, 0, 0, 0.8), 5.0)
		c.draw_line(Vector2(x, r.position.y - 6), Vector2(x, r.end.y + 6), col, 2.5)
	var n := phases.size() + 1
	for i in n:  # 단계 점: 오른쪽 아래, 들어간 단계까지 채움
		var p := Vector2(r.end.x - (n - 1 - i) * (PIP_R * 2.6), r.end.y + 20)
		c.draw_circle(p, PIP_R + 2.0, Color(0, 0, 0, 0.75))
		if i <= b.phase_index:
			c.draw_circle(p, PIP_R, TICK)
		else:
			c.draw_arc(p, PIP_R - 1.0, 0.0, TAU, 16, Color(TICK, 0.7), 2.0)
	var name_text := b.data.display_name if b.data and b.data.display_name != "" else "보스"
	UiStyle.text(c, UiStyle.TITLE_FONT, Vector2(0, r.position.y - 16), name_text, 46, EnemyNameTag.BOSS_COLOR, width,
		Color(0, 0, 0, 0.95), 10)
