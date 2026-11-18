class_name Player
extends CharacterBody2D
## 이순신 (P0 플레이어블). P0-A 범위: 이동 + 대시(무영보, 2회 충전).
## 임시 그래픽은 _draw()로 그린다.

signal dash_started(direction: Vector2)
signal dash_ended

@export var move_speed: float = 340.0
## 대시 1회 이동 거리(px)와 지속 시간(초). 실험 초기값.
@export var dash_distance: float = 260.0
@export var dash_duration: float = 0.16
@export var max_dash_charges: int = 2
@export var dash_recharge_time: float = 1.2
## 플레이어가 벗어날 수 없는 영역 (월드 좌표). 크기가 0이면 제한 없음.
@export var arena_rect: Rect2 = Rect2()
@export var body_radius: float = 26.0

var move_input: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var dash: DashCharges

var _dash_dir: Vector2 = Vector2.ZERO
var _dash_time_left: float = 0.0
## 대시 잔상용 최근 위치 (월드 좌표).
var _trail: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	dash = DashCharges.new(max_dash_charges, dash_recharge_time)


func _ready() -> void:
	# 인스펙터 값이 _init 이후에 적용되므로 다시 생성한다.
	dash = DashCharges.new(max_dash_charges, dash_recharge_time)


func is_dashing() -> bool:
	return _dash_time_left > 0.0


## P0-B 피격 판정에서 사용. 현재는 대시 중 무적.
func is_invulnerable() -> bool:
	return is_dashing()


func get_dash_direction() -> Vector2:
	return _dash_dir


func set_move_input(v: Vector2) -> void:
	move_input = v.limit_length(1.0)
	if move_input.length_squared() > 0.0001 and not is_dashing():
		facing = move_input.normalized()


## 방향이 0이면 현재 이동 방향, 그것도 없으면 바라보는 방향으로 대시한다.
## 반환: 대시가 시작되면 true.
func request_dash(direction: Vector2 = Vector2.ZERO) -> bool:
	if is_dashing():
		return false
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = move_input if move_input.length_squared() > 0.0001 else facing
	if not dash.try_consume():
		return false
	_dash_dir = dir.normalized()
	_dash_time_left = dash_duration
	facing = _dash_dir
	dash_started.emit(_dash_dir)
	return true


## 이번 물리 프레임의 속도를 계산하고 대시·충전 타이머를 진행한다.
func compute_velocity(delta: float) -> Vector2:
	dash.update(delta)
	if not is_dashing():
		return move_input * move_speed
	var step := minf(delta, _dash_time_left)
	_dash_time_left -= delta
	var v := _dash_dir * (dash_distance / dash_duration) * (step / delta if delta > 0.0 else 0.0)
	if _dash_time_left <= 0.0:
		_dash_time_left = 0.0
		dash_ended.emit()
	return v


func _physics_process(delta: float) -> void:
	var was_dashing := is_dashing()
	velocity = compute_velocity(delta)
	move_and_slide()
	if arena_rect.has_area():
		global_position = global_position.clamp(arena_rect.position, arena_rect.end)
	_update_trail(was_dashing)
	queue_redraw()


func _update_trail(was_dashing: bool) -> void:
	if was_dashing:
		_trail.append(global_position)
		if _trail.size() > 8:
			_trail.remove_at(0)
	elif _trail.size() > 0:
		_trail.remove_at(0)


func _draw() -> void:
	# 대시 잔상 (푸른 해류)
	for i in _trail.size():
		var a := float(i + 1) / float(_trail.size() + 1)
		draw_circle(to_local(_trail[i]), body_radius * (0.6 + 0.4 * a), Color(0.3, 0.7, 1.0, 0.35 * a))
	# 그림자
	draw_set_transform(Vector2(0, body_radius * 0.8), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, body_radius * 1.1, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 몸체
	var body_color := Color(0.55, 0.85, 1.0) if is_dashing() else Color(0.15, 0.4, 0.8)
	draw_circle(Vector2(0, -body_radius * 0.4), body_radius, body_color)
	# 바라보는 방향 (검)
	var tip := Vector2(0, -body_radius * 0.4) + facing * body_radius * 1.6
	draw_line(Vector2(0, -body_radius * 0.4), tip, Color(0.85, 0.95, 1.0), 4.0)
