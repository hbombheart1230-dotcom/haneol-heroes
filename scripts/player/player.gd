class_name Player
extends CharacterBody2D
## 플레이어 영웅 (공통). 이동, 대시(무영보, 충전식), 접촉 피해.
## 영웅별 수치는 hero(HeroData)에서 읽는다. 그리기는 PlayerView가 맡는다.

signal dash_started(direction: Vector2)
signal dash_ended
## 적 공격을 대시로 피했을 때 (회피 반격의 시작점).
signal evaded

## 지정하면 _ready에서 아래 수치를 이 데이터로 덮어쓴다.
@export var hero: HeroData
@export var move_speed: float = 340.0
## 대시 1회 이동 거리(px)와 지속 시간(초).
@export var dash_distance: float = 260.0
@export var dash_duration: float = 0.16
@export var max_dash_charges: int = 2
@export var dash_recharge_time: float = 1.2
## 피격 후 무적 시간(초).
@export var hurt_invuln_time: float = 0.6
## 플레이어가 벗어날 수 없는 영역 (월드 좌표). 크기가 0이면 제한 없음.
@export var arena_rect: Rect2 = Rect2()
@export var body_radius: float = 26.0
## 접촉 판정용 Area2D (적 몸체 레이어를 감지). 없으면 접촉 피해 없음.
@export var contact_sensor: Area2D

var move_input: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var dash: DashCharges
## health_hitbox_hurtbox 애드온의 Health. 씬에서 자식 "Health"로 둔다.
var health: Health

var _hurt_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_time_left: float = 0.0
## 마지막 대시가 끝난 뒤 지난 시간(초). 대시 직후 연계 입력 판정용.
var _since_dash_end: float = INF
## 마지막 대시 시작 후 지난 시간(초)과 시작 위치 (회피 판정용).
var _since_dash_start: float = INF
var _dash_start_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	dash = DashCharges.new(max_dash_charges, dash_recharge_time)


func _ready() -> void:
	health = get_node_or_null("Health") as Health
	if hero:
		apply_hero(hero)
	# 인스펙터 값이 _init 이후에 적용되므로 다시 생성한다.
	dash = DashCharges.new(max_dash_charges, dash_recharge_time)


func apply_hero(h: HeroData) -> void:
	hero = h
	move_speed = h.move_speed
	dash_distance = h.dash_distance
	dash_duration = h.dash_duration
	max_dash_charges = h.max_dash_charges
	dash_recharge_time = h.dash_recharge_time
	hurt_invuln_time = h.hurt_invuln_time
	if health:
		health.max = h.max_hp
		health.current = h.max_hp


func is_dashing() -> bool:
	return _dash_time_left > 0.0


## 대시 중이거나 피격 직후면 피해를 받지 않는다.
func is_invulnerable() -> bool:
	return is_dashing() or _hurt_cd > 0.0


func hurt_time_left() -> float:
	return _hurt_cd


func is_dead() -> bool:
	return health != null and health.is_dead()


## 접촉 피해 처리. amount는 이번 프레임 닿아 있는 적들 중 최대 피해량(없으면 0).
## 반환: 실제로 피해를 받았으면 true.
func apply_contact_damage(delta: float, amount: int) -> bool:
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)
	if amount <= 0 or health == null or is_dead() or is_invulnerable():
		return false
	health.damage(amount)
	_hurt_cd = hurt_invuln_time
	Feedback.player_hurt()
	return true


## 적 공격 타격. 무적이면 무시. 반환: 실제로 피해를 받았으면 true.
func apply_hit(amount: int) -> bool:
	if amount <= 0 or health == null or is_dead() or is_invulnerable():
		return false
	health.damage(amount)
	_hurt_cd = hurt_invuln_time
	Feedback.player_hurt()
	return true


## within초 안에 시작한 대시가 원(center, radius) 안에서 출발했으면 true (원 밖으로 빠져나간 회피).
func dashed_out_of(center: Vector2, radius: float, within: float) -> bool:
	return _since_dash_start <= within and _dash_start_pos.distance_to(center) <= radius


func register_evade() -> void:
	evaded.emit()


func _touching_damage() -> int:
	if contact_sensor == null:
		return 0
	var best := 0
	for b in contact_sensor.get_overlapping_bodies():
		if b is Enemy:
			best = maxi(best, (b as Enemy).contact_damage)
	return best


func get_dash_direction() -> Vector2:
	return _dash_dir


## 대시 중이거나, 대시가 끝난 지 window초 이내면 true.
func in_dash_link(window: float) -> bool:
	return is_dashing() or _since_dash_end <= window


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
	_since_dash_start = 0.0
	_dash_start_pos = global_position
	facing = _dash_dir
	dash_started.emit(_dash_dir)
	return true


## 이번 물리 프레임의 속도를 계산하고 대시·충전 타이머를 진행한다.
func compute_velocity(delta: float) -> Vector2:
	dash.update(delta)
	_since_dash_start += delta
	if not is_dashing():
		_since_dash_end += delta
		return move_input * move_speed
	var step := minf(delta, _dash_time_left)
	_dash_time_left -= delta
	var v := _dash_dir * (dash_distance / dash_duration) * (step / delta if delta > 0.0 else 0.0)
	if _dash_time_left <= 0.0:
		_dash_time_left = 0.0
		_since_dash_end = 0.0
		dash_ended.emit()
	return v


func _physics_process(delta: float) -> void:
	if is_dead():
		velocity = Vector2.ZERO
		return
	velocity = compute_velocity(delta)
	apply_contact_damage(delta, _touching_damage())
	move_and_slide()
	if arena_rect.has_area():
		global_position = global_position.clamp(arena_rect.position, arena_rect.end)
