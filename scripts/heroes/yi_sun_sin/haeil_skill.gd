class_name HaeilSkill
extends SkillDef
## 이순신 · 해일검기: 충전량에 비례해 커지고 강해지는 관통 물결 검기.

@export var min_damage: int = 20
@export var max_damage: int = 60
@export var min_scale: float = 1.6
@export var max_scale: float = 3.2
@export var speed: float = 650.0
@export var lifetime: float = 1.1
## charge_scaling(SkillDef)이 있으면 min/max_damage·min/max_scale을 그 곡선으로 잇고, 사거리·넉백·연출도 키운다.
## 놓는 순간 화면 흔들림 (charge_scaling.fx배), 다 모았을 때 vfx_cast를 이만큼 높은 단계로 한 번 더.
@export var release_shake: float = 0.12
@export var full_vfx_level_gain: int = 2
## 물결 그림 (오른쪽 = 진행 방향)과 크기(px, size_scale 배율 적용). 비면 코드로 그린 물결 호.
@export var wave_art: Texture2D
@export var wave_art_size: Vector2 = Vector2(150, 60)
## 연출: 물결 잔상 수, 나갈 때 늘어나는 시간(초), 출렁임, 뒤로 흩뿌리는 물보라 (Projectile "물결 연출").
@export var wave_ghosts: int = 3
@export var wave_launch: float = 0.12
@export var wave_surge: float = 0.08
@export var wave_wake: SkillVfxData
@export var wave_flicker: float = 0.9
## 움직이는 물결 시트 (있으면 wave_art 대신 되풀이 재생, docs/skill_vfx_sheets.md) 와 칸 수·초당 장 수.
@export var wave_sheet: Texture2D
@export var wave_sheet_grid: Vector2i = Vector2i(4, 2)
@export var wave_sheet_fps: float = 14.0
@export_group("큰 변형 · 세 갈래")
## 양옆으로 더 쏘는 물결 수 (0이면 한 줄기). 쌍으로 퍼진다.
@export var extra_waves: int = 0
@export var spread_degrees: float = 20.0


func cast(ctx: SkillContext, charge: float) -> SkillRun:
	var c := clampf(charge, 0.0, 1.0)
	var dir := aim(ctx)
	if charge_scaling:
		Feedback.shake(release_shake * charge_scaling.at(charge_scaling.fx, c))
		if charge_scaling.is_full(c) and vfx_cast and ctx.player:
			Feedback.vfx_burst(vfx_cast, ctx.player.global_position, dir, vfx_level + full_vfx_level_gain)
	var p := _wave(ctx, dir, c)
	for i in extra_waves:
		var side := 1.0 if i % 2 == 0 else -1.0
		var step := float(floori(i / 2.0) + 1)
		_wave(ctx, dir.rotated(deg_to_rad(spread_degrees * step * side)), c)
	var run := SkillRun.instant(0)
	run.set_meta(&"projectile", p)
	return run


## 조준 길: 물결이 가는 거리와 맞는 폭 (투사체 판정 원 지름 HIT_DIAMETER × 크기).
const HIT_DIAMETER := 24.0


func aim_length(c: float) -> float:
	return speed * lifetime * (charge_scaling.at(charge_scaling.reach, c) if charge_scaling else 1.0)


func aim_width(c: float) -> float:
	var s := charge_scaling.between(min_scale, max_scale, c) if charge_scaling else lerpf(min_scale, max_scale, c)
	return HIT_DIAMETER * s


func _wave(ctx: SkillContext, dir: Vector2, c: float) -> Projectile:
	return ctx.spawn_projectile_configured(func(pr: Projectile) -> void: _wave_configure(pr, dir, c))


## 물결 하나 꾸미기 (트리에 들어가기 전). c = 충전 0~1.
func _wave_configure(pr: Projectile, dir: Vector2, c: float) -> void:
	pr.direction = dir
	pr.speed = speed
	pr.lifetime = lifetime
	pr.pierce = true
	pr.wave_style = true
	if charge_scaling:
		pr.damage = charge_scaling.damage_at(min_damage, max_damage, c)
		pr.size_scale = charge_scaling.between(min_scale, max_scale, c)
		pr.lifetime = lifetime * charge_scaling.at(charge_scaling.reach, c)
		pr.knockback = charge_scaling.at(charge_scaling.knockback, c)
	else:
		pr.damage = roundi(lerpf(min_damage, max_damage, c))
		pr.size_scale = lerpf(min_scale, max_scale, c)
	if wave_sheet:
		pr.art_sheet = wave_sheet
		pr.art_sheet_grid = wave_sheet_grid
		pr.art_sheet_fps = wave_sheet_fps
	if wave_art or wave_sheet:
		pr.art = wave_art
		pr.art_size = wave_art_size
		pr.ghosts = wave_ghosts
		pr.ghost_gap = wave_art_size.x * 0.22
		pr.launch_stretch = wave_launch
		pr.surge = wave_surge
		pr.wake = wave_wake
		pr.flicker = wave_flicker
