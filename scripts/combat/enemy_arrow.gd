class_name EnemyArrow
extends Node2D
## 궁수 화살. 플레이어 피격 판정(Player.apply_hit)을 거치므로 대시·회피 무적이 적용된다.
## 대시로 화살을 뚫고 지나가면 회피 성공 (반격 기회). 체력 애드온의 HitBox는 무적을 거치지 않아 쓰지 않는다.

var target: Player
var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var max_range: float = 650.0
var damage: int = 12
var radius: float = 14.0
## 플레이어 몸 반지름 (판정에 더함).
var player_radius: float = 22.0

var traveled: float = 0.0
var evaded: bool = false


func setup(p_target: Player, origin: Vector2, data: EnemyAttackData) -> void:
	target = p_target
	global_position = origin
	speed = data.projectile_speed
	max_range = data.projectile_range
	damage = data.damage
	radius = data.projectile_radius


func _ready() -> void:
	rotation = direction.angle()


## 반환: 화살이 사라져야 하면 true.
func step(delta: float) -> bool:
	var move := direction * speed * delta
	global_position += move
	traveled += move.length()
	if target and is_instance_valid(target) and not target.is_dead() \
			and global_position.distance_to(target.global_position) <= radius + player_radius:
		if target.is_dashing():
			if not evaded:
				evaded = true
				target.register_evade()
		elif target.apply_hit(damage):
			return true
	return traveled >= max_range


func _physics_process(delta: float) -> void:
	if step(delta):
		queue_free()


## 그림 한 장 (나무 대·먹 촉·붉은 깃·먹 꼬리, InkPaint.ARROW). 판정(radius)과는 별개로 겉모습만.
func _draw() -> void:
	draw_texture_rect(InkPaint.ARROW, Rect2(-42.0, -9.0, 72.0, 18.0), false)
