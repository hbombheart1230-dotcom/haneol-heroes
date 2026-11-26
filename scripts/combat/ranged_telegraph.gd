class_name RangedTelegraph
extends RefCounted
## 원거리(사격) 예고 그리기 (EnemyArt가 부른다): 가늘고 날렵한 인주 획(양 끝이 가늘어지는 Ink.stroke)은 그대로 두고
## 바닥에서 뜨게만 한다 — 불투명하게, 아주 얇은 먹 그림자와 밝은 속심, 쏘기 직전 팽팽해졌다 번쩍.
## 모양(RangedTelegraphData.style): 0 또렷한 획 / 1 쏘는 쪽에서 과녁으로 그어지는 획 / 2 또렷한 획 + 맞는 폭을 끝에만.
## 수치는 RangedTelegraphData. c는 적과 같은 좌표계. 화면 밖 사수는 획이 화면 가장자리에서 들어오는 것으로 충분하다.


static var _one := InkBatch.new()


## 적 하나의 예고를 c에 (InkBatch 하나 = 그리기 호출 하나). 전장 층(RangedTelegraphLayer)이 맡으면 그쪽이 모아 그린다.
static func draw(e: Enemy, c: CanvasItem, k: float, flash: bool) -> void:
	paint(e, _one, Vector2.ZERO, k, flash, 1)
	_one.flush(c)


## 예고 획을 b에 모은다. at = 그릴 층에서 사수 자리, crowd = 지금 한꺼번에 예고 중인 사수 수 (VolleyFeelData 붐빔 모양).
static func paint(e: Enemy, b: InkBatch, at: Vector2, k: float, flash: bool, crowd: int) -> void:
	var a := e.attack
	var d := RangedTelegraphData.default()
	var v := VolleyFeelData.default()
	var busy := crowd >= v.crowd_from
	var wm := v.crowd_width_mult if busy else 1.0
	var am := v.crowd_alpha_mult if busy else 1.0
	var sm := v.crowd_shadow_mult if busy else 1.0
	var dir := a.aim_dir
	var full := a.data.projectile_range
	var len := full
	if d.style == 1:  # 처음 draw_part 동안 쏘는 쪽에서 과녁 쪽으로 그어진다 (예고 시간은 그대로)
		len = full * (1.0 - pow(1.0 - clampf(k / d.draw_part, 0.0, 1.0), 2.0))
	var w := lerpf(d.width_from, d.width_to, k)
	if d.style == 1 and k >= d.tense_from:  # 팽팽: 더 가늘고 곧게
		w = d.tense_width
	w *= wm
	var end := dir * len
	var shadow := Color(Ink.INK, d.shadow_alpha * sm)
	var seal := TelegraphStyleData.default().seal()  # 그림새에 따라 쨍한/탁한 인주 (근접 예고와 한 식구)
	var main := Color(seal.lightened(0.45), 1.0) if flash else Color(seal, lerpf(d.alpha_from, d.alpha_to, k) * am)
	if d.style == 2:  # 실제 맞는 폭: 과녁 쪽 끝 가까이에만 옅게 (끝이 가늘어지는 획 모양 그대로)
		b.stroke(at + dir * full * (1.0 - d.hit_tail), at + dir * full, a.data.projectile_radius * 2.0,
			Color(seal, d.hit_alpha * k * am))
	b.stroke(at + dir * 4.0, at + end + dir * 4.0, w + d.shadow_extra * sm, shadow)
	b.stroke(at, at + end, w, main)
	b.stroke(at, at + end, d.core_width * wm, Color(Ink.PAPER, d.core_alpha * am * (1.5 if flash else 1.0)))
