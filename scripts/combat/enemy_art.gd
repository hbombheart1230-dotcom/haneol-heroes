class_name EnemyArt
extends RefCounted
## 적 임시 그래픽: 수묵풍 실루엣 + 인주 빛 예고 영역. 정식 그래픽 교체 시 이 파일만 바꾼다.
## 종류는 data.id로 구분: chaser(창), archer(활), heavy(두꺼운 갑옷), boss(투구·대검·금빛).


static func draw(e: Enemy) -> void:
	_telegraph(e)
	var r := e.body_radius
	var id: StringName = e.data.id if e.data else &"chaser"
	var seed := float(e.get_instance_id() % 97)
	Ink.shadow(e, Vector2(0, r * 0.7), r * 1.05)
	if e.sprite:
		return  # 몸은 구워진 스프라이트가 그린다
	var body := Color(1, 1, 1) if e.flash_left() > 0.0 else Ink.INK
	var to_target := Vector2.DOWN
	if e.target and is_instance_valid(e.target):
		var d := e.target.global_position - e.global_position
		if d.length_squared() > 1.0:
			to_target = d.normalized()
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
		&"boss_general":
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


## 예고 영역: 인주 빛으로 차오르고 먹선 테두리.
static func _telegraph(e: Enemy) -> void:
	_opening(e)
	var a := e.attack
	if a == null or a.state != EnemyAttack.State.WINDUP:
		return
	var k := a.windup_ratio()
	var fill := Color(Ink.SEAL, 0.12 + 0.3 * k)
	var edge := Color(Ink.SEAL, 0.85)
	var origin := e.to_local(a.aim_origin)
	match a.data.kind:
		EnemyAttackData.Kind.SHOOT:
			var end := a.aim_dir * a.data.projectile_range
			Ink.stroke(e, Vector2.ZERO, end, 3.0 + 7.0 * k, Color(Ink.SEAL, 0.2 + 0.4 * k))
		EnemyAttackData.Kind.CONE:
			var half := deg_to_rad(a.data.angle_degrees * 0.5)
			var a0 := a.aim_dir.angle()
			var pts := PackedVector2Array([origin])
			for i in 17:
				pts.append(origin + Vector2.from_angle(a0 - half + 2.0 * half * i / 16.0) * a.data.radius)
			e.draw_colored_polygon(pts, fill)
			pts.append(origin)
			e.draw_polyline(pts, edge, 4.0)
		EnemyAttackData.Kind.CHARGE, EnemyAttackData.Kind.PULL:
			var d := a.aim_dir
			var n := d.orthogonal() * a.data.width * 0.5
			var back := origin - d * a.data.width * 0.5
			var front := origin + d * a.data.length
			var rect := PackedVector2Array([back + n, front + n, front - n, back - n])
			e.draw_colored_polygon(rect, fill)
			rect.append(back + n)
			e.draw_polyline(rect, edge, 4.0)
		EnemyAttackData.Kind.SHOCKWAVE:
			Ink.blob(e, origin, a.data.radius * k, fill, 3.0, 0.06, 0.6)
			Ink.ring(e, origin, a.data.radius, 4.0, edge)
		_:  # SLAM: 플레이어 자리
			var p := e.to_local(a.target_point)
			Ink.blob(e, p, a.data.radius * k, fill, 4.0, 0.06, 0.6)
			Ink.ring(e, p, a.data.radius, 4.0, edge)
