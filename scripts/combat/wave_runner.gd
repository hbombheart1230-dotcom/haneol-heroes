class_name WaveRunner
extends RefCounted
## 물결 진행 (순수 로직, 하데스식): 숨 고르기 → 물결 (먼저 first_count, 남은 적이 next_when_left 이하일 때 이어서)
## → 다 죽으면 물결 끝 → … → 마지막 물결 뒤 보스. 강화 고르는 동안(hold)은 다음 물결을 기다린다.

enum Phase { GAP, RUN, BOSS_WAIT, BOSS }
enum Event { NONE, CLEARED, BOSS }

var data: WaveSetData
var index: int = -1
var phase: Phase = Phase.GAP
## 이번 물결에서 아직 안 나온 적 (null = 정예).
var _queue: Array = []
var _budget: int = 0
var _timer: float = 0.0
var _stagger: float = 0.0


func _init(p_data: WaveSetData, first_delay: float = 0.5) -> void:
	data = p_data
	_timer = first_delay


func is_fighting() -> bool:
	return phase == Phase.RUN


func is_last() -> bool:
	return index >= data.waves.size() - 1


## alive = 살아 있는 적 + 예고 중인 자리. hold = 강화 고르는 중.
func tick(delta: float, alive: int, hold: bool) -> Event:
	_stagger = maxf(_stagger - delta, 0.0)
	match phase:
		Phase.GAP:
			if not hold:
				_timer -= delta
				if _timer <= 0.0:
					_start(index + 1)
		Phase.RUN:
			if _queue.is_empty() and alive <= 0:
				if is_last():
					phase = Phase.BOSS_WAIT
					_timer = data.boss_delay
				else:
					phase = Phase.GAP
					_timer = data.gap_time
				return Event.CLEARED
			if _budget <= 0 and not _queue.is_empty() and alive <= data.next_when_left:
				_budget = mini(maxi(data.waves[index].first_count, 1), _queue.size())
		Phase.BOSS_WAIT:
			if not hold:
				_timer -= delta
				if _timer <= 0.0:
					phase = Phase.BOSS
					return Event.BOSS
	return Event.NONE


## 지금 내보낼 적 하나: [EnemyData] (null이면 정예), 없으면 빈 배열. cap = 화면 최대.
func next_spawn(alive: int, cap: int) -> Array:
	if phase != Phase.RUN or _budget <= 0 or _queue.is_empty() or _stagger > 0.0 or alive >= cap:
		return []
	_budget -= 1
	_stagger = data.spawn_stagger
	return [_queue.pop_front()]


func _start(i: int) -> void:
	if i >= data.waves.size():
		phase = Phase.BOSS_WAIT
		_timer = data.boss_delay
		return
	index = i
	phase = Phase.RUN
	var w: WaveData = data.waves[i]
	_queue = w.enemies.duplicate()
	if w.elite_last:
		_queue.append(null)
	_budget = mini(maxi(w.first_count, 1), _queue.size())
