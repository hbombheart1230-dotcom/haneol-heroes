class_name SwingGuardData
extends Resource
## 휘두르는 동안 버팀 (사용자 2026-11-25 "광개토 = 맞으면서 밀고 들어가는 장수", HeroData.swing_guard):
## 연타(1~3타)·4타를 휘두르는 동안 받는 피해를 줄이고, 맞아도 휘두르는 그림이 맞는 동작으로 끊기지 않는다.
## 휘두르는 동안 = 칼이 닿기 전(모으기·휘두름) + 4타 동작 + 닿은 뒤 tail초 (ComboSteps.swinging).

## 받는 피해 배율 (0.7 = 30% 줄임, 최소 1).
@export var damage_taken_mult: float = 0.7
## 칼이 닿은 뒤에도 이만큼(초) 버팀으로 본다 (휘두르는 그림이 끝날 때까지).
@export var tail: float = 0.15
## 맞아도 휘두르는 그림을 그대로 둔다 (맞는 동작으로 바꾸지 않는다).
@export var keep_pose: bool = true
