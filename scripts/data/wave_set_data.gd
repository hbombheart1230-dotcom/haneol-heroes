class_name WaveSetData
extends Resource
## 무대 하나의 물결 구성 (StageTheme.waves). 물결을 다 깨면 보스.

@export var waves: Array[WaveData] = []
## 화면에 동시에 있는 적 최대 (예고 중인 자리 포함). 난이도 단계만큼 더해진다.
@export var max_alive: int = 8
## 살아 있는 적이 이 수 이하가 되면 남은 적이 이어서 나온다.
@export var next_when_left: int = 2
## 근접 잡몹 수 배율 (WaveSwarm): 1 = 배율 없음. 무대 .tres가 정한다 (D안 1.5). 체력은 그대로, 원거리·정예·무리·우두머리는 늘지 않는다.
@export var melee_count_mult: float = 1.0
## 켜면 하데스식 보충: 상한에 닿은 뒤로는 한 마리가 죽을 때마다 한 마리 (first_count·next_when_left는 쓰지 않음).
@export var refill_each: bool = false
## 등장: 영웅에게서 이 거리(px, 화면 안)에 먹 번짐 예고를 warn_time초 보인 뒤 나타난다. 예고끼리 간격(초).
@export var spawn_min: float = 260.0
@export var spawn_max: float = 420.0
@export var warn_time: float = 0.6
@export var spawn_stagger: float = 0.12
## 등장 자리를 보이는 화면 안에 두는 여유(px, 카메라 줌 반영): 원 대신 화면 비율 타원으로 줄인다. 음수면 끔.
@export var spawn_screen_margin: float = 40.0
## 물결 사이 숨 고르기(초, 강화 고르기가 끝난 뒤부터)와 마지막 물결 뒤 보스까지(초).
@export var gap_time: float = 1.2
@export var boss_delay: float = 1.5
## 처치 경험치 배율 (적이 적은 만큼, 강화 횟수가 지금과 비슷하게).
@export var xp_mult: float = 3.5
## 숨 고르기(물결 끝·보스 단계)마다 강화를 한 번만 고른다 (하데스식: 연달아 여러 번 고르지 않는다).
@export var one_pick_per_break: bool = true
## RunConfig.levels가 없을 때만: 그 한 번이 올려 주는 단계 수 (있으면 적립 카드 계획 LevelRules.plan을 따른다).
@export var pick_stacks: int = 2
## 화면 동시 상한에 더하는 수 (물결마다·무대 전체, 밀도 변형): 0 = 지금 (꺼짐). 늘어난 자리는 나올 차례의 적이 채운다.
@export var alive_cap_add: int = 0
## 중간 우두머리 물결(정예·무리)을 깬 뒤 최대 체력의 이 비율만큼 회복 (우두머리 앞 숨 고르기): 0 = 꺼짐.
@export var elite_clear_heal: float = 0.0

@export_group("우두머리 부르기")
## 우두머리·중간 우두머리가 부르는 그 전장의 원거리 대형 (비면 부르지 않음). 사용자 0.4.3 "보스전에서 왕창 부르는 거, 중간 보스도 몇 번".
@export var call_formation: FormationData
## 우두머리 체력이 이 몫 아래로 내려갈 때마다 부른다 (차례대로), 몇 묶음씩 (모자라면 1).
@export var boss_call_hp: PackedFloat32Array = PackedFloat32Array([0.4, 0.25, 0.1])
@export var boss_call_count: PackedInt32Array = PackedInt32Array([1, 1, 2])
## 중간 우두머리 셋 가운데 쓰러질 때마다 (남은 셋이 있을 때) 한 번씩, 이만큼까지.
@export var mid_calls: int = 2
## 부를 때 우두머리 머리 위 외침 (비면 없음).
@export var call_label: String = ""

