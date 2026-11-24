class_name LanePlan
extends RefCounted
## 가로줄 공격의 순수 계산: 어느 줄을 고를지, 누가 줄에 걸치는지, 북을 언제 칠지.


## 줄 고르기: 화면 안(위아래 margin 안쪽) 후보 중 줄에 걸친 적이 가장 많은 줄. 같으면 영웅에게 가까운 줄.
## 화면 안 후보가 없으면 영웅에게 가장 가까운 줄. avoid(직전 줄)는 후보가 둘 이상이면 뺀다. 없으면 -1.
static func pick_row(rows: PackedVector3Array, view: Rect2, margin: float, hero: Vector2,
		enemies: PackedVector2Array, half_width: float, avoid: int = -1) -> int:
	var cands: Array[int] = []
	for i in rows.size():
		var y := rows[i].x
		if y >= view.position.y + margin and y <= view.end.y - margin:
			cands.append(i)
	if cands.size() > 1 and cands.has(avoid):
		cands.erase(avoid)
	if cands.is_empty():
		return nearest_row(rows, hero.y)
	var best := -1
	var best_score := -INF
	for i in cands:
		var n := 0
		for e in enemies:
			if in_lane(rows[i], half_width, e, 0.0):
				n += 1
		var score := float(n) - absf(rows[i].x - hero.y) / 100000.0
		if score > best_score:
			best_score = score
			best = i
	return best


static func nearest_row(rows: PackedVector3Array, y: float) -> int:
	var best := -1
	var best_d := INF
	for i in rows.size():
		var d := absf(rows[i].x - y)
		if d < best_d:
			best_d = d
			best = i
	return best


## 점 p(몸 반지름 r)가 줄(row = y, 왼쪽 x, 오른쪽 x, 반폭 half_width)에 걸치는가.
static func in_lane(row: Vector3, half_width: float, p: Vector2, r: float) -> bool:
	return absf(p.y - row.x) <= half_width + r and p.x >= row.y - r and p.x <= row.z + r


## 예고 시작 뒤 북 시각들: 예고를 beats칸으로 고르게 나눠 0초부터 (마지막 북 다음 칸 끝에 발동).
static func beat_times(warn_time: float, beats: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in maxi(beats, 0):
		out.append(warn_time * i / maxf(beats, 1))
	return out


## 줄 가운데에서 밀어내는 방향 (줄 위면 위로, 아래면 아래로).
static func push_dir(row_y: float, p: Vector2) -> Vector2:
	return Vector2.UP if p.y < row_y else Vector2.DOWN
