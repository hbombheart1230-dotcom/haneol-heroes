class_name Projectile
extends HitBox2D
## 자동 원거리 공격 투사체 (임시 검기). 첫 적중 후 사라진다.
## 피해 적용은 HitBox2D(health_hitbox_hurtbox)가 HurtBox2D에 들어갈 때 처리한다.

@export var speed: float = 700.0
@export var lifetime: float = 0.8
@export var damage: int = 10

var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0


func _ready() -> void:
	super._ready()
	var a: Array[HealthAction] = [HealthAction.new(Health.Affect.DAMAGE, HealthActionType.Enum.KINETIC, damage)]
	actions = a
	action_applied.connect(_on_action_applied)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_action_applied(_hurt_box: HurtBox2D) -> void:
	ignore_collisions = true
	set_deferred("monitoring", false)
	queue_free()


func _draw() -> void:
	draw_line(Vector2(-18, 0), Vector2(18, 0), Color(0.6, 0.9, 1.0), 6.0)
	draw_line(Vector2(-10, 0), Vector2(14, 0), Color(1, 1, 1), 2.0)
