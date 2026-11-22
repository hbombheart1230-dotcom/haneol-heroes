class_name SkillStageFeel
extends Resource
## 기술 연출 공통 수치 (조각 등장·바늘·눈금·자국·띠·명중 밀림). 기술별 모양은 SkillVfxData "연출" 묶음.
## 저사양 안드로이드 기준으로 동시에 그리는 수를 여기서 막는다.

const PATH := "res://data/feel/skill_stage.tres"

@export_group("동시 상한")
## 조각 등장 그림 (그림 하나 = 조각 piece_count개), 바늘, 눈금 번쩍임, 바닥 자국, 베인 자국, 모이는 기운 알갱이.
@export var max_piece_sets: int = 6
@export var max_hands: int = 3
@export var max_ticks: int = 24
@export var max_ground: int = 10
@export var max_hit_marks: int = 16
@export var max_gather: int = 48

@export_group("조각")
## 조각 하나의 테두리 마디 수 (부채꼴 호를 이만큼 나눔. 클수록 둥글다).
@export var piece_arc_steps: int = 6
## 조각이 양옆 조각 쪽으로 겹쳐 뻗는 비율 (끝으로 갈수록 투명 → 곧은 칼선 대신 먹으로 갉힌 가장자리).
@export var piece_feather: float = 0.5
## 조각이 튀어나와 자리 잡는 시간(초).
@export var piece_settle: float = 0.1
## 다 모인 번쩍임 시간(초)과 크기 배율(그림 대비).
@export var flash_time: float = 0.14
@export var flash_scale: float = 0.8

@export_group("바늘·눈금")
## 바늘 뒤로 끌리는 옅은 잔상 수와 간격(라디안).
@export var hand_ghosts: int = 2
@export var hand_ghost_gap: float = 0.12
## 바늘이 한 바퀴 돈 뒤 남는 시간(초).
@export var hand_linger: float = 0.25
## 눈금 번쩍임 시간(초).
@export var tick_time: float = 0.3

@export_group("자국")
## 바닥 자국이 나타나는 시간(초, 처음 커짐).
@export var ground_fade_in: float = 0.08
## 베인 자국: 긋는 시간 비율 (수명 중 앞부분), 두께 비율.
@export var hit_mark_draw: float = 0.35
@export var hit_mark_thickness: float = 0.42

@export_group("띠 (직선 기술)")
## 띠를 이만큼 나눠 그린다: 꼬리부터 먹으로 번져 사라지고, 펼쳐지는 머리는 굵게 부푼다.
@export var strip_slices: int = 6
## 머리 부풂 배율과 꼬리가 먼저 사라지는 정도 (0 = 한꺼번에).
@export var strip_head_swell: float = 0.3
@export var strip_tail_lead: float = 0.6

@export_group("컷인 (큰 기술)")
## 컷인 전체 시간(실제 초), 게임을 느리게 하는 시간·배율, 다음 컷인까지 최소 간격(초, 연속 발동에 과하지 않게).
@export var cutin_time: float = 0.5
@export var cutin_slow: float = 0.26
@export var cutin_slow_scale: float = 0.25
@export var cutin_min_gap: float = 8.0
## 먹 띠 높이(화면 높이 비율)와 세로 자리(0 = 위, 1 = 아래), 이름 글자 크기(px).
@export var cutin_band: float = 0.2
@export var cutin_y: float = 0.36
@export var cutin_font_px: int = 84

@export_group("명중 밀림 (기술)")
## 기술이 맞을 때마다 화면을 맞은 방향으로 민다: 피해 × per_damage px (최대 cap).
@export var kick_per_damage: float = 0.12
@export var kick_cap: float = 9.0
## 흔들림 더하기: 피해 × per_damage (최대 cap).
@export var trauma_per_damage: float = 0.004
@export var trauma_cap: float = 0.22

static var _cached: SkillStageFeel


static func get_default() -> SkillStageFeel:
	if _cached == null:
		_cached = load(PATH) as SkillStageFeel if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = SkillStageFeel.new()
	return _cached


## 명중 하나의 화면 밀림(px)과 흔들림.
func kick_for(damage: int) -> float:
	return minf(maxf(damage, 0) * kick_per_damage, kick_cap)


func trauma_for(damage: int) -> float:
	return minf(maxf(damage, 0) * trauma_per_damage, trauma_cap)
