class_name PlayerView
extends Node2D
## 플레이어 임시 그래픽 (부모 Player를 읽어서 그린다). 정식 그래픽 교체 시 이 노드만 바꾼다.

@export var player: Player

## 대시 잔상용 최근 위치 (월드 좌표).
var _trail: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	if player == null:
		player = get_parent() as Player


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	if player.is_dashing():
		_trail.append(player.global_position)
		if _trail.size() > 8:
			_trail.remove_at(0)
	elif _trail.size() > 0:
		_trail.remove_at(0)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var r := player.body_radius
	# 대시 잔상 (푸른 해류)
	for i in _trail.size():
		var a := float(i + 1) / float(_trail.size() + 1)
		draw_circle(to_local(_trail[i]), r * (0.6 + 0.4 * a), Color(0.3, 0.7, 1.0, 0.35 * a))
	# 그림자
	draw_set_transform(Vector2(0, r * 0.8), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 몸체
	var base := player.hero.body_color if player.hero else Color(0.15, 0.4, 0.8)
	var body_color := Color(0.55, 0.85, 1.0) if player.is_dashing() else base
	var hurt := player.hurt_time_left()
	if hurt > 0.0 and not player.is_dashing() and int(hurt * 20.0) % 2 == 0:
		body_color = Color(1.0, 0.5, 0.5)
	draw_circle(Vector2(0, -r * 0.4), r, body_color)
	# 바라보는 방향 (검)
	var tip := Vector2(0, -r * 0.4) + player.facing * r * 1.6
	draw_line(Vector2(0, -r * 0.4), tip, Color(0.85, 0.95, 1.0), 4.0)
