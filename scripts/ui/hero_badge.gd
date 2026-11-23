class_name HeroBadge
extends RefCounted
## 왼쪽 위 구석의 영웅 묶음 (Hud가 그린다, 사용자 선택 (다)): 위에서부터 둥근 초상(HeroData.portrait,
## 지금 모델과 같은 얼굴) + 그 둘레를 도는 공력(경험치) 고리 + 초상에 겹친 경지 도장, 그 아래 체력 띠, 적립한 패와 처치 수,
## 행동 점수 글씨("연타 +2"), 경지가 오르면 "경지 오름"·"패 +1". 위쪽 가운데는 우두머리 띠 전용으로 비운다
## (BossBarDrawer.TOP_FREE), 시간은 톱니 단추 아래 (Hud). 맞으면 초상이 붉게 번쩍·흔들린다.
## 화면 글씨에 외래어를 쓰지 않는다 (레벨 → 경지, 카드 → 패, 보스 → 우두머리).

const R := 50.0  # 초상 반지름
const HP_W := 230.0
const HP_H := 18.0
const POP_TIME := 0.7
const LEVEL_TIME := 1.3
const LABELS := {&"combo": "연타", &"evade": "회피", &"counter": "반격", &"charge": "충전"}

var progress: RunProgress
var player: Player
var pops: Array = []
var glint: float = 0.0
var level_t: float = 0.0
var card_pulse: float = 0.0
var hurt_t: float = 0.0
var _last_hp: int = -1
## 초상 원 (가운데 0 기준 꼭짓점과 UV). 처음 그릴 때 한 번 만든다.
var _circle_pts := PackedVector2Array()
var _circle_uvs := PackedVector2Array()


func on_scored(kind: StringName, amount: int) -> void:
	glint = 0.35
	if LABELS.has(kind):
		pops.append(["%s +%d" % [LABELS[kind], amount], POP_TIME])
		if pops.size() > 3:
			pops.pop_front()


func on_level_up(_level: int) -> void:
	level_t = LEVEL_TIME
	card_pulse = 0.6


func on_cards_used() -> void:
	card_pulse = 0.4


func tick(delta: float) -> void:
	glint = maxf(glint - delta, 0.0)
	level_t = maxf(level_t - delta, 0.0)
	card_pulse = maxf(card_pulse - delta, 0.0)
	hurt_t = maxf(hurt_t - delta, 0.0)
	for p in pops:
		p[1] -= delta
	pops = pops.filter(func(p: Array) -> bool: return p[1] > 0.0)
	if player and player.health:
		var hp := player.health.current
		if _last_hp >= 0 and hp < _last_hp:
			hurt_t = 0.45
		_last_hp = hp


const ORIGIN := Vector2(20 + 50.0, 22 + 50.0)  # 초상 중심 (R = 50)


func draw(c: CanvasItem, kills: int) -> void:
	var ctr := ORIGIN
	if hurt_t > 0.0:  # 맞음: 흔들림
		ctr += Vector2(sin(hurt_t * 70.0), cos(hurt_t * 55.0)) * 5.0 * (hurt_t / 0.45)
	_draw_portrait(c, ctr)
	var x := 20.0
	var hp_r := Rect2(x, ORIGIN.y + R + 18, R * 2 + 30, HP_H)
	_draw_health(c, hp_r)
	if progress == null:
		return
	_draw_cards(c, Vector2(x, hp_r.end.y + 8))
	UiStyle.text(c, UiStyle.BODY_FONT, Vector2(x + 86, hp_r.end.y + 30), "처치 %d" % kills, 20, UiStyle.PAPER, -1,
		Color(0, 0, 0, 0.7), 4)
	var y := hp_r.end.y + 62.0
	for p in pops:  # 행동 점수: 묶음 아래에서 떠오르며 흐려진다
		var k: float = p[1] / POP_TIME
		UiStyle.text(c, UiStyle.BODY_FONT, Vector2(x, y - (1.0 - k) * 14.0), p[0], 22,
			Color(UiStyle.GOLD, minf(k * 2.0, 1.0)), -1, Color(0, 0, 0, 0.7 * k), 4)
		y += 24.0
	if level_t > 0.0:
		_draw_level_up(c, Vector2(x, hp_r.end.y + 130.0))


func _draw_portrait(c: CanvasItem, ctr: Vector2) -> void:
	c.draw_circle(ctr, R + 9.0, UiStyle.LACQUER)
	if progress:  # 공력(경험치) 고리
		c.draw_arc(ctr, R + 5.0, 0.0, TAU, 48, Color(UiStyle.GOLD_DIM, 0.35), 6.0)
		c.draw_arc(ctr, R + 5.0, -PI / 2, -PI / 2 + TAU * progress.xp_ratio(), 48, UiStyle.GOLD, 6.0)
		if glint > 0.0:
			var a := -PI / 2 + TAU * progress.xp_ratio()
			c.draw_circle(ctr + Vector2(cos(a), sin(a)) * (R + 5.0), 6.0 + 10.0 * glint, Color(1, 0.93, 0.6, glint * 1.6))
	var hero := player.hero if player else null
	if hero and hero.portrait:
		_build_circle()
		c.draw_circle(ctr, R, hero.body_color.darkened(0.55))  # 투명한 바탕 자리는 영웅 색으로
		c.draw_set_transform(ctr)  # 원 꼭짓점은 한 번만 만들고 자리만 옮겨 그린다
		c.draw_polygon(_circle_pts, PackedColorArray([Color.WHITE]), _circle_uvs, hero.portrait)
		c.draw_set_transform(Vector2.ZERO)
	else:
		c.draw_circle(ctr, R, hero.body_color if hero else Color(0.3, 0.3, 0.3))
	if hurt_t > 0.0:
		c.draw_circle(ctr, R, Color(0.9, 0.1, 0.05, 0.5 * hurt_t / 0.45))
	if level_t > LEVEL_TIME - 0.45:
		var f := (level_t - (LEVEL_TIME - 0.45)) / 0.45  # 경지 오름: 얼굴은 가리지 않고 테두리만 금빛으로 번쩍
		c.draw_arc(ctr, R + 6.0, 0.0, TAU, 48, Color(1, 0.95, 0.7, f), 6.0 + 10.0 * f)
		c.draw_circle(ctr, R, Color(1, 0.95, 0.7, 0.25 * f))
	c.draw_arc(ctr, R + 9.0, 0.0, TAU, 48, UiStyle.GOLD, 2.5)
	if progress:  # 경지 도장 (초상 오른쪽 아래)
		var pop := 1.0 + 0.35 * clampf((level_t - (LEVEL_TIME - 0.35)) / 0.35, 0.0, 1.0)
		var s := ctr + Vector2(R * 0.72, R * 0.72)
		var rr := 19.0 * pop
		c.draw_circle(s, rr + 2.5, UiStyle.GOLD)
		c.draw_circle(s, rr, Color(0.66, 0.12, 0.1))
		UiStyle.text(c, UiStyle.TITLE_FONT, s + Vector2(-rr, rr * 0.45), str(progress.level), int(24 * pop), Ink.PAPER,
			rr * 2.0, Color(0, 0, 0, 0.0), 0)


func _draw_health(c: CanvasItem, r: Rect2) -> void:
	if player == null or player.health == null:
		return
	c.draw_rect(r.grow(3.0), UiStyle.LACQUER)
	var pct := player.health.percent()
	var fill := Rect2(r.position, Vector2(r.size.x * pct, r.size.y))
	c.draw_rect(fill, Color(0.72, 0.13, 0.12) if hurt_t <= 0.0 else Color(1.0, 0.45, 0.3))
	c.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 5)), Color(1, 0.55, 0.45, 0.45))
	c.draw_rect(r.grow(3.0), UiStyle.GOLD, false, 2.0)
	UiStyle.text(c, UiStyle.BODY_FONT, Vector2(r.position.x + 6, r.end.y - 2), "%d" % player.health.current, 16,
		Ink.PAPER, -1, Color(0, 0, 0, 0.8), 3)


func _draw_cards(c: CanvasItem, at: Vector2) -> void:
	var n := progress.pending
	var card := Rect2(at + Vector2(2, -6.0 * card_pulse), Vector2(20, 26))
	c.draw_rect(card.grow(2.0), UiStyle.GOLD if n > 0 else Color(UiStyle.GOLD_DIM, 0.6))
	c.draw_rect(card, Color(Ink.PAPER, 1.0 if n > 0 else 0.5))
	c.draw_rect(Rect2(card.position + Vector2(4, 5), Vector2(12, 11)), Color(0.66, 0.12, 0.1, 0.8 if n > 0 else 0.3))
	UiStyle.text(c, UiStyle.TITLE_FONT, at + Vector2(30, 22), "× %d" % n, 24,
		UiStyle.GOLD if n > 0 else Color(UiStyle.PAPER, 0.6), -1, Color(0, 0, 0, 0.8), 5)


## 묶음 아래 붓글씨 "경지 오름" + "패 +1 · 다음 숨 고르기에서 고른다" (싸움 한가운데를 가리지 않게 구석 가까이).
func _draw_level_up(c: CanvasItem, at: Vector2) -> void:
	var t := LEVEL_TIME - level_t
	var a := clampf(t / 0.12, 0.0, 1.0) * clampf(level_t / 0.35, 0.0, 1.0)
	var s := 1.0 + 0.25 * maxf(1.0 - t / 0.18, 0.0)
	UiStyle.text(c, UiStyle.TITLE_FONT, at, "경지 오름", int(48 * s), Color(UiStyle.GOLD, a), -1, Color(0, 0, 0, 0.9 * a), 7)
	UiStyle.text(c, UiStyle.BODY_FONT, at + Vector2(4, 30), "패 +1 · 다음 숨 고르기에서 고른다", 22, Color(UiStyle.PAPER, a), -1,
		Color(0, 0, 0, 0.8 * a), 4)


func _build_circle() -> void:
	if not _circle_pts.is_empty():
		return
	for i in 40:
		var d := Vector2.from_angle(TAU * i / 40.0)
		_circle_pts.append(d * R)
		_circle_uvs.append(Vector2(0.5, 0.5) + d * 0.5)
