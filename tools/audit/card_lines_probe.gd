extends SceneTree
## 패 글 확인: 영웅마다 모든 보통 패를 0장부터 최고 단계 앞까지 차례로 고르며 패 화면에 보일 줄("지금 → 뒤", "+47%")과
## 후보에 남는지(UpgradeEffect.useful)를 찍는다. 레벨 보너스 0, 기본 설정(기술 단추 꺼짐) 기준.
## godot --headless --path . -s res://tools/audit/card_lines_probe.gd

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


func _initialize() -> void:
	for h in HEROES:
		for u0 in (load("res://data/heroes/%s.tres" % h) as HeroData).upgrade_pool.upgrades:
			var b := RunBuild.new()
			b.hero = (load("res://data/heroes/%s.tres" % h) as HeroData).duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
			var u: UpgradeDef = null
			for x in b.hero.upgrade_pool.upgrades:
				if x.id == u0.id:
					u = x
			var rows := PackedStringArray()
			for n in u.max_stacks:
				var parts := PackedStringArray()
				for l in UpgradeReadout.lines(u, b, 1):
					parts.append("%s %s" % [l["label"], l.get("text", "%s → %s" % [l.get("from"), l.get("to")])])
				rows.append("%d장[%s]%s" % [n, ", ".join(parts), "" if UpgradeEffect.useful(b, u) else " (후보 빠짐)"])
				b.apply(u)
			print("%s %s: %s" % [h, u.id, " | ".join(rows)])
	quit()
