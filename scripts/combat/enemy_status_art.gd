class_name EnemyStatusArt
extends RefCounted
## 적 상태 표시 (enemy.gd가 400줄을 넘지 않게 나눔): 느려짐 고리, 기절 고리, 정예 갑옷·보스 경직 막대.


## slow_amount = 느려진 정도 (0~1, 1 - 속도 배율), slow_left = 남은 시간 비율 (0~1).
static func draw(e: Enemy, slowed: bool, stunned: bool, slow_amount: float = 0.5, slow_left: float = 1.0) -> void:
	var r := e.body_radius
	if slowed:  # 느려짐: 발밑 한지색 번짐(짙기 = 느려진 정도) + 남은 시간만큼 남는 바닥 호 (시계처럼 줄어듦)
		var ai := Enemy.ai_data()
		var m := r * ai.slow_mark_scale
		var foot := Vector2(0, r * 0.7)
		e.draw_set_transform(foot, 0.0, Vector2(1.0, 0.6))  # 바닥에 눕힌 붓 번짐
		InkPaint.wash(e, Vector2.ZERO, m, Color(ai.slow_color, ai.slow_wash_alpha * clampf(slow_amount, 0.0, 1.0)))
		e.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_floor_arc(e, foot, m, clampf(slow_left, 0.0, 1.0), Color(ai.slow_color, ai.slow_ring_alpha), ai.slow_ring_width)
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


## 바닥에 눕힌 호 (가로 r, 세로 r × 0.6): 위에서 시작해 시계 방향으로 k만큼 (k = 1이면 한 바퀴).
static func _floor_arc(e: Enemy, center: Vector2, r: float, k: float, color: Color, width: float) -> void:
	if k <= 0.0:
		return
	var n := maxi(int(32.0 * k), 2)
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := -PI * 0.5 + TAU * k * float(i) / n
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.6))
	e.draw_polyline(pts, color, width, true)
