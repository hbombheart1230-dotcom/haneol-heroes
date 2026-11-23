class_name DashLook
extends RefCounted
## 내닫기 생김새 판정 (순수, DashLookData): 지금 대시가 치는 내닫기인지 피하는 내닫기인지와 붙잡을 자세.
## 치는 내닫기 = 돌진 타격이 있는 대시 (Player.dash_strikes, DashDirection.begin이 정한다), 그 밖은 모두 피하는 내닫기.


static func data(p: Player) -> DashLookData:
	return p.hero.dash_look if p and p.hero else null


static func is_strike(p: Player) -> bool:
	return data(p) != null and p.is_dashing() and p.dash_strikes


static func is_evade(p: Player) -> bool:
	return data(p) != null and p.is_dashing() and not p.dash_strikes


## 대시 중 그림 [동작, 칸] (시트에 없으면 [dash, -1], 생김새 데이터가 없으면 빈 배열 = 예전 그대로).
static func pose(p: Player, sheet: SpriteSheetSet) -> Array:
	var d := data(p)
	if d == null or sheet == null:
		return []
	var want: Array = d.pose(p.dash_strikes)
	if not sheet.has_anim(String(want[0])):
		return ["dash", -1]
	return [String(want[0]), clampi(int(want[1]), -1, sheet.frame_count(String(want[0])) - 1)]


## 붙잡을 칸 (-1 = 붙잡지 않음).
static func pose_frame(p: Player, sheet: SpriteSheetSet) -> int:
	if not p.is_dashing():
		return -1
	var po := pose(p, sheet)
	return int(po[1]) if po.size() == 2 else -1
