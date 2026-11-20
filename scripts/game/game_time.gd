class_name GameTime
extends RefCounted
## 게임 시간 배율의 기준값. 레벨업 인장 고르기 동안 느리게(예: 0.35) 둔다.
## 히트스톱은 끝나면 1.0이 아니라 이 기준값으로 돌아간다 (느린 시간이 풀리지 않게).

static var base: float = 1.0
## 지금 걸린 멈춤이 끝나는 실제 시각(ms). 겹친 멈춤은 가장 긴 것이 끝날 때까지 이어진다
## (짧은 처치 멈춤이 정예·보스 슬로모션을 일찍 풀지 않게, Codex c6580b8 지적).
static var _stop_until_ms: int = 0
static var _tree: SceneTree


static func set_base(scale: float) -> void:
	base = scale
	Engine.time_scale = scale
	_stop_until_ms = 0


static func reset() -> void:
	set_base(1.0)


static func is_stopped() -> bool:
	return Time.get_ticks_msec() < _stop_until_ms


## 히트스톱·슬로모션: duration초(실제 시간) 동안 게임 시간을 base × scale로. tree가 없으면 아무 일도 안 함.
## 해제는 매 프레임 실제 시각으로 확인한다 (SceneTreeTimer의 ignore_time_scale는 느린 시간에서 일찍 끝났다).
static func stop(tree: SceneTree, duration: float, scale: float = 0.05) -> void:
	if tree == null or duration <= 0.0:
		return
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if is_stopped() and until < _stop_until_ms:
		return  # 더 긴 멈춤이 이미 걸려 있다
	_stop_until_ms = until
	Engine.time_scale = base * scale
	if _tree != tree:
		_unwatch()
		_tree = tree
	if not tree.process_frame.is_connected(_on_frame):
		tree.process_frame.connect(_on_frame)


static func _on_frame() -> void:
	if is_stopped():
		return
	Engine.time_scale = base
	_unwatch()


static func _unwatch() -> void:
	if _tree and is_instance_valid(_tree) and _tree.process_frame.is_connected(_on_frame):
		_tree.process_frame.disconnect(_on_frame)
	_tree = null
