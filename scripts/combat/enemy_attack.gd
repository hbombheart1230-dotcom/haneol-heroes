class_name EnemyAttack
extends RefCounted
## 적의 예고 공격 상태 머신 (순수 로직). 대기 → 예고 → 타격 → 경직 → 대기.
## 회피 성공(회피 반격의 시작점):
## - 예고 중 대시로 원 밖으로 나가는 그 순간 즉시 (무적·반격이 바로 시작, 실기기 피드백)
## - 또는 타격 순간 대시 무적으로 원 안에서 버텼을 때

enum State { READY, WINDUP, RECOVER }
enum Result { NONE, HIT, EVADED, MISSED, FIRED }

## 동시에 예고 중인 공격 수 제한 (적 30마리가 한꺼번에 예고하지 않게).
static var active_windups: int = 0
static var max_concurrent: int = 4
## 대시로 원에서 빠져나간 것을 회피로 인정하는 시간(초).
static var escape_window: float = 0.3

var data: EnemyAttackData
var state: State = State.READY
var target_point: Vector2 = Vector2.ZERO
## 사격(SHOOT) 조준 방향과 출발점.
var aim_dir: Vector2 = Vector2.RIGHT
var aim_origin: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _cooldown: float = 0.0
## 이번 예고에서 이미 회피 처리됐는지 (타격 때 다시 처리하지 않음).
var _evaded: bool = false
var _was_inside: bool = false


func _init(p_data: EnemyAttackData, initial_cooldown: float = 0.0) -> void:
	data = p_data
	_cooldown = initial_cooldown


func is_shoot() -> bool:
	return data.kind == EnemyAttackData.Kind.SHOOT


func is_busy() -> bool:
	return state != State.READY


## 0~1 예고 진행률 (예고 중이 아니면 0).
func windup_ratio() -> float:
	return clampf(1.0 - _timer / maxf(data.windup, 0.001), 0.0, 1.0) if state == State.WINDUP else 0.0


## 반환: 이번 틱의 결과 (타격이 일어난 틱에만 NONE 이외).
func tick(delta: float, self_pos: Vector2, player: Player) -> Result:
	_cooldown = maxf(_cooldown - delta, 0.0)
	match state:
		State.READY:
			if player and not player.is_dead() and _cooldown <= 0.0 \
					and self_pos.distance_to(player.global_position) <= data.trigger_range \
					and active_windups < max_concurrent:
				state = State.WINDUP
				active_windups += 1
				_timer = data.windup
				target_point = player.global_position
				aim_origin = self_pos
				var to_p := player.global_position - self_pos
				aim_dir = to_p.normalized() if to_p.length_squared() > 0.01 else Vector2.DOWN
				_evaded = false
				_was_inside = true
		State.WINDUP:
			if is_shoot():
				aim_origin = self_pos
			else:
				_check_escape(player)
			_timer -= delta
			if _timer <= 0.0:
				var r := Result.FIRED if is_shoot() else strike(player)
				_end_windup()
				state = State.RECOVER
				_timer = data.recovery
				_cooldown = data.cooldown
				return r
		State.RECOVER:
			_timer -= delta
			if _timer <= 0.0:
				state = State.READY
	return Result.NONE


## 예고 중 원 밖으로 대시해 나가는 순간 바로 회피 처리.
func _check_escape(player: Player) -> void:
	if _evaded or player == null or player.is_dead():
		return
	var inside := player.global_position.distance_to(target_point) <= data.radius
	if _was_inside and not inside and (player.is_dashing() or player.dashed_out_of(target_point, data.radius, escape_window)):
		_evaded = true
		player.register_evade()
	_was_inside = inside


## 타격 판정. 이미 대시로 빠져나갔거나, 대시 무적으로 원 안에서 버텼으면 회피.
func strike(player: Player) -> Result:
	if player == null or player.is_dead():
		return Result.MISSED
	if _evaded:
		return Result.EVADED
	var inside := player.global_position.distance_to(target_point) <= data.radius
	if inside and player.is_dashing():
		player.register_evade()
		return Result.EVADED
	if not inside and player.dashed_out_of(target_point, data.radius, escape_window):
		player.register_evade()
		return Result.EVADED
	if inside:
		return Result.HIT if player.apply_hit(data.damage) else Result.MISSED
	return Result.MISSED


## 적이 죽거나 사라질 때 예고 슬롯을 돌려준다.
func cancel() -> void:
	_end_windup()
	state = State.READY


func _end_windup() -> void:
	if state == State.WINDUP:
		active_windups = maxi(active_windups - 1, 0)
