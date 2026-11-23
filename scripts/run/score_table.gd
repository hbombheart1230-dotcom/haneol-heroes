class_name ScoreTable
extends Resource
## 한 판 안의 점수(경험치)원: 처치 + 잘한 행동. 같은 행동 반복으로 끝없이 벌지 못하게 행동마다 간격·물결당 상한.
## ScoreFeed가 쓴다. 값은 모두 데이터 (data/runs/score_table.tres).

## 처치 점수 = EnemyData.xp × 무대 xp_mult × kill_mult. 정예·보스는 EnemyData.xp에 이미 크게 들어 있다.
@export var kill_mult: float = 1.0
## 연타 마무리 (kit.combo_hits타 뒤 마무리 기술이 적에 닿음).
@export var combo_finish: int = 2
## 회피 성공 (적 공격을 대시로 흘림).
@export var evade: int = 2
## 반격 명중 (회피 뒤 반격 기술이 적에 닿음).
@export var counter_hit: int = 4
## 충전 기술을 다 모아(full_charge_ratio 이상) 적에 맞힘.
@export var full_charge: int = 4
@export var full_charge_ratio: float = 0.95

@export_group("상한")
## 같은 행동 사이 최소 간격(초, 판 시간). 이보다 빨리 또 하면 점수 없음.
@export var combo_gap: float = 3.0
@export var evade_gap: float = 2.0
@export var counter_gap: float = 1.0
@export var charge_gap: float = 2.0
## 물결 하나(숨 고르기 사이)에서 행동마다 점수를 받는 최대 횟수. 0이면 제한 없음.
@export var per_wave_cap: int = 8


func value_of(kind: StringName) -> int:
	match kind:
		&"combo":
			return combo_finish
		&"evade":
			return evade
		&"counter":
			return counter_hit
		&"charge":
			return full_charge
	return 0


func gap_of(kind: StringName) -> float:
	match kind:
		&"combo":
			return combo_gap
		&"evade":
			return evade_gap
		&"counter":
			return counter_gap
		&"charge":
			return charge_gap
	return 0.0
