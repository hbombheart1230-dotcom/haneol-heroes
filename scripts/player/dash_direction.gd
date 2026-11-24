class_name DashDirection
extends RefCounted
## 대시 방향 나누기 (DashDirData, Player가 대시를 시작할 때·대시 중에 부른다): 돌진·뒤로 빠지기·옆(지금 대시).
## 기준 적 = 영웅에서 가장 가까운 살아 있는 적 (enemy_range 안). 돌진 타격은 멈춤 없이 지나간 몹마다 한 번.

enum Kind { SIDE, CHARGE, BACK }

## 돌진 타격으로 피해를 주는 동안 true (처치 멈춤을 걸지 않게, Feedback.enemy_died).
static var striking: bool = false


## 순수 판정: 대시 방향 dir, 영웅에서 기준 적까지 to_enemy (ZERO면 적 없음).
static func classify(d: DashDirData, dir: Vector2, to_enemy: Vector2) -> Kind:
	if d == null or to_enemy.length_squared() < 1.0 or dir.length_squared() < 0.0001:
		return Kind.SIDE
	var deg := rad_to_deg(absf(dir.angle_to(to_enemy)))
	if deg <= d.charge_cone_deg:
		return Kind.CHARGE
	if deg >= 180.0 - d.back_cone_deg:
		return Kind.BACK
	return Kind.SIDE


## 영웅 기준 가장 가까운 적까지 (enemy_range 밖이면 ZERO).
static func to_nearest(p: Player, list: Array, range_px: float) -> Vector2:
	var best := Vector2.ZERO
	var best_d := range_px
	for e in list:
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or en.health.is_dead():
			continue
		var off := en.global_position - p.global_position
		if off.length() <= best_d:
			best_d = off.length()
			best = off
	return best


## 대시 시작: 종류를 정하고, 뒤로 빠지기는 적을 본 채로 (그림 방향), 연속 대시면 타격 없음.
static func begin(p: Player, list: Array, chained: bool) -> void:
	var d := p.hero.dash_dir if p.hero else null
	p.dash_struck.clear()
	if d == null:
		p.dash_kind = Kind.SIDE
		p.dash_strikes = false
		return
	var to := to_nearest(p, list, d.enemy_range)
	p.dash_kind = classify(d, p.get_dash_direction(), to)
	# 예고 범위 안에서 시작한 대시는 회피 (빠져나오기): 돌진 타격·대가(충전·끝 경직)를 붙이지 않는다 (회피를 방해하지 않게)
	p.dash_strikes = p.dash_kind == Kind.CHARGE and d.strike_enabled and not chained 		and not ComboSteps.in_windup(list, p.global_position)
	if p.dash_kind == Kind.BACK:
		p.facing = to.normalized()  # 적을 본 채로 뒤로


## 대시 중 한 틱: 돌진 타격 (지나간 몹마다 한 번, 멈춤 없음: 처치 멈춤도 걸지 않는다).
## 이번 틱에 지나갈 선분(지금 자리 → 속도 × delta)과 몹 사이 거리로 본다 (빠른 대시가 몹을 건너뛰지 않게).
static func tick(p: Player, list: Array, delta: float) -> void:
	if not p.dash_strikes or p.hero == null or p.hero.dash_dir == null:
		return
	var d := p.hero.dash_dir
	var dmg := maxi(roundi(p.hero.attack.melee_damage * d.strike_damage_mult), 1)
	var hit := false
	for e in list:
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or en.health.is_dead() or p.dash_struck.has(en.get_instance_id()):
			continue
		var near := Geometry2D.get_closest_point_to_segment(en.global_position, p.global_position, p.global_position + p.velocity * delta)
		if en.global_position.distance_to(near) > d.strike_radius + en.body_radius * en.size_mult:
			continue
		p.dash_struck[en.get_instance_id()] = true
		striking = true
		en.health.damage(EnemyAnswer.scaled(en, EnemyAnswer.DASH, dmg))  # 정답 표 (내닫아 치기)
		striking = false
		hit = true
		if d.strike_push > 0.0:  # 밀쳐내기 = 넉백 + 잡몹 잠깐 경직 (Enemy.shove)
			en.shove(p.get_dash_direction() * d.strike_push)
		if d.strike_slow_time > 0.0:
			en.slow(d.strike_slow, d.strike_slow_time)
		var look := p.hero.dash_look
		if look and look.strike_hit_fx:  # 평타와 같은 타격 효과 (섬광·튐 줄기·퍽)
			HitImpact.on_enemy(en, p.global_position, 1, p.hero.attack.swing_color)
	if hit and d.strike_sfx != &"" and Feedback.instance:
		Feedback.instance.play(d.strike_sfx, 0.05)


## 대시가 끝남: 맞힌 게 있으면 대가 (충전 더 쓰기·끝 경직).
static func end(p: Player) -> void:
	var d := p.hero.dash_dir if p.hero else null
	if d == null or p.dash_struck.is_empty():
		return
	for i in d.strike_extra_charge:
		p.dash.try_consume()
	if d.strike_end_lag > 0.0:
		p.slow_for(d.strike_end_lag, d.strike_end_mult)


## 이번 대시의 그림 (시트에 없으면 dash).
static func anim(p: Player, sheet: SpriteSheetSet) -> String:
	var look := DashLook.pose(p, sheet)  # 치는·피하는 내닫기 자세 (DashLookData)가 있으면 그것
	if look.size() == 2:
		return String(look[0])
	var d := p.hero.dash_dir if p.hero else null
	if d == null or sheet == null:
		return "dash"
	var want := String(d.charge_anim if p.dash_kind == Kind.CHARGE else (d.back_anim if p.dash_kind == Kind.BACK else &"dash"))
	if not sheet.has_anim(want) and p.dash_kind == Kind.BACK:
		want = String(d.back_fallback)
	return want if sheet.has_anim(want) else "dash"
