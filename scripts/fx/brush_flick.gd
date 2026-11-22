class_name BrushFlick
extends RefCounted
## 사임당 중거리 먹 털기 연출 (BrushFlickData, BrushFlickFx): 칼이 닿는 순간(AutoAttack.melee_swung) 판정 모양 그대로
## 붓 획이 휘둘러지고, 붓 터는 소리, 튄 먹 방울. 판정·피해·접점 섬광(HitImpact)·젖은 타격음은 근접 경로가 이미 한다.
## RangedFeel.attach에서 함께 붙는다 (AutoAttack은 고치지 않음). Feedback이 없으면 아무것도 안 함 (테스트 안전).

static var _layer: BrushFlickFx


static func data() -> BrushFlickData:
	return BrushFlickData.get_default()


static func layer() -> BrushFlickFx:
	var fb := Feedback.instance
	if fb == null or fb.fx == null or not fb.fx.is_inside_tree():
		return null
	if _layer == null or not is_instance_valid(_layer) or _layer.get_parent() != fb.fx:
		_layer = BrushFlickFx.new(data(), fb.feel.stroke_art)
		fb.fx.add_child(_layer)
	return _layer


static func attach(a: AutoAttack) -> void:
	if a == null or a.has_meta(&"brush_flick"):
		return
	a.set_meta(&"brush_flick", true)
	a.melee_swung.connect(func(dir: Vector2, hits: int) -> void: on_swung(a, dir, hits))


## 이 털기의 판정 모양 (AutoAttack._strike와 같은 계산): [거리 px, 각도 도].
static func shape_for(a: AutoAttack) -> Vector2:
	var d := a.stats()
	var s := a.chain_step
	return Vector2(d.melee_range * ComboSteps.at(d.step_range_mults, s, 1.0),
		d.melee_arc_degrees * ComboSteps.at(d.step_arc_mults, s, 1.0))


static func applies(a: AutoAttack) -> bool:
	var hero := a.player.hero if a and a.player else null
	return hero != null and data().applies_to(hero.id)


## 닿는 순간 (맞은 적이 없어도 획은 그린다: 허공을 터는 붓).
static func on_swung(a: AutoAttack, dir: Vector2, _hits: int) -> void:
	if not applies(a):
		return
	var d := data()
	var step := clampi(a.chain_step, 1, 3)
	var shape := shape_for(a)
	var origin := a.player.global_position
	var col := a.stats().swing_color
	var l := layer()
	if l:
		l.flick(origin, dir, shape.x, shape.y, step, col)
	var fb := Feedback.instance
	if fb == null:
		return
	if d.flick_sfx != &"":
		fb.play(d.flick_sfx, d.flick_gap, HitImpactData.at_f(d.flick_pitch, step, 1.0))
	if fb.kill_fx:  # 붓끝에서 튄 먹 방울 (획 끝 쪽으로)
		var tip := origin + dir.normalized() * shape.x * 0.8
		fb.kill_fx.drops(tip, dir, HitImpactData.at_i(d.drops, step, 4), d.ink_color)
