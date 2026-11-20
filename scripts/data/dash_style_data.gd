class_name DashStyleData
extends Resource
## 영웅마다 다른 회피(대시): 생김새(시작·자취·도착 이펙트, 몸 색·투명도)와 도착할 때의 작은 효과.
## HeroData.dash_style에 붙인다. 없으면 기본 대시.

@export_group("이펙트")
## 출발할 때 (출발 자리, 대시 방향), 대시 중 일정 간격으로 자취, 도착할 때.
@export var start_vfx: SkillVfxData
@export var trail_vfx: SkillVfxData
@export var trail_interval: float = 0.04
@export var end_vfx: SkillVfxData
## 대시 중 몸 색과 투명도 (0에 가까우면 사라졌다 나타나는 순간이동처럼).
@export var body_tint: Color = Color(0.75, 0.9, 1.0)
@export var body_alpha: float = 1.0
## 몸 뒤 먹 번짐 자취 색 (PlayerView).
@export var trail_color: Color = Color(0.25, 0.55, 0.85)

@export_group("도착 효과 (작게, 균형 유지)")
## 효과 범위(px). 0이면 효과 없음.
@export var end_radius: float = 0.0
## 도착 자리 둘레 적 밀어내기 힘, 기절 시간(초), 느리게(배율·시간).
@export var end_push: float = 0.0
@export var end_stun: float = 0.0
@export var end_slow_factor: float = 1.0
@export var end_slow_time: float = 0.0
## 도착 효과 사이 최소 간격(초). 연속 대시로 기절·느리게를 줄줄이 걸지 못하게 (이펙트는 매번).
@export var end_cooldown: float = 0.8
## true면 효과를 도착 자리가 아니라 출발 자리에 남긴다 (사임당 먹 웅덩이).
@export var effect_at_start: bool = false
