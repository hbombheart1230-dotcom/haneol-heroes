class_name LevelBand
extends RefCounted
## HUD 레벨 띠 (Hud가 그린다): 체력 띠 아래 — 왼쪽 레벨 도장 + 경험치 띠, 그 아래 처치 수와 적립 카드 수.
## 오른쪽 위 톱니 단추(SettingsButton, 중심 y 112) 자리는 비운다.
## 점수가 들어오면 띠 끝이 반짝 + 행동 점수는 작은 글씨 ("연타 +2"), 레벨업이면 띠가 번쩍 + 화면 위쪽 붓글씨
## "레벨 업"과 "카드 +1" (싸움을 가리지 않게 위쪽, 1초 남짓). 수묵·한지 톤 (UiStyle·Ink 색).

const TOP := 46.0  # 체력 띠(16~36) 아래
const SEAL_R := 25.0
const BAR_H := 14.0
const GEAR_W := 110.0  # 행동 점수 글씨가 톱니 단추에 닿지 않게
const POP_TIME := 0.7
const LEVEL_TIME := 1.3
const LABELS := {&"combo": "연타", &"evade": "회피", &"counter": "반격", &"charge": "충전"}

var progress: RunProgress
## 떠오르는 점수 글씨: [글, 남은 시간]
var pops: Array = []
var glint: float = 0.0
var level_t: float = 0.0
var card_pulse: float = 0.0
var level_shown: int = 1


func on_scored(kind: StringName, amount: int) -> void:
	glint = 0.35
	if LABELS.has(kind):
		pops.append(["%s +%d" % [LABELS[kind], amount], POP_TIME])
		if pops.size() > 3:
			pops.pop_front()


func on_level_up(level: int) -> void:
	level_t = LEVEL_TIME
	card_pulse = 0.6
	level_shown = level


func on_cards_used() -> void:
	card_pulse = 0.4


func tick(delta: float) -> void:
	glint = maxf(glint - delta, 0.0)
	level_t = maxf(level_t - delta, 0.0)
	card_pulse = maxf(card_pulse - delta, 0.0)
	for p in pops:
		p[1] -= delta
	pops = pops.filter(func(p: Array) -> bool: return p[1] > 0.0)


func bar_rect(width: float) -> Rect2:
	return Rect2(16 + SEAL_R * 2 + 14, TOP + 14, width - (16 + SEAL_R * 2 + 14) - 19, BAR_H)


func draw(c: CanvasItem, width: float, kills: int) -> void:
	if progress == null:
		return
	var r := bar_rect(width)
	# 경험치 띠: 옻칠 바탕 + 금빛 먹 채움 + 금테
	c.draw_rect(r.grow(3.0), UiStyle.LACQUER)
	var fill := Rect2(r.position, Vector2(r.size.x * progress.xp_ratio(), r.size.y))
	c.draw_rect(fill, UiStyle.GOLD)
	c.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 4)), Color(1, 0.95, 0.75, 0.5))
	if glint > 0.0:
		var x := fill.end.x
		c.draw_circle(Vector2(x, r.get_center().y), 10.0 + 14.0 * glint, Color(1, 0.93, 0.6, glint * 1.6))
	if level_t > LEVEL_TIME - 0.45:  # 레벨업 순간 띠 전체가 번쩍
		c.draw_rect(r.grow(4.0), Color(1, 1, 0.9, (level_t - (LEVEL_TIME - 0.45)) / 0.45 * 0.9))
	c.draw_rect(r.grow(3.0), UiStyle.GOLD, false, 2.0)
	_draw_seal(c, Vector2(16 + SEAL_R, r.get_center().y))
	UiStyle.text(c, UiStyle.BODY_FONT, Vector2(r.position.x, r.end.y + 28), "처치 %d" % kills, 20, UiStyle.PAPER, -1,
		Color(0, 0, 0, 0.7), 4)
	_draw_cards(c, Rect2(r.position.x + 96, r.end.y + 6, 90, 34))
	var y := r.end.y + 28.0
	for p in pops:  # 행동 점수: 띠 아래 (톱니 단추 왼쪽)에서 떠오르며 흐려진다
		var k: float = p[1] / POP_TIME
		UiStyle.text(c, UiStyle.BODY_FONT, Vector2(width - GEAR_W - 150, y - (1.0 - k) * 14.0), p[0], 22,
			Color(UiStyle.GOLD, minf(k * 2.0, 1.0)), 150, Color(0, 0, 0, 0.7 * k), 4)
		y += 24.0
	if level_t > 0.0:
		_draw_level_up(c, width)


func _draw_seal(c: CanvasItem, at: Vector2) -> void:
	var pop := 1.0 + 0.35 * clampf((level_t - (LEVEL_TIME - 0.35)) / 0.35, 0.0, 1.0)
	var rr := SEAL_R * pop
	c.draw_circle(at, rr + 3.0, UiStyle.GOLD)
	c.draw_circle(at, rr, Color(0.66, 0.12, 0.1))  # 인주
	UiStyle.text(c, UiStyle.TITLE_FONT, at + Vector2(-rr, rr * 0.42), str(progress.level), int(30 * pop), Ink.PAPER,
		rr * 2.0, Color(0, 0, 0, 0.0), 0)


func _draw_cards(c: CanvasItem, r: Rect2) -> void:
	var n := progress.pending
	var lift := 6.0 * card_pulse
	var card := Rect2(r.position + Vector2(4, 2 - lift), Vector2(22, 28))
	c.draw_rect(card.grow(2.0), UiStyle.GOLD if n > 0 else Color(UiStyle.GOLD_DIM, 0.6))
	c.draw_rect(card, Color(Ink.PAPER, 1.0 if n > 0 else 0.5))
	c.draw_rect(Rect2(card.position + Vector2(4, 5), Vector2(14, 12)), Color(0.66, 0.12, 0.1, 0.8 if n > 0 else 0.3))
	UiStyle.text(c, UiStyle.TITLE_FONT, Vector2(r.position.x + 32, r.position.y + 26), "× %d" % n, 24,
		UiStyle.GOLD if n > 0 else Color(UiStyle.PAPER, 0.6), -1, Color(0, 0, 0, 0.8), 5)


## 화면 위쪽 (시간 표시 아래) 붓글씨 "레벨 업" + "카드 +1": 커지며 나타나 잠깐 머물고 흐려진다. 바탕 띠 없이 글씨만 (싸움을 덜 가리게).
func _draw_level_up(c: CanvasItem, width: float) -> void:
	var t := LEVEL_TIME - level_t
	var a := clampf(t / 0.12, 0.0, 1.0) * clampf(level_t / 0.35, 0.0, 1.0)
	var s := 1.0 + 0.25 * maxf(1.0 - t / 0.18, 0.0)
	var y := 210.0
	for i in 3:  # 먹이 번진 듯한 옅은 바탕 (가운데만, 가장자리로 갈수록 옅게)
		var w := 460.0 - i * 90.0
		c.draw_rect(Rect2(width * 0.5 - w * 0.5, y - 58 + i * 6, w, 96 - i * 12), Color(Ink.INK, 0.16 * a))
	UiStyle.text(c, UiStyle.TITLE_FONT, Vector2(0, y), "레벨 업", int(64 * s), Color(UiStyle.GOLD, a), width,
		Color(0, 0, 0, 0.9 * a), 8)
	UiStyle.text(c, UiStyle.BODY_FONT, Vector2(0, y + 38), "카드 +1  ·  다음 숨 고르기에서 고른다", 22,
		Color(UiStyle.PAPER, a), width, Color(0, 0, 0, 0.8 * a), 4)
