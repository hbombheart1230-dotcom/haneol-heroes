class_name HordeDirector
extends RefCounted
## 무리 이벤트 (Vampire Survivors·Halls of Torment식): 일정 시간마다 포위 → 휩쓸기 → 떼 순서로.
## 위치 계산은 순수 로직 (테스트용), 실제 생성은 EnemySpawner.spawn_at.

enum Kind { RING, WALL, SWARM }

var ai: EnemyAIData
var _next: float = 0.0
var _index: int = 0


func _init(p_ai: EnemyAIData) -> void:
	ai = p_ai if p_ai else EnemyAIData.new()
	_next = ai.horde_first


## 이번 시각에 이벤트가 열리면 그 종류, 아니면 -1.
func tick(elapsed: float) -> int:
	if ai.horde_interval <= 0.0 or ai.horde_first <= 0.0 or elapsed < _next:
		return -1
	_next = elapsed + ai.horde_interval
	var kind := _index % 3
	_index += 1
	return kind


## 포위: center 둘레 고르게.
func ring_points(center: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(ai.ring_count, 1)
	for i in n:
		out.append(center + Vector2.from_angle(TAU * i / n) * ai.ring_radius)
	return out


## 휩쓸기: side 쪽 wall_distance에 side에 수직인 한 줄. 그 줄이 -side 방향으로 지나간다.
func wall_points(center: Vector2, side: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := side.normalized()
	var start := center + s * ai.wall_distance
	var n := maxi(ai.wall_count, 1)
	for i in n:
		out.append(start + s.orthogonal() * (i - (n - 1) * 0.5) * ai.wall_spacing)
	return out


## 떼: side 쪽 한 덩어리 (흩어져 들어온다).
func swarm_points(center: Vector2, side: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var base := center + side.normalized() * ai.ring_radius
	for i in maxi(ai.swarm_count, 1):
		out.append(base + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * ai.swarm_spread)
	return out
