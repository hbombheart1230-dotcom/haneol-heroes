class_name HaeilSkill
extends SkillDef
## 이순신 · 해일검기: 충전량에 비례해 커지고 강해지는 관통 물결 검기.

@export var min_damage: int = 20
@export var max_damage: int = 60
@export var min_scale: float = 1.6
@export var max_scale: float = 3.2
@export var speed: float = 650.0
@export var lifetime: float = 1.1
@export_group("큰 변형 · 세 갈래")
## 양옆으로 더 쏘는 물결 수 (0이면 한 줄기). 쌍으로 퍼진다.
@export var extra_waves: int = 0
@export var spread_degrees: float = 20.0


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var c := clampf(charge, 0.0, 1.0)
	var p := _wave(ctx, ctx.player.facing, c)
	for i in extra_waves:
		var side := 1.0 if i % 2 == 0 else -1.0
		var step := float(floori(i / 2.0) + 1)
		_wave(ctx, ctx.player.facing.rotated(deg_to_rad(spread_degrees * step * side)), c)
	var run := SkillRun.instant(0)
	run.set_meta(&"projectile", p)
	return run


func _wave(ctx: SkillContext, dir: Vector2, c: float) -> Projectile:
	return ctx.spawn_projectile_configured(func(pr: Projectile) -> void:
		pr.direction = dir
		pr.speed = speed
		pr.lifetime = lifetime
		pr.pierce = true
		pr.wave_style = true
		pr.damage = roundi(lerpf(min_damage, max_damage, c))
		pr.size_scale = lerpf(min_scale, max_scale, c))
