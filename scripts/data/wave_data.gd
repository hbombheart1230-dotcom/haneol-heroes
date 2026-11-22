class_name WaveData
extends Resource
## 물결 하나 (하데스식): enemies를 차례로. 처음 first_count마리가 먼저 나오고, 나머지는 살아 있는 적이
## WaveSetData.next_when_left 이하일 때마다 이어서 나온다. 다 나오고 다 죽으면 물결 끝.

@export var enemies: Array[EnemyData] = []
@export var first_count: int = 4
## 이 물결 마지막에 정예 한 마리 (무대의 elite, 변종 무작위).
@export var elite_last: bool = false
