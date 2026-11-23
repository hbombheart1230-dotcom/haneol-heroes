class_name SkillContext
extends RefCounted
## 기술이 세계와 상호작용하는 공통 도구 (대상 찾기, 피해, 투사체, 이펙트).
## 영웅별 기술은 이 도구만 사용해 노드 구조에 의존하지 않는다.

var player: Player
var world: Node
var fx: FxLayer
var projectile_scene: PackedScene
var enemy_source: Callable
var hit_stop_enabled: bool = true
## 지금 발동 중인 기술 (이펙트 데이터를 읽는다). 없으면 이펙트 없음.
var skill: SkillDef
## 휘감는 기술(sweep) 중: 적마다 멈추지 않고 휘감기가 끝날 때 한 번 크게 (CombatFeelData.sweep_final_stop).
var defer_stop: bool = false
## 충전 조준 (SkillDef.charge_aim): 모으는 동안 잡은 방향. ZERO면 없음.
var aim_dir: Vector2 = Vector2.ZERO
var _thud_done: bool = false


## 히트스톱: 아주 짧게 게임 시간을 거의 멈춘다 (엔진 기본 time_scale + 실시간 타이머, GameTime 공용).
func hit_stop(duration: float, scale: float = 0.05) -> void:
	if not hit_stop_enabled or duration <= 0.0 or player == null or not player.is_inside_tree():
		return
	GameTime.stop(player.get_tree(), duration, scale)


func enemies() -> Array:
	return enemy_source.call() if enemy_source.is_valid() else []


## 가장자리 판정 (LoL식): 적 몸이 범위에 걸치면 맞는다 (중심점 + 몸 반경 × skill_edge_scale).
func enemies_in_radius(center: Vector2, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies():
		var en := e as Enemy
		if en and is_instance_valid(en) and en.global_position.distance_to(center) <= radius + edge_of(en):
			out.append(en)
	return out


## 적 몸이 판정에 더해지는 폭(px).
static func edge_of(en: Enemy) -> float:
	return en.body_radius * en.size_mult * Feedback.feel_data().skill_edge_scale


func enemies_near_segment(a: Vector2, b: Vector2, half_width: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies():
		var en := e as Enemy
		if en == null or not is_instance_valid(en):
			continue
		var p := Geometry2D.get_closest_point_to_segment(en.global_position, a, b)
		if p.distance_to(en.global_position) <= half_width + edge_of(en):
			out.append(en)
	return out


## 살아 있는 적에게 피해. 반환: 실제로 맞았으면 true.
## stop: 기술 명중 멈춤 공통 규칙(SkillHitStop)에 알림. 계속 닿는 장판·도는 글자·벌레는 false.
func hit(en: Enemy, dmg: int, stop: bool = true) -> bool:
	var h := en.get_node_or_null("Health") as Health
	if h == null or not h.is_alive():
		return false
	h.damage(dmg)
	if stop and not defer_stop and hit_stop_enabled and player and player.is_inside_tree():
		SkillHitStop.request(player.get_tree(), dmg)
	if stop and player:  # 한 번에 끊어 치는 명중: 닿는 자리 섬광·튐 줄기 + 퍽 소리 (평타와 같은 한 타 충격)
		HitImpact.on_enemy(en, player.global_position, HitImpact.data().skill_step, spark_color())
		if not _thud_done:  # 퍽 소리·진동은 발동 한 번에 한 번 (기술 소리 층과 겹쳐 한꺼번에 울리지 않게)
			_thud_done = true
			HitImpact.on_swing(HitImpact.data().skill_step)
	if fx:
		fx.add_spark(en.global_position, spark_color())  # 흰 불꽃 대신 영웅색 (밝은 바닥에서 묻히지 않게)
	if skill and skill.vfx_hit and player:
		var dir := en.global_position - player.global_position
		Feedback.vfx_burst(skill.vfx_hit, en.global_position, dir, skill.vfx_level)
		if stop:  # 한 번에 끊어 치는 명중만 (계속 닿는 장판·글자는 자국·밀림 없음)
			SkillStageFx.on_hit(skill.vfx_hit, en.global_position, dir, dmg, skill.vfx_level, skill.hit_layer_sfx)
	return true


## 기술이 내리꽂히는 자리: vfx_impact 입자 + (설정돼 있으면) 하늘에서 번개 줄기.
## radius > 0이면 그림을 그 판정 반경에 맞춘다 (판정과 그림 크기가 같아야 "맞을 것 같은" 대로 맞는다).
func impact(pos: Vector2, dir: Vector2 = Vector2.ZERO, radius: float = 0.0) -> void:
	if skill == null or skill.vfx_impact == null:
		return
	var v := skill.vfx_impact
	if v.has_bolt() and fx:
		fx.add_bolt(pos + Vector2(0, -v.bolt_height), pos, v.bolt_width, v.bolt_time, v.bolt_color, v.bolt_segments,
			v.bolt_jitter)
	if dir.length_squared() < 0.0001 and v.piece_count > 0 and player:
		dir = player.facing  # 조각은 바라보는 방향부터 휘감는다 (SweepRun과 같은 시작)
	Feedback.vfx_burst(v, pos, dir, skill.vfx_level, radius)
	Feedback.impact_haptic()
	SkillStageFx.play(skill.impact_sfx, 0.06)


## 지연 기술의 예고 (vfx_impact.gather_*): 떨어질·펼쳐질 자리로 기운이 모인다.
func foretell(pos: Vector2) -> void:
	if skill and skill.vfx_impact:
		SkillStageFx.gather(skill.vfx_impact, pos, skill.vfx_level)


## 휘감는 기술: 바라보는 방향부터 vfx_impact.piece_sweep초에 한 바퀴 돌며 targets를 차례로 strike.
## 그림(조각 등장·바늘)도 같은 방향·같은 시간으로 펼친다. 눈금이 있으면 지날 때마다 번쩍.
func sweep(center: Vector2, targets: Array[Enemy], strike: Callable) -> SweepRun:
	var v := skill.vfx_impact if skill else null
	var start := player.facing.angle() if player and player.facing.length_squared() > 0.0001 else -PI * 0.5
	var dir_sign := v.piece_dir if v else 1.0
	var t := v.piece_sweep if v and v.piece_count > 0 else 0.0
	var ticks := v.tick_count if v else 0
	var level := skill.vfx_level if skill else 0
	var on_tick := func(i: int) -> void: SkillStageFx.tick(v, center, start, i, level)
	defer_stop = t > 0.0 and Feedback.feel_data().sweep_final_stop > 0.0  # 시작 방향 적(누르는 순간)부터 미룬다
	return SweepRun.new(strike, center, targets, start, dir_sign, t, ticks, on_tick if ticks > 0 else Callable(), _sweep_done)


## 휘감기가 끝남: 맞힌 적이 있으면 한 번 크게 멈춤 (기술 멈춤 상한 skill_stop_cap × sweep_final_stop 안에서).
func _sweep_done(hits: int) -> void:
	var was := defer_stop
	defer_stop = false
	var f := Feedback.feel_data()
	if was and hits > 0 and hit_stop_enabled and player and player.is_inside_tree():
		GameTime.stop(player.get_tree(), f.skill_stop_cap * clampf(f.sweep_final_stop, 0.0, 1.0), f.sweep_final_scale)


## 직선 기술 경로 a→b에 그림 띠 (vfx_impact.strip). 띠가 없으면 아무것도 안 한다.
func strip(a: Vector2, b: Vector2) -> void:
	if skill and skill.vfx_impact:
		Feedback.vfx_strip_for(skill.vfx_impact, a, b, skill.vfx_level)


## a→b 번개 줄기 (vfx_impact에 번개 설정이 있으면 꺾인 번개, 없으면 붓 획). 연쇄·벼락길에 쓴다.
func bolt(a: Vector2, b: Vector2, width: float, duration: float, color: Color) -> void:
	if fx == null:
		return
	var v := skill.vfx_impact if skill else null
	if v and v.has_bolt():
		fx.add_bolt(a, b, width, duration, v.bolt_color, v.bolt_segments, v.bolt_jitter)
	else:
		fx.add_slash(a, b, width, duration, color)


## 화면 흔들림 (Feedback이 없으면 아무 일도 안 함).
func shake(amount: float) -> void:
	Feedback.shake(amount)


## 기술이 남기는 노드(소용돌이 등)를 월드에 붙인다.
func add_to_world(node: Node2D, at: Vector2) -> void:
	var parent := world if world else player.get_parent()
	parent.add_child(node)
	node.global_position = at


## 투사체 생성. configure는 트리에 들어가기 전(_ready 전)에 호출된다.
func spawn_projectile_configured(configure: Callable) -> Projectile:
	if projectile_scene == null:
		return null
	var p := projectile_scene.instantiate() as Projectile
	configure.call(p)
	p.global_position = player.global_position
	var parent := world if world else player.get_parent()
	parent.add_child(p)
	return p


## 타격 불꽃 색: 영웅 근접 색 (없으면 흰색).
func spark_color() -> Color:
	var a := player.hero.attack if player and player.hero else null
	return Color(a.swing_color, 1.0) if a else Color.WHITE
