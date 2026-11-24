class_name EnemyAnswerData
extends Resource
## 적마다 통하는 수 (정답 표, docs/research/enemy_answers.md): 이 적에게 잘 듣는 조작 하나와 그때 피해 배율.
## "그 수가 아니면 못 잡는다"가 아니라 "그 수면 훨씬 빨리 잡는다" (다른 수는 others_mult, 0.2 아래로는 안 간다).
## 계산은 EnemyAnswer (순수 함수), 붙이는 곳은 EnemyData.answer.

## 조작 넷: combo(연타·4타 마무리), dash(내닫아 치기·돌진 타격), charge(모아 치기), counter(피하고 반격).
@export_enum("combo", "dash", "charge", "counter") var kind: String = "combo"
## 맞는 수로 맞았을 때 피해 배율.
@export var mult: float = 2.0
## 다른 수로 맞았을 때 피해 배율 (갑옷·방패: 1보다 작게. 0으로는 두지 않는다 — 다른 수로도 잡히되 느리게).
@export_range(0.2, 1.0) var others_mult: float = 1.0
