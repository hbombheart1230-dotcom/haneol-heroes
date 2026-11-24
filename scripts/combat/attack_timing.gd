class_name AttackTiming
extends RefCounted
## 무기와 피해 시점 맞추기 (타격감 2차 W2, 순수 함수).
## 적: 예고 동안 0 → 맞닿는 프레임 직전까지, 피해 순간 맞닿는 프레임, 회복 동안 나머지 프레임.
## 영웅: 근접 피해를 맞닿는 프레임까지 늦춘다 (지연 = strike / fps, 범위 안으로).


## 적 공격 동작의 지금 프레임. windup_ratio·recover_ratio는 0~1, recovering이면 회복 중.
static func enemy_frame(recovering: bool, windup_ratio: float, recover_ratio: float, strike: int, frames: int) -> int:
	if frames <= 1:
		return 0
	var s := clampi(strike, 0, frames - 1)
	if recovering:
		var rest := frames - s
		return clampi(s + int(recover_ratio * rest), s, frames - 1)
	if s == 0:
		return 0
	return clampi(int(windup_ratio * s), 0, s - 1)


## 영웅 근접 피해 지연(초). override ≥ 0이면 그 값, 아니면 맞닿는 프레임 / fps를 [lo, hi]로.
static func melee_delay(override: float, strike: int, fps: float, lo: float, hi: float) -> float:
	if override >= 0.0:
		return override
	if fps <= 0.0 or strike < 0:
		return lo
	return clampf(strike / fps, lo, hi)


## 시트 칸 px → 월드 오프셋 (스프라이트 위치·배율 적용). 기록이 없으면 fallback.
static func tip_offset(tip_px: Vector2, sprite_pos: Vector2, sprite_scale: Vector2, fallback: Vector2) -> Vector2:
	if tip_px == Vector2.INF:
		return fallback
	return sprite_pos + tip_px * sprite_scale
