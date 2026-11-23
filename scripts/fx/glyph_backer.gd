class_name GlyphBacker
extends Node2D
## 세종 글자 탄 밑받침 (RangedFeelData "글자 탄"): 뒤로 끌리는 먹 꼬리, 한지색 부드러운 심, 먹 테두리 고리.
## 어두운 바닥(한산 갑판 등)에서 금빛 글자가 묻히지 않게. 탄(Projectile)의 자식이라 함께 돌고 움직인다 (꼬리 = 뒤쪽 -x).

var px: float = 110.0
var tail: float = 90.0
var data: RangedFeelData


func setup(p_data: RangedFeelData, glyph_px: float, trail_len: float) -> void:
	data = p_data
	px = glyph_px
	tail = trail_len * p_data.glyph_tail_mult
	show_behind_parent = true
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var r := px * 0.5 * data.glyph_paper_scale
	if tail > 0.0:  # 먹 꼬리: 뒤로 갈수록 가늘게
		Ink.stroke(self, Vector2(-tail - r * 0.5, 0.0), Vector2(-r * 0.3, 0.0), px * data.glyph_tail_width, data.glyph_rim)
	var dot := VfxTextures.get_texture(SkillVfxData.Shape.DOT)
	draw_texture_rect(dot, Rect2(-r * 1.05, -r * 1.05, r * 2.1, r * 2.1), false, data.glyph_paper)
	Ink.ring(self, Vector2.ZERO, r * 0.92, data.glyph_rim_width, data.glyph_rim, 1.0)  # 붓으로 그은 먹 테두리 (둥글게)
