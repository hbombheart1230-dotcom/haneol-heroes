class_name BasicAttackData
extends Resource
## 자동 기본 공격 수치 (근접 부채꼴 + 원거리 투사체).

@export_group("근접")
@export var melee_interval: float = 0.55
@export var melee_range: float = 110.0
@export var melee_arc_degrees: float = 140.0
@export var melee_damage: int = 12
## 근접 적중 시 적을 밀어내는 힘 (피격 반응).
@export var melee_knockback: float = 140.0
## 근접 적중 시 플레이어가 반대로 살짝 밀리는 거리(px). 칼이 닿은 반동 (Hollow Knight식).
@export var melee_recoil: float = 0.0

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
@export var release_delay: float = 0.0
@export var release_offset: Vector2 = Vector2.ZERO
