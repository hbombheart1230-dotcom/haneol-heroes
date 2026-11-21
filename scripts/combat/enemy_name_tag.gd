class_name EnemyNameTag
extends RefCounted
## 네임드(정예·보스) 머리 위 이름표: 적 이름(정예 금빛, 보스 붉은 금빛) + 그 위에 변종 이름(철갑·질풍 등).
## 보통 적은 이름을 그리지 않는다. Enemy._draw에서 부른다.

const NAME_PX := 28
const BOSS_PX := 34
const AFFIX_PX := 22
const BOSS_COLOR := Color(1.0, 0.55, 0.35)


static func shows_name(e: Enemy) -> bool:
	return e.data != null and (e.data.is_elite or e.data.is_boss) and e.data.display_name != ""


static func draw(e: Enemy) -> void:
	var y := -e.body_radius * 3.2 - 10.0  # 체력 막대(EnemyBars) 바로 위
	if shows_name(e):
		var boss := e.data.is_boss
		var px := BOSS_PX if boss else NAME_PX
		UiStyle.text(e, UiStyle.TITLE_FONT, Vector2(-180, y), e.data.display_name, px,
			BOSS_COLOR if boss else UiStyle.GOLD, 360.0, Color(0, 0, 0, 0.9), 8)
		y -= px + 4.0
	if e.affix and e.affix.label != "":
		UiStyle.text(e, UiStyle.TITLE_FONT, Vector2(-60, y), e.affix.label, AFFIX_PX, e.affix.rim_color, 120.0,
			Color(0, 0, 0, 0.75), 5)
