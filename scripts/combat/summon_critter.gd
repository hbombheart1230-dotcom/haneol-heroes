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
## 그려 넣은 벌레 그림 (B안 부품 그림, 위에서 본 모습·머리 = 위). 있으면 꽃잎 모양 대신 이 그림이 붓으로 그려지듯 나타나
## 날갯짓(가로 눌림)·뜀(세로 눌림)을 한다. 크기(px).
var art: Texture2D
var art_size: float = 64.0

var hits: int = 0
var _age: float = 0.0
var _cd: float = 0.0
var _wobble: float = 0.0


func age() -> float:
	return _age


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
		if ctx.tick_hit(t, damage, _age + hit_interval > lifetime):  # 사라지기 전 마지막 물기는 크게
			hits += 1
			ctx.impact(t.global_position)  # 문 자리에 매화 꽃잎
		_cd = hit_interval
	if _age >= lifetime:
		queue_free()
	queue_redraw()


## 붓으로 그려지듯 등장: 부위 j가 그려진 정도 (몸통 → 날개·다리 차례). 순수 계산.
static func part_progress(age: float, j: int, step: float = 0.09, stroke: float = 0.14) -> float:
	return clampf((age - step * j) / maxf(stroke, 0.01), 0.0, 1.0)


func _draw() -> void:
	var a := clampf((lifetime - _age) / 0.5, 0.0, 1.0)
	var flap := sin(_age * 22.0)
	var petal := VfxTextures.get_texture(SkillVfxData.Shape.PETAL)
	var blot := Feedback.feel_data().splat_art
	if blot and _age < 0.45:  # 화폭에서 붓이 찍히는 먹 자국
		var bk := _age / 0.45
		var bs := 90.0 * (0.6 + 0.6 * bk)
		draw_texture_rect(blot, Rect2(-Vector2.ONE * bs * 0.5, Vector2.ONE * bs), false, Color(0.08, 0.07, 0.06, 0.6 * (1.0 - bk)))
	if art:
		var pa := part_progress(_age, 0, 0.0, 0.3)
		var sq := Vector2(0.55 + 0.45 * absf(flap), 1.0) if kind == Kind.BUTTERFLY else Vector2(1.0, 0.85 + 0.15 * absf(flap))
		var h := art_size * art.get_height() / maxf(art.get_width(), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, sq * lerpf(0.4, 1.0, pa))
		draw_texture_rect(art, Rect2(-art_size * 0.5, -h * 0.5, art_size, h), false, Color(1, 1, 1, a * pa))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif kind == Kind.BUTTERFLY:  # 꽃잎 날개 두 쌍이 팔랑인다 (윗날개 → 아랫날개 순으로 그려진다)
		for side in [-1.0, 1.0]:
			var p0 := part_progress(_age, 0 if side < 0.0 else 1)
			var p1 := part_progress(_age, 2 if side < 0.0 else 3)
			var w := 26.0 * (0.55 + 0.45 * absf(flap))
			if p0 > 0.0:
				draw_set_transform(Vector2(side * 10.0, -2.0), side * 0.6, Vector2(w / 26.0, 1.0) * p0)
				draw_texture_rect(petal, Rect2(-13, -16, 26, 32), false, Color(color, 0.9 * a * p0))
			if p1 > 0.0:
				draw_set_transform(Vector2(side * 8.0, 9.0), side * 1.1, Vector2.ONE * p1)
				draw_texture_rect(petal, Rect2(-8, -10, 16, 20), false, Color(color.darkened(0.2), 0.85 * a * p1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:  # 방아깨비: 몸통 → 뒷다리 차례
		var pb := part_progress(_age, 0)
		if pb > 0.0:
			draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2(1.0 * pb, 0.45))
			draw_texture_rect(petal, Rect2(-14, -26, 28, 52), false, Color(0.35, 0.6, 0.25, 0.95 * a * pb))
		for side in [-1.0, 1.0]:
			var pl := part_progress(_age, 1 if side < 0.0 else 2)
			if pl <= 0.0:
				continue
			draw_set_transform(Vector2(side * 14.0, 10.0 + flap * side * 3.0), side * 0.9, Vector2(0.5, 0.9) * pl)
			draw_texture_rect(petal, Rect2(-8, -14, 16, 28), false, Color(0.3, 0.5, 0.2, 0.9 * a * pl))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
