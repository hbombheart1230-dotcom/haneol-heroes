extends SceneTree
## 강화 패 점검 측정: 영웅마다 기술 패를 1장씩 더 고르며, 패 값(원래 값)과 실제 판정 값(성장 단계 배율을 곱한 값)을 찍는다.
## 패의 "지금 → 뒤"와 실제로 커지는 몫이 얼마나 다른지 보는 용도. 레벨 보너스는 0으로 둔다.
## godot --headless --path . -s res://tools/audit/card_effect_probe.gd

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const PROPS := [&"radius", &"width", &"length", &"max_radius", &"max_scale", &"outer_radius"]


func _initialize() -> void:
	var g := SkillGrowthData.get_default()
	for h in HEROES:
		for u0 in (load("res://data/heroes/%s.tres" % h) as HeroData).upgrade_pool.upgrades:
			var b := RunBuild.new()
			b.hero = (load("res://data/heroes/%s.tres" % h) as HeroData).duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
			var u: UpgradeDef = null
			for x in b.hero.upgrade_pool.upgrades:
				if x.id == u0.id:
					u = x
			var sk := b.target_of(u.mods[0].target) as SkillDef
			if sk == null:
				continue
			var rows := PackedStringArray()
			for n in u.max_stacks + 1:
				if n > 0:
					b.apply(u)
				var eff := g.scaled_def(sk)
				var parts := PackedStringArray()
				for p in PROPS:
					if p in sk and float(sk.get(p)) > 0.0:
						parts.append("%s %s→%s" % [p, str(snappedf(float(sk.get(p)), 0.1)), str(snappedf(float(eff.get(p)), 0.1))])
				rows.append("%d장 lv%d [%s]" % [n, sk.vfx_level, ", ".join(parts)])
			print("%s %s (%s.%s): %s" % [h, u.id, u.mods[0].target, u.mods[0].property, " | ".join(rows)])
	quit()
