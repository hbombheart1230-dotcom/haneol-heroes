class_name FormationSpawn
extends RefCounted
## 대형 내보내기·돌리기 (EnemySpawner에서 나눔): 물결 차례에 FormationData가 오면 자리마다 먹 번짐 예고 뒤 구성원이 서고,
## 생성기 tick마다 살아 있는 대형의 머리(FormationBrain)를 돌린다 (헤드리스 시뮬도 같은 길).


## 대형 하나: 가운데는 영웅 위나 아래 spawn_dist (화면 세로가 길어 가로 줄이 화면 안에 든다), RING은 영웅 둘레.
static func spawn(sp: EnemySpawner, d: FormationData) -> FormationBrain:
	if d == null or d.member == null or sp.target == null:
		return null
	var t := sp.target.global_position
	var anchor := t
	var facing := Vector2.DOWN
	if d.shape != FormationData.Shape.RING:
		var up := -1.0 if sp.rng.randf() < 0.5 else 1.0
		var other := _live_anchor(sp)
		if other != Vector2.INF:  # 이미 대형이 있으면 영웅 반대쪽에 (두 묶음이 겹쳐 서지 않게)
			up = -1.0 if other.y > t.y else 1.0
		var dir := Vector2(0.0, up).rotated(sp.rng.randf_range(-0.35, 0.35))
		anchor = sp.bounded(t + dir * d.spawn_dist)
		if anchor.distance_to(t) < d.spawn_dist * 0.6:  # 벽에 막혀 너무 가까우면 반대쪽
			anchor = sp.bounded(t - dir * d.spawn_dist)
		facing = (t - anchor).normalized()
	var b := FormationBrain.new(d, sp, anchor, facing)
	sp.formations.append(b)
	for i in d.count:
		var slot := i
		var at := free_point(sp, b.slot_point(i))  # 바위·가림막 속 자리면 그 자리 가까이 빈 곳 (모양 유지)
		sp.warn_spawn(d.member, at, false, i * sp.group_spread, func(e: Enemy) -> void: b.join(e, slot))
	return b


## 살아 있는 마지막 대형의 가운데 (없으면 INF).
static func _live_anchor(sp: EnemySpawner) -> Vector2:
	for i in range(sp.formations.size() - 1, -1, -1):
		if not sp.formations[i].is_over():
			return sp.formations[i].anchor
	return Vector2.INF


## p가 장애물(바위·가림막) 속이면 그 둘레를 가까운 고리부터 (30px씩, 8방향) 훑어 첫 빈 자리 (걸을 곳 안).
## 생성기 난수를 쓰지 않는다 (다시 뽑아도 다른 적 등장 자리가 그대로). 다 막히면 p 그대로.
static func free_point(sp: EnemySpawner, p: Vector2) -> Vector2:
	var at := sp.bounded(p)
	if not sp.blocked_check.is_valid() or not bool(sp.blocked_check.call(at, sp.spawn_clearance)):
		return at
	for ring in range(1, 9):
		for k in 8:
			var q := sp.bounded(p + Vector2.from_angle(TAU * k / 8.0) * 30.0 * ring)
			if not bool(sp.blocked_check.call(q, sp.spawn_clearance)):
				return q
	return at


static func tick_all(sp: EnemySpawner, delta: float) -> void:
	for b: FormationBrain in sp.formations:
		b.tick(delta)
	sp.formations = sp.formations.filter(func(b: FormationBrain) -> bool: return not b.is_over())
