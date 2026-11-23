class_name ChargeScaling
extends Resource
## 충전 기술 공통 (순수 데이터 + 계산): 모은 시간 c(0~1)에 따라 피해·크기·사거리·넉백·연출이 커진다.
## 기술 자신의 최소·최대 값(피해·크기, 강화가 바꾸는 값)은 기술에 두고 이 곡선으로 잇는다 (between).
## 여기 있는 값은 Vector2(바로 놓음, 다 모음). 곡선은 curve(있으면) 또는 c^exponent.
## 단계(stages): 모으는 동안 눈에 보이고 소리 나는 마디 (위력은 이어서 커진다). 다 모으면 full_bonus를 더 곱한다.
## 기술마다 SkillDef에 붙여 쓴다 (지금은 순신 해일검기만).

## 모은 비율 → 위력 비율 곡선 (0~1 → 0~1). 비면 c^exponent.
@export var curve: Curve
## 1보다 크면 끝으로 갈수록 가파르다 (덜 모은 것은 약하고, 다 모아야 세다).
@export var exponent: float = 1.5
## 눈에 보이는 마디 수 (표시 눈금·마디 소리). 1이면 다 모았을 때만.
@export var stages: int = 3
## 사거리 배율 (수명 × 이 값).
@export var reach: Vector2 = Vector2(0.75, 1.15)
## 넉백 (px/s, 0이면 없음).
@export var knockback: Vector2 = Vector2(60, 280)
## 연출 배율 (맞은 자리 이펙트·화면 흔들림).
@export var fx: Vector2 = Vector2(0.8, 1.5)
## 다 모았을 때 피해에 더 곱하는 값 (다 모은 보상).
@export var full_bonus: float = 1.0


## 위력 비율 0~1.
func k(c: float) -> float:
	c = clampf(c, 0.0, 1.0)
	if curve:
		return clampf(curve.sample_baked(c), 0.0, 1.0)
	return pow(c, maxf(exponent, 0.01))


func at(range_v: Vector2, c: float) -> float:
	return lerpf(range_v.x, range_v.y, k(c))


## 기술의 최소·최대 값을 곡선으로 잇는다.
func between(lo: float, hi: float, c: float) -> float:
	return lerpf(lo, hi, k(c))


## 피해: 기술의 최소·최대 피해를 곡선으로, 다 모았으면 full_bonus배.
func damage_at(lo: int, hi: int, c: float) -> int:
	return maxi(roundi(between(lo, hi, c) * (full_bonus if is_full(c) else 1.0)), 1)


func is_full(c: float) -> bool:
	return c >= 0.999


## 지금 넘어선 마디 수 (0 ~ stages). 마지막 마디 = 다 모음.
func stage_of(c: float) -> int:
	var n := maxi(stages, 1)
	if is_full(c):
		return n
	return clampi(floori(clampf(c, 0.0, 1.0) * n), 0, n - 1)
