class_name TelegraphRim
extends Node2D
## 적 예고의 테두리만 기술 효과 위 층에 (색 규칙 B, 사용자 2026-11-24): 채움은 적 노드(바닥)에, 테두리는 여기서
## 절대 z(EnemyAIData.telegraph_rim_z, 기본 22: 검기 4·효과 5·타격 섬광 20·탄 부서짐 21 위)로 그려
## 큰 기술이 터져도 예고 선은 늘 보인다. 적과 같은 좌표계 (위치·변형 없음).

var enemy: Enemy
var _was: bool = false


func _ready() -> void:
	name = "TelegraphRim"
	z_as_relative = false
	z_index = Enemy.ai_data().telegraph_rim_z


func _process(_delta: float) -> void:
	var on := enemy != null and enemy.attack != null and enemy.attack.state == EnemyAttack.State.WINDUP
	if on or _was:
		queue_redraw()  # 예고 중엔 매 프레임, 끝난 그 프레임에 한 번 더 (지우기)
	_was = on


func _draw() -> void:
	if enemy:
		EnemyArt.telegraph_part(enemy, self, EnemyArt.RIM)
