class_name AutoAttack
extends Node2D
## 자동 기본 공격 (영웅 공통). 수치는 BasicAttackData(영웅 데이터)에서 읽는다.
## - 근접: 사거리 안에 적이 있으면 가장 가까운 적 방향 부채꼴 베기.
## - 원거리: 근접 사거리 밖, 원거리 사거리 안의 가장 가까운 적에게 투사체 발사.
## 이동 중에도 계속 발동한다.

signal melee_swung(direction: Vector2, hits: int)
## 근접: 휘두르는 동작 시작 (피해는 melee_delay 뒤 칼이 닿을 때, PlayerView가 동작을 맞춘다).
signal melee_windup(direction: Vector2)
signal projectile_fired(projectile: Projectile)
## 원거리: 던지는 동작 시작 (손을 떠나기 전, PlayerView가 동작을 맞춘다).
signal ranged_windup(direction: Vector2)

@export var player: Player
## 비어 있으면 player.hero.attack, 그것도 없으면 기본값.
@export var data: BasicAttackData
@export var projectile_scene: PackedScene
## 투사체를 붙일 노드 (월드). 비어 있으면 플레이어의 부모.
@export var projectile_parent: Node

var _melee_cd: float = 0.0
var _ranged_cd: float = 0.0
var _glyph_i: int = 0
var _swing_dir: Vector2 = Vector2.DOWN
var _swing_time: float = 0.0
## 던지는 중인 탄: 손을 떠나기까지 남은 시간과 방향.
var _release_left: float = -1.0
var _release_dir: Vector2 = Vector2.ZERO
## 던지기 시작할 때의 수치 사본 (던지는 사이 성장이 같은 리소스를 바꿔도 이 탄은 그대로)과
## 그때의 데이터 (영웅이 바뀌어 data가 다른 것으로 바뀌면 던지지 않는다).
var _release_data: BasicAttackData
var _release_src: BasicAttackData
## 휘두르는 중: 칼이 닿기까지 남은 시간 (-1 = 없음)과 그때의 데이터 (바뀌면 버린다).
var _melee_left: float = -1.0
## 모으기(step_windup_pause)가 끝난 뒤로 미룬 전진 (모으는 동안에는 제자리).
var _stepin_left: float = -1.0
var _stepin_vec := Vector2.ZERO
var _melee_src: BasicAttackData
## 근접 우선 (A1): 원거리를 참은 시간. 평타 연계 (B4): 몇 번째 근접인지와 마지막 근접 뒤 흐른 시간.
var _hold: float = 0.0
var chain_step: int = 0
var _since_melee: float = INF
## 마지막으로 칼이 닿은 근접이 강타(연계 마지막)였는지 (PlayerView 멈춤 길이).
var last_heavy: bool = false
## 탭 연타 (A안): 마지막 손 평타 뒤 흐른 시간, 지금 나가는 평타가 손으로 낸 것인지 (신호 받는 쪽이 구분).
var _since_manual: float = INF
var last_manual: bool = false
## 연타 흐름: 마지막으로 칼이 닿은 뒤 흐른 시간 (캔슬 구간), 이번 원거리 연타 번호와 손에 든 탄의 번호·동작.
var _since_strike: float = INF
var ranged_step: int = 0
var _release_step: int = 0
var _release_anim: String = ""


func _ready() -> void:
	if data == null and player and player.hero:
		data = player.hero.attack
	if data == null:
		data = BasicAttackData.new()
	RangedFeel.attach(self)  # 원거리 한 발의 타격감 (scripts/fx/ranged_feel.gd)


## 사용 중인 수치 (테스트 등에서 _ready 전에 호출돼도 기본값을 준다).
func stats() -> BasicAttackData:
	if data == null:
		data = BasicAttackData.new()
	return data


func enemies() -> Array:
	return get_tree().get_nodes_in_group(Enemy.GROUP) if is_inside_tree() else []


## 공격 타이머 진행. 테스트에서 적 목록을 직접 넣을 수 있다.
func tick(delta: float, enemy_list: Array) -> void:
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	_ranged_cd = maxf(_ranged_cd - delta, 0.0)
	_swing_time = maxf(_swing_time - delta, 0.0)
	_since_melee += delta
	_since_manual += delta
	_since_strike += delta
	if player == null:
		return
	if player.is_dead():  # 죽으면 손에 든 탄·휘두르던 칼은 버린다
		_release_left = -1.0
		_melee_left = -1.0
		_stepin_left = -1.0
		_release_data = null
		return
	if _stepin_left >= 0.0:
		_stepin_left -= delta
		if _stepin_left < 0.0 and not player.is_dashing() and player.hurt_time_left() <= 0.0:
			player.apply_recoil(_stepin_vec, stats().step_in_time)
	if _melee_left >= 0.0:  # 휘두르는 중: 칼이 닿는 순간 피해
		_melee_left -= delta
		if _melee_left < 0.0 and _melee_src == data:
			_strike(player.global_position, enemy_list)
	if _release_left >= 0.0:
		_release_left -= delta
		if _release_left < 0.0:
			RangedShot.release(self, enemy_list)
	var from := player.global_position
	var nearest := Targeting.nearest(enemy_list, from, stats().ranged_range)
	if nearest == null:
		return
	var to_nearest := nearest.global_position - from
	var d := stats()
	var dist := to_nearest.length()
	if dist <= d.melee_range and d.use_melee:
		_hold = 0.0
		if _melee_cd <= 0.0:
			_melee(from, to_nearest, enemy_list)
	elif d.use_ranged and _ranged_cd <= 0.0:
		if d.use_melee and dist <= d.melee_range * d.engage_mult and _hold < d.engage_hold_max:
			_hold += delta  # 곧 붙는다: 원거리를 참고 칼을 기다린다
			return
		_hold = 0.0
		_fire(from, to_nearest.normalized())


## 손 평타를 지금 낼 수 있는지: min_gap초가 지났고, 휘두르던 칼·손에 든 탄이 없다.
func can_manual(min_gap: float) -> bool:
	return player != null and not player.is_dead() and _since_manual >= min_gap and _melee_left < 0.0 		and _release_left < 0.0 and _since_strike >= stats().cancel_after  # 앞 타가 닿은 뒤에야 끊고 들어간다


## 휘두른 칼이 아직 닿기 전인지 (대시로 끊기면 false).
func swing_pending() -> bool:
	return _melee_left >= 0.0


## 손 평타 (탭): 가장 가까운 적(원거리 사거리 안) 쪽으로, 없으면 바라보는 쪽으로 헛스윙.
## step: 근접 연계 동작 번호 (3 = 강타). ranged면 원거리 한 발 (세종 글자).
func manual_strike(step: int, ranged: bool, enemy_list: Array = []) -> void:
	var list := enemy_list if not enemy_list.is_empty() else enemies()
	var from := player.global_position
	var nearest := Targeting.nearest(list, from, stats().ranged_range)
	var to: Vector2 = nearest.global_position - from if nearest else player.facing
	_since_manual = 0.0
	_hold = 0.0
	last_manual = true
	if ranged:
		ranged_step = step
		_fire(from, to.normalized() if to.length_squared() > 0.0001 else player.facing)
		ranged_step = 0
	else:
		_step_in(to, list, step)
		_melee(from, to, list, step)
		player.slow_for(stats().swing_slow_time, stats().swing_move_mult)  # 휘두르는 동안 느리게 (M1)
	last_manual = false


## 타별 짧은 전진 (손 평타만): 앞 적 몸 안으로는 안 들어가고, 적 예고가 영웅을 덮으면 생략.
func _step_in(toward: Vector2, list: Array, step: int) -> void:
	var d := stats()
	if not d.step_in_enabled or toward.length_squared() < 0.0001 or player.is_dashing() or player.hurt_time_left() > 0.0:
		return  # 대시 중·맞아서 밀리는 중에는 전진을 얹지 않는다 (Codex 0f4456f 지적)
	var dir := toward.normalized()
	var from := player.global_position
	var px := ComboSteps.step_in(ComboSteps.at(d.step_in_px, step, 0.0), d.step_in_max,
		ComboSteps.gap_ahead(list, from, dir, player.body_radius) - 4.0, ComboSteps.in_windup(list, from))
	if px <= 0.0:
		return
	var pause := ComboSteps.at(d.step_windup_pause, step, 0.0)
	if pause > 0.0:  # 모은 뒤에 내딛는다 (Codex 22d062c 지적)
		_stepin_left = pause
		_stepin_vec = dir * px
	else:
		player.apply_recoil(dir * px, d.step_in_time)


## 이번 타의 모으기(초): 휘두르기 전 첫 칸에서 멈춤 (PlayerView가 그림을 멈춘다).
func step_pause() -> float:
	return ComboSteps.at(stats().step_windup_pause, chain_step, 0.0)


func _melee(from: Vector2, toward: Vector2, enemy_list: Array, step: int = -1) -> void:
	var d := stats()
	_melee_cd = d.melee_interval
	_swing_dir = toward.normalized() if toward.length_squared() > 0.0001 else player.facing
	chain_step = step if step > 0 else next_chain_step(chain_step, _since_melee, d)
	_since_melee = 0.0
	melee_windup.emit(_swing_dir)
	var delay := melee_delay() + step_pause()
	if delay > 0.0:
		_melee_left = delay
		_melee_src = data
		return
	_strike(from, enemy_list)


## 다음 연계 번호: window초 안에 이어지면 하나 더, 마지막 다음이나 끊기면 1 (chain_len 0 = 늘 1).
static func next_chain_step(step: int, since: float, d: BasicAttackData) -> int:
	if d.chain_len <= 0 or since > d.chain_window or step >= d.chain_len:
		return 1
	return step + 1


## 이번 근접이 연계 마지막 강타인지.
func is_heavy() -> bool:
	var d := stats()
	return d.chain_len > 1 and chain_step == d.chain_len


## 이번 근접 동작 이름: 시트에 attack2·attack3가 있으면 연계 번호대로, 없으면 attack.
func chain_anim() -> String:
	var sheet := player.hero.sprite_sheet if player and player.hero else null
	var anim := "attack%d" % chain_step if chain_step >= 2 else "attack"
	return anim if sheet and sheet.has_anim(anim) else "attack"


## 이 영웅의 근접 피해 지연 (데이터 또는 시트의 맞닿는 프레임, 연계 동작마다).
func melee_delay() -> float:
	var d := stats()
	if d.melee_delay >= 0.0:
		return d.melee_delay
	var sheet := player.hero.sprite_sheet if player and player.hero else null
	var feel := Feedback.feel_data()
	var anim := chain_anim()
	if sheet == null or not sheet.has_anim(anim):
		return feel.melee_delay_min
	var i := sheet.anim_names.find(anim)
	return AttackTiming.melee_delay(-1.0, sheet.strike_frame(anim), sheet.fps[i], feel.melee_delay_min, feel.melee_delay_max)


## 칼이 닿는 순간: 그때 부채꼴 안의 적에게 피해·넉백.
func _strike(from: Vector2, enemy_list: Array) -> void:
	var d := stats()
	_swing_time = 0.12
	var heavy := is_heavy()  # 연계 마지막: 피해·넉백 배율, 잡몹 넘어짐 (B4·B8)
	var dmg := roundi(d.melee_damage * (d.heavy_damage_mult if heavy else 1.0))
	var kb := d.melee_knockback * (d.heavy_knockback_mult if heavy else 1.0) * ComboSteps.at(d.step_knockback_mults, chain_step, 1.0)
	_since_strike = 0.0
	var hits := Targeting.in_arc(enemy_list, from, _swing_dir, d.melee_range * ComboSteps.at(d.step_range_mults, chain_step, 1.0),
		d.melee_arc_degrees * ComboSteps.at(d.step_arc_mults, chain_step, 1.0))  # 타별 모양 (3타 좁고 길게)
	for e in hits:
		var h := e.get_node_or_null("Health") as Health
		var en := e as Enemy
		if en:
			en.heavy_pending = heavy
		if h:
			h.damage(dmg)
		if en:
			en.heavy_pending = false
			ComboSteps.push(en, from, kb, heavy, d)  # 피격 반응: 툭 밀려남 (타별 배율), 3타 크게 날리기 (있으면)
			HitImpact.on_enemy(en, from, chain_step, d.swing_color)  # 닿는 자리 섬광·튐 줄기 (한 타 충격)
	if not hits.is_empty():
		HitImpact.on_swing(chain_step)  # 퍽 소리 (타마다 음높이) + 짧은 진동
		ImpactFx.melee_hit(from + _swing_dir * d.melee_range * 0.5, _swing_dir, d, heavy)  # 무기 소리·강타 흔들림
		if d.melee_recoil > 0.0:  # 칼이 닿은 반동 (Hollow Knight식)
			player.apply_recoil(-_swing_dir * d.melee_recoil)
	last_heavy = heavy
	melee_swung.emit(_swing_dir, hits.size())
	queue_redraw()


## 원거리: 던지는 동작을 시작하고 release_delay초 뒤 손에서 놓는다 (0이면 바로).
func _fire(from: Vector2, dir: Vector2) -> void:
	var d := stats()
	_ranged_cd = d.ranged_interval
	_release_step = maxi(ranged_step, 1)
	_release_anim = ranged_anim_now()
	ranged_windup.emit(dir)
	var delay := release_delay()
	if delay > 0.0:
		_release_left = delay
		_release_dir = dir
		_release_data = d.duplicate()
		_release_src = data
		return
	RangedShot.spawn_step(self, from, dir, d)


## 이번 원거리 동작: 연타 2·3번이고 시트에 throw2·throw3가 있으면 그것, 아니면 ranged_anim.
func ranged_anim_now() -> String:
	var base := String(stats().ranged_anim)
	var sheet := player.hero.sprite_sheet if player and player.hero else null
	var alt := "throw%d" % ranged_step
	return alt if ranged_step >= 2 and sheet and sheet.has_anim(alt) else base


## 손을 떠나기까지(초): 데이터, 음수면 시트 던지는 동작의 맞닿는 프레임 (근접 melee_delay와 같은 방식).
func release_delay() -> float:
	var d := stats()
	if d.release_delay >= 0.0:
		return d.release_delay
	var sheet := player.hero.sprite_sheet if player and player.hero else null
	var feel := Feedback.feel_data()
	var anim := _release_anim if _release_anim != "" else String(d.ranged_anim)
	if sheet == null or not sheet.has_anim(anim):
		return feel.release_delay_min
	var i := sheet.anim_names.find(anim)
	return AttackTiming.melee_delay(-1.0, sheet.strike_frame(anim), sheet.fps[i], feel.release_delay_min, feel.release_delay_max)


## 탄이 나가는 자리 (영웅 기준 오프셋): 시트에 무기 끝이 기록돼 있으면 던지는 동작의 맞닿는 프레임에서
## (T2, 방향마다 다름), 없으면 release_offset (앞으로 x, 위로 y).
func release_point(dir: Vector2, d: BasicAttackData) -> Vector2:
	var fallback := dir * d.release_offset.x + Vector2(0, -d.release_offset.y)
	var h := player.hero if player else null
	if h == null or h.sprite_sheet == null or d.ranged_anim == &"":
		return fallback
	var anim := _release_anim if _release_anim != "" else String(d.ranged_anim)
	var sheet := h.sprite_sheet
	var px := sheet.tip(anim, sheet.dir_index(dir), sheet.strike_frame(anim))
	return AttackTiming.tip_offset(px, h.sprite_offset, Vector2.ONE * h.sprite_scale, fallback)


func _physics_process(delta: float) -> void:
	tick(delta, enemies())
	queue_redraw()


func _draw() -> void:
	if _swing_time <= 0.0:
		return
	var a := _swing_dir.angle()
	var sd := stats()
	var half := deg_to_rad(sd.melee_arc_degrees * ComboSteps.at(sd.step_arc_mults, chain_step, 1.0) * 0.5)
	var flip := ComboSteps.at(sd.step_trail_flip, chain_step, 1.0)  # 2타는 반대쪽에서
	var alpha := _swing_time / 0.12
	var art := Feedback.feel_data().crescent_art
	var col := stats().swing_color
	if art:  # 붓으로 그린 초승달 베기 (오른쪽 = 베는 방향, scripts/fx/swing_crescent.gd)
		var r := sd.melee_range * ComboSteps.at(sd.step_range_mults, chain_step, 1.0)
		SwingCrescent.draw(self, art, a, r, half, flip, col, alpha, chain_step, Feedback.feel_data())
		return
	draw_arc(Vector2.ZERO, stats().melee_range * 0.85, a - half, a + half, 20, Color(col, col.a * alpha), 10.0)
