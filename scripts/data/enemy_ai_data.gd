class_name EnemyAIData
extends Resource
## 적 무리 공통 규칙: 공격권, 둘러싸기, 처벌 시간, 일제 사격 박자, 무리 이벤트, 정예 변종.
## data/enemies/enemy_ai.tres 하나를 모든 적이 함께 쓴다.

@export_group("공격권 (Doom 2016식)")
## 동시에 덤비는 근접 적 최대 수. 나머지는 hold_radius 고리에서 맴돈다.
@export var max_melee_tokens: int = 3
## 이 거리 안에 들어오면 공격권을 달라고 한다.
@export var engage_radius: float = 280.0
## 공격권이 없으면 이 거리에서 플레이어 둘레를 돈다 (옆걸음 속도 배율).
@export var hold_radius: float = 240.0
@export var strafe_ratio: float = 0.5
## 고리에서 이 폭(px) 안쪽·바깥쪽에서는 천천히 다가가거나 물러난다.
@export var hold_band: float = 60.0
## 공격권을 가진 적이 이보다 멀어지면 돌려준다.
@export var release_radius: float = 420.0
## 거리 유지 고리 (C1): 쫓는 적은 영웅 몸 + 자기 몸 + margin(px)에서 멈춘다 (영웅 그림 위로 파고들지 않게).
## margin은 음수: 영웅 접촉 판정(감지 반경 30 + 적 몸)과 겹쳐야 접촉 피해가 그대로 들어온다.
## band(px) 앞부터 천천히 멈추고, 더 안쪽이면 살짝 물러난다. band가 0이면 끔.
@export var stand_off_margin: float = -8.0
@export var stand_off_band: float = 24.0

@export_group("적 공격 소리 (타격감 2차 E1)")
## 공격 종류(EnemyAttackData.Kind 번호) → [예고 소리, 타격 소리]. 공격 데이터에 따로 적으면 그것이 이긴다.
@export var attack_sfx: Dictionary = {}

@export_group("무게 등급 (B3)")
## 정예 갑옷 = 최대체력 × elite_armor_frac. 갑옷이 있는 동안 넉백 면역, 깨지면 armor_break_stun초 기절,
## armor_regen_delay초 뒤 다시 찬다. 분열로 나온 작은 적은 잡몹 취급.
@export var elite_armor_frac: float = 0.3
@export var armor_break_stun: float = 1.0
@export var armor_regen_delay: float = 6.0
## 보스: 넉백 면역, 경직 게이지 = 최대체력 × boss_stagger_frac. 차면 boss_stagger_time초 휘청, 다음 게이지는 growth배.
@export var boss_stagger_frac: float = 0.22
@export var boss_stagger_time: float = 0.8
@export var boss_stagger_growth: float = 2.0
## 발밑 막대: 두께(px), 갑옷 색, 경직 게이지 색.
@export var poise_bar_height: float = 4.0
@export var armor_bar_color: Color = Color(0.82, 0.88, 0.95, 0.95)
@export var stagger_bar_color: Color = Color(1.0, 0.78, 0.3, 0.95)

@export_group("예고·처벌")
## 공격 직후 경직 중 받는 피해 배율 (빈틈을 찌르면 더 아프다).
@export var punish_mult: float = 1.3
## 예고 마지막 이 비율부터 몸이 번쩍인다 (곧 친다는 신호)와 그 밝기.
@export var strike_flash_from: float = 0.8
## 공통 예고 규칙 (하데스 슬라이스): 모든 적 예고는 붉은 먹으로 칠해 진해지다 맞기 strike_flash_time초 전부터 번쩍인다
## (비율이 아니라 남은 시간이라 예고 길이와 상관없이 같은 박자). 예고는 min_windup초 이상 (데이터 검사).
@export var strike_flash_time: float = 0.15
@export var min_windup: float = 0.6
## 예고 끝 몸 떨림 (하데스 PreAttackEndShake): 번쩍이는 동안 좌우로 이만큼(px) 이 빠르기(Hz)로 떤다. 0이면 끔.
@export var windup_shake_px: float = 3.0
@export var windup_shake_hz: float = 28.0
@export var strike_flash: float = 1.6

@export_group("일제 사격")
## 박자 간격(초)과 조준을 시작할 수 있는 창(초).
@export var volley_interval: float = 2.6
@export var volley_window: float = 0.25

@export_group("무리 이벤트")
## 무리 이벤트·분열로 동시 최대 수(EnemySpawner.max_alive)를 이만큼까지 넘을 수 있다 (모바일 상한).
@export var horde_extra_alive: int = 16
## 첫 이벤트 시각과 간격(초). 0이면 없음.
@export var horde_first: float = 25.0
@export var horde_interval: float = 30.0
## 포위(RING): 수, 반지름. 휩쓸기(WALL): 수, 간격, 출발 거리, 속도 배율, 직진 시간. 떼(SWARM): 수, 체력·속도·크기 배율.
@export var ring_count: int = 12
@export var ring_radius: float = 560.0
@export var wall_count: int = 9
@export var wall_spacing: float = 80.0
@export var wall_distance: float = 640.0
@export var wall_speed_mult: float = 1.4
@export var wall_time: float = 4.0
@export var swarm_count: int = 14
@export var swarm_hp_mult: float = 0.5
@export var swarm_speed_mult: float = 1.6
@export var swarm_scale: float = 0.8
@export var swarm_spread: float = 140.0

@export_group("정예 변종")
@export var elite_affixes: Array[EliteAffixData] = []
