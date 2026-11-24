class_name BossFeelData
extends Resource
## 보스전 박자·연출 (EnemyData.boss_feel). 네 무대 보스가 함께 쓴다: 부하를 부리고 단계마다 군령(BossPhaseData.seal_label)으로
## 조합(EnemyAttackData.follow_up)을 거는 장수 박자. 공격 구성은 보스 데이터마다 다르다.
## 하데스 값은 예고·틈 비율과 한 방 피해가 터무니없지 않은지 보는 데만 썼다. 비어 있는 보스는 옛 방식 그대로
## (차례대로 돌기, 단계 바뀌면 바로 소환, 처치하면 바로 승리).
## 순서: 등장(intro_hold 동안 치지 않음) → 단계 전환(낙인·글자·북 → pick_delay 뒤 강화 → summon_delay 뒤 부하)
## → 처치(finale_time 동안 느린 시간·확대·한지 번짐·"적장 격파" 띠, 그 뒤 승리).

@export_group("공격 고르기")
## 켜면 공격을 차례 대신 고른다: 바로 전과 같은 종류는 빼고, 지금 거리에서 닿는 공격을 먼저 (한 판 15~20번뿐이라 연속 없음).
@export var pick_by_range: bool = true
## 보스 공격은 보스가 화면 안(가장자리에서 이 px 안쪽)에 있을 때만 시작한다 (화면 밖 돌진 금지). 음수면 끔.
@export var onscreen_margin: float = 60.0

@export_group("추격")
## 0보다 크면 보스 이동 속도를 이 값으로 (쉬지 않고 쫓아오는 우두머리). 0 = EnemyData.move_speed 그대로.
@export var chase_speed: float = 0.0
## 무리(같은 물결 중간 우두머리 여럿) 가운데 동시에 예고하는 수 최대. 0 = 제한 없음.
@export var group_windup_cap: int = 0

@export_group("등장")
## 등장 뒤 이 시간(초)은 치지 않는다 (이름 띠·붉은 깜박임이 끝날 즈음 첫 공격).
@export var intro_hold: float = 2.2

@export_group("단계 전환")
## 전환 동안 보스는 치지 않고(무적은 BossPhaseData.invuln_time), 영웅도 이 시간(초) 동안 맞지 않는다.
@export var transition_hold: float = 1.8
## 낙인이 떨어지고 글자가 읽힌 뒤 강화 고르기를 연다(초).
@export var pick_delay: float = 0.7
## 전환 한 박자 동안 보일 동작 (시트에 있을 때만, 예: 칼을 하늘로 드는 외침 shout). 비면 없음.
@export var phase_anim: StringName = &"shout"
## 부하 먹 번짐 예고를 시작하는 때(초, 전환 시작부터). 예고 0.6초 뒤 나타난다.
@export var summon_delay: float = 1.0
## 보스와 함께 있을 부하 최대 (근접 전용 영웅이 보스와 함께 감당할 수). 넘는 소환은 버린다.
@export var max_minions: int = 3
## 부하는 영웅 반대편, 보스 뒤 이 거리(px)·부채꼴 폭(도)에 나온다 (지휘관 뒤 진형, 영웅 바로 옆이 아니라).
@export var summon_distance: float = 190.0
@export var summon_spread_deg: float = 100.0

@export_group("중간 보스")
## 단계가 바뀔 때 강화 고르기를 연다 (중간 보스는 끔: 강화는 물결 끝 숨 고르기에서).
@export var phase_pick: bool = true
## 등장 띠 아래 글자 (비면 BossBanner 기본 "적장 출현").
@export var intro_subtitle: String = ""

@export_group("처치")
## 마지막 일격 뒤 승리 화면까지 실제 시간(초). 그동안 영웅은 맞지 않고 남은 부하는 흩어진다.
@export var finale_time: float = 2.6
## 느린 시간 배율·길이(초)·되돌아오는 시간(초).
@export var finale_slow_scale: float = 0.2
@export var finale_slow_time: float = 1.1
@export var finale_slow_back: float = 0.5
## 확대 배율 (무대 기본 확대에 곱함)과 들어가는·머무는·돌아오는 시간(초, 실제 시간).
@export var finale_zoom: float = 1.28
@export var finale_zoom_in: float = 0.25
@export var finale_zoom_hold: float = 1.1
@export var finale_zoom_out: float = 0.8
## 한지색 번짐 진하기와 빠지는 시간(초).
@export var finale_flash_alpha: float = 0.7
@export var finale_flash_time: float = 1.4
## 처치 띠 글자 (BossBanner).
@export var finale_subtitle: String = "적장 격파"
