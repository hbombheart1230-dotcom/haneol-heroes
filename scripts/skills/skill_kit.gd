class_name SkillKit
extends Resource
## 영웅 하나의 단일 버튼 기술 구성 (무공 연계).
##   tap    : 짧게 눌렀다 뗌
##   dash   : 대시 중 / 대시 직후 누름
##   charge : 길게 눌러 충전 후 뗌

@export var tap: SkillDef
@export var dash: SkillDef
@export var charge: SkillDef
## 대시가 끝난 뒤에도 dash 기술로 인정하는 시간(초).
@export var dash_link_window: float = 0.45
## 이 시간 이상 누르면 충전으로 본다(초).
@export var hold_threshold: float = 0.2
## 충전 시작 후 최대 충전까지(초).
@export var full_charge_time: float = 1.0
