class_name SynergyEffect
extends Resource
## 짝 효과의 공통 틀. 기술 명중(SkillContext.hit)과 기술 탄 명중(on_projectile_hit) 두 곳에서 불린다.
## 하위 효과(SynergyMark 등)가 필요한 쪽만 덮어쓴다.


## 기술 명중 직전: 넣을 피해를 돌려준다 (그대로면 dmg).
func adjust(_ctx: SkillContext, _en: Enemy, dmg: int) -> int:
	return dmg


## 기술 탄(투사체)이 적에게 닿은 뒤 (탄 피해는 이미 들어갔다).
func on_projectile_hit(_ctx: SkillContext, _p: Projectile, _en: Enemy) -> void:
	pass
