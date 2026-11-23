class_name Player
extends CharacterBody2D
## 플레이어 영웅 (공통). 이동, 대시(무영보, 충전식), 접촉 피해.
## 영웅별 수치는 hero(HeroData)에서 읽는다. 그리기는 PlayerView가 맡는다.

signal dash_started(direction: Vector2)
signal dash_ended
## 적 공격을 대시로 피했을 때 (회피 반격의 시작점).
signal evaded
## 실제로 피해를 받았을 때 (붉은 가장자리 등).
signal hurt(amount: int)

## 지정하면 _ready에서 아래 수치를 이 데이터로 덮어쓴다.
@export var hero: HeroData
@export var move_speed: float = 340.0
## 대시 1회 이동 거리(px)와 지속 시간(초).
@export var dash_distance: float = 260.0
@export var dash_duration: float = 0.12
@export var max_dash_charges: int = 2
@export var dash_recharge_time: float = 1.2
## 피격 후 무적 시간(초).
@export var hurt_invuln_time: float = 0.6
## 적 공격을 대시로 피한(예고 원을 벗어난) 순간부터 무적 시간(초). 파고들어 반격하기 위함.
@export var evade_invuln_time: float = 1.0
## 플레이어가 벗어날 수 없는 영역 (월드 좌표). 크기가 0이면 제한 없음.
@export var arena_rect: Rect2 = Rect2()
@export var body_radius: float = 26.0
## 접촉 판정용 Area2D (적 몸체 레이어를 감지). 없으면 접촉 피해 없음.
@export var contact_sensor: Area2D

var move_input: Vector2 = Vector2.ZERO
var _swing_left: float = 0.0
var _swing_mult: float = 1.0
var facing: Vector2 = Vector2.DOWN
var dash: DashCharges
## health_hitbox_hurtbox 애드온의 Health. 씬에서 자식 "Health"로 둔다.
var health: Health

var _hurt_cd: float = 0.0
## 이번 피격 무적의 전체 길이 (피해에 비례, HurtResponse).
var _hurt_total: float = 0.0
## 회피 성공 등으로 얻은 추가 무적 남은 시간(초).
var _skill_invuln: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
## 대시 끝 미끄러짐: 대시가 끝날 때 속도를 이어받아 이 시간(초) 동안 감속 (대시 사이를 매끄럽게).
@export var dash_glide_time: float = 0.1
## 미끄러짐 시작 속도 = 대시 속도 × 이 값.
@export var dash_glide_ratio: float = 0.4
var _glide_vel: Vector2 = Vector2.ZERO
## 걷기 속도 (가속·감속을 거친 실제 값).
var _walk_vel: Vector2 = Vector2.ZERO
## 멈춤 → 최고 속도 / 최고 속도 → 멈춤 시간(초). 0이면 즉시.
var move_accel_time: float = 0.0
var move_decel_time: float = 0.0
## 근접 적중 반동: 남은 이동량(px/s)과 남은 시간.
var _recoil_vel: Vector2 = Vector2.ZERO
var _recoil_left: float = 0.0
## 영웅별 회피 이펙트·도착 효과 (hero.dash_style이 있을 때).
var dash_runner: DashStyleRunner
var _arrive_pending: bool = false
var _glide_left: float = 0.0
var _dash_time_left: float = 0.0
## 마지막 대시가 끝난 뒤 지난 시간(초). 대시 직후 연계 입력 판정용.
var _since_dash_end: float = INF
## 마지막 대시 시작 후 지난 시간(초)과 시작 위치 (회피 판정용).
var _since_dash_start: float = INF
var _dash_start_pos: Vector2 = Vector2.ZERO
## 이번 대시에 이미 밀쳐 낸 적 (한 번씩만).
var _shoved: Dictionary = {}
## 접점 시각 (그림 쪽이 넣는다: 2D SheetContact, 3D 칼끝 뼈)과 칼이 박혀 멈춘 상태 (BladeBite, 두 그림이 같이 읽는다).
var contact: HeroContact
var bite := BladeBite.new()


func _init() -> void:
	dash = DashCharges.new(max_dash_charges, dash_recharge_time)
	bite.released.connect(func() -> void: BladeBite.on_release(self))


func _ready() -> void:
	health = get_node_or_null("Health") as Health
	if hero:
		apply_hero(hero)
	# 인스펙터 값이 _init 이후에 적용되므로 다시 생성한다.
	dash = DashCharges.new(max_dash_charges, dash_recharge_time)


## 판 시작 전 영웅 바꾸기 (고르기 화면). 대시 충전도 새로 만든다.
func change_hero(h: HeroData) -> void:
	apply_hero(h)
	dash = DashCharges.new(max_dash_charges, dash_recharge_time)
	var view := get_node_or_null("PlayerView") as PlayerView
	if view:
		view.refresh()


func apply_hero(h: HeroData) -> void:
	hero = h
	dash_runner = DashStyleRunner.new(h.dash_style) if h.dash_style else null
	move_speed = h.move_speed
	move_accel_time = h.move_accel_time
	move_decel_time = h.move_decel_time
	dash_distance = h.dash_distance
	dash_duration = h.dash_duration
	max_dash_charges = h.max_dash_charges
	dash_recharge_time = h.dash_recharge_time
	hurt_invuln_time = h.hurt_invuln_time
	evade_invuln_time = h.evade_invuln_time
	if health:
		health.max = h.max_hp
		health.current = h.max_hp


## 대시 돌격: 경로 옆 적을 대시 방향의 옆으로 밀쳐 낸다. 밀친 적 수를 돌려준다.
func shove_enemies(list: Array) -> int:
	var n := 0
	for e in list:
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or _shoved.has(en.get_instance_id()):
			continue
		var off := en.global_position - global_position
		if off.length() > hero.dash_shove_radius + en.body_radius:
			continue
		_shoved[en.get_instance_id()] = true
		var side := _dash_dir.orthogonal()
		if off.dot(side) < 0.0:
			side = -side
		en.apply_knockback((side * 0.8 + _dash_dir * 0.4).normalized() * hero.dash_shove)
		n += 1
	return n


## 성장으로 hero 수치가 바뀐 뒤 다시 읽는다 (체력은 늘어난 만큼 회복, 대시 충전은 늘어난 만큼 채움).
func refresh_stats(old_max_hp: int) -> void:
	if hero == null:
		return
	move_speed = hero.move_speed
	dash_distance = hero.dash_distance
	dash_duration = hero.dash_duration
	hurt_invuln_time = hero.hurt_invuln_time
	evade_invuln_time = hero.evade_invuln_time
	dash_recharge_time = hero.dash_recharge_time
	dash.recharge_time = maxf(hero.dash_recharge_time, 0.01)
	if hero.max_dash_charges != max_dash_charges:
		var diff := hero.max_dash_charges - max_dash_charges
		max_dash_charges = maxi(hero.max_dash_charges, 1)
		dash.max_charges = max_dash_charges
		dash.charges = clampi(dash.charges + maxi(diff, 0), 0, max_dash_charges)
	if health and hero.max_hp != old_max_hp:
		health.max = hero.max_hp
		health.current = clampi(health.current + maxi(hero.max_hp - old_max_hp, 0), 1, health.max)


## 근접 적중 반동: offset(px)만큼 seconds초(기본 = CombatFeelData.recoil_time) 동안 밀린다. 개구리 혀 끌어당기기도.
func apply_recoil(offset: Vector2, seconds: float = -1.0) -> void:
	var t := maxf(seconds if seconds > 0.0 else Feedback.feel_data().recoil_time, 0.001)
	_recoil_vel = offset / t
	_recoil_left = t


## 이번 프레임 걷기 속도: 목표 속도로 가속·감속 (영웅별 무게감).
func _walk_velocity(delta: float) -> Vector2:
	var want := move_input * move_speed
	var speeding_up := want.length() >= _walk_vel.length() - 0.01
	var t := move_accel_time if speeding_up else move_decel_time
	if t <= 0.0:
		_walk_vel = want
	else:
		_walk_vel = _walk_vel.move_toward(want, move_speed / t * delta)
	return _walk_vel


func walk_velocity() -> Vector2:
	return _walk_vel


func is_dashing() -> bool:
	return _dash_time_left > 0.0


## 대시 중, 피격 직후, 회피 무적 중이면 피해를 받지 않는다.
func is_invulnerable() -> bool:
	return is_dashing() or _hurt_cd > 0.0 or _skill_invuln > 0.0


## 추가 무적 부여 (더 긴 쪽 유지).
func grant_invulnerability(seconds: float) -> void:
	_skill_invuln = maxf(_skill_invuln, seconds)


func skill_invuln_left() -> float:
	return _skill_invuln


func hurt_time_left() -> float:
	return _hurt_cd


## 마지막 피격 뒤 흐른 시간 (무적 중일 때만 의미 있음).
func hurt_elapsed() -> float:
	return _hurt_total - _hurt_cd


func is_dead() -> bool:
	return health != null and health.is_dead()


## 접촉 피해 처리. amount는 이번 프레임 닿아 있는 적들 중 최대 피해량(없으면 0).
## 반환: 실제로 피해를 받았으면 true.
func apply_contact_damage(delta: float, amount: int) -> bool:
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)
	if amount <= 0 or health == null or is_dead() or is_invulnerable():
		return false
	_take_hit(amount)
	return true


## 피해 공통: 무적(피해 비례) + 주변 적 밀어내기(숨 돌릴 틈) + 연출.
func _take_hit(amount: int) -> void:
	health.damage(amount)
	var react := Feedback.feel_data().reaction_data()
	_hurt_total = HurtResponse.invuln_for(amount, health.max, hurt_invuln_time, react)
	_hurt_cd = _hurt_total
	if is_inside_tree() and not is_dead():
		HurtResponse.breathe(global_position, get_tree().get_nodes_in_group(Enemy.GROUP), react)
	Feedback.player_hurt()
	hurt.emit(amount)


## 적 공격 타격. 무적이면 무시. 반환: 실제로 피해를 받았으면 true.
func apply_hit(amount: int) -> bool:
	if amount <= 0 or health == null or is_dead() or is_invulnerable():
		return false
	_take_hit(amount)
	return true


## within초 안에 시작한 대시가 원(center, radius) 안에서 출발했으면 true (원 밖으로 빠져나간 회피).
func dashed_out_of(center: Vector2, radius: float, within: float) -> bool:
	return _since_dash_start <= within and _dash_start_pos.distance_to(center) <= radius


## 마지막 대시 시작 위치와, 그 대시가 within초 안에 시작됐는지 (모양이 다른 예고 영역의 회피 판정용).
func dash_start_position() -> Vector2:
	return _dash_start_pos


func dashed_within(within: float) -> bool:
	return _since_dash_start <= within


## 회피 성공: 즉시 무적 + evaded 신호 (반격 시간 시작).
func register_evade() -> void:
	grant_invulnerability(evade_invuln_time)
	evaded.emit()


func _touching_damage() -> int:
	if contact_sensor == null:
		return 0
	var best := 0
	for b in contact_sensor.get_overlapping_bodies():
		if b is Enemy:
			best = maxi(best, (b as Enemy).contact_damage)
	return best


func get_dash_direction() -> Vector2:
	return _dash_dir


## 대시 중이거나, 대시가 끝난 지 window초 이내면 true.
func in_dash_link(window: float) -> bool:
	return is_dashing() or _since_dash_end <= window


func set_move_input(v: Vector2) -> void:
	move_input = v.limit_length(1.0)
	if move_input.length_squared() > 0.0001 and not is_dashing():
		facing = move_input.normalized()


## 방향이 0이면 현재 이동 방향, 그것도 없으면 바라보는 방향으로 대시한다.
## 반환: 대시가 시작되면 true.
func request_dash(direction: Vector2 = Vector2.ZERO) -> bool:
	if bite.hold_dash(direction, dash.can_consume()):  # 칼이 박혀 멈춘 중: 풀릴 때 바로 (BladeBite)
		return true
	if is_dashing():
		# 연속 대시: 충전이 남아 있으면 지금 대시를 끊고 즉시 새 방향으로 (기다리지 않음, 실기기 피드백).
		if not dash.can_consume():
			return false
		_dash_time_left = 0.0
		_since_dash_end = 0.0
		_dash_arrived()
		dash_ended.emit()
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = move_input if move_input.length_squared() > 0.0001 else facing
	if not dash.try_consume():
		return false
	_dash_dir = dir.normalized()
	_dash_time_left = dash_duration
	_swing_left = 0.0  # 대시가 휘두름을 끊으면 느려짐도 끝 (대시 뒤에 남지 않게)
	_glide_left = 0.0
	_since_dash_start = 0.0
	_dash_start_pos = global_position
	_shoved.clear()
	facing = _dash_dir
	if dash_runner:
		dash_runner.on_start(global_position, _dash_dir)
	dash_started.emit(_dash_dir)
	return true


## 이번 물리 프레임의 속도를 계산하고 대시·충전 타이머를 진행한다.
## 손 평타 휘두르는 동안 걷기 속도 배율 (AutoAttack.manual_strike, M1).
func slow_for(seconds: float, mult: float) -> void:
	_swing_left = maxf(_swing_left, seconds)
	_swing_mult = mult


func compute_velocity(delta: float) -> Vector2:
	dash.update(delta)
	bite.tick(delta)
	_since_dash_start += delta
	_skill_invuln = maxf(_skill_invuln - delta, 0.0)
	if not is_dashing():
		_since_dash_end += delta
		var v_move := _walk_velocity(delta) * (_swing_mult if _swing_left > 0.0 else 1.0)
		_swing_left = maxf(_swing_left - delta, 0.0)
		if _recoil_left > 0.0:
			v_move += _recoil_vel * (minf(delta, _recoil_left) / delta if delta > 0.0 else 0.0)
			_recoil_left = maxf(_recoil_left - delta, 0.0)
		if _glide_left > 0.0:
			v_move += _glide_vel * (_glide_left / dash_glide_time)
			_glide_left = maxf(_glide_left - delta, 0.0)
		return v_move
	var step := minf(delta, _dash_time_left)
	_dash_time_left -= delta
	var v := _dash_dir * (dash_distance / dash_duration) * (step / delta if delta > 0.0 else 0.0)
	if _dash_time_left <= 0.0:
		_dash_time_left = 0.0
		_since_dash_end = 0.0
		if dash_glide_time > 0.0:
			_glide_vel = _dash_dir * (dash_distance / dash_duration) * dash_glide_ratio
			_glide_left = dash_glide_time
		# 대시 직후엔 가속을 다시 기다리지 않는다 (대시 → 걷기 끊김 없이).
		_walk_vel = move_input * move_speed
		_arrive_pending = true  # 도착 효과는 이번 프레임 이동을 마친 실제 자리에서 (_physics_process)
		dash_ended.emit()
	return v


## 대시 도착: 영웅별 도착 이펙트·효과 (트리 밖 테스트에서는 이펙트만).
## 레벨업 인장을 고르는 느린 시간(GameTime.base < 1)에는 걸지 않는다.
func _dash_arrived() -> void:
	_arrive_pending = false
	if dash_runner and not is_dead() and GameTime.base >= 1.0:
		dash_runner.on_end(global_position, get_tree().get_nodes_in_group(Enemy.GROUP) if is_inside_tree() else [])


func _physics_process(delta: float) -> void:
	if is_dead():
		velocity = Vector2.ZERO
		return
	velocity = compute_velocity(delta)
	if dash_runner and is_dashing():
		dash_runner.tick(delta, global_position)
	if is_dashing() and hero and hero.dash_shove > 0.0:
		shove_enemies(get_tree().get_nodes_in_group(Enemy.GROUP))
	apply_contact_damage(delta, _touching_damage())
	move_and_slide()
	if arena_rect.has_area():
		global_position = global_position.clamp(arena_rect.position, arena_rect.end)
	if _arrive_pending:
		_dash_arrived()
