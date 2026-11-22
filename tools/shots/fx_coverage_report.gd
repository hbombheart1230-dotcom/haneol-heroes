extends SceneTree
## 기술 이펙트가 화면 너비의 몇 %를 덮는지 표로 찍는다 (전 = 상한 없음 / 후 = 지금 SkillStageFeel).
## 강화 전(기본)과 최대(그 기술을 건드리는 강화를 모두 최대 중첩 + 큰 변형)를 함께.
## godot --headless --path . -s res://tools/shots/fx_coverage_report.gd -- [화면 너비 px, 기본 720]

const HEROES := ["yi_sun_sin", "sejong", "gwanggaeto", "shin_saimdang"]
const SLOTS := ["tap", "dash", "charge", "counter"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var view_w := float(args[0]) if args.size() > 0 else FxCoverage.DEFAULT_VIEW_W
	var after := SkillStageFeel.get_default()
	var before := after.duplicate() as SkillStageFeel
	before.screen_cap = 0.0
	before.fit_grow = 99.0
	before.big_from = 99.0
	print("| 기술 | 판정 지름 | 기본 전 → 후 | 최대 단계 | 최대 전 → 후 | 큰 이펙트 처리 |")
	print("|---|---|---|---|---|---|")
	for id in HEROES:
		var hero: HeroData = load("res://data/heroes/%s.tres" % id)
		var maxed := _maxed_kit(hero, id)
		for slot in SLOTS:
			var s0: SkillDef = hero.kit.get(slot)
			var s1: SkillDef = maxed.get(slot)
			if s0 and s0.vfx_impact and (s0.vfx_impact.strip or s0.vfx_impact.strip_sheet):
				var sd := s0.vfx_impact
				var old_sd := sd.duplicate() as SkillVfxData
				old_sd.max_size_mult = 99.0
				print("| %s %s (띠 두께) | - | %d%% → %d%% | %d | %d%% → %d%% | |" % [id, slot,
					roundi(sd.strip_width * old_sd.size_mult(s0.vfx_level) / view_w * 100.0),
					roundi(sd.strip_width * sd.size_mult(s0.vfx_level) / view_w * 100.0), s1.vfx_level,
					roundi(sd.strip_width * old_sd.size_mult(s1.vfx_level) / view_w * 100.0),
					roundi(sd.strip_width * sd.size_mult(s1.vfx_level) / view_w * 100.0)])
			if s0 == null or s0.vfx_impact == null or not s0.vfx_impact.has_decal():
				continue
			var r0 := _radius(s0)
			var r1 := _radius(s1)
			var d := s0.vfx_impact
			var old_d := d.duplicate() as SkillVfxData
			old_d.max_size_mult = 99.0  # 예전: 강화 배율 상한 없음
			var b0 := FxCoverage.plan(old_d, s0.vfx_level, r0, before, view_w)
			var a0 := FxCoverage.plan(d, s0.vfx_level, r0, after, view_w)
			var b1 := FxCoverage.plan(old_d, s1.vfx_level, r1, before, view_w)
			var a1 := FxCoverage.plan(d, s1.vfx_level, r1, after, view_w)
			print("| %s %s (%s) | %s | %d%% → %d%% | %d | %d%% → %d%% | %s |" % [id, slot, s0.get_script().get_global_name(),
				("%d%%" % roundi(r0 * 2.0 / view_w * 100.0) + (" → %d%%" % roundi(r1 * 2.0 / view_w * 100.0) if r1 != r0 else "")) if r0 > 0.0 else "-",
				roundi(float(b0["frac"]) * 100.0), roundi(float(a0["frac"]) * 100.0), s1.vfx_level,
				roundi(float(b1["frac"]) * 100.0), roundi(float(a1["frac"]) * 100.0),
				("빛 %d%% · 시간 %d%%" % [roundi(after.big_light * 100), roundi(after.big_time * 100)]
					+ (" · 가운데부터 비움" if d.piece_count > 0 else "")) if a1["big"] else ""])
	quit()


## 그림을 맞추는 판정 반경 (기술이 ctx.impact에 넘기는 값). 모르면 0 (데이터 크기 그대로).
func _radius(s: SkillDef) -> float:
	if s is CanvasSkill:
		return (s as CanvasSkill).max_radius  # 가득 충전
	for p in ["radius"]:
		if p in s and s.get_script().get_global_name() in ["CounterSlashSkill", "HaeryongSkill", "SundialSkill",
				"QuakeSkill", "ConquerorSkill", "MeteorSkill", "PlumBlossomSkill"]:
			return float(s.get(p))
	return 0.0


## 강화를 모두 최대 중첩 + 큰 변형까지 넣은 기술 묶음 (RunBuild.apply와 같은 규칙).
func _maxed_kit(hero: HeroData, id: String) -> SkillKit:
	var kit := hero.kit.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as SkillKit
	for path in ["res://data/upgrades/%s.tres" % id, "res://data/upgrades/%s_major.tres" % id]:
		var pool: UpgradePool = load(path) if ResourceLoader.exists(path) else null
		if pool == null:
			continue
		for u in pool.upgrades:
			for n in u.max_stacks:
				var leveled := {}
				for m in u.mods:
					var obj: Object = kit.get(m.target) if m.target in SLOTS else null
					if obj == null or not (m.property in obj):
						continue
					obj.set(m.property, m.apply_to(obj.get(m.property)))
					if obj is SkillDef and not leveled.has(obj):
						leveled[obj] = true
						(obj as SkillDef).vfx_level += u.vfx_level_gain
	return kit
