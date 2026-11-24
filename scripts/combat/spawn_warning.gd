class_name SpawnWarning
extends Node2D
## 적 등장 예고: 그 자리에 먹 번짐 원이 퍼진 뒤 time초 뒤 done을 부른다 (그동안 적은 없다 → 맞지 않음).
## 그림은 CombatFeelData.spawn_warn_art (없으면 붓 고리 ring_art).

var time: float = 0.6
var done: Callable
var _t: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_seed = randf() * TAU
	z_index = -1  # 적·영웅 아래 바닥에


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= time:
		set_physics_process(false)
		if done.is_valid():
			done.call()
		queue_free()


func _draw() -> void:
	var feel := Feedback.feel_data()
	var tex: Texture2D = feel.spawn_warn_art if feel.spawn_warn_art else feel.ring_art
	var k := clampf(_t / maxf(time, 0.001), 0.0, 1.0)
	var size := feel.spawn_warn_size * (0.45 + 0.55 * k)
	var col := Color(Ink.INK, 0.25 + 0.5 * k)
	if tex:
		draw_set_transform(Vector2.ZERO, _seed + k * 0.6, Vector2(1.0, 0.55))  # 바닥에 눕힌 원
		draw_texture_rect(tex, Rect2(-size * 0.5, -size * 0.5, size, size), false, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_arc(Vector2.ZERO, size * 0.4, 0.0, TAU, 24, col, 4.0)
