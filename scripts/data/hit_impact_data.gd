class_name HitImpactData
extends Resource
## 한 타의 충격 (사용자: "평타와 연타 스킬 1번의 타격감이 너무 없는데"): 무기가 닿는 자리의 밝은 섬광(심) + 영웅색 고리 +
## 먹 외곽선을 두른 튐 줄기, 낮은 "퍽" 소리, 짧은 진동. 배열은 연타 1·2·3타 순서 (기술 명중은 skill_step).
## 기준: GDQuest juicy-attack (번쩍임 2번·넉백 약 30px·입자 6개), 하데스 (매 타 경직, 3타 크게). docs/research/open_data_benchmark.md

@export_group("섬광 · 줄기 (px, 초)")
## 밝은 심 반지름 (타마다).
@export var core_radius: PackedFloat32Array = PackedFloat32Array([26.0, 34.0, 48.0])
## 영웅색 고리 반지름 = 심 × 이 값, 두께.
@export var ring_mult: float = 1.9
@export var ring_width: float = 5.0
## 튐 줄기 수·길이·두께 (먹 외곽선은 두께 + outline).
@export var streak_count: PackedInt32Array = PackedInt32Array([4, 5, 7])
@export var streak_length: PackedFloat32Array = PackedFloat32Array([46.0, 58.0, 84.0])
@export var streak_width: float = 8.0
@export var outline: float = 3.0
## 줄기가 퍼지는 각도(도, 맞은 방향 기준).
@export var streak_spread_deg: float = 110.0
## 보이는 시간 (심은 앞 core_share만큼 밝다).
@export var duration: float = 0.16
@export var core_share: float = 0.45
@export var core_color: Color = Color(1.0, 0.98, 0.9, 1.0)
## 심을 영웅색 쪽으로 물들이는 비율 (검기의 흰빛 심과 묻히지 않게).
@export var core_tint: float = 0.3
## 그리는 높이 (절대 z): 검기·영웅·적 위.
@export var draw_z: int = 20
@export var ink_color: Color = Color(0.08, 0.06, 0.05, 0.85)
## 영웅색을 이만큼 밝혀 줄기·고리에 쓴다 (어두운 바닥에서 묻히지 않게).
@export var color_lighten: float = 0.45
## 먹 방울 수 (KillFx.drops, 타마다).
@export var drops: PackedInt32Array = PackedInt32Array([4, 5, 8])
## 동시에 그리는 최대 수 (넘으면 가장 오래된 것을 덮어쓴다).
@export var max_active: int = 24
## 몸 접점 높이: 적 sprite_offset의 이 비율만큼 위 (가슴께).
@export var body_height_ratio: float = 0.6

@export_group("소리 · 진동")
## 낮은 "퍽" 층 (SoundBank 종류)과 타마다 음높이 배율 (1 → 2 → 3타로 올라감).
@export var thud_sfx: StringName = &"thud"
@export var pitch: PackedFloat32Array = PackedFloat32Array([1.0, 1.06, 1.14])
## 진동(ms)·세기 (설정의 진동 끄기와 CombatFeelData.haptic_min_gap을 따른다).
@export var haptic_ms: PackedInt32Array = PackedInt32Array([12, 12, 30])
@export var haptic_amp: PackedFloat32Array = PackedFloat32Array([0.35, 0.35, 0.7])

@export_group("기술 명중")
## 기술 명중(해룡참 등)이 쓰는 타 번호 (1~3).
@export var skill_step: int = 2


## 타 번호(1~3)의 값 (배열이 짧으면 마지막 값).
static func at_f(arr: PackedFloat32Array, step: int, fallback: float) -> float:
	if arr.is_empty():
		return fallback
	return arr[clampi(step - 1, 0, arr.size() - 1)]


static func at_i(arr: PackedInt32Array, step: int, fallback: int) -> int:
	if arr.is_empty():
		return fallback
	return arr[clampi(step - 1, 0, arr.size() - 1)]
