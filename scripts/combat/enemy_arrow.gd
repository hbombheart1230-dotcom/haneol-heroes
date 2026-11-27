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
## 일제 사격 열쇠 (VolleyBeat.key_for, "" = 아님): 같은 열쇠 탄이 상한만큼 맞혔으면 이 탄은 지나간다.
var volley_key: String = ""
## 겉모습 (null = 화살, 조총은 납탄 + 불빛 꼬리).
var look: ShotLookData


func setup(p_target: Player, origin: Vector2, data: EnemyAttackData) -> void:
	target = p_target
	global_position = origin
	speed = data.projectile_speed
	max_range = data.projectile_range
	damage = data.damage
	radius = data.projectile_radius
	look = data.shot_look


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
		elif VolleyBeat.can_hit(volley_key) and target.apply_hit(damage):
			VolleyBeat.note_hit(volley_key)
			return true
	return traveled >= max_range


func _physics_process(delta: float) -> void:
	if step(delta):
		queue_free()


## 그림 한 장 (쇠 화살촉·나무 대·양쪽 깃털·먹 꼬리, InkPaint.ARROW). 촉 끝이 옛 그림 끝(+20)과 비슷하게 오고 몸통은 뒤로 길다. 판정(radius)과는 별개로 겉모습만.
func _draw() -> void:
	if look:  # 조총 탄: 불빛 꼬리 + 납탄 한 장 (ShotLookData.texture, 화살처럼 그림 한 장)
		draw_texture_rect(look.texture(), look.texture_rect(), false)
		return
	draw_texture_rect(InkPaint.ARROW, Rect2(-96.0, -15.0, 120.0, 30.0), false)
