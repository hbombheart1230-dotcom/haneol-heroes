class_name EnemySteer
extends RefCounted
## 적의 이동 (Enemy에서 나눔): 쫓기·거리 유지·서로 밀어내기, 공격 중 움직임, 장애물 돌아가기. 상태는 Enemy에 그대로.


## 이번 프레임 이동 속도. neighbors는 분리 계산용 주변 적 목록.
static func chase(e: Enemy, neighbors: Array) -> Vector2:
	if e.target == null or not is_instance_valid(e.target) or e.health.is_dead():
		return Vector2.ZERO
	if e.formation:  # 대형 구성원: 자기 자리로 (줄 유지는 FormationBrain)
		return e.formation.steer(e)
	var to_target := e.target.global_position - e.global_position
	var dir := to_target.normalized() if to_target.length_squared() > 1.0 else Vector2.ZERO
	var speed_k := 1.0
	# 거리 유지형(궁수): 너무 가까우면 물러나고, 적당하면 멈춘다.
	if e.data and e.data.preferred_range > 0.0:
		var d := to_target.length()
		if d < e.data.preferred_range - 40.0:
			dir = -dir
		elif d <= e.data.preferred_range + 40.0:
			dir = Vector2.ZERO
	if e.brain:
		dir = e.brain.steer(dir, to_target.length())
		speed_k = e.brain.speed_k
		if e.brain.sweep_left <= 0.0 and Enemy.AI.stand_off_band > 0.0:
			var stop: float = e.body_radius * e.size_mult + ((e.target as Player).body_radius if e.target is Player else 22.0) \
				+ Enemy.AI.stand_off_margin + (e.data.reach_px if e.data else 0.0)
			dir = EnemyBrain.stand_off(dir, to_target.normalized(), to_target.length(), stop, Enemy.AI.stand_off_band)
	var push := Vector2.ZERO
	for n in neighbors:
		var other := n as Node2D
		if other == null or other == e or not is_instance_valid(other):
			continue
		var off := e.global_position - other.global_position
		var d := off.length()
		if d > 0.001 and d < e.separation_radius:
			push += off / d * (1.0 - d / e.separation_radius)
	return (dir + push * e.separation_strength).limit_length(1.0) * e.move_speed * e.speed_scale() * speed_k


## 공격 중 움직임 (물러나며 쏘기만, 나머지는 제자리).
static func busy(e: Enemy) -> Vector2:
	if e.brain == null:
		return Vector2.ZERO
	return e.brain.busy_dir(e.attack, dir_to_target(e)) * e.move_speed * e.speed_scale()


static func dir_to_target(e: Enemy) -> Vector2:
	if e.target == null or not is_instance_valid(e.target):
		return Vector2.ZERO
	var d := e.target.global_position - e.global_position
	return d.normalized() if d.length_squared() > 1.0 else Vector2.ZERO


## 장애물에 부딪혔으면 잠시 가장자리를 따라 돈다 (길 찾기 없이 직진하는 적이 끼지 않게).
static func note_obstacle(e: Enemy) -> void:
	for i in e.get_slide_collision_count():
		var col := e.get_slide_collision(i)
		var body := col.get_collider() as Node
		if body and body.is_in_group(Obstacles.GROUP):
			e._detour_normal = col.get_normal()
			e._detour_left = 0.4
			return
