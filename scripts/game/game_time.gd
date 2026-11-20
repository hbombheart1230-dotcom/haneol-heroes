class_name GameTime
extends RefCounted
## 게임 시간 배율의 기준값. 레벨업 인장 고르기 동안 느리게(예: 0.35) 둔다.
## 히트스톱은 끝나면 1.0이 아니라 이 기준값으로 돌아간다 (느린 시간이 풀리지 않게).

static var base: float = 1.0
## 겹친 히트스톱 중 가장 마지막 것만 시간을 되돌린다 (Codex e593772 지적).
static var _stop_token: int = 0


static func set_base(scale: float) -> void:
	base = scale
	Engine.time_scale = scale


static func reset() -> void:
	set_base(1.0)


## 히트스톱·슬로모션: duration초(실제 시간) 동안 게임 시간을 base × scale로. tree가 없으면 아무 일도 안 함.
static func stop(tree: SceneTree, duration: float, scale: float = 0.05) -> void:
	if tree == null or duration <= 0.0:
		return
	Engine.time_scale = base * scale
	_stop_token += 1
	var token := _stop_token
	var timer := tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void:
		if token == _stop_token:
			Engine.time_scale = base)
