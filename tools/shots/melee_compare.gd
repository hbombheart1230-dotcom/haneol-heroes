extends SceneTree
## 근접 영웅 평타 1·2·3타 수치 비교 (순신 · 광개토 · 사임당): 닿는 시각, 동작 길이, 닿은 뒤 남은 길이, 멈춤(영웅 히트스톱),
## 넉백, 전진(내딛기·찌르기), 사거리·각도, 검기 그림 (초승달 크기·켜진 시간 / 궤적). 표를 찍고 끝난다.
## godot --headless --path . -s res://tools/shots/melee_compare.gd

const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang"]


func _initialize() -> void:
	var feel: CombatFeelData = load("res://data/feel/combat_feel.tres")
	var impact := feel.impact_data()
	var trail: SwingTrailData = load("res://data/feel/swing_trail.tres")
	print("hero step anim frames fps strike contact_s len_s after_s stop_s kb step_in lunge range arc fx")
	for id: String in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		var d := h.attack
		var sheet := h.sprite_sheet
		var bite := h.blade_bite
		var contact := SheetContact.new(sheet, bite.clip_contact if bite else {})
		for step: int in [1, 2, 3]:
			var anim := "attack%d" % step if step >= 2 and sheet.has_anim("attack%d" % step) else "attack"
			var i := sheet.anim_names.find(anim)
			var fps: float = sheet.fps[i]
			var n := sheet.frame_count(anim)
			var sf := sheet.strike_frame(anim)
			var t := AttackTiming.melee_delay(-1.0, sf, fps, feel.melee_delay_min, feel.melee_delay_max)
			if bite and bite.enabled:
				var ct := contact.contact_time(StringName(anim))
				if ct >= 0.0:
					t = clampf(ct, bite.contact_min, bite.contact_max)
			t += ComboSteps.at(d.step_windup_pause, step, 0.0)
			var heavy := step == d.chain_len
			var stop := bite.stop_for(step) if bite and bite.enabled else impact.hero_hitstop(1, heavy)
			var kb := d.melee_knockback * (d.heavy_knockback_mult if heavy else 1.0) * ComboSteps.at(d.step_knockback_mults, step, 1.0)
			var r := d.melee_range * ComboSteps.at(d.step_range_mults, step, 1.0)
			var arc := d.melee_arc_degrees * ComboSteps.at(d.step_arc_mults, step, 1.0)
			var fx := ""
			if trail.heroes.has(id):
				fx = "trail r%.0f w%.0f lead%.2f life%.2f" % [r * trail.reach, trail.width * ComboSteps.at(trail.step_widths, step, 1.0),
					trail.lead * ComboSteps.at(trail.step_lead_mults, step, 1.0), trail.life]
			else:
				var ks := ComboSteps.at(feel.crescent_step_scales, step, 1.0)
				var half := deg_to_rad(arc * 0.5)
				fx = "crescent depth%.0f h%.0f on0.12" % [r * feel.crescent_depth * ks, r * maxf(sin(half), 0.35) * 1.8 * feel.crescent_scale * ks]
			var length := n / fps
			print("%s %d %s %d %.0f %d %.3f %.3f %.3f %.3f %.0f %.0f %.0f %.0f %.0f %s" % [id, step, anim, n, fps, sf, t, length,
				length - t, stop, kb, ComboSteps.at(d.step_in_px, step, 0.0), ComboSteps.at(d.lunge_px, step, 0.0), r, arc, fx])
	quit()
