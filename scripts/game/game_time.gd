class_name GameTime
extends RefCounted
## 게임 시간 배율의 기준값. 레벨업 인장 고르기 동안 느리게(예: 0.35) 둔다.
## 히트스톱은 끝나면 1.0이 아니라 이 기준값으로 돌아간다 (느린 시간이 풀리지 않게).

static var base: float = 1.0


static func set_base(scale: float) -> void:
	base = scale
	Engine.time_scale = scale


static func reset() -> void:
	set_base(1.0)
