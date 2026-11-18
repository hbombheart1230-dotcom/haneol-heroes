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
## 넉백 속도 (매 프레임 감쇠).
var knockback: Vector2 = Vector2.ZERO
## 넉백 감쇠율(초당). 클수록 빨리 멈춘다.
@export var knockback_damping: float = 8.0


func apply_knockback(impulse: Vector2) -> void:
	knockback += impulse


func _ready() -> void:
	if data:
		move_speed = data.move_speed
		contact_damage = data.contact_damage
		body_radius = data.body_radius
		health.max = data.max_hp
		health.current = data.max_hp
	add_to_group(GROUP)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## 이번 프레임 이동 속도. neighbors는 분리 계산용 주변 적 목록.
func compute_velocity(neighbors: Array) -> Vector2:
	if target == null or not is_instance_valid(target) or health.is_dead():
		return Vector2.ZERO
	var to_target := target.global_position - global_position
	var dir := to_target.normalized() if to_target.length_squared() > 1.0 else Vector2.ZERO
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
	velocity = compute_velocity(get_tree().get_nodes_in_group(GROUP)) + knockback
	knockback = knockback.move_toward(Vector2.ZERO, knockback.length() * knockback_damping * delta + 1.0)
	move_and_slide()
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func _on_damaged(_entity: Node, _type: HealthActionType.Enum, _amount: int, _inc: int, _mul: float, _applied: int) -> void:
	_flash = 0.1
	queue_redraw()


func _on_died(_entity: Node) -> void:
	remove_from_group(GROUP)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2(0, body_radius * 0.7), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, body_radius, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := data.color if data else Color(0.75, 0.2, 0.25)
	var c := Color(1, 1, 1) if _flash > 0.0 else base
	draw_circle(Vector2(0, -body_radius * 0.3), body_radius, c)
