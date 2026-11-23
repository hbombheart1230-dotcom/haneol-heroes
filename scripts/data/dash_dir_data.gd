class_name DashDirData
extends Resource
## 대시를 방향으로 나누기 (입력은 튕기기 하나 그대로, 상태가 아니라 방향): 겨눈 기준 적(가장 가까운 적, enemy_range 안) 쪽으로
## 튕기면 치고 들어가는 돌진 (지나간 몹에 약한 피해 + 움찔, 몹당 한 번, 멈춤 없음), 반대쪽이면 뒤로 뛰어 빠지기 (타격 없음, 적을 본 채),
## 옆이나 적이 없으면 지금 대시. 통과·무적·회피 판정은 셋 다 그대로. HeroData.dash_dir (비면 예전 대시).

## 개발용 되돌리기: 끄면 돌진도 타격 없이 동작만 (플레이어 설정 아님).
@export var strike_enabled: bool = true
## 기준 적을 찾는 거리(px). 이 안에 적이 없으면 옆 대시와 같다.
@export var enemy_range: float = 420.0
## 적 쪽과 대시 방향 사이 각도가 이 아래면 돌진, (180 − back_cone_deg) 위면 뒤로 빠지기 (도).
@export var charge_cone_deg: float = 60.0
@export var back_cone_deg: float = 60.0
## 돌진 피해 = 평타 1타 피해 × 이 값 (1타급 이하), 닿는 폭(px, 영웅 중심에서 + 적 몸 반경).
@export var strike_damage_mult: float = 0.8
@export var strike_radius: float = 40.0
## 연속 대시: 앞 대시가 끝난 뒤 이 시간(초) 안에 시작한 대시는 타격 없음 (연속 대시에서는 첫 대시만).
@export var chain_gap: float = 0.6
## 돌진 타격의 대가: 맞힌 게 있으면 대시 충전을 이만큼 더 쓴다 (0이면 없음).
@export var strike_extra_charge: int = 0
## 돌진 끝 경직(초): 맞힌 게 있으면 도착 뒤 이만큼 걷기 느림 (0이면 없음)과 그때 걷기 배율.
@export var strike_end_lag: float = 0.0
@export var strike_end_mult: float = 0.4
## 동작: 돌진 = 돌진 베기 (없으면 dash), 뒤로 빠지기 = 뒤로 뛰기 (없으면 dash를 적을 본 채로).
@export var charge_anim: StringName = &"cast_dash"
@export var back_anim: StringName = &"backstep"
## 뒤로 뛰기 동작이 시트에 없을 때 대신 (맞고 물러나는 hit: 적을 본 채 뒤로 젖혀진다. dash는 앞구르기라 뒤로는 어색하다).
@export var back_fallback: StringName = &"hit"
## 돌진 타격 소리 (SoundBank 종류).
@export var strike_sfx: StringName = &"w_sword"
