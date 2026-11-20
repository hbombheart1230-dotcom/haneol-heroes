class_name HitReactionData
extends Resource
## 맞는 반응 수치 (docs/research/game_feel_benchmark.md R1·R2·R3·B1·C2).
## 적: 구워 둔 맞는 동작·잡몹 경직·그림만 움찔·흰 번쩍임. 영웅: 붉은 번쩍임·무적 깜빡임·화면 가장자리·숨 돌릴 틈.

@export_group("적 맞는 동작")
## 구운 "hit" 동작을 보여 주는 시간(초, 개별 멈춤이 끝난 뒤부터). 3프레임 12fps = 0.25초.
@export var hit_anim_time: float = 0.25
## 정예는 한 번에 최대체력의 이 비율 이상을 잃을 때만 맞는 동작 (Diablo II 1/16 규칙). 보스는 boss_flinch일 때만.
@export var elite_flinch_hp_frac: float = 0.0625
@export var boss_flinch: bool = false

@export_group("잡몹 경직")
## 잡몹(정예·보스 아님)이 맞으면 이 시간 동안 쫓아오지 않고 넉백만 받는다 (Vampire Survivors 120ms).
@export var stagger_time: float = 0.15

@export_group("움찔 (그림만, 판정은 그대로)")
## 발 기준 눌림 (가로, 세로)과 원래대로 돌아오는 시간(초).
@export var squash: Vector2 = Vector2(1.12, 0.88)
@export var squash_time: float = 0.08
## 맞은 방향으로 젖혀지는 거리(px)·기울기(도)와 돌아오는 시간(초).
@export var lean_px: float = 8.0
@export var tilt_deg: float = 6.0
@export var lean_time: float = 0.14
## 정예·보스 움찔 크기 배율 (무거워 보이게).
@export var heavy_flinch_scale: float = 0.4

@export_group("흰 번쩍임 (셰이더)")
## 처음 아주 밝은 구간(CombatFeelData.flash_peak_time)에 흰색을 섞는 비율, 그 뒤 시작 비율 (0으로 줄어듦).
@export var flash_white: float = 0.85
@export var flash_white_tail: float = 0.45

@export_group("영웅 피격")
## 맞은 순간 붉은 번쩍임 시간(초)과 색 (스프라이트 modulate).
@export var hero_flash_time: float = 0.1
@export var hero_flash_color: Color = Color(1.5, 0.45, 0.4)
## 맞는 동작을 보여 주는 시간(초).
@export var hero_hit_anim_time: float = 0.25
## 무적 동안 깜빡임: 초당 켜고 끄기 횟수와 꺼질 때 투명도.
@export var blink_hz: float = 12.0
@export var blink_alpha: float = 0.4
## 화면 가장자리 붉은 빛: 시간(초)·진하기·색.
@export var vignette_time: float = 0.35
@export var vignette_alpha: float = 0.55
@export var vignette_color: Color = Color(0.6, 0.02, 0.02)

@export_group("숨 돌릴 틈")
## 맞으면 이 반경(px, 영웅 중심) 안 적을 바깥으로 민다. 가까울수록 세게 (가장자리에서 절반).
@export var breathe_radius: float = 90.0
@export var breathe_impulse: float = 240.0
## 피격 무적 = 영웅 hurt_invuln_time × (min_ratio ~ 1). 최대체력의 full_hp_frac 이상 잃으면 전체 (Brotato식).
@export var invuln_min_ratio: float = 0.67
@export var invuln_full_hp_frac: float = 0.15
