class_name RangedTelegraph
extends RefCounted
## 원거리(사격) 예고 그리기 (EnemyArt가 부른다): 가늘고 날렵한 인주 획(양 끝이 가늘어지는 Ink.stroke)은 그대로 두고
## 바닥에서 뜨게만 한다 — 불투명하게, 아주 얇은 먹 그림자와 밝은 속심, 쏘기 직전 팽팽해졌다 번쩍.
## 모양(RangedTelegraphData.style): 0 또렷한 획 / 1 쏘는 쪽에서 과녁으로 그어지는 획 / 2 또렷한 획 + 맞는 폭을 끝에만.
## 수치는 RangedTelegraphData. c는 적과 같은 좌표계. 화면 밖 사수는 획이 화면 가장자리에서 들어오는 것으로 충분하다.


static func draw(e: Enemy, c: CanvasItem, k: float, flash: bool) -> void:
	var a := e.attack
	var d := RangedTelegraphData.default()
	var dir := a.aim_dir
	var full := a.data.projectile_range
	var len := full
	if d.style == 1:  # 처음 draw_part 동안 쏘는 쪽에서 과녁 쪽으로 그어진다 (예고 시간은 그대로)
		len = full * (1.0 - pow(1.0 - clampf(k / d.draw_part, 0.0, 1.0), 2.0))
	var w := lerpf(d.width_from, d.width_to, k)
	if d.style == 1 and k >= d.tense_from:  # 팽팽: 더 가늘고 곧게
		w = d.tense_width
	var end := dir * len
	var shadow := Color(Ink.INK, d.shadow_alpha)
	var main := Color(Ink.SEAL.lightened(0.45), 1.0) if flash else Color(Ink.SEAL, lerpf(d.alpha_from, d.alpha_to, k))
	if d.style == 2:
		_hit_width(c, dir, full, a.data.projectile_radius * 2.0, d, k)
	Ink.stroke(c, dir * 4.0, end + dir * 4.0, w + d.shadow_extra, shadow)
	Ink.stroke(c, Vector2.ZERO, end, w, main)
	Ink.stroke(c, Vector2.ZERO, end, d.core_width, Color(Ink.PAPER, d.core_alpha * (1.5 if flash else 1.0)))


## 실제 맞는 폭: 과녁 쪽 끝 가까이에만 옅게 (끝이 가늘어지는 획 모양 그대로).
static func _hit_width(c: CanvasItem, dir: Vector2, full: float, hit_w: float, d: RangedTelegraphData, k: float) -> void:
	var from := dir * full * (1.0 - d.hit_tail)
	Ink.stroke(c, from, dir * full, hit_w, Color(Ink.SEAL, d.hit_alpha * k))

