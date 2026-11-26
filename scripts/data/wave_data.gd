class_name WaveData
extends Resource
## 물결 하나 (하데스식): enemies를 차례로. 처음 first_count마리가 먼저 나오고, 나머지는 살아 있는 적이
## WaveSetData.next_when_left 이하일 때마다 이어서 나온다. 다 나오고 다 죽으면 물결 끝.

@export var enemies: Array[EnemyData] = []
@export var first_count: int = 4
## 이 물결에서 동시에 있는 적 최대 (0 = WaveSetData.max_alive). 난이도 단계의 추가 수는 여기에도 더해진다.
## 하데스: 상한 = 2.3 + 0.35 × 방 깊이 (docs/research/hades_data.md) → 한산 3 · 4 · 5.
@export var max_alive: int = 0
## 이 물결 마지막에 정예 한 마리 (무대의 elite, 변종 무작위).
@export var elite_last: bool = false
## 0 이상이면 정예는 살아 있는 적이 이 수 이하가 될 때까지 기다렸다 나온다 (중간 보스: 잡몹 몇 마리 → 등장).
## 정예가 마지막이라 그 뒤로는 일반 보충이 없고, 잡몹은 중간 보스의 소환으로만 나온다.
@export var elite_when_left: int = -1
## 비어 있지 않으면 정예 자리에 이 적들이 한꺼번에 나온다 (중간 우두머리 무리: 돌격·원거리·지원). 비면 무대의 정예 하나.
@export var elite_group: Array[EnemyData] = []
## 끄면 이 물결은 근접 잡몹 수 배율(WaveSetData.melee_count_mult)을 받지 않는다 (첫 물결을 가볍게 여는 무대).
@export var swarm: bool = true
## 대형 묶음 (FormationData): formation_after[i]마리가 나온 뒤 formations[i]가 한꺼번에 선다 (없으면 0, 물결 처음).
@export var formations: Array[FormationData] = []
@export var formation_after: PackedInt32Array = PackedInt32Array()
