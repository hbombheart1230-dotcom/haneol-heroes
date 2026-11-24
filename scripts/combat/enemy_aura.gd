class_name EnemyAura
extends RefCounted
## 둘레에 미치는 힘 (EnemyData.aura, 수치는 EnemyAuraData): 매 틱 둘레 안 아군을 잠깐 빠르게, 영웅은 장판 안에서 느리게.
## 장판 그림은 몸 아래 옅은 먹물 얼룩 (화면을 가리지 않게, EnemyArt가 그린다).

## 한 틱에 걸어 두는 시간(초): 둘레를 벗어나면 곧 풀린다.
const HOLD := 0.25


static func tick(e: Enemy) -> void:
	var a := e.data.aura
	if a == null or e.health.is_dead():
		return
	if a.ally_speed_mult > 1.0:
		for n in e.get_tree().get_nodes_in_group(Enemy.GROUP):
			var o := n as Enemy
			if o and o != e and not o.health.is_dead() and o.global_position.distance_to(e.global_position) <= a.radius:
				o.boost(a.ally_speed_mult, HOLD)
	if a.field_slow_mult < 1.0 and e.target is Player:
		var p := e.target as Player
		if not p.is_dashing() and p.global_position.distance_to(e.global_position) <= a.radius:
			p.slow_for(HOLD, a.field_slow_mult)


## 장판 그림: 반지름 radius 먹물 얼룩 + 테두리 (장판이 있을 때만).
static func draw(e: Enemy) -> void:
	var a := e.data.aura if e.data else null
	if a == null or a.field_slow_mult >= 1.0:
		return
	e.draw_circle(Vector2.ZERO, a.radius, Color(Ink.INK, a.field_alpha))
	e.draw_arc(Vector2.ZERO, a.radius, 0.0, TAU, 40, Color(Ink.INK, a.field_alpha * 2.0), 3.0)
