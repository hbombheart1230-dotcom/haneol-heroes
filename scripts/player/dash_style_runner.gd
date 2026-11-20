class_name DashStyleRunner
extends RefCounted
## 영웅별 회피(대시) 이펙트·도착 효과를 돌린다 (Player가 대시 시작·진행·끝에 부른다).

var style: DashStyleData
var _trail_cd: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
## 마지막 도착 효과 시각(초, 실제 시간).
var _last_effect: float = -INF


func _init(p_style: DashStyleData) -> void:
	style = p_style


func on_start(pos: Vector2, dir: Vector2) -> void:
	_start_pos = pos
	_dir = dir
	_trail_cd = 0.0
	if style and style.start_vfx:
		Feedback.vfx_burst(style.start_vfx, pos, dir)


## 대시 중 매 프레임: 자취를 남긴다.
func tick(delta: float, pos: Vector2) -> void:
	if style == null or style.trail_vfx == null:
		return
	_trail_cd -= delta
	if _trail_cd <= 0.0:
		_trail_cd = maxf(style.trail_interval, 0.01)
		Feedback.vfx_burst(style.trail_vfx, pos, -_dir)


func _draw_path(pos: Vector2) -> void:
	if _start_pos.distance_squared_to(pos) < 4.0:
		return
	if style.path_strip:
		Feedback.vfx_strip(style.path_strip, _start_pos, pos, style.path_width, style.path_time, style.path_time * 0.3)
	else:
		Feedback.vfx_stroke(_start_pos, pos, style.path_width * 0.35, style.path_time, style.path_color)


## 도착: 이펙트 + 범위 안 적에게 작은 효과 (end_cooldown마다 한 번). 효과 받은 적 수를 돌려준다.
## now_sec을 넘기지 않으면 실제 시간.
func on_end(pos: Vector2, enemies: Array, now_sec: float = -1.0) -> int:
	if style == null:
		return 0
	_draw_path(pos)  # 지나간 길은 대시마다
	var now := now_sec if now_sec >= 0.0 else Time.get_ticks_msec() / 1000.0
	if now - _last_effect < style.end_cooldown:
		return 0  # 연속 대시: 도착 그림·효과 모두 간격마다 한 번 (자취는 계속)
	_last_effect = now
	if style.end_vfx:
		Feedback.vfx_burst(style.end_vfx, pos, _dir)
	if style.end_radius <= 0.0:
		return 0
	var center := _start_pos if style.effect_at_start else pos
	var n := 0
	for e in enemies:
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or en.global_position.distance_to(center) > style.end_radius + en.body_radius:
			continue
		n += 1
		if style.end_push > 0.0:
			var off := en.global_position - center
			en.apply_knockback((off.normalized() if off.length_squared() > 0.01 else _dir) * style.end_push)
		if style.end_stun > 0.0:
			en.stun(style.end_stun)
		if style.end_slow_time > 0.0 and style.end_slow_factor < 1.0:
			en.slow(style.end_slow_factor, style.end_slow_time)
	return n
