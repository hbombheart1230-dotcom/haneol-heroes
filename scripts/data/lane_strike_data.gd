class_name LaneStrikeData
extends StageHazardData
## 가로줄 공격 (한산 포격선): 예고 동안 북이 울리고 줄이 바닥에 그려진 뒤, 줄 위 모두를 한 번에 친다.
## 줄 자리는 지도에 그려진 대포 줄(rows) 중 화면 안에서 적이 가장 많이 선 줄 (LanePlan).

## 줄 후보: (월드 y, 왼쪽 끝 x, 오른쪽 끝 x). 한산은 양쪽 난간 대포 쌍의 높이.
@export var rows: PackedVector3Array = PackedVector3Array()
## 줄 반폭(px). 몸이 걸치면 맞는다 (중심 + 몸 반지름).
@export var half_width: float = 70.0
## 같은 줄을 두 번 이어 고르지 않는다 (후보가 둘 이상일 때).
@export var avoid_repeat: bool = true
## 화면 위아래 가장자리에서 이만큼 안쪽 줄만 후보 (세로 화면에서 줄이 잘리지 않게).
@export var view_margin: float = 120.0

@export_group("박자")
## 예고 동안 북 수 (예고 길이를 고르게 나눠 0초부터). 마지막 북 뒤 한 박자에 포격.
@export var beats: int = 3
@export var beat_sfx: StringName = &"gugak_buk"
## 포성: 조총 소리를 낮게 + 꽹과리 층.
@export var strike_sfx: StringName = &"e_gun"
@export var strike_pitch: float = 0.5
@export var strike_layer_sfx: StringName = &"gugak_big"

@export_group("맞을 때")
## 줄 가운데에서 위아래로 밀어낸다(px 충격).
@export var enemy_push: float = 160.0
@export var shake: float = 0.5

@export_group("그림")
@export var warn_color: Color = Color(0.86, 0.16, 0.1, 1.0)
## 예고 면 진하기 (처음 → 포격 직전).
@export var fill_alpha: Vector2 = Vector2(0.08, 0.3)
@export var edge_width: float = 7.0
## 포격 뒤 줄이 번쩍이는 시간(초)과 색.
@export var flash_time: float = 0.28
@export var flash_color: Color = Color(1.0, 0.86, 0.5, 0.85)
## 양 끝 포구 불꽃, 줄을 따라 튀는 나무 조각 (hit_spacing px마다, 화면 안만).
@export var muzzle_vfx: SkillVfxData
@export var splinter_vfx: SkillVfxData
@export var hit_spacing: float = 140.0


func make() -> Node2D:
	return LaneStrike.new(self)
