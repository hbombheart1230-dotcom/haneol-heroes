class_name CastAnim
extends RefCounted
## 기술 시전 동작 고르기 (순수 계산, PlayerView가 쓴다): 기술 데이터의 cast_anim을 영웅 시트에서 찾아
## 어느 칸부터 몇 초 동안 틀지 정한다. 피해는 누르는 순간 나가므로 맞닿는 칸 바로 앞에서 시작한다.

## 시트에 없을 때 대신 트는 동작과 길이(초) (예전 그대로).
const FALLBACK := "attack"
const FALLBACK_TIME := 0.35

var anim: String = FALLBACK
## 시작 칸, 재생 시간(초), 재생 속도 배율.
var from: int = 0
var seconds: float = FALLBACK_TIME
var speed: float = 1.0


## def의 시전 동작 (sheet가 없거나 동작이 없으면 attack 0.35초).
static func of(def: SkillDef, sheet: SpriteSheetSet) -> CastAnim:
	var c := CastAnim.new()
	if def == null or sheet == null or def.cast_anim == &"" or not sheet.has_anim(String(def.cast_anim)):
		return c
	c.anim = String(def.cast_anim)
	c.speed = maxf(def.cast_speed, 0.05)
	var i := sheet.anim_names.find(c.anim)
	var fps := (sheet.fps[i] if i < sheet.fps.size() else 12.0) * c.speed
	var n := sheet.frame_count(c.anim)
	c.from = start_frame(sheet.strike_frame(c.anim), fps, def.cast_lead, n)
	c.seconds = (n - c.from) / maxf(fps, 1.0)
	return c


## 맞닿는 칸(strike)에서 lead초 앞 칸. lead < 0이거나 맞닿는 칸을 모르면 첫 칸.
static func start_frame(strike: int, fps: float, lead: float, frames: int) -> int:
	if lead < 0.0 or strike < 0:
		return 0
	return clampi(strike - ceili(lead * fps - 0.001), 0, maxi(frames - 1, 0))


## 충전 중 붙잡을 모으는 자세 (없으면 ""): 충전 기술의 시전 동작 첫 칸.
static func charge_pose(def: SkillDef, sheet: SpriteSheetSet) -> String:
	if def == null or sheet == null or not def.charge_pose or def.cast_anim == &"":
		return ""
	return String(def.cast_anim) if sheet.has_anim(String(def.cast_anim)) else ""
