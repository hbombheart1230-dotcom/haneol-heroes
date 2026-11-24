class_name HeroGrowthData
extends Resource
## 판을 넘어 남는 영웅 성장 수치 (data/progression/hero_growth.tres). 입력은 성장 점수 하나 (지금은 처음 깬 전장 수,
## 나중에 재화로 산 점수로 바꿔도 HeroGrowth.points 한 곳만 바뀐다).

const PATH := "res://data/progression/hero_growth.tres"

## 점수 하나당 최대 체력·모든 피해 (기본 공격·기술) 오름 비율.
@export var hp_per: float = 0.08
@export var atk_per: float = 0.08
## 이 점수마다 기술 시작 단계 +1 (SkillGrowthData 단계), 시작 단계 상한.
@export var skill_every: int = 3
@export var skill_start_max: int = 2
## 시작 단계가 이 이상이면 기술 맨 위 단계(5단계)가 열린다.
@export var top_stage_from_start: int = 1
## 점수 상한 (데이터 값으로만).
@export var max_points: int = 99
