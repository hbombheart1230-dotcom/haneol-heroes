class_name DamageZone
extends Node2D
## 잠시 남는 피해 영역 (해룡참 · 소용돌이 등). interval마다 반경 안 적에게 피해.
## 기술 공통 도구(SkillContext)로 적을 찾고 때린다.

var ctx: SkillContext
var radius: float = 120.0
var duration: float = 2.0
var interval: float = 0.3
var damage: int = 6
var color: Color = Color(0.35, 0.75, 1.0)
## 안쪽으로 끌어당기는 힘 (0이면 없음).
var pull: float = 0.0

var ticks: int = 0
var _age: float = 0.0
var _next: float = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	_next -= delta
	if _next <= 0.0 and ctx:
		_next += interval
		ticks += 1
		for en in ctx.enemies_in_radius(global_position, radius):
			if pull > 0.0:
				en.apply_knockback((global_position - en.global_position).normalized() * pull)
			ctx.hit(en, damage)
	if _age >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(1.0 - _age / maxf(duration, 0.001), 0.0, 1.0)
	var spin := _age * 6.0
	for i in 3:
		var a := spin + i * TAU / 3.0
		draw_arc(Vector2.ZERO, radius * (0.45 + 0.2 * i), a, a + PI * 0.9, 24, Color(color, 0.55 * k), 6.0 - i)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(Ink.INK, 0.25 * k), 2.0)
