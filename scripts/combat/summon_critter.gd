class_name SummonCritter
extends Node2D
## 내 편 소환물 (사임당 풀벌레): 가까운 적에게 날아가 닿으면 hit_interval초마다 피해. lifetime 뒤 사라진다.
## 그림 속 생물처럼 먹선으로 그린다 (나비·방아깨비).

enum Kind { BUTTERFLY, GRASSHOPPER }

var ctx: SkillContext
var kind: Kind = Kind.BUTTERFLY
var owner_node: Node2D
var lifetime: float = 8.0
var speed: float = 380.0
var damage: int = 8
var hit_interval: float = 0.5
var seek_radius: float = 520.0
var touch_radius: float = 34.0
var color: Color = Color(0.85, 0.4, 0.55)

var hits: int = 0
var _age: float = 0.0
var _cd: float = 0.0
var _wobble: float = 0.0


func _ready() -> void:
	_wobble = randf() * TAU


## 다음 목표 (가장 가까운 산 적). 없으면 null.
func pick_target() -> Enemy:
	if ctx == null:
		return null
	var best: Enemy = null
	var best_d := seek_radius
	for en in ctx.enemies_in_radius(global_position, seek_radius):
		if en.health.is_alive():
			var d := en.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = en
	return best


func _physics_process(delta: float) -> void:
	_age += delta
	_cd = maxf(_cd - delta, 0.0)
	var t := pick_target()
	var goal := t.global_position if t else (owner_node.global_position + Vector2(0, -60) if owner_node else global_position)
	var to := goal - global_position
	var wob := Vector2.from_angle(_age * 9.0 + _wobble) * 40.0
	global_position += ((to.normalized() * speed) + wob) * delta if to.length() > 6.0 else wob * delta
	if t and _cd <= 0.0 and t.global_position.distance_to(global_position) <= touch_radius + t.body_radius:
		if ctx.hit(t, damage):
			hits += 1
			ctx.impact(t.global_position)  # 문 자리에 매화 꽃잎
		_cd = hit_interval
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf((lifetime - _age) / 0.5, 0.0, 1.0)
	var flap := sin(_age * 22.0)
	var petal := VfxTextures.get_texture(SkillVfxData.Shape.PETAL)
	if kind == Kind.BUTTERFLY:  # 꽃잎 날개 두 쌍이 팔랑인다
		for side in [-1.0, 1.0]:
			var w := 26.0 * (0.55 + 0.45 * absf(flap))
			draw_set_transform(Vector2(side * 10.0, -2.0), side * 0.6, Vector2(w / 26.0, 1.0))
			draw_texture_rect(petal, Rect2(-13, -16, 26, 32), false, Color(color, 0.9 * a))
			draw_set_transform(Vector2(side * 8.0, 9.0), side * 1.1, Vector2.ONE)
			draw_texture_rect(petal, Rect2(-8, -10, 16, 20), false, Color(color.darkened(0.2), 0.85 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:  # 방아깨비: 길쭉한 풀잎 몸 + 뛰는 다리 잎
		draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2(1.0, 0.45))
		draw_texture_rect(petal, Rect2(-14, -26, 28, 52), false, Color(0.35, 0.6, 0.25, 0.95 * a))
		for side in [-1.0, 1.0]:
			draw_set_transform(Vector2(side * 14.0, 10.0 + flap * side * 3.0), side * 0.9, Vector2(0.5, 0.9))
			draw_texture_rect(petal, Rect2(-8, -14, 16, 28), false, Color(0.3, 0.5, 0.2, 0.9 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
