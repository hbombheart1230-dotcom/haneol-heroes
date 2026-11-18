class_name HaeilSkill
extends SkillDef
## 이순신 · 해일검기: 충전량에 비례해 커지고 강해지는 관통 물결 검기.

@export var min_damage: int = 20
@export var max_damage: int = 60
@export var min_scale: float = 1.6
@export var max_scale: float = 3.2
@export var speed: float = 650.0
@export var lifetime: float = 1.1


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var c := clampf(charge, 0.0, 1.0)
	var p := ctx.spawn_projectile_configured(func(pr: Projectile) -> void:
		pr.direction = ctx.player.facing
		pr.speed = speed
		pr.lifetime = lifetime
		pr.pierce = true
		pr.wave_style = true
		pr.damage = roundi(lerpf(min_damage, max_damage, c))
		pr.size_scale = lerpf(min_scale, max_scale, c))
	var run := SkillRun.instant(0)
	run.set_meta(&"projectile", p)
	return run
