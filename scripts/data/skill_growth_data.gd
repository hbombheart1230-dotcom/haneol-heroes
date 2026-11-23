class_name SkillGrowthData
extends Resource
## 강화할수록 기술 모습이 단계적으로 커지고 화려해진다 (사용자: "초반엔 작게 나중엔 크고 화려하게").
## 입력은 SkillDef.vfx_level 하나 (카드 한 장·레벨업 두 번마다 +1 등, 진행 방식이 바뀌어도 이 숫자만 오르면 된다).
## vfx_level → 단계 (stage_from): 0 기본 · 1 (1~2) · 2 (3~4) · 3 (큰 강화/만렙). 단계마다 크기·입자·빛·겹·화면 상한.
## SkillVfxData.growth가 켜진 효과에만 쓴다 (켜지 않은 효과는 예전 level_size 방식). 판정(반경)은 바꾸지 않는다 — 그림만.

const PATH := "res://data/feel/skill_growth.tres"

## 이 vfx_level부터 그 단계 (오름차순, 첫 값 0).
@export var stage_from: PackedInt32Array = PackedInt32Array([0, 1, 3, 5])
## 그림 크기 배율 (판정에 맞춘 지름 × 이것). 기본은 지금보다 작게 시작한다.
@export var size: PackedFloat32Array = PackedFloat32Array([0.6, 0.8, 1.0, 1.3])
## 입자 수 배율, 빛 세기 배율, 밝기 배율.
@export var count: PackedFloat32Array = PackedFloat32Array([0.6, 1.0, 1.5, 2.2])
@export var glow: PackedFloat32Array = PackedFloat32Array([0.6, 1.0, 1.4, 1.9])
@export var bright: PackedFloat32Array = PackedFloat32Array([0.9, 1.0, 1.15, 1.3])
## 그림 겹 추가 (돌며 겹치는 그림 한 장씩 더).
@export var layers: PackedInt32Array = PackedInt32Array([0, 0, 1, 2])
## 이 단계부터 금빛 고리.
@export var ring_stage: int = 2
## 화면 너비 대비 상한 (SkillStageFeel.screen_cap 대신). 마지막 단계는 지금(0.58)보다 크게.
@export var screen_cap: PackedFloat32Array = PackedFloat32Array([0.36, 0.46, 0.58, 0.75])

static var _cached: SkillGrowthData


static func get_default() -> SkillGrowthData:
	if _cached == null:
		_cached = load(PATH) as SkillGrowthData if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = SkillGrowthData.new()
	return _cached


## vfx_level → 단계 번호 (0 ~ stage_from.size() - 1).
func stage_of(level: int) -> int:
	var s := 0
	for i in stage_from.size():
		if level >= stage_from[i]:
			s = i
	return s


func size_at(level: int) -> float:
	return _f(size, level, 1.0)


func count_at(level: int) -> float:
	return _f(count, level, 1.0)


func glow_at(level: int) -> float:
	return _f(glow, level, 1.0)


func bright_at(level: int) -> float:
	return _f(bright, level, 1.0)


func cap_at(level: int) -> float:
	return _f(screen_cap, level, 0.58)


func layers_at(level: int) -> int:
	var s := stage_of(level)
	return layers[s] if s < layers.size() else 0


func ring_at(level: int) -> bool:
	return stage_of(level) >= ring_stage


func _f(arr: PackedFloat32Array, level: int, fallback: float) -> float:
	var s := stage_of(level)
	return arr[s] if s < arr.size() else (arr[arr.size() - 1] if not arr.is_empty() else fallback)
