class_name Enemy
extends CharacterBody2D
## 추적형 적 (P0-B 1종). 플레이어를 향해 직선 추적, 주변 적과 간단히 분리.
## 체력·피격은 health_hitbox_hurtbox 애드온의 Health / HurtBox2D를 쓴다.

signal killed(enemy: Enemy)

const GROUP := "enemies"

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


func _ready() -> void:
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
	velocity = compute_velocity(get_tree().get_nodes_in_group(GROUP))
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
	var c := Color(1, 1, 1) if _flash > 0.0 else Color(0.75, 0.2, 0.25)
	draw_circle(Vector2(0, -body_radius * 0.3), body_radius, c)
