class_name SwingCrescent
extends RefCounted
## 평타 검기 (붓으로 그린 초승달) 그리기: 먹 외곽선 → 영웅색 → 밝은 심.
## 크기·밝기는 CombatFeelData(crescent_scale·crescent_step_scales·crescent_core_*), 모양은 BasicAttackData 타별 값.
## 어두운 바닥에서도 보이게 크고 밝게 (하데스 슬라이스: 영웅 몸의 절반이던 검기를 몸보다 크게).


## 원점(영웅)에서 오른쪽(dir 각도)으로 벤다. r = 사거리, half = 반각(라디안), flip = 위아래 뒤집기(2타 -1).
static func draw(ci: CanvasItem, art: Texture2D, angle: float, r: float, half: float, flip: float,
		col: Color, alpha: float, step: int, feel: CombatFeelData) -> void:
	var aa := ci as AutoAttack
	if aa and SwingTrail.covers(aa.player):  # 궤적(SwingTrail)이 대신 그린다
		return
	var ks := ComboSteps.at(feel.crescent_step_scales, step, 1.0)
	var k := feel.crescent_scale * ks
	var h := r * maxf(sin(half), 0.35)
	# 바깥 가장자리(물마루)를 판정 사거리에 맞춘다: 배율은 옆 폭과 두께에만 (예전엔 사거리의 1.65배까지 나가 실타격과 어긋남)
	var depth := r * feel.crescent_depth * ks
	var cr := Rect2(r * feel.crescent_reach - depth, -h * 0.9 * k, depth, h * 1.8 * k)
	ci.draw_set_transform(Vector2.ZERO, angle, Vector2(1.0, flip))
	if feel.fx_ink_outline > 0.0:  # 먹 외곽선 (조금 크게 먼저)
		ci.draw_texture_rect(art, cr.grow(r * 0.06), false, Color(Ink.INK, col.a * alpha * feel.fx_ink_outline))
	ci.draw_texture_rect(art, cr, false, Color(col.lightened(feel.crescent_lighten), col.a * alpha))
	if feel.crescent_core_alpha > 0.0:  # 밝은 심: 안쪽으로 줄여 한 번 더, 흰빛 쪽으로
		var core := Rect2(cr.position + Vector2(cr.size.x * 0.12, cr.size.y * 0.1), cr.size * Vector2(0.86, 0.8))
		var c := col.lerp(Color.WHITE, feel.crescent_core_white)
		ci.draw_texture_rect(art, core, false, Color(c, feel.crescent_core_alpha * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
