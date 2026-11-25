class_name EnemyArt
extends RefCounted
## 적 임시 그래픽: 수묵풍 실루엣 + 인주 빛 예고 영역. 정식 그래픽 교체 시 이 파일만 바꾼다.
## 종류는 data.id로 구분: chaser(창), archer(활), heavy(두꺼운 갑옷). 보스(is_boss)는 모두 투구·대검·금빛.


static func draw(e: Enemy) -> void:
	EnemyAura.draw(e)  # 먹물 장판은 맨 아래
	_telegraph(e)
	var r := e.body_radius
	var id: StringName = e.data.id if e.data else &"chaser"
	if e.data and e.data.is_boss:
		id = &"boss"
	var seed := float(e.get_instance_id() % 97)
	var feel := Feedback.feel_data()  # 큰 적일수록 넓고 진한 먹 그림자 (무게감)
	var rr := r * e.size_mult
	var big := clampf((rr - 18.0) / maxf(feel.enemy_shadow_big_radius - 18.0, 1.0), 0.0, 1.0)
	Ink.weight_shadow(e, Vector2(0, r * 0.7), rr * feel.enemy_shadow_scale, lerpf(feel.enemy_shadow_alpha, feel.enemy_shadow_alpha_big, big))
	if e.sprite:
		return  # 몸은 구워진 스프라이트가 그린다
	var body := Color(1, 1, 1) if e.flash_left() > 0.0 else Ink.INK
	var to_target := Vector2.DOWN
	if e.target and is_instance_valid(e.target):
		var d := e.target.global_position - e.global_position
		if d.length_squared() > 1.0:
			to_target = d.normalized()
	if e.data and e.data.aura and e.data.move_speed <= 0.0:  # 깃발 (서 있기만 하는 적): 깃대 + 인주 깃발
		Ink.stroke(e, Vector2(0, r * 0.6), Vector2(0, -r * 2.6), 5.0, body)
		e.draw_colored_polygon(PackedVector2Array([Vector2(2, -r * 2.6), Vector2(r * 1.6, -r * 2.2), Vector2(2, -r * 1.7)]), Ink.SEAL)
		return
	match id:
		&"archer":
			Ink.blob(e, Vector2(0, -r * 0.3), r * 0.85, body, seed, 0.2, 1.1)
			var bow := Vector2(0, -r * 0.4) + to_target * r * 0.9
			e.draw_arc(bow, r * 0.8, to_target.angle() - 1.2, to_target.angle() + 1.2, 12, Ink.INK, 3.0)
			e.draw_circle(Vector2(0, -r * 1.25), r * 0.35, Color(0.35, 0.55, 0.3))  # 초록 두건
		&"heavy":
			Ink.blob(e, Vector2(0, -r * 0.3), r, body, seed, 0.08, 1.0)
			for k in 3:  # 갑옷 미늘
				var y := -r * 0.6 + k * r * 0.4
				e.draw_line(Vector2(-r * 0.7, y), Vector2(r * 0.7, y), Color(0.55, 0.45, 0.65), 4.0)
			e.draw_circle(Vector2(0, -r * 1.2), r * 0.4, Color(0.4, 0.3, 0.5))
		&"boss":
			Ink.blob(e, Vector2(0, -r * 0.3), r * 1.05, body, seed, 0.1, 1.1)
			Ink.ring(e, Vector2(0, -r * 0.3), r * 0.9, 6.0, Ink.GOLD, 1.0, seed)
			e.draw_circle(Vector2(0, -r * 1.3), r * 0.42, Ink.GOLD)  # 투구
			Ink.stroke(e, Vector2(0, -r * 1.75), Vector2(0, -r * 1.25), 8.0, Ink.SEAL)  # 투구 술
			var blade := to_target * r * 2.0
			Ink.stroke(e, to_target * r * 0.4, blade, 12.0, Ink.INK)
			e.draw_line(to_target * r * 0.6, blade, Color(0.85, 0.85, 0.8), 3.0)
		_:  # chaser: 창병
			Ink.blob(e, Vector2(0, -r * 0.3), r * 0.9, body, seed, 0.18, 1.1)
			e.draw_circle(Vector2(0, -r * 1.2), r * 0.32, Ink.SEAL)  # 붉은 두건
			Ink.stroke(e, -to_target * r * 0.6, to_target * r * 1.5, 4.0, Color(0.35, 0.25, 0.15))


## 공격 직후 경직(빈틈): 머리 위 흰 먹 소용돌이 (이때 치면 더 아프다).
static func _opening(e: Enemy) -> void:
	var a := e.attack
	if a == null or a.state != EnemyAttack.State.RECOVER:
		return
	var top := Vector2(0, -e.body_radius * 2.4)
	var spin := -Time.get_ticks_msec() * 0.006
	e.draw_arc(top, e.body_radius * 0.55, spin, spin + PI * 1.5, 12, Color(Ink.PAPER, 0.95), 4.0)
	e.draw_arc(top, e.body_radius * 0.55, spin, spin + PI * 1.5, 12, Color(Ink.INK, 0.6), 1.5)


## 예고 그리는 부분: 채움(바닥, 적 노드)과 테두리(기술 효과 위 층, TelegraphRim). 색 규칙 B (사용자 2026-11-24).
const FILL := 1
const RIM := 2


## 예고 영역: 인주 빛으로 차오르고 먹선 테두리. 테두리는 TelegraphRim이 있으면 그쪽(기술 효과 위)에서 그린다.
static func _telegraph(e: Enemy) -> void:
	_opening(e)
	telegraph_part(e, e, FILL if e.has_node(^"TelegraphRim") else FILL | RIM)


## 예고 한 부분을 c(적과 같은 좌표계)에 그린다. part = FILL·RIM 비트.
static func telegraph_part(e: Enemy, c: CanvasItem, part: int) -> void:
	var a := e.attack
	if a == null or a.state != EnemyAttack.State.WINDUP:
		return
	var k := a.windup_ratio()
	# 공통 예고 규칙: 붉은 먹 채움이 진해지고 (fill), 테두리는 처음부터 (edge), 맞기 직전엔 번쩍 (밝고 두껍게).
	var flash := a.is_flashing(Enemy.ai_data().strike_flash_time)
	var fill := Color(Ink.SEAL, (0.12 + 0.3 * k) + (0.2 if flash else 0.0))
	var edge := Color(Ink.SEAL.lightened(0.45), 1.0) if flash else Color(Ink.SEAL, 0.85)
	var do_fill := part & FILL != 0
	var do_rim := part & RIM != 0
	var origin := e.to_local(a.aim_origin)
	match a.data.kind:
		EnemyAttackData.Kind.SHOOT:  # 조준선 자체가 테두리
			if do_rim:
				RangedTelegraph.draw(e, c, k, flash)
		EnemyAttackData.Kind.CONE:
			var half := deg_to_rad(a.data.angle_degrees * 0.5)
			var a0 := a.aim_dir.angle()
			var pts := PackedVector2Array([origin])
			for i in 17:
				pts.append(origin + Vector2.from_angle(a0 - half + 2.0 * half * i / 16.0) * a.data.radius)
			if do_fill:
				c.draw_colored_polygon(pts, fill)
			if do_rim:
				pts.append(origin)
				c.draw_polyline(pts, edge, 4.0)
		EnemyAttackData.Kind.CHARGE, EnemyAttackData.Kind.PULL, EnemyAttackData.Kind.THRUST:
			var d := a.aim_dir
			var n := d.orthogonal() * a.data.width * 0.5
			var back := origin - d * a.data.width * 0.5
			var front := origin + d * a.data.length
			var rect := PackedVector2Array([back + n, front + n, front - n, back - n])
			if do_fill:
				c.draw_colored_polygon(rect, fill)
			if do_rim:
				rect.append(back + n)
				c.draw_polyline(rect, edge, 4.0)
		EnemyAttackData.Kind.SHOCKWAVE:
			if do_fill:
				Ink.blob(c, origin, a.data.radius * k, fill, 3.0, 0.06, 0.6)
			if do_rim:
				Ink.ring(c, origin, a.data.radius, 4.0, edge)
		_:  # SLAM: 플레이어 자리
			var p := e.to_local(a.target_point)
			if do_fill:
				Ink.blob(c, p, a.data.radius * k, fill, 4.0, 0.06, 0.6)
			if do_rim:
				Ink.ring(c, p, a.data.radius, 4.0, edge)
