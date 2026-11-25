class_name PlayerDash
extends RefCounted
## 영웅 대시 (Player에서 나눔, 파일 400줄 규칙): 시작·연속 대시, 한 틱 이동, 대시 프레임의 돌진 타격·밀쳐내기·대시 틱.
## 상태는 Player에 그대로 두고 (테스트·다른 코드가 읽는다) 여기는 그 상태를 진행하는 로직만.


## 방향이 0이면 현재 이동 방향, 그것도 없으면 바라보는 방향으로 대시한다. 반환: 대시가 시작되면 true.
static func request(p: Player, direction: Vector2) -> bool:
	if p.bite.hold_dash(direction, p.dash.can_consume()):  # 칼이 박혀 멈춘 중: 풀릴 때 바로 (BladeBite)
		return true
	var chained := p.is_dashing() or (p.hero != null and p.hero.dash_dir != null and p._since_dash_end < p.hero.dash_dir.chain_gap)
	if p.is_dashing():
		# 연속 대시: 충전이 남아 있으면 지금 대시를 끊고 즉시 새 방향으로 (기다리지 않음, 실기기 피드백).
		if not p.dash.can_consume():
			return false
		p._dash_time_left = 0.0
		p._since_dash_end = 0.0
		p._dash_arrived()
		p.dash_ended.emit()
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = p.move_input if p.move_input.length_squared() > 0.0001 else p.facing
	if not p.dash.try_consume():
		return false
	p._dash_dir = dir.normalized()
	p._dash_time_left = p.dash_duration
	p._dash_dk = 1.0
	p._dash_tk = 1.0
	p._swing_left = 0.0  # 대시가 휘두름을 끊으면 느려짐도 끝 (대시 뒤에 남지 않게)
	p._glide_left = 0.0
	p._since_dash_start = 0.0
	p._dash_start_pos = p.global_position
	p._shoved.clear()
	p.facing = p._dash_dir
	DashDirection.begin(p, p.get_tree().get_nodes_in_group(Enemy.GROUP) if p.is_inside_tree() else [], chained)
	if p.dash_runner:
		p.dash_runner.on_start(p.global_position, p._dash_dir)
	p.dash_started.emit(p._dash_dir)
	return true


## 대시 중 한 틱의 속도. 마지막 틱은 남은 시간만큼만 가고 대시를 끝낸다 (도착 효과는 이동 뒤 _physics_process에서).
static func step(p: Player, delta: float) -> Vector2:
	var step_t := minf(delta, p._dash_time_left)
	p._dash_time_left -= delta
	var speed := p.dash_distance * p._dash_dk / (p.dash_duration * p._dash_tk)  # 백스텝은 짧고 빠르게
	var v := p._dash_dir * speed * (step_t / delta if delta > 0.0 else 0.0)
	if p._dash_time_left <= 0.0:
		p._dash_time_left = 0.0
		p._since_dash_end = 0.0
		if p.dash_glide_time > 0.0:
			p._glide_vel = p._dash_dir * speed * p.dash_glide_ratio
			p._glide_left = p.dash_glide_time
		# 대시 직후엔 가속을 다시 기다리지 않는다 (대시 → 걷기 끊김 없이).
		p._walk_vel = p.move_input * p.move_speed
		p._arrive_pending = true
		p.dash_ended.emit()
	return v


## 대시 프레임 (마지막 걸음 포함): 대시 틱·밀쳐내기·돌진 타격. struck_before = 이 프레임 전 맞힌 수.
## 마지막 걸음에서 처음 맞혔으면 끝날 때(dash_ended) 못 붙인 대가를 지금 (외부 감사 84b0930).
static func frame(p: Player, delta: float, struck_before: int) -> void:
	if p.dash_runner:
		p.dash_runner.tick(delta, p.global_position)
	var list: Array = p.get_tree().get_nodes_in_group(Enemy.GROUP)
	if p.hero and p.hero.dash_shove > 0.0:
		shove(p, list)
	if p.dash_strikes:
		DashDirection.tick(p, list, delta)
		if not p.is_dashing() and struck_before == 0 and not p.dash_struck.is_empty():
			DashDirection.end(p)


## 대시 돌격: 경로 옆 적을 대시 방향의 옆으로 밀쳐 낸다. 밀친 적 수.
static func shove(p: Player, list: Array) -> int:
	var n := 0
	for e in list:
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or p._shoved.has(en.get_instance_id()):
			continue
		var off := en.global_position - p.global_position
		if off.length() > p.hero.dash_shove_radius + en.body_radius:
			continue
		p._shoved[en.get_instance_id()] = true
		var side := p._dash_dir.orthogonal()
		if off.dot(side) < 0.0:
			side = -side
		en.apply_knockback((side * 0.8 + p._dash_dir * 0.4).normalized() * p.hero.dash_shove)
		n += 1
	return n
