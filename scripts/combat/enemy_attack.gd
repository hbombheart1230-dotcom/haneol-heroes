class_name EnemyAttack
extends RefCounted
## 적의 예고 공격 상태 머신 (순수 로직). 대기 → 예고 → 타격 → 경직 → 대기.
## 타격 순간 플레이어가 대시로 피했으면 "회피 성공"을 알린다 (회피 반격의 시작점).

enum State { READY, WINDUP, RECOVER }
enum Result { NONE, HIT, EVADED, MISSED }

## 동시에 예고 중인 공격 수 제한 (적 30마리가 한꺼번에 예고하지 않게).
static var active_windups: int = 0
static var max_concurrent: int = 4
## 대시로 원에서 빠져나간 것을 회피로 인정하는 시간(초).
static var escape_window: float = 0.3

var data: EnemyAttackData
var state: State = State.READY
var target_point: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _cooldown: float = 0.0


func _init(p_data: EnemyAttackData, initial_cooldown: float = 0.0) -> void:
	data = p_data
	_cooldown = initial_cooldown


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
		State.WINDUP:
			_timer -= delta
			if _timer <= 0.0:
				var r := strike(player)
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


## 타격 판정. 대시 무적으로 원 안에서 버텼거나, 직전에 원 안에서 대시로 빠져나갔으면 회피.
func strike(player: Player) -> Result:
	if player == null or player.is_dead():
		return Result.MISSED
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
