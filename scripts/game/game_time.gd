class_name GameTime
extends RefCounted
## 게임 시간 배율의 기준값. 레벨업 인장 고르기 동안 느리게(예: 0.35) 둔다.
## 히트스톱은 끝나면 1.0이 아니라 이 기준값으로 돌아간다 (느린 시간이 풀리지 않게).

static var base: float = 1.0
## 지금 걸린 멈춤이 끝나는 실제 시각(ms). 겹친 멈춤은 가장 긴 것이 끝날 때까지 이어진다
## (짧은 처치 멈춤이 정예·보스 슬로모션을 일찍 풀지 않게, Codex c6580b8 지적).
static var _stop_until_ms: int = 0
static var _tree: SceneTree
## 지금 걸린 멈춤의 배율 (base × 이 값).
static var _stop_scale: float = 1.0
## 긴 멈춤(컷인 느림 등) 안에 걸린 더 짧고 더 센 멈춤(히트스톱). 끝나면 긴 멈춤의 배율로 돌아간다.
static var _inner_until_ms: int = 0
static var _inner_scale: float = 1.0
## 긴 멈춤 끝의 되돌아오는 구간(ms): 이 동안 배율이 _stop_scale에서 1로 부드럽게 올라간다 (하데스 LerpTime).
static var _ramp_ms: int = 0


## 기준 배율 바꾸기 (인장 고르기 느린 시간). 걸려 있던 멈춤은 지우지 않고 새 기준 위에서 이어 간다
## (정예 처치 슬로모션 직후 인장이 열려도 슬로모션이 사라지지 않게, Codex 5fb5388 지적).
static func set_base(scale: float) -> void:
	base = scale
	_apply()


## 판 새로 시작·장면 다시 불러오기: 기준 1.0, 걸린 멈춤과 감시도 바로 끊는다.
static func reset() -> void:
	_stop_until_ms = 0
	_stop_scale = 1.0
	_inner_until_ms = 0
	_ramp_ms = 0
	_unwatch()
	set_base(1.0)


static func is_stopped() -> bool:
	return Time.get_ticks_msec() < _stop_until_ms


## 히트스톱·슬로모션: duration초(실제 시간) 동안 게임 시간을 base × scale로. tree가 없으면 아무 일도 안 함.
## ramp초(duration 안의 마지막 구간) 동안은 1로 부드럽게 돌아온다.
## 해제는 매 프레임 실제 시각으로 확인한다 (SceneTreeTimer의 ignore_time_scale는 느린 시간에서 일찍 끝났다).
static func stop(tree: SceneTree, duration: float, scale: float = 0.05, ramp: float = 0.0) -> void:
	if tree == null or duration <= 0.0:
		return
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if is_stopped() and until < _stop_until_ms:
		# 더 긴 멈춤이 이미 걸려 있다. 더 센 멈춤이면 그 안에서 잠깐만 건다 (컷인 중 히트스톱, Codex b11a3b0 지적).
		if scale < _stop_scale and until > _inner_until_ms:
			_inner_until_ms = until
			_inner_scale = scale
			_apply()
		return
	_stop_until_ms = until
	_stop_scale = scale
	_ramp_ms = int(clampf(ramp, 0.0, duration) * 1000.0)
	_apply()
	if _tree != tree:
		_unwatch()
		_tree = tree
	if not tree.process_frame.is_connected(_on_frame):
		tree.process_frame.connect(_on_frame)


## 지금 배율을 엔진에 반영 (순수 계산은 current_scale).
static func _apply() -> void:
	Engine.time_scale = base * current_scale(Time.get_ticks_msec())


## now 시각의 멈춤 배율: 멈춤이 없으면 1, 안쪽 멈춤이 살아 있으면 둘 중 더 센 쪽.
static func current_scale(now_ms: int) -> float:
	if now_ms >= _stop_until_ms:
		return 1.0
	var outer := _stop_scale
	if _ramp_ms > 0 and now_ms > _stop_until_ms - _ramp_ms:
		outer = lerpf(_stop_scale, 1.0, float(now_ms - (_stop_until_ms - _ramp_ms)) / _ramp_ms)
	return minf(outer, _inner_scale) if now_ms < _inner_until_ms else outer


static func _on_frame() -> void:
	if is_stopped():
		_apply()  # 안쪽 멈춤이 끝나면 긴 멈춤의 배율로
		return
	_stop_scale = 1.0
	_inner_until_ms = 0
	_ramp_ms = 0
	Engine.time_scale = base
	_unwatch()


static func _unwatch() -> void:
	if _tree and is_instance_valid(_tree) and _tree.process_frame.is_connected(_on_frame):
		_tree.process_frame.disconnect(_on_frame)
	_tree = null
