class_name BasicAttackData
extends Resource
## 자동 기본 공격 수치 (근접 부채꼴 + 원거리 투사체).

@export_group("근접")
@export var melee_interval: float = 0.55
@export var melee_range: float = 110.0
@export var melee_arc_degrees: float = 140.0
@export var melee_damage: int = 12
## 근접 베기 그림 색 (CombatFeelData.crescent_art에 곱함).
@export var swing_color: Color = Color(0.55, 0.85, 1.0, 0.9)
## 근접 적중 시 적을 밀어내는 힘 (피격 반응).
@export var melee_knockback: float = 140.0
## 근접 적중 시 플레이어가 반대로 살짝 밀리는 거리(px). 칼이 닿은 반동 (Hollow Knight식).
@export var melee_recoil: float = 0.0
## 휘두르기 시작부터 피해까지(초): 칼이 닿는 프레임에 맞는다 (W2). 0이면 바로, 음수면 시트의
## 맞닿는 프레임 ÷ fps를 CombatFeelData.melee_delay_min~max로.
@export var melee_delay: float = 0.0
## 근접 우선 (A1): 근접 사거리 × engage_mult 안에 적이 있으면 원거리를 참고 붙기를 기다린다.
## 1이면 끔 (원거리 영웅). 그래도 engage_hold_max초 넘게 근접이 안 나가면 쏜다 (거리 두는 궁수 등).
@export var engage_mult: float = 1.0
@export var engage_hold_max: float = 0.5
## 평타 연계 (B4): chain_window초 안에 이어진 근접 chain_len번째가 강타 (0이면 끔).
## 강타: 피해·넉백 배율, 잡몹 넘어짐. 시트에 attack2·attack3가 있으면 그 동작으로.
@export var chain_len: int = 3
@export var chain_window: float = 1.2
@export var heavy_damage_mult: float = 1.6
@export var heavy_knockback_mult: float = 2.0
## 무기 타격음 (B9): 근접이 맞을 때 겹치는 소리, 강타에 더 겹치는 소리 (사운드 뱅크 이름, 비면 없음).
@export var melee_hit_sfx: StringName = &""
@export var heavy_hit_sfx: StringName = &""

@export_group("원거리")
@export var ranged_interval: float = 0.8
@export var ranged_range: float = 480.0
@export var ranged_damage: int = 10
@export var ranged_speed: float = 700.0
@export var ranged_lifetime: float = 0.8
## 원거리 적중 시 넉백 (근접의 절반 정도).
@export var ranged_knockback: float = 0.0
## 비어 있지 않으면 원거리 투사체를 이 글자들로 차례로 그린다 (세종 문자탄).
@export var ranged_glyphs: String = ""

@export_group("원거리 탄 그림")
## 영웅마다 다른 탄 그림 (오른쪽 = 날아가는 방향, assets/vfx/proj_*.png). 비면 먹 획.
@export var proj_art: Texture2D
## 탄 그림 길이·두께(px), 글자 탄 글자 크기(px).
@export var proj_size: Vector2 = Vector2(96, 36)
@export var glyph_px: int = 40
## 뒤 자취 자취 색과 길이(px).
@export var proj_trail_color: Color = Color(0.3, 0.55, 0.9, 0.6)
@export var proj_trail_len: float = 60.0
## 던지는 동작: 쏘기 시작 후 손을 떠나기까지(초)와 손 위치 (앞으로 x px, 위로 y px).
## 음수면 시트의 던지는 동작 맞닿는 프레임 ÷ fps를 CombatFeelData.release_delay_min~max로 (근접 melee_delay와 같은 방식).
@export var release_delay: float = 0.0
## 던질 때 재생할 동작 (시트 이름). 비우면 동작 없이 손에서 나간다.
@export var ranged_anim: StringName = &"attack"
## 던지는 동작을 보여 주는 시간(초). 동작 길이(프레임 수 ÷ fps)에 맞춘다.
@export var ranged_anim_time: float = 0.35
@export var release_offset: Vector2 = Vector2.ZERO
