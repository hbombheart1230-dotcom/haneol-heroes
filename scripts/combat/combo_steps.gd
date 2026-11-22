class_name ComboSteps
extends RefCounted
## 연타 흐름 (타별 수치 읽기·전진 거리, 순수 로직). auto_attack.gd가 400줄을 넘지 않게 나눔.
## 배열은 1타부터 차례로, 모자라면 마지막 값, 비었으면 기본값.


static func at(arr: PackedFloat32Array, step: int, fallback: float) -> float:
	if arr.is_empty():
		return fallback
	return arr[clampi(step - 1, 0, arr.size() - 1)]


## 이번 타의 전진 거리(px): 데이터 값을 max로 자르고, 앞 적의 몸 안으로 들어가지 않게 (gap_to_enemy = 몸끼리
## 남은 거리, 적이 없으면 INF), 적 예고가 영웅을 덮고 있으면 0 (한 손 조작에서 원치 않는 이동 방지).
static func step_in(want: float, max_px: float, gap_to_enemy: float, in_danger: bool) -> float:
	if in_danger or want <= 0.0:
		return 0.0
	return clampf(minf(want, max_px), 0.0, maxf(gap_to_enemy, 0.0))


## 적 목록 중 하나라도 공격 예고가 pos를 덮고 있는지.
static func in_windup(enemy_list: Array, pos: Vector2) -> bool:
	for n in enemy_list:
		var e := n as Enemy
		if e and is_instance_valid(e) and e.attack and e.attack.state == EnemyAttack.State.WINDUP and e.attack.contains(pos):
			return true
	return false


## dir 쪽 가장 가까운 적까지 몸끼리 남은 거리 (부채꼴 cone_deg 안, 없으면 INF).
static func gap_ahead(enemy_list: Array, from: Vector2, dir: Vector2, my_radius: float, cone_deg: float = 60.0) -> float:
	var best := INF
	for n in enemy_list:
		var e := n as Enemy
		if e == null or not is_instance_valid(e):
			continue
		var off := e.global_position - from
		var d := off.length()
		if d < 0.001 or dir.dot(off / d) < cos(deg_to_rad(cone_deg * 0.5)):
			continue
		best = minf(best, d - e.body_radius * e.size_mult - my_radius)
	return best
