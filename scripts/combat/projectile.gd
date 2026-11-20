class_name Projectile
extends HitBox2D
## 검기 투사체. 자동 원거리 공격(단일 적중)과 해일검기(관통 대형 물결)에 함께 쓴다.
## 피해 적용은 HitBox2D(health_hitbox_hurtbox)가 HurtBox2D에 들어갈 때 처리한다.
## 관통 시 같은 적은 한 번만 맞는다 (영역 진입 시 1회 적용).

@export var speed: float = 700.0
@export var lifetime: float = 0.8
@export var damage: int = 10
## 적중 시 진행 방향으로 미는 힘 (0이면 없음).
@export var knockback: float = 0.0
## true면 적중 후에도 사라지지 않고 계속 관통한다.
@export var pierce: bool = false
## 크기 배율 (충돌 영역과 그림 모두).
@export var size_scale: float = 1.0
## true면 해일검기 물결 모양으로 그린다.
@export var wave_style: bool = false
## 비어 있지 않으면 이 글자를 붓글씨로 그린다 (세종 문자탄).
@export var glyph: String = ""

var direction: Vector2 = Vector2.RIGHT
var hits: int = 0
var _age: float = 0.0


func _ready() -> void:
	super._ready()
	var a: Array[HealthAction] = [HealthAction.new(Health.Affect.DAMAGE, HealthActionType.Enum.KINETIC, damage)]
	actions = a
	action_applied.connect(_on_action_applied)
	rotation = direction.angle()
	scale = Vector2.ONE * size_scale


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()
	if wave_style:
		queue_redraw()


func _on_action_applied(hurt_box: HurtBox2D) -> void:
	hits += 1
	if knockback > 0.0 and hurt_box and hurt_box.get_parent() is Enemy:
		(hurt_box.get_parent() as Enemy).apply_knockback(direction * knockback)
	if pierce:
		return
	ignore_collisions = true
	set_deferred("monitoring", false)
	queue_free()


func _draw() -> void:
	if glyph != "":
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)  # 글자는 똑바로
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(-20, 14), glyph, 40, UiStyle.GOLD, 40.0, Color(0, 0, 0, 0.7), 5)
		return
	if wave_style:
		var a := 1.0 - _age / lifetime * 0.5
		for i in 3:
			var r := 22.0 - i * 6.0
			draw_arc(Vector2(-i * 10.0, 0), r, -PI * 0.55, PI * 0.55, 16, Color(Ink.WATER.darkened(0.2 * i), a * (1.0 - i * 0.25)), 7.0 - i)
		return
	Ink.stroke(self, Vector2(-20, 0), Vector2(18, 0), 8.0, Ink.INDIGO)
	draw_line(Vector2(-8, 0), Vector2(14, 0), Ink.WATER, 2.0)
