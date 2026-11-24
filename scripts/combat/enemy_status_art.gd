class_name EnemyStatusArt
extends RefCounted
## 적 상태 표시 (enemy.gd가 400줄을 넘지 않게 나눔): 느려짐 고리, 기절 고리, 정예 갑옷·보스 경직 막대.


static func draw(e: Enemy, slowed: bool, stunned: bool) -> void:
	var r := e.body_radius
	if slowed:  # 느려짐: 발밑 먹 고리
		e.draw_set_transform(Vector2(0, r * 0.7), 0.0, Vector2(1.0, 0.6))  # 바닥에 눕힌 붓 고리
		InkPaint.ring(e, Vector2.ZERO, r * 1.1, Color(Ink.INK, 0.6))
		e.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if stunned:  # 기절: 머리 위 번개 고리
		var top := Vector2(0, -r * 2.2)
		var spin := Time.get_ticks_msec() * 0.008
		InkPaint.arc(e, top, r * 0.6, spin, spin + PI * 1.3, 7.0, Color(1.0, 0.9, 0.3, 0.95), 12)
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
	var col := ai.armor_bar_color if p.armor_max > 0.0 else ai.stagger_bar_color
	if p.armor_max > 0.0 and not p.is_armored():
		col = Color(col, 0.35)  # 깨짐: 흐리게 (다시 차는 중)
		ratio = 1.0 - p.regen_left / maxf(ai.armor_regen_delay, 0.01)
	InkPaint.bar(e, Rect2(at, Vector2(w, ai.poise_bar_height)), ratio, col, Color(1, 1, 1, 0.55), 2.0)
