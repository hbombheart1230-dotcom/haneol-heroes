class_name SweepRun
extends SkillRun
## 휘감는 기술 (해룡참·해시계): 붓이 시작 방향부터 한 바퀴 도는 동안, 지나가는 자리의 적을 차례로 벤다.
## 대상·피해는 발동 순간 정해지고 (밸런스 그대로), 맞는 "순간"만 각도에 따라 sweep초 안에 나뉜다.
## 한꺼번에 맞던 것이 차르륵 이어 맞아 명중음·멈춤·자국이 따로따로 난다.

## 적마다 strike.call(enemy) -> bool (실제로 맞았으면 true).
var strike: Callable
## 눈금이 지날 때마다 on_tick.call(i) (해시계 눈금 번쩍임·소리). 비면 없음.
var on_tick: Callable
## 끝날 때 한 번 on_done.call(hits) (마지막 큰 멈춤). 비면 없음.
var on_done: Callable
var _targets: Array[Enemy] = []
var _delays: PackedFloat32Array = PackedFloat32Array()
var _done: PackedByteArray = PackedByteArray()
var _tick_count: int = 0
var _next_tick: int = 0
var _sweep: float = 0.0
var _t: float = 0.0


## 시작 각도(라디안)에서 dir_sign 쪽(1 = 화면 시계 방향)으로 sweep초에 한 바퀴. 0도(시작 방향)의 적은 바로 맞는다.
static func delay_of(center: Vector2, pos: Vector2, start_angle: float, dir_sign: float, sweep: float) -> float:
	var off := pos - center
	if off.length_squared() < 0.01 or sweep <= 0.0:
		return 0.0
	var a := off.angle() - start_angle
	if dir_sign < 0.0:
		a = -a
	return sweep * fposmod(a, TAU) / TAU


func _init(p_strike: Callable, center: Vector2, targets: Array[Enemy], start_angle: float, dir_sign: float,
		sweep: float, ticks: int = 0, p_on_tick: Callable = Callable(), p_on_done: Callable = Callable()) -> void:
	strike = p_strike
	on_tick = p_on_tick
	on_done = p_on_done
	_sweep = maxf(sweep, 0.0)
	_tick_count = maxi(ticks, 0)
	_targets = targets
	announce_hits = targets.size()  # 발동 소리·흔들림은 누르는 순간 (SkillCaster)
	_delays.resize(targets.size())
	_done.resize(targets.size())
	for i in targets.size():
		_delays[i] = delay_of(center, targets[i].global_position, start_angle, dir_sign, _sweep)
		_done[i] = 0
	tick(0.0)  # 시작 방향의 적은 누르는 순간 바로


func pending() -> int:
	var n := 0
	for d in _done:
		n += 1 - d
	return n


func tick(delta: float) -> bool:
	if finished:
		return true
	_t += delta
	while _next_tick < _tick_count and _t >= _sweep * float(_next_tick) / float(_tick_count):
		if on_tick.is_valid():
			on_tick.call(_next_tick)
		_next_tick += 1
	for i in _targets.size():
		if _done[i] == 0 and _t >= _delays[i]:
			_done[i] = 1
			var en := _targets[i]
			if is_instance_valid(en) and strike.call(en):
				hits += 1
	finished = _t >= _sweep and _next_tick >= _tick_count and pending() == 0
	if finished and on_done.is_valid():
		var cb := on_done
		on_done = Callable()
		cb.call(hits)
	return finished
