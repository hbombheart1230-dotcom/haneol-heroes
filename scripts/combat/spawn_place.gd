class_name SpawnPlace
extends RefCounted
## 생성기 등장 자리 계산 (EnemySpawner에서 나눔, 파일 400줄): 화면 안 자리, 화면 맞춤, 막힌 자리 피하기.


## 화면 안 등장 자리: center에서 min~max px (전장 안).
static func near_point(sp: EnemySpawner, center: Vector2, dmin: float, dmax: float) -> Vector2:
	var p := center
	var tries := maxi(sp.spawn_point_tries, 1)
	for i in tries * 3:  # 장애물 속이면 다시 뽑는다 (Codex e423e86 지적); 한 바퀴 다 막히면 둘레를 넓혀 두 바퀴 더 (벽 많은 경복궁)
		var far := dmax * (1.0 + 0.5 * float(i / tries))
		p = center + fit_view(sp, Vector2.from_angle(sp.rng.randf_range(0.0, TAU)) * sp.rng.randf_range(dmin, far), far)
		p = sp.bounded(p)
		if not sp.blocked_check.is_valid() or not bool(sp.blocked_check.call(p, sp.spawn_clearance)):
			break
		if i == tries - 1:
			sp.spawn_widened += 1
		if i == tries * 3 - 1:
			sp.spawn_stuck += 1
	return p


## 화면 안에 들게 줄인 등장 오프셋: 가로·세로를 각각 (보이는 반폭·반높이 − 여유) ÷ dmax 배까지 (줄일 때만).
static func fit_view(sp: EnemySpawner, off: Vector2, dmax: float) -> Vector2:
	if sp.view_margin < 0.0 or not sp.is_inside_tree():
		return off
	var half := view_half(sp)
	if half == Vector2.INF:
		return off
	return Vector2(off.x * clampf((half.x - sp.view_margin) / maxf(dmax, 1.0), 0.2, 1.0),
		off.y * clampf((half.y - sp.view_margin) / maxf(dmax, 1.0), 0.2, 1.0))


## 보이는 화면의 반폭·반높이 (월드 px, 카메라 줌 반영). 카메라가 없으면 INF.
static func view_half(sp: EnemySpawner) -> Vector2:
	var cam := sp.get_viewport().get_camera_2d()
	if cam == null:
		return Vector2.INF
	return sp.get_viewport().get_visible_rect().size / cam.zoom * 0.5


## at이 장애물 속이거나 전장 밖이면 around 둘레에서 다시 뽑은 자리 (보스 부하 소환).
static func safe_point(sp: EnemySpawner, at: Vector2, around: Vector2, dmin: float, dmax: float) -> Vector2:
	var p := sp.bounded(at)
	if sp.blocked_check.is_valid() and bool(sp.blocked_check.call(p, sp.spawn_clearance)):
		return near_point(sp, around, dmin, dmax)
	return p
