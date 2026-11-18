class_name Enemy
extends CharacterBody2D
## 추적형 적. 플레이어를 향해 직선 추적, 주변 적과 간단히 분리.
## 종류별 수치는 data(EnemyData)에서 읽는다. 체력·피격은 health_hitbox_hurtbox 애드온.

signal killed(enemy: Enemy)

const GROUP := "enemies"

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
## 예고 공격 (data.attack이 있을 때만).
var attack: EnemyAttack
## 넉백 속도 (매 프레임 감쇠).
var knockback: Vector2 = Vector2.ZERO
## 넉백 감쇠율(초당). 클수록 빨리 멈춘다.
@export var knockback_damping: float = 8.0


func apply_knockback(impulse: Vector2) -> void:
	knockback += impulse * (data.knockback_scale if data else 1.0)


func _ready() -> void:
	if data:
		move_speed = data.move_speed
		contact_damage = data.contact_damage
		body_radius = data.body_radius
		health.max = data.max_hp
		health.current = data.max_hp
		if data.attack:
			# 첫 공격 시점을 흩어 놓아 한꺼번에 예고하지 않게 한다.
			attack = EnemyAttack.new(data.attack, randf_range(0.3, 1.5))
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
	if attack:
		if attack.tick(delta, global_position, target as Player) == EnemyAttack.Result.FIRED:
			_fire_arrow()
		busy = attack.is_busy()
		if busy:
			queue_redraw()
	var chase := Vector2.ZERO if busy else compute_velocity(get_tree().get_nodes_in_group(GROUP))
	velocity = chase + knockback
	knockback = knockback.move_toward(Vector2.ZERO, knockback.length() * knockback_damping * delta + 1.0)
	move_and_slide()
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func _on_damaged(_entity: Node, _type: HealthActionType.Enum, _amount: int, _inc: int, _mul: float, applied: int) -> void:
	_flash = 0.1
	Feedback.enemy_hit(global_position, applied)
	queue_redraw()


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
	Feedback.enemy_died(global_position)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	_draw_telegraph()
	draw_set_transform(Vector2(0, body_radius * 0.7), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, body_radius, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := data.color if data else Color(0.75, 0.2, 0.25)
	var c := Color(1, 1, 1) if _flash > 0.0 else base
	draw_circle(Vector2(0, -body_radius * 0.3), body_radius, c)
	if data and data.knockback_scale < 1.0:  # 중장병: 갑옷 테두리
		draw_arc(Vector2(0, -body_radius * 0.3), body_radius, 0, TAU, 24, Color(0.85, 0.85, 0.9), 4.0)


## 예고 원: 바닥에 붉은 원이 차오르고, 타격 직전에 밝아진다.
func _draw_telegraph() -> void:
	if attack == null or attack.state != EnemyAttack.State.WINDUP:
		return
	if attack.is_shoot():  # 조준선: 점점 굵고 밝아진다
		var k0 := attack.windup_ratio()
		var end := attack.aim_dir * attack.data.projectile_range
		draw_line(Vector2.ZERO, end, Color(1, 0.3, 0.2, 0.15 + 0.35 * k0), 2.0 + 6.0 * k0)
		return
	var p := to_local(attack.target_point)
	var r := attack.data.radius
	var k := attack.windup_ratio()
	draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, r, Color(1, 0.2, 0.15, 0.12))
	draw_circle(Vector2.ZERO, r * k, Color(1, 0.25, 0.15, 0.25 + 0.25 * k))
	draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(1, 0.35, 0.25, 0.8), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
