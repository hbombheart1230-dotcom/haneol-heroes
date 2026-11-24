class_name SynergyMark
extends SynergyEffect
## 표식 짝: mark_skill에 맞은 적에게 mark_time초 표식, 표식 있는 적은 bonus_skill 피해가 bonus_mult배.
## 예: 순신 파도격(젖음) → 해일검기. 다른 영웅도 같은 틀 (광개토 벽력돌파 감전 → 낙뢰 등).

@export var mark_skill: StringName = &""
@export var mark_tag: StringName = &"mark"
@export var mark_time: float = 4.0
@export var mark_label: String = ""
@export var bonus_skill: StringName = &""
@export var bonus_mult: float = 1.5
## 표식 있는 적에게 처음 더 세게 들어갈 때 적 위에 띄울 글 (표식마다 한 번).
@export var bonus_label: String = ""
@export var color: Color = Color(0.55, 0.85, 1.0)
@export var ring_radius: float = 46.0


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _key() -> StringName:
	return StringName("syn_" + String(mark_tag))


func marked(en: Enemy) -> bool:
	return is_instance_valid(en) and float(en.get_meta(_key(), -1.0)) > now()


func mark(ctx: SkillContext, en: Enemy) -> void:
	var fresh := not marked(en)
	en.set_meta(_key(), now() + mark_time)
	if fresh:
		en.set_meta(StringName(String(_key()) + "_told"), false)
		if ctx.fx:
			ctx.fx.add_ring(en.global_position, ring_radius, 0.35, color)
			if mark_label != "":
				ctx.fx.add_label(en.global_position - Vector2(0, 70), mark_label, color)


func adjust(ctx: SkillContext, en: Enemy, dmg: int) -> int:
	var id := ctx.skill.id if ctx.skill else &""
	if id == mark_skill:
		mark(ctx, en)
	elif id == bonus_skill and marked(en):
		_tell(ctx, en)
		return roundi(dmg * bonus_mult)
	return dmg


## 탄이 직접 넣은 첫 타에도 배율을 맞춘다 (나머지 긁기 타는 SkillContext.hit을 지나며 adjust로 커진다).
func on_projectile_hit(ctx: SkillContext, p: Projectile, en: Enemy) -> void:
	if ctx.skill == null or ctx.skill.id != bonus_skill or not marked(en) or en.health == null:
		return
	var extra := roundi(p.damage * (bonus_mult - 1.0))
	if extra > 0 and en.health.is_alive():
		en.health.damage(extra)
		_tell(ctx, en)


func _tell(ctx: SkillContext, en: Enemy) -> void:
	var k := StringName(String(_key()) + "_told")
	if bool(en.get_meta(k, false)):
		return
	en.set_meta(k, true)
	if ctx.fx:
		ctx.fx.add_ring(en.global_position, ring_radius * 1.6, 0.4, color)
		if bonus_label != "":
			ctx.fx.add_label(en.global_position - Vector2(0, 100), bonus_label, color)
