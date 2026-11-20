class_name Enemy
extends CharacterBody2D
## 추적형 적. 플레이어를 향해 직선 추적, 주변 적과 간단히 분리.
## 종류별 수치는 data(EnemyData)에서 읽는다. 체력·피격은 health_hitbox_hurtbox 애드온.

signal killed(enemy: Enemy)

const GROUP := "enemies"
const BOSS_GROUP := "boss"

## 지정하면 _ready에서 아래 수치와 체력을 이 데이터로 덮어쓴다.
@export var data: EnemyData
@export var move_speed: float = 120.0
## 플레이어 접촉 시 피해량.
@export var contact_damage: int = 10
## 이 거리 안의 다른 적에게서 밀려난다 (뭉침 방지).
@export var separation_radius: float = 40.0
@export var separation_strength: float = 0.6
@export var body_radius: float = 20.0

var target: Node2D
@onready var health: Health = $Health

var _flash: float = 0.0
## 구워진 스프라이트 (data.sprite_sheet가 있을 때).
var sprite: AnimatedSprite2D
## 예고 공격 (data.attack이 있을 때만).
var attack: EnemyAttack
## 넉백 속도 (매 프레임 감쇠).
var knockback: Vector2 = Vector2.ZERO
var _stun_left: float = 0.0
## 장애물 돌아가기: 남은 시간, 부딪힌 면의 법선, 정면일 때 도는 쪽 (적마다 고정).
var _detour_left: float = 0.0
var _detour_normal: Vector2 = Vector2.ZERO
var _detour_side: float = 1.0
## 느려짐: 이동 속도 배율과 남은 시간 (해시계 멈춤·발묵).
var _slow_factor: float = 1.0
var _slow_left: float = 0.0
## 개별 멈춤(맞은 적만 잠깐 멈춤) 남은 시간과 떨림 기준 위치.
var _freeze_left: float = 0.0
## 마지막으로 맞은 방향과 피해 (처치 날림용).
var _last_hit_dir: Vector2 = Vector2.ZERO
var _last_damage: int = 0
## 넉백 감쇠율(초당). 클수록 빨리 멈춘다.
@export var knockback_damping: float = 8.0


func apply_knockback(impulse: Vector2) -> void:
	knockback += impulse * (data.knockback_scale if data else 1.0)


## 기절: 그동안 움직이지도 공격하지도 않는다. 기절에 약한 적(stun_scale 1 이상)은 예고 공격이 끊긴다.
func stun(seconds: float) -> void:
	var scale := data.stun_scale if data else 1.0
	if seconds * scale <= 0.0:
		return
	_stun_left = maxf(_stun_left, seconds * scale)
	if attack and scale >= 1.0 and attack.is_busy():
		attack.cancel()
	queue_redraw()


func is_stunned() -> bool:
	return _stun_left > 0.0


## 느리게: factor(0~1)배 속도로 seconds초. 더 강한 느려짐이 이긴다. 보스·정예도 stun_scale만큼 짧게.
func slow(factor: float, seconds: float) -> void:
	var t := seconds * (data.stun_scale if data else 1.0)
	if t <= 0.0:
		return
	if factor < _slow_factor or _slow_left <= 0.0:
		_slow_factor = clampf(factor, 0.05, 1.0)
	_slow_left = maxf(_slow_left, t)


func speed_scale() -> float:
	return _slow_factor if _slow_left > 0.0 else 1.0


func _ready() -> void:
	_detour_side = 1.0 if get_instance_id() % 2 == 0 else -1.0
	if data:
		move_speed = data.move_speed
		contact_damage = data.contact_damage
		body_radius = data.body_radius
		health.max = data.max_hp
		health.current = data.max_hp
		if not data.patterns.is_empty():
			attack = EnemyAttack.new(data.patterns[0], 1.0)
			attack.set_patterns(data.patterns)
		elif data.attack:
			# 첫 공격 시점을 흩어 놓아 한꺼번에 예고하지 않게 한다.
			attack = EnemyAttack.new(data.attack, randf_range(0.3, 1.5))
		if data.is_boss:
			add_to_group(BOSS_GROUP)
		if data.sprite_sheet:
			_setup_sprite()
	add_to_group(GROUP)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## 이번 프레임 이동 속도. neighbors는 분리 계산용 주변 적 목록.
func compute_velocity(neighbors: Array) -> Vector2:
	if target == null or not is_instance_valid(target) or health.is_dead():
		return Vector2.ZERO
	var to_target := target.global_position - global_position
	var dir := to_target.normalized() if to_target.length_squared() > 1.0 else Vector2.ZERO
	# 거리 유지형(궁수): 너무 가까우면 물러나고, 적당하면 멈춘다.
	if data and data.preferred_range > 0.0:
		var d := to_target.length()
		if d < data.preferred_range - 40.0:
			dir = -dir
		elif d <= data.preferred_range + 40.0:
			dir = Vector2.ZERO
	var push := Vector2.ZERO
	for n in neighbors:
		var other := n as Node2D
		if other == null or other == self or not is_instance_valid(other):
			continue
		var off := global_position - other.global_position
		var d := off.length()
		if d > 0.001 and d < separation_radius:
			push += off / d * (1.0 - d / separation_radius)
	return (dir + push * separation_strength).limit_length(1.0) * move_speed * speed_scale()


## 맞은 적만 seconds초 멈추고 떨린다 (Smash식 개별 히트스톱). 더 긴 쪽 유지.
func freeze(seconds: float) -> void:
	_freeze_left = maxf(_freeze_left, seconds)


func is_frozen() -> bool:
	return _freeze_left > 0.0


func last_hit_dir() -> Vector2:
	return _last_hit_dir


## 멈춤 중: 움직이지 않고 동작도 멈춘 채 좌우로 떤다. 넉백은 멈춤이 끝나면 그대로 이어진다.
func _tick_freeze(delta: float) -> void:
	_freeze_left = maxf(_freeze_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	if sprite:
		var px := Feedback.feel_data().hit_shake_px
		sprite.speed_scale = 0.0 if _freeze_left > 0.0 else 1.0
		sprite.position = data.sprite_offset + Vector2((px if Engine.get_physics_frames() % 2 == 0 else -px) if _freeze_left > 0.0 else 0.0, 0)
		sprite.modulate = _flash_color()
	queue_redraw()


func _flash_color() -> Color:
	if _flash <= 0.0:
		return data.sprite_tint if data else Color.WHITE
	var feel := Feedback.feel_data()
	return Color(2.6, 2.6, 2.6) if _flash > feel.flash_time - feel.flash_peak_time else Color(1.8, 1.8, 1.8)


func _physics_process(delta: float) -> void:
	if _freeze_left > 0.0:
		_tick_freeze(delta)
		return
	var busy := false
	_slow_left = maxf(_slow_left - delta, 0.0)
	if _stun_left > 0.0:
		_stun_left = maxf(_stun_left - delta, 0.0)
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, knockback.length() * knockback_damping * delta + 1.0)
		move_and_slide()
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()
		return
	if attack:
		var r := attack.tick(delta, global_position, target as Player)
		if r == EnemyAttack.Result.FIRED:
			_fire_arrow()
		elif r != EnemyAttack.Result.NONE and attack.data.kind == EnemyAttackData.Kind.CHARGE:
			_charge_to(attack.charge_end())
		busy = attack.is_busy()
		if busy:
			queue_redraw()
	var chase := Vector2.ZERO if busy else compute_velocity(get_tree().get_nodes_in_group(GROUP))
	if _detour_left > 0.0:
		_detour_left -= delta
		chase = Obstacles.steer_around(chase, _detour_normal, _detour_side)
	velocity = chase + knockback
	if sprite:
		_update_sprite(busy)
	knockback = knockback.move_toward(Vector2.ZERO, knockback.length() * knockback_damping * delta + 1.0)
	move_and_slide()
	_note_obstacle()
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


## 장애물에 부딪혔으면 잠시 가장자리를 따라 돈다 (길 찾기 없이 직진하는 적이 끼지 않게).
func _note_obstacle() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider() as Node
		if body and body.is_in_group(Obstacles.GROUP):
			_detour_normal = col.get_normal()
			_detour_left = 0.4
			return


func _on_damaged(_entity: Node, _type: HealthActionType.Enum, _amount: int, _inc: int, _mul: float, applied: int) -> void:
	var feel := Feedback.feel_data()
	_flash = feel.flash_time
	_last_damage = applied
	if target and is_instance_valid(target):
		var d := global_position - target.global_position
		_last_hit_dir = d.normalized() if d.length_squared() > 0.01 else _last_hit_dir
	if applied > 0 and not health.is_dead():
		freeze(feel.freeze_for(applied))
	Feedback.enemy_hit(global_position, applied, _last_hit_dir)
	queue_redraw()


## 돌진: 예고한 직사각형 끝까지 빠르게 이동 (엔진 기본 Tween).
func _setup_sprite() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = data.sprite_sheet.shared_sprite_frames()
	sprite.scale = Vector2.ONE * data.sprite_scale
	sprite.position = data.sprite_offset
	sprite.modulate = data.sprite_tint
	sprite.material = EnemyLook.material_for(data)  # 군대별 테두리·밝기 (잘 보이게)
	add_child(sprite)


## 상태 → 애니메이션 (피격 > 공격 중 > 이동 > 대기), 방향은 대상 쪽.
func _update_sprite(busy: bool) -> void:
	var sheet := data.sprite_sheet
	var anim := "idle"
	if _flash > 0.0 and sheet.has_anim("hit"):
		anim = "hit"
	elif busy and attack and sheet.has_anim(String(attack.data.anim)):
		anim = String(attack.data.anim)
	elif busy and sheet.has_anim("attack"):
		anim = "attack"
	elif velocity.length() > 10.0:
		anim = "run"
	var face := Vector2.DOWN
	if busy and attack:
		face = attack.aim_dir
	elif target and is_instance_valid(target):
		face = target.global_position - global_position
	var name_dir := StringName("%s_%d" % [anim, sheet.dir_index(face)])
	if sprite.animation != name_dir:
		sprite.play(name_dir)
	sprite.speed_scale = 1.0
	sprite.position = data.sprite_offset
	sprite.modulate = _flash_color()


func _charge_to(end: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", end, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fire_arrow() -> void:
	var a := EnemyArrow.new()
	a.direction = attack.aim_dir
	a.setup(target as Player, global_position, attack.data)
	get_parent().add_child(a)


func _exit_tree() -> void:
	if attack:
		attack.cancel()


func _on_died(_entity: Node) -> void:
	if attack:
		attack.cancel()
	remove_from_group(GROUP)
	remove_from_group(BOSS_GROUP)
	Feedback.enemy_died(self, _last_hit_dir, _last_damage)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	EnemyArt.draw(self)
	if _slow_left > 0.0:  # 느려짐: 발밑 먹 고리
		draw_arc(Vector2(0, body_radius * 0.7), body_radius * 1.1, 0.0, TAU, 20, Color(Ink.INK, 0.35), 3.0)
	if _stun_left > 0.0:  # 기절: 머리 위 번개 고리
		var top := Vector2(0, -body_radius * 2.2)
		var spin := Time.get_ticks_msec() * 0.008
		draw_arc(top, body_radius * 0.6, spin, spin + PI * 1.3, 12, Color(1.0, 0.9, 0.3, 0.9), 3.0)


func flash_left() -> float:
	return _flash
