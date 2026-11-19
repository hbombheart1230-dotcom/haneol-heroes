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


func _ready() -> void:
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
	return (dir + push * separation_strength).limit_length(1.0) * move_speed


func _physics_process(delta: float) -> void:
	var busy := false
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
	velocity = chase + knockback
	if sprite:
		_update_sprite(busy)
	knockback = knockback.move_toward(Vector2.ZERO, knockback.length() * knockback_damping * delta + 1.0)
	move_and_slide()
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func _on_damaged(_entity: Node, _type: HealthActionType.Enum, _amount: int, _inc: int, _mul: float, applied: int) -> void:
	_flash = 0.1
	Feedback.enemy_hit(global_position, applied)
	queue_redraw()


## 돌진: 예고한 직사각형 끝까지 빠르게 이동 (엔진 기본 Tween).
func _setup_sprite() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = data.sprite_sheet.shared_sprite_frames()
	sprite.scale = Vector2.ONE * data.sprite_scale
	sprite.position = data.sprite_offset
	sprite.modulate = data.sprite_tint
	add_child(sprite)


## 상태 → 애니메이션 (피격 > 공격 중 > 이동 > 대기), 방향은 대상 쪽.
func _update_sprite(busy: bool) -> void:
	var sheet := data.sprite_sheet
	var anim := "idle"
	if _flash > 0.0 and sheet.has_anim("hit"):
		anim = "hit"
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
	sprite.modulate = Color(1.8, 1.8, 1.8) if _flash > 0.0 else data.sprite_tint


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
	Feedback.enemy_died(global_position)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	EnemyArt.draw(self)
	if _stun_left > 0.0:  # 기절: 머리 위 번개 고리
		var top := Vector2(0, -body_radius * 2.2)
		var spin := Time.get_ticks_msec() * 0.008
		draw_arc(top, body_radius * 0.6, spin, spin + PI * 1.3, 12, Color(1.0, 0.9, 0.3, 0.9), 3.0)


func flash_left() -> float:
	return _flash
