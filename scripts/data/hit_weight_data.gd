class_name HitWeightData
extends Resource
## 적 무게 등급 (맞는 쪽 반응, 사용자 2026-11-25): 가벼운 적은 크게 젖혀지고 멀리 밀려 날아가고, 묵직한 적은
## 무릎을 굽혀 버티며 조금만 젖혀진다. 타 세기(HitReaction.Power: 1·2타 / 3타 / 4타·기술)마다 크기가 커진다.
## 그림(젖힘·기울기·눌림·도는 각도)과 밀림 거리만 바꾼다. 체력·피해·경직 시간은 그대로.
## EnemyData.hit_weight가 비면 예전 반응 그대로.

## 젖힘·기울기 크기 배율 (HitReactionData.lean_px · tilt_deg에 곱한다).
@export var flinch_mult: float = 1.0
## 눌림(무릎 굽힘) 크기 배율: 묵직한 적은 젖혀지는 대신 눌려 버틴다.
@export var squash_mult: float = 1.0
## 젖혔다 돌아오는 시간 배율 (가벼운 적은 튕기듯 빨리, 무거운 적은 천천히 돌아온다).
@export var lean_time_mult: float = 1.0
## 밀림(넉백) 거리 배율 (Enemy.apply_knockback, 적 knockback_scale에 곱한다).
@export var knockback_mult: float = 1.0
## 3타 넘어짐 떠오르는 높이 배율 (ImpactFeelData.down_lift_px).
@export var down_lift_mult: float = 1.0
## 크게 날아갈 때(4타·기술, EnemyLaunch) 그림이 맞은 쪽으로 도는 각도(도, 0 = 안 돎).
@export var launch_spin_deg: float = 0.0
## 타 세기별 움찔 배율: [1·2타, 3타, 4타·기술].
@export var power_flinch: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0])
## 정예가 맞는 동작을 보이는 가장 약한 타 세기 (-1 = 예전 규칙: 한 번에 최대체력 1/16 이상일 때만).
@export var elite_anim_power: int = -1


func power_mult(power: int) -> float:
	return ComboSteps.at(power_flinch, power + 1, 1.0)
