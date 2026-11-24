class_name SkillKit
extends Resource
## 영웅 하나의 단일 버튼 기술 구성 (무공 연계).
##   tap    : 짧게 눌렀다 뗌
##   dash   : 대시 중 / 대시 직후 누름
##   charge : 길게 눌러 충전 후 뗌

@export var tap: SkillDef
@export var dash: SkillDef
@export var charge: SkillDef
## 회피 성공 직후 반격 기술 (기획서 §6.3 우선순위 1).
@export var counter: SkillDef
@export_group("스킬 좌표 (원거리 영웅)")
## true면 설치·낙하·고리 기술이 영웅 자리 대신 겨눈 적 자리에 떨어진다 (SkillAim, 세종). 다른 영웅은 false (예전 그대로).
@export var skills_at_target: bool = false
## 떨어지는 자리의 사거리 상한(px, 영웅에서): 더 먼 적은 이 거리에서 자른다.
@export var target_range: float = 520.0
## 겨눌 적을 찾는 거리(px)와, 적이 없을 때 바라보는 방향으로 떨어지는 기본 거리(px).
@export var target_search: float = 760.0
@export var target_default: float = 240.0
@export_group("")
## 회피 성공 후 반격을 쓸 수 있는 시간(초).
@export var counter_window: float = 1.0
## 대시가 끝난 뒤에도 dash 기술로 인정하는 시간(초).
@export var dash_link_window: float = 0.45
## 이 시간 이상 누르면 충전으로 본다(초).
@export var hold_threshold: float = 0.2
## 충전 시작 후 최대 충전까지(초).
@export var full_charge_time: float = 1.0

@export_group("한 손 제스처")
## 이동 손가락을 제자리에서 이 시간 이상 누르면 충전 시작(초).
@export var gesture_hold_threshold: float = 0.3
## 이 거리(px) 이상 움직이면 탭/충전이 아니라 이동으로 본다.
@export var gesture_tap_slop: float = 14.0

@export_group("탭 연타 (A안)")
## 켜면 제자리 탭 = 평타 한 타 (근접 영웅은 근접 연계 1·2·3타, ranged_taps면 원거리), combo_hits타 뒤 탭 = tap 기술 마무리.
## 끄면 예전처럼 탭 = tap 기술 (쿨타임). 스킬 단추 누름은 켜도 예전 그대로.
@export var tap_combo: bool = true
## 탭 평타를 원거리로 (세종: 글자 던지기 연사).
@export var ranged_taps: bool = false
## 마무리 전에 이을 타 수 (3 = 탭·탭·탭 → 넷째 탭 마무리).
@export var combo_hits: int = 3
## 마무리 기술 피해 배율 (범위·개수는 그대로). 강화의 tap 수치를 먼저 반영한 뒤 곱한다.
@export var combo_finisher_mult: float = 0.6
## 마무리 뒤 tap 기술 쿨타임 = cooldown × 이 값 (연타로 쿨타임 없이 쏟아붓지 않게). 쿨타임 중 넷째 탭은 평타.
@export var combo_finisher_cd_ratio: float = 0.5
## 손 평타 최소 간격 = 평타 간격(근접 melee_interval·원거리 ranged_interval) × 이 값 (무한 연타 방지, 공격속도 강화를 따른다).
@export var tap_min_gap_mult: float = 0.7
## 너무 빨리 친 탭을 기억하는 시간(초).
@export var tap_buffer: float = 0.2
## 연계가 이어지는 시간(초): 마지막 손 타 뒤 이 안에 다음 탭.
@export var combo_window: float = 1.2
## 자동 평타도 연계 수에 넣을지 (기본 끔: 마무리는 손으로 연타한 보상).
@export var combo_auto_counts: bool = false
## 켜면 연계가 찬 뒤 넷째 탭이 마무리 대신 평타가 되면 (마무리 쿨타임 중) 그 타가 새 1타: 마무리는 언제나 1→2→3을 이은 바로 다음 탭
## (사용자 2026-11-24 "4타 스킬이 아무 때나 나온다": 끄면 연계 수가 찬 채로 남아 쿨타임이 풀리는 아무 타 뒤에 나간다).
@export var combo_fresh_after_full: bool = false
## 마무리 탭은 3타가 닿고 이만큼(초) 지난 뒤에 나간다 (그 전 탭은 finisher_buffer초 기억, F1): 3타 내려베기가 보이게.
@export var finisher_after_strike: float = 0.1
@export var finisher_buffer: float = 0.5
## 마무리(넷째 탭 기술) 동안 평타(손·자동)가 끼어들지 못하는 시간(초). 음수면 마무리 시전 동작이 끝날 때까지 (CastAnim).
## 그 사이 탭은 한 번만 기억했다가 풀리면 1타로 나간다. 대시는 언제든 끊는다.
@export var finisher_recover: float = -1.0
