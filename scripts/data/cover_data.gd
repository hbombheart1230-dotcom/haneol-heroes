class_name CoverData
extends StageHazardData
## 엄폐 (경복궁 기둥·품계석): 곧게 날아가는 것(적 화살·조총 탄, 영웅의 날아가는 기술)을 막고, 막을 때마다 금이 가
## max_hits번에 깨진다 (깨지면 걸음도 막지 않고 그 판 동안 사라진다). 위에서 떨어지는 기술(유성·낙뢰)과
## 바닥에 그리는 기술(글자·화폭)은 날아가는 것이 아니라 그대로 넘는다. 박자 없음 (period 등 공통 수치는 쓰지 않는다).

## 엄폐 한 개: (월드 x, 월드 y, 종류 번호). 종류는 아래 배열들의 번호.
@export var pieces: PackedVector3Array = PackedVector3Array()
## 종류마다: 서 있는 그림, 깨진 그림, 화면 높이(px), 막는 원 반지름(px, 발밑).
@export var intact: Array[Texture2D] = []
@export var broken: Array[Texture2D] = []
@export var heights: PackedFloat32Array = PackedFloat32Array()
@export var radii: PackedFloat32Array = PackedFloat32Array()
@export var max_hits: int = 3

@export_group("무엇을 막나")
## 적 화살·조총 탄 (EnemyArrow).
@export var block_enemy_shots: bool = true
## 영웅의 날아가는 기술 (Projectile: 해일검기, 사방 검기).
@export var block_hero_skills: bool = true
## 영웅 평타 탄 (세종 글자 탄). 기본은 넘는다 (글자는 돌을 넘는다 — 세종 홈 전장).
@export var block_hero_basic: bool = false

@export_group("맞을 때")
@export var hit_sfx: StringName = &"mat_blunt"
@export var hit_pitch: float = 1.35
@export var break_sfx: StringName = &"e_heavy"
@export var dust_vfx: SkillVfxData
@export var shake_on_break: float = 0.2
## 금 그리기: 먹선 색과 굵기.
@export var crack_color: Color = Color(0.1, 0.09, 0.08, 0.85)
@export var crack_width: float = 4.0


func make() -> Node2D:
	return StoneCover.new(self)
