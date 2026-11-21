class_name EnemyStatusArt
extends RefCounted
## 적 상태 표시 (enemy.gd가 400줄을 넘지 않게 나눔): 느려짐 고리, 기절 고리, 정예 갑옷·보스 경직 막대.


static func draw(e: Enemy, slowed: bool, stunned: bool) -> void:
	var r := e.body_radius
	if slowed:  # 느려짐: 발밑 먹 고리
		e.draw_arc(Vector2(0, r * 0.7), r * 1.1, 0.0, TAU, 20, Color(Ink.INK, 0.35), 3.0)
	if stunned:  # 기절: 머리 위 번개 고리
		var top := Vector2(0, -r * 2.2)
		var spin := Time.get_ticks_msec() * 0.008
		e.draw_arc(top, r * 0.6, spin, spin + PI * 1.3, 12, Color(1.0, 0.9, 0.3, 0.9), 3.0)
	_draw_poise(e)


## 발밑 막대: 정예 갑옷 (은빛, 깨지면 비었다가 다시 찬다), 보스 경직 게이지 (금빛, 차면 휘청).
static func _draw_poise(e: Enemy) -> void:
	var p := e.poise
	if p == null:
		return
	var ratio := p.bar_ratio()
	if ratio < 0.0:
		return
	var ai := Enemy.ai_data()
	var w := maxf(e.body_radius * e.size_mult * 2.2, 36.0)
	var at := Vector2(-w * 0.5, e.body_radius * e.size_mult + 6.0)
	e.draw_rect(Rect2(at, Vector2(w, ai.poise_bar_height)), Color(Ink.INK, 0.55))
	var col := ai.armor_bar_color if p.armor_max > 0.0 else ai.stagger_bar_color
	if p.armor_max > 0.0 and not p.is_armored():
		col = Color(col, 0.35)  # 깨짐: 흐리게 (다시 차는 중)
		ratio = 1.0 - p.regen_left / maxf(ai.armor_regen_delay, 0.01)
	e.draw_rect(Rect2(at, Vector2(w * clampf(ratio, 0.0, 1.0), ai.poise_bar_height)), col)
