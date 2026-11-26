class_name WaveRunner
extends RefCounted
## 물결 진행 (순수 로직, 하데스식): 숨 고르기 → 물결 (먼저 first_count, 남은 적이 next_when_left 이하일 때 이어서;
## refill_each면 물결 상한까지 채우고 한 마리 죽을 때마다 한 마리)
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


## 지금 내보낼 적 하나: [EnemyData] (null이면 정예), 없으면 빈 배열. cap = 화면 최대 (난이도 추가 포함).
func next_spawn(alive: int, cap: int) -> Array:
	if phase != Phase.RUN or _queue.is_empty() or _stagger > 0.0 or alive >= wave_cap(cap):
		return []
	var w: WaveData = data.waves[index]
	if _queue[0] == null and w.elite_when_left >= 0 and alive > w.elite_when_left:
		return []  # 중간 보스는 잡몹이 줄어든 뒤
	if _queue[0] is FormationData and alive + mini((_queue[0] as FormationData).count, wave_cap(cap)) > wave_cap(cap):
		return []  # 대형은 한꺼번에 count명: 동시 상한 안에 다 들어갈 자리가 날 때까지 기다린다
	if not data.refill_each:
		if _budget <= 0:
			return []
		_budget -= 1
	_stagger = data.spawn_stagger
	return [_queue.pop_front()]


## 이번 물결의 중간 우두머리 무리 (비면 무대 정예 하나).
func elite_group() -> Array:
	if index < 0 or index >= data.waves.size():
		return []
	return data.waves[index].elite_group


## 지금(방금 깬) 물결이 중간 우두머리 물결인지 (정예·무리).
func is_elite_wave() -> bool:
	if index < 0 or index >= data.waves.size():
		return false
	var w: WaveData = data.waves[index]
	return w.elite_last or not w.elite_group.is_empty()


## 이번 물결의 화면 최대: 물결 값(있으면) + 난이도 추가분 (cap − 무대 기본 최대), cap을 넘지 않게.
func wave_cap(cap: int) -> int:
	if index < 0 or index >= data.waves.size():
		return cap
	var w: WaveData = data.waves[index]
	var add := maxi(data.alive_cap_add, 0)  # 밀도 변형: 물결 값과 무대 상한에 같이
	return cap + add if w.max_alive <= 0 else mini(cap + add, w.max_alive + add + maxi(cap - data.max_alive, 0))


func _start(i: int) -> void:
	if i >= data.waves.size():
		phase = Phase.BOSS_WAIT
		_timer = data.boss_delay
		return
	index = i
	phase = Phase.RUN
	var w: WaveData = data.waves[i]
	_queue = WaveSwarm.expand(w.enemies, data.melee_count_mult if w.swarm else 1.0)
	for k in range(w.formations.size() - 1, -1, -1):  # 대형 묶음을 차례 자리에 (뒤에서부터 넣어 앞 자리가 밀리지 않게)
		var at := w.formation_after[k] if k < w.formation_after.size() else 0
		_queue.insert(clampi(at, 0, _queue.size()), w.formations[k])
	if w.elite_last:
		_queue.append(null)
	_budget = mini(maxi(w.first_count, 1), _queue.size())
