class_name PlayerView
extends Node2D
## 플레이어 임시 그래픽: 수묵풍 실루엣 (부모 Player를 읽어서 그린다). 정식 그래픽 교체 시 이 노드만 바꾼다.
## 쪽빛 두루마기 + 갓 + 푸른 검. 대시 잔상은 물빛 먹 번짐.

@export var player: Player

## 대시 잔상용 최근 위치 (월드 좌표).
var _trail: PackedVector2Array = PackedVector2Array()
var _t: float = 0.0


func _ready() -> void:
	if player == null:
		player = get_parent() as Player


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
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
	# 대시 잔상: 물빛 먹 번짐
	for i in _trail.size():
		var a := float(i + 1) / float(_trail.size() + 1)
		Ink.blob(self, to_local(_trail[i]) + Vector2(0, -r * 0.4), r * (0.5 + 0.4 * a), Color(Ink.WATER, 0.28 * a), i)
	Ink.shadow(self, Vector2(0, r * 0.8), r * 1.1)
	var robe := player.hero.body_color if player.hero else Ink.INDIGO
	if player.is_dashing():
		robe = Ink.WATER
	if player.skill_invuln_left() > 0.0 and not player.is_dashing():
		robe = Ink.GOLD  # 회피 무적: 금빛
	var hurt := player.hurt_time_left()
	if hurt > 0.0 and not player.is_dashing() and int(hurt * 20.0) % 2 == 0:
		robe = Ink.SEAL
	var sway := sin(_t * 6.0) * 2.0 * minf(player.move_input.length(), 1.0)
	# 두루마기 (아래가 넓은 덩어리)
	Ink.blob(self, Vector2(sway * 0.5, -r * 0.2), r * 0.95, robe, 2.0, 0.14, 1.15)
	# 얼굴과 갓
	var head := Vector2(sway, -r * 1.25)
	draw_circle(head, r * 0.38, Color(0.95, 0.88, 0.76))
	Ink.blob(self, head + Vector2(0, -r * 0.12), r * 0.75, Ink.INK, 5.0, 0.05, 0.22)  # 갓 챙
	draw_circle(head + Vector2(0, -r * 0.32), r * 0.3, Ink.INK)  # 갓 모자
	# 검: 바라보는 방향으로 먹 획 + 푸른 날
	var hand := Vector2(0, -r * 0.4) + player.facing * r * 0.6
	var tip := hand + player.facing * r * 1.4
	Ink.stroke(self, hand, tip, 7.0, Ink.INK)
	draw_line(hand + player.facing * 4.0, tip, Color(0.75, 0.9, 1.0), 2.0)
