class_name EnemyAuraData
extends Resource
## 둘레에 미치는 힘 (EnemyData.aura): 깃발·북잡이처럼 서 있기만 해도 판을 바꾸는 적. EnemyAura가 매 틱 적용한다.
## 아군 빠르게 (둘레 안 적의 이동 배율), 먹물 장판 (둘레 안 영웅이 느려짐 — 피해는 없음: 맞은 뒤 무적이 큰 공격을 막지 않게).

@export var radius: float = 160.0
## 둘레 안 아군 이동 배율 (1 = 없음).
@export var ally_speed_mult: float = 1.0
## 둘레 안 영웅 이동 배율 (1 = 장판 없음). 회피(내닫기)는 막지 않는다.
@export var field_slow_mult: float = 1.0
## 장판 그림 (먹물 둥근 얼룩) 진하기. 화면을 가리지 않게 옅게.
@export var field_alpha: float = 0.22
