class_name FireGrid
extends RefCounted
## 들불 칸들 (순수 로직): 마른 풀 → 불 → 재 → (다시 자라) 마른 풀. 불은 spread_delay마다 네 이웃으로 번진다.

enum State { DRY, BURNING, ASH }

var data: FireData
var at := PackedVector2Array()
var state := PackedInt32Array()
## 불: 붙은 뒤 흐른 시간, 재: 재가 된 뒤 흐른 시간.
var age := PackedFloat32Array()
var _index := {}
var _near: Array[PackedInt32Array] = []


func _init(d: FireData) -> void:
	data = d
	for p in d.patches:
		var r := p.z
		var c0 := Vector2i(floori((p.x - r) / d.cell), floori((p.y - r) / d.cell))
		var c1 := Vector2i(ceili((p.x + r) / d.cell), ceili((p.y + r) / d.cell))
		for y in range(c0.y, c1.y + 1):
			for x in range(c0.x, c1.x + 1):
				var k := Vector2i(x, y)
				var center := (Vector2(k) + Vector2(0.5, 0.5)) * d.cell
				if _index.has(k) or center.distance_to(Vector2(p.x, p.y)) > r:
					continue
				_index[k] = at.size()
				at.append(center)
				state.append(State.DRY)
				age.append(0.0)
	for i in at.size():
		var k := _key(at[i])
		var n := PackedInt32Array()
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _index.has(k + o):
				n.append(_index[k + o])
		_near.append(n)


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / data.cell), floori(p.y / data.cell))


func size() -> int:
	return at.size()


## p가 든 칸 번호 (풀밭 밖이면 -1).
func cell_at(p: Vector2) -> int:
	return _index.get(_key(p), -1)


func burning_at(p: Vector2) -> bool:
	var i := cell_at(p)
	return i >= 0 and state[i] == State.BURNING


func count(s: State) -> int:
	var n := 0
	for v in state:
		if v == s:
			n += 1
	return n


## 반경 안 마른 칸에 불. 반환: 새로 붙은 칸 수.
func ignite(p: Vector2, r: float) -> int:
	var n := 0
	for i in at.size():
		if state[i] == State.DRY and at[i].distance_to(p) <= r + data.cell * 0.5:
			state[i] = State.BURNING
			age[i] = 0.0
			n += 1
	return n


## 반경 안 불·마른 풀을 재로 (물에 젖어 그 판 동안 regrow_time까지 다시 안 붙는다). 반환: 꺼진 불 칸 수.
func douse(p: Vector2, r: float) -> int:
	var n := 0
	for i in at.size():
		if state[i] != State.ASH and at[i].distance_to(p) <= r + data.cell * 0.5:
			if state[i] == State.BURNING:
				n += 1
			state[i] = State.ASH
			age[i] = 0.0
	return n


## dt초 흐름: 번지기·타 버리기·다시 자라기. 반환: 이번에 새로 붙은 칸들.
func step(dt: float) -> PackedInt32Array:
	var spread := PackedInt32Array()
	for i in at.size():
		match state[i]:
			State.BURNING:
				var before := age[i]
				age[i] += dt
				if before < data.spread_delay and age[i] >= data.spread_delay:
					for j in _near[i]:
						if state[j] == State.DRY and not spread.has(j):
							spread.append(j)
				if age[i] >= data.burn_time:
					state[i] = State.ASH
					age[i] = 0.0
			State.ASH:
				age[i] += dt
				if age[i] >= data.regrow_time:
					state[i] = State.DRY
					age[i] = 0.0
	for j in spread:
		state[j] = State.BURNING
		age[j] = 0.0
	return spread


## 곧 불이 옮겨붙을 마른 칸인가 (이웃 불이 smoke_time 안에 번진다) — 연기로 미리 보인다.
func smoking(i: int) -> bool:
	if state[i] != State.DRY:
		return false
	for j in _near[i]:
		if state[j] == State.BURNING and age[j] >= data.spread_delay - data.smoke_time and age[j] < data.spread_delay:
			return true
	return false


## 불씨 자리: 화면 안 마른 칸 중 반경 안 적이 가장 많은 칸 (같으면 영웅에게 가까운 칸). 화면 안에 없으면 -1.
func pick_ember(view: Rect2, hero: Vector2, enemies: PackedVector2Array, r: float) -> int:
	var best := -1
	var best_score := -INF
	for i in at.size():
		if state[i] != State.DRY or not view.has_point(at[i]):
			continue
		var n := 0
		for e in enemies:
			if e.distance_to(at[i]) <= r:
				n += 1
		var score := float(n) - at[i].distance_to(hero) / 100000.0
		if score > best_score:
			best_score = score
			best = i
	return best
