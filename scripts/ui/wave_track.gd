class_name WaveTrack
extends RefCounted
## 물결 진행 표시의 상태 (순수 로직): 한 판 = 물결들 + 마지막 우두머리. 점마다 종류(보통·중간 우두머리·우두머리)와
## 상태(남음·지금·끝냄). 물결 수는 무대 데이터(WaveSetData.waves)에서 읽는다 (늘어나도 그대로).

enum Kind { NORMAL, ELITE, BOSS }
enum State { FUTURE, CURRENT, CLEARED }


## 점 하나마다의 종류. 마지막은 우두머리.
static func kinds(set: WaveSetData) -> PackedInt32Array:
	var out := PackedInt32Array()
	if set == null:
		return out
	for w in set.waves:
		out.append(Kind.ELITE if w.elite_last or w.elite_when_left >= 0 or not w.elite_group.is_empty() else Kind.NORMAL)
	out.append(Kind.BOSS)
	return out


## 점마다 지금 상태. 숨 고르기 중에는 끝낸 물결까지만 차 있고 "지금" 점은 없다.
static func states(runner: WaveRunner) -> PackedInt32Array:
	var out := PackedInt32Array()
	if runner == null:
		return out
	var n := runner.data.waves.size() + 1
	out.resize(n)
	var cleared := cleared_count(runner)
	for i in n:
		out[i] = State.CLEARED if i < cleared else State.FUTURE
	var cur := current_index(runner)
	if cur >= 0 and cur < n:
		out[cur] = State.CURRENT
	return out


## 끝낸 물결 수.
static func cleared_count(runner: WaveRunner) -> int:
	if runner == null:
		return 0
	var waves := runner.data.waves.size()
	match runner.phase:
		WaveRunner.Phase.RUN:
			return clampi(runner.index, 0, waves)
		WaveRunner.Phase.GAP:
			return clampi(runner.index + 1, 0, waves)
	return waves  # 우두머리 기다림·우두머리: 물결은 다 끝


## 지금 싸우는 점 (없으면 -1).
static func current_index(runner: WaveRunner) -> int:
	if runner == null:
		return -1
	match runner.phase:
		WaveRunner.Phase.RUN:
			return runner.index
		WaveRunner.Phase.BOSS:
			return runner.data.waves.size()
	return -1


## 글자 "물결 N/M"의 N: 싸우는 중이면 그 번호, 쉬는 중이면 다음 번호 (1부터).
static func shown_number(runner: WaveRunner) -> int:
	if runner == null:
		return 0
	var total := runner.data.waves.size() + 1
	var cur := current_index(runner)
	return clampi((cur if cur >= 0 else cleared_count(runner)) + 1, 1, total)
