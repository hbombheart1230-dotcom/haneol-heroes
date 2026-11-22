class_name Enemy
extends CharacterBody2D
## 추적형 적. 플레이어를 향해 직선 추적, 주변 적과 간단히 분리.
## 종류별 수치는 data(EnemyData)에서 읽는다. 체력·피격은 health_hitbox_hurtbox 애드온.

signal killed(enemy: Enemy)

const GROUP := "enemies"
const BOSS_GROUP := "boss"
const AI := preload("res://data/enemies/enemy_ai.tres")

## 지정하면 _ready에서 아래 수치와 체력을 이 데이터로 덮어쓴다.
@export var data: EnemyData
@export var move_speed: float = 120.0
## 플레이어 접촉 시 피해량.
@export var contact_damage: int = 10
## 이 거리 안의 다른 적에게서 밀려난다 (뭉침 방지).
@export var separation_radius: float = 40.0
@export var separation_strength: float = 0.6
@export var body_radius: float = 20.0

## 0 이상이면 AI 버릇(우회 방향·뜀 등)의 씨앗 (보통 -1 = 인스턴스 id).
var ai_seed: int = -1
var target: Node2D
@onready var health: Health = $Health

var _flash: float = 0.0
## 구워진 스프라이트 (data.sprite_sheet가 있을 때).
var sprite: AnimatedSprite2D
## 예고 공격 (data.attack이 있을 때만).
var attack: EnemyAttack
## 넉백 속도 (매 프레임 감쇠).
var knockback: Vector2 = Vector2.ZERO
var launch := EnemyLaunch.new()  # 큰 기술의 크게 날리기 (정해진 곡선)
var _stun_left: float = 0.0
## 장애물 돌아가기: 남은 시간, 부딪힌 면의 법선, 정면일 때 도는 쪽 (적마다 고정).
var _detour_left: float = 0.0
var _detour_normal: Vector2 = Vector2.ZERO
var _detour_side: float = 1.0
## 느려짐: 이동 속도 배율과 남은 시간 (해시계 멈춤·발묵).
var _slow_factor: float = 1.0
var _slow_left: float = 0.0
## 개별 멈춤(맞은 적만 잠깐 멈춤) 남은 시간과 떨림 기준 위치.
var _freeze_left: float = 0.0
var _freeze_total: float = 0.0
## 맞는 반응 (맞는 동작·잡몹 경직·그림 움찔·흰 번쩍임).
var reaction: HitReaction
## 무게 등급 (정예 갑옷·보스 경직 게이지).
var poise: EnemyPoise
## 돌진 이동 (맞아 경직·기절하면 멈춘다).
var _charge_tw: Tween
## 마지막으로 맞은 방향과 피해 (처치 날림용).
var _last_hit_dir: Vector2 = Vector2.ZERO
var _last_damage: int = 0
## 움직임 판단 (공격권·둘레 돌기·뛰기·매복·휩쓸기·정면 막기).
var brain: EnemyBrain
## 정예 변종 (없으면 null)과 무리 이벤트 배율 (떼: 작고 빠르고 약하게).
var affix: EliteAffixData
var size_mult: float = 1.0
var speed_mult: float = 1.0
var hp_mult: float = 1.0
var _damage_mult: float = 1.0
## 지금 맞으면 반격·뒤치기인지 (HitBonus 깃발, 피해 배율과 같은 값으로 글자를 띄운다).
var _bonus: int = 0
## 영웅 3타째 강타가 이번 피해인지 (AutoAttack이 피해 직전에 켜고 바로 끈다).
var heavy_pending: bool = false
## 보스 단계 (BossPhases): 들어간 단계 수, 단계가 바뀐 순간 무적 남은 시간.
var phase_index: int = 0
var phase_invuln: float = 0.0
## 넉백 감쇠율(초당). 클수록 빨리 멈춘다.
@export var knockback_damping: float = 8.0


static func ai_data() -> EnemyAIData:
	return AI


## AI 버릇 씨앗: ai_seed(0 이상)이 있으면 그것, 없으면 인스턴스 id (헤드리스 시뮬레이션이 실행마다 같게).
func _seed_id() -> int:
	return ai_seed if ai_seed >= 0 else get_instance_id()


func apply_knockback(impulse: Vector2) -> void:
	knockback += impulse * (data.knockback_scale if data else 1.0) * (poise.knockback_mult() if poise else 1.0)


## 밀쳐내기 (영웅 숨 돌릴 틈): 넉백 + 잡몹은 잠깐 경직 (쫓아오며 넉백을 지우지 않게).
func shove(impulse: Vector2) -> void:
	apply_knockback(impulse)
	if reaction:
		reaction.on_shove()
		if reaction.is_staggered():
			_stop_charge()


## 기절: 그동안 움직이지도 공격하지도 않는다. 기절에 약한 적(stun_scale 1 이상)은 예고 공격이 끊긴다.
func stun(seconds: float) -> void:
	var scale := data.stun_scale if data else 1.0
	if seconds * scale <= 0.0:
		return
	_stun_left = maxf(_stun_left, seconds * scale)
	_stop_charge()
	if attack and scale >= 1.0 and attack.is_busy():
		attack.cancel()
	_update_damage_mult()
	queue_redraw()


func is_stunned() -> bool:
	return _stun_left > 0.0


## 느리게: factor(0~1)배 속도로 seconds초. 더 강한 느려짐이 이긴다. 보스·정예도 stun_scale만큼 짧게.
func slow(factor: float, seconds: float) -> void:
	var t := seconds * (data.stun_scale if data else 1.0)
	if t <= 0.0:
		return
	if factor < _slow_factor or _slow_left <= 0.0:
		_slow_factor = clampf(factor, 0.05, 1.0)
	_slow_left = maxf(_slow_left, t)


func speed_scale() -> float:
	return _slow_factor if _slow_left > 0.0 else 1.0


func _ready() -> void:
	_detour_side = 1.0 if _seed_id() % 2 == 0 else -1.0
	if data:
		move_speed = data.move_speed
		contact_damage = data.contact_damage
		body_radius = data.body_radius
		move_speed *= speed_mult * (affix.speed_mult if affix else 1.0)
		health.max = maxi(roundi(data.max_hp * hp_mult * (affix.hp_mult if affix else 1.0)), 1)
		health.current = health.max
		var beh := data.behaviour
		var pats: Array[EnemyAttackData] = beh.patterns if beh and not beh.patterns.is_empty() else data.patterns
		var atk: EnemyAttackData = beh.attack if beh and beh.attack else data.attack
		if not pats.is_empty():
			attack = EnemyAttack.new(pats[0], 1.0)
			attack.set_patterns(pats)
		elif atk:
			# 첫 공격 시점을 흩어 놓아 한꺼번에 예고하지 않게 한다.
			attack = EnemyAttack.new(atk, EnemyAttack.first_wait(ai_seed))
		if attack:
			attack.ai = AI
		var melee := data.preferred_range <= 0.0 and not data.is_boss and not data.is_elite
		brain = EnemyBrain.new(AI, beh, _seed_id(), melee)
		if has_meta(&"sweep"):  # 휩쓸기 무리: 한쪽으로 곧장 지나간다
			brain.sweep_dir = get_meta(&"sweep")
			brain.sweep_left = AI.wall_time
		if data.is_boss:
			add_to_group(BOSS_GROUP)
		if data.sprite_sheet:
			sprite = EnemySprite.setup(self)
	reaction = HitReaction.new(Feedback.feel_data().reaction_data(), HitReaction.tier_of(data, affix != null, hp_mult))
	reaction.stagger_override = data.stagger_time if data else -1.0
	poise = EnemyPoise.new(reaction.tier, health.max, AI)
	add_to_group(GROUP)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## 이번 프레임 이동 속도. neighbors는 분리 계산용 주변 적 목록.
func compute_velocity(neighbors: Array) -> Vector2:
	if target == null or not is_instance_valid(target) or health.is_dead():
		return Vector2.ZERO
	var to_target := target.global_position - global_position
	var dir := to_target.normalized() if to_target.length_squared() > 1.0 else Vector2.ZERO
	var speed_k := 1.0
	# 거리 유지형(궁수): 너무 가까우면 물러나고, 적당하면 멈춘다.
	if data and data.preferred_range > 0.0:
		var d := to_target.length()
		if d < data.preferred_range - 40.0:
			dir = -dir
		elif d <= data.preferred_range + 40.0:
			dir = Vector2.ZERO
	if brain:
		dir = brain.steer(dir, to_target.length())
		speed_k = brain.speed_k
		if brain.sweep_left <= 0.0 and AI.stand_off_band > 0.0:
			var stop: float = body_radius * size_mult + ((target as Player).body_radius if target is Player else 22.0) \
				+ AI.stand_off_margin + (data.reach_px if data else 0.0)
			dir = EnemyBrain.stand_off(dir, to_target.normalized(), to_target.length(), stop, AI.stand_off_band)
	var push := Vector2.ZERO
	for n in neighbors:
		var other := n as Node2D
		if other == null or other == self or not is_instance_valid(other):
			continue
		var off := global_position - other.global_position
		var d := off.length()
		if d > 0.001 and d < separation_radius:
			push += off / d * (1.0 - d / separation_radius)
	return (dir + push * separation_strength).limit_length(1.0) * move_speed * speed_scale() * speed_k


## 맞은 적만 seconds초 멈추고 떨린다 (Smash식 개별 히트스톱). 더 긴 쪽 유지.
func freeze(seconds: float) -> void:
	if seconds > _freeze_left:
		_freeze_total = seconds
	_freeze_left = maxf(_freeze_left, seconds)


func is_frozen() -> bool:
	return _freeze_left > 0.0


func last_hit_dir() -> Vector2:
	return _last_hit_dir


## 멈춤 중: 움직이지 않고 동작도 멈춘 채 좌우로 떤다. 넉백은 멈춤이 끝나면 그대로 이어진다.
func _tick_freeze(delta: float) -> void:
	_freeze_left = maxf(_freeze_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	if sprite:
		sprite.speed_scale = 0.0 if _freeze_left > 0.0 else 1.0
		var px := HitReaction.shake_px(Feedback.feel_data().hit_shake_px, _freeze_left, _freeze_total)
		EnemySprite.pose(self, px if Engine.get_physics_frames() % 2 == 0 else -px)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _freeze_left > 0.0:
		_tick_freeze(delta)
		return
	var busy := false
	_slow_left = maxf(_slow_left - delta, 0.0)
	phase_invuln = maxf(phase_invuln - delta, 0.0)
	if reaction:
		reaction.tick(delta)
	if poise and poise.armor_max > 0.0 and not poise.is_armored():
		poise.tick(delta)
		queue_redraw()  # 깨진 갑옷이 다시 차는 막대 (그 밖엔 맞을 때만 다시 그린다)
	if _stun_left > 0.0 or (reaction and reaction.is_down()):  # 기절·넘어짐 (B8)
		_stun_left = maxf(_stun_left - delta, 0.0)
		_drift(delta)
		return
	if attack:
		var was_ready := attack.state == EnemyAttack.State.READY
		var r := attack.tick(delta, global_position, target as Player)
		if was_ready and attack.state == EnemyAttack.State.WINDUP:
			EnemyActions.play_sfx(attack.data, true)  # 예고 소리 (E1)
		if r != EnemyAttack.Result.NONE:
			EnemyActions.on_attack_result(self, r)
		busy = attack.is_busy()
		if busy:
			queue_redraw()
			if brain:
				brain.revealed = true  # 숨은 채로 치지 않는다 (예고는 늘 보이게, Codex de7556d)
	var chase := _busy_velocity() if busy else compute_velocity(get_tree().get_nodes_in_group(GROUP))
	if brain:
		brain.tick_sweep(delta)
		var hop := brain.tick_hop(delta, _dir_to_target(), busy)
		if hop != Vector2.ZERO:
			chase = hop
		_update_damage_mult()
	if _detour_left > 0.0:
		_detour_left -= delta
		chase = Obstacles.steer_around(chase, _detour_normal, _detour_side)
	if (reaction and reaction.is_staggered()) or launch.active():
		chase = Vector2.ZERO  # 잡몹 경직·날아가는 중: 밀림만 (공격 예고는 그대로 흘러 공격권을 붙잡지 않는다)
	velocity = chase + knockback + launch.tick(delta)
	if sprite:
		EnemySprite.update(self, busy)
	knockback = knockback.move_toward(Vector2.ZERO, knockback.length() * knockback_damping * delta + 1.0)
	move_and_slide()
	_note_obstacle()
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


## 기절·넘어짐: 쫓지도 치지도 않고 넉백·크게 날리기만 받는다 (기절시키는 큰 기술도 바로 날아간다).
func _drift(delta: float) -> void:
	_update_damage_mult()
	velocity = knockback + launch.tick(delta)
	knockback = knockback.move_toward(Vector2.ZERO, knockback.length() * knockback_damping * delta + 1.0)
	move_and_slide()
	_flash = maxf(_flash - delta, 0.0)
	if sprite:
		EnemySprite.update(self, false)
	queue_redraw()


## 장애물에 부딪혔으면 잠시 가장자리를 따라 돈다 (길 찾기 없이 직진하는 적이 끼지 않게).
func _note_obstacle() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider() as Node
		if body and body.is_in_group(Obstacles.GROUP):
			_detour_normal = col.get_normal()
			_detour_left = 0.4
			return


func _on_damaged(_entity: Node, _type: HealthActionType.Enum, _amount: int, _inc: int, _mul: float, applied: int) -> void:
	var feel := Feedback.feel_data()
	_flash = feel.flash_time
	_last_damage = applied
	if target and is_instance_valid(target):
		var d := global_position - target.global_position
		_last_hit_dir = d.normalized() if d.length_squared() > 0.01 else _last_hit_dir
	if applied > 0 and not health.is_dead():
		freeze(feel.freeze_for(applied))
		if reaction and reaction.on_hit(applied, health.max, _last_hit_dir) and sprite:
			EnemySprite.start_hit(self)  # 멈춤 동안 첫 프레임, 멈춤 뒤 나머지 (R1)
		if reaction and reaction.is_staggered():
			_stop_charge()  # 잡몹 돌진은 맞으면 멈춘다 (정예·보스는 그대로 밀고 온다)
		EnemyHits.on_hit(self, heavy_pending)  # 잡몹 예고 끊김 · 강타 멈춤·넘어짐
		BossPhases.on_damaged(self)  # 보스 단계 (66%·33%)
		if poise:
			EnemyHits.on_poise(self, poise.on_damage(applied))
	Feedback.enemy_hit(global_position, applied, _last_hit_dir, EnemyHits.number_style(applied, heavy_pending),
		_bonus if applied > 0 else HitBonus.NONE)
	_update_damage_mult()
	queue_redraw()


## 공격 중 움직임 (물러나며 쏘기만, 나머지는 제자리).
func _busy_velocity() -> Vector2:
	if brain == null:
		return Vector2.ZERO
	return brain.busy_dir(attack, _dir_to_target()) * move_speed * speed_scale()


func _dir_to_target() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	var d := target.global_position - global_position
	return d.normalized() if d.length_squared() > 1.0 else Vector2.ZERO


## 받는 피해 배율 (경직 처벌 × 정면 방패 × 변종 × 반격·뒤치기)을 체력 애드온의 modifier로. 바뀔 때만 새로 만든다.
func _update_damage_mult() -> void:
	if brain == null:
		return
	var facing := attack.aim_dir if attack and attack.is_busy() else _dir_to_target()
	_bonus = EnemyHits.bonus_flags(self)
	var m := brain.damage_mult(attack, facing, _dir_to_target(), affix.damage_taken_mult if affix else 1.0) 		* HitBonus.mult(_bonus, EnemyHits.impact()) * (0.0 if phase_invuln > 0.0 else 1.0)
	if is_equal_approx(m, _damage_mult):
		return
	_damage_mult = m
	var mod := HealthModifier.new(0, m)
	health.modifiers[HealthActionType.Enum.NONE] = mod
	health.modifiers[HealthActionType.Enum.KINETIC] = mod


func damage_mult() -> float:
	return _damage_mult


func _charge_to(end: Vector2) -> void:
	_stop_charge()
	_charge_tw = create_tween()
	_charge_tw.tween_property(self, "global_position", end, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _stop_charge() -> void:
	if _charge_tw and _charge_tw.is_valid():
		_charge_tw.kill()
	_charge_tw = null


func is_charging() -> bool:
	return _charge_tw != null and _charge_tw.is_valid() and _charge_tw.is_running()


func _exit_tree() -> void:
	if attack:
		attack.cancel()
	if brain:
		brain.forget()


func _on_died(_entity: Node) -> void:
	if attack:
		attack.cancel()
	if brain:
		brain.forget()
	remove_from_group(GROUP)
	remove_from_group(BOSS_GROUP)
	Feedback.enemy_died(self, _last_hit_dir, _last_damage)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	EnemyArt.draw(self)
	EnemyNameTag.draw(self)  # 네임드 이름·변종 이름
	EnemyStatusArt.draw(self, _slow_left > 0.0, _stun_left > 0.0)  # 느려짐·기절 고리, 갑옷·경직 막대


func flash_left() -> float:
	return _flash
