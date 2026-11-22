class_name PlayerView
extends Node2D
## 플레이어 임시 그래픽: 수묵풍 실루엣 (부모 Player를 읽어서 그린다). 정식 그래픽 교체 시 이 노드만 바꾼다.
## 쪽빛 두루마기 + 갓 + 푸른 검. 대시 잔상은 물빛 먹 번짐.
## hero.sprite_sheet가 있으면 구워진 8방향 스프라이트(AnimatedSprite2D)로 그린다 (하데스식 3D→2D).

@export var player: Player

## 대시 잔상용 최근 위치 (월드 좌표).
var _trail: PackedVector2Array = PackedVector2Array()
var _t: float = 0.0
var _sprite: AnimatedSprite2D
var _sheet: SpriteSheetSet
## 일회성 동작(공격·피격)이 끝날 때까지 남은 시간.
var _oneshot: String = ""
var _oneshot_left: float = 0.0
## 지금 보여 주는 방향 번호 (-1 = 아직 없음). 경계에서 떨리지 않게 붙잡아 둔다.
var _dir: int = -1
## 문턱·재생 속도 범위는 CombatFeelData("영웅 동작")에 있다.
var _running: bool = false
## 칼이 닿은 순간 영웅 동작도 멈춘다 (역경직, B3): 남은 시간.
var _hitstop_left: float = 0.0
## 연타 흐름: 공격 동작이 끝난 뒤 마지막 자세를 붙잡는 남은 시간, 같은 동작을 처음부터 다시 틀지.
var _hold_left: float = 0.0
var _restart: bool = false
## 무게감 (그림만): 대시 착지 눌림·멈칫 남은 시간, 멈출 때 앞쏠림 남은 시간·방향, 지난 프레임 걷기 입력.
var _land_left: float = 0.0
var _land_hold_left: float = 0.0
var _slide_left: float = 0.0
var _slide_dir: Vector2 = Vector2.ZERO
var _had_input: bool = false
var _attack: AutoAttack


func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	if player and player.hero and player.hero.sprite_sheet and not player.hero.sprite_sheet.anim_names.is_empty():
		_setup_sprite(player.hero)


## 영웅이 바뀌면 스프라이트를 다시 만든다 (신호 연결은 처음 한 번만).
func refresh() -> void:
	if player == null or player.hero == null:
		return
	var h := player.hero
	if h.sprite_sheet == null or h.sprite_sheet.anim_names.is_empty():
		if _sprite:
			_sprite.queue_free()
			_sprite = null
		_sheet = null
		return
	if _sprite == null:
		_setup_sprite(h)
		return
	_sheet = h.sprite_sheet
	_sprite.sprite_frames = _sheet.build_sprite_frames()
	_sprite.scale = Vector2.ONE * h.sprite_scale
	_sprite.position = h.sprite_offset


func _setup_sprite(h: HeroData) -> void:
	_sheet = h.sprite_sheet
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _sheet.build_sprite_frames()
	_sprite.scale = Vector2.ONE * h.sprite_scale
	_sprite.position = h.sprite_offset
	add_child(_sprite)
	var attack := player.get_node_or_null("AutoAttack") as AutoAttack
	_attack = attack
	if attack:
		attack.melee_windup.connect(_on_auto_swing.bind(0))  # 휘두르기 시작에 동작, 피해는 칼이 닿을 때
		attack.melee_swung.connect(_on_melee_contact)  # 칼이 닿은 순간 멈춤
		attack.ranged_windup.connect(_on_ranged_windup)  # 던지는 동작
	if not player.dash_ended.is_connected(on_land):
		player.dash_ended.connect(on_land)
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	if caster:
		caster.skill_cast.connect(func(_s: SkillCaster.Slot, _h: int) -> void: play_oneshot("attack", 0.35))


## 자동 공격 동작은 서 있을 때만. 달리는 중엔 다리를 멈추지 않고 검기 이펙트만 보인다
## (0.55초마다 달리기가 끊겨 끊겨 보이던 원인).
func _on_auto_swing(_d: Vector2, _h: int) -> void:
	if not is_moving():
		var anim := _attack.chain_anim() if _attack else "attack"  # 연계 2·3타 동작 (B4)
		play_oneshot(anim, anim_seconds(anim, 0.35))
		var pause := _attack.step_pause() if _attack else 0.0
		if pause > 0.0:  # 3타 앞 모으기: 첫 칸에서 잠깐 멈춤
			_hitstop_left = maxf(_hitstop_left, pause)


## 칼이 닿은 순간: 맞았으면 지금 보여 주는 공격 동작을 잠깐 멈춘다 (달리는 중엔 다리를 멈추지 않는다).
func _on_melee_contact(_d: Vector2, hits: int) -> void:
	if _oneshot_left > 0.0 and _oneshot.begins_with("attack") and not GameTime.is_stopped():  # 기술 멈춤·마무리 슬로우와 겹치지 않게
		_hitstop_left = Feedback.feel_data().impact_data().hero_hitstop(hits, _attack != null and _attack.last_heavy)


## 동작 한 번 길이(초) = 칸 수 ÷ fps (시트에 없으면 fallback).
func anim_seconds(anim: String, fallback: float) -> float:
	if _sheet == null or not _sheet.has_anim(anim):
		return fallback
	var i := _sheet.anim_names.find(anim)
	return _sheet.frame_count(anim) / maxf(_sheet.fps[i], 1.0)


## 실제 걷기 속도 기준으로 달리는 중인지 (문턱 두 개로 깜빡임 방지).
## 원거리: 영웅 데이터가 고른 던지는 동작 (비면 동작 없음), 서 있을 때만.
func _on_ranged_windup(_d: Vector2) -> void:
	var atk := player.hero.attack if player.hero else null
	var anim := String(atk.ranged_anim) if atk else "attack"
	if _attack and anim != "":
		anim = _attack.ranged_anim_now()  # 연타 2·3번은 throw2·throw3
	if anim != "" and not is_moving():
		play_oneshot(anim, anim_seconds(anim, atk.ranged_anim_time if atk else 0.35))


func is_moving() -> bool:
	var top := maxf(player.move_speed, 1.0)
	var ratio := player.walk_velocity().length() / top
	if player.move_input.length() > 0.1:
		ratio = maxf(ratio, player.move_input.length())
	var feel := Feedback.feel_data()
	_running = ratio > (feel.run_exit if _running else feel.run_enter)
	return _running


func play_oneshot(anim: String, seconds: float) -> void:
	_oneshot = anim
	_oneshot_left = seconds
	_hold_left = 0.0
	_restart = true  # 같은 이름 동작이 연달아 와도 처음부터


## 지금 보여줄 애니메이션 이름 (상태 우선순위: 사망 > 대시 > 피격 > 공격 > 달리기 > 대기).
func current_anim() -> String:
	if player.is_dead():
		return "death"
	if player.is_dashing():
		return "dash"
	if player.hurt_time_left() > 0.0 and player.hurt_elapsed() < Feedback.feel_data().reaction_data().hero_hit_anim_time:
		return "hit"
	if _oneshot_left > 0.0:
		return _oneshot
	if _hold_left > 0.0 and not is_moving():  # 연타 사이: 대기 자세로 튀지 않고 마지막 자세 유지
		return _oneshot
	if is_moving():
		return "run"
	return "idle"


## 시트에 없는 동작은 비슷한 것으로 대신한다 (AI 3D 모델은 동작이 일부 빠질 수 있다).
func available_anim(anim: String) -> String:
	if _sheet == null or _sheet.anim_names.is_empty() or _sheet.has_anim(anim):
		return anim
	if anim == "dash" and _sheet.has_anim("run"):
		return "run"
	return "idle" if _sheet.has_anim("idle") else _sheet.anim_names[0]


func _update_sprite(delta: float) -> void:
	if _hitstop_left > 0.0:  # 멈춘 동안은 공격 동작 시간도 흐르지 않는다
		_hitstop_left = maxf(_hitstop_left - delta, 0.0)
	elif _oneshot_left > 0.0:
		_oneshot_left = maxf(_oneshot_left - delta, 0.0)
		if _oneshot_left <= 0.0 and (_oneshot.begins_with("attack") or _oneshot.begins_with("throw")):
			_hold_left = Feedback.feel_data().combo_hold_time
	else:
		_hold_left = maxf(_hold_left - delta, 0.0)
	_dir = _sheet.dir_index_sticky(player.facing, _dir, Feedback.feel_data().dir_margin_deg)
	var dir := _dir
	var anim_name := StringName("%s_%d" % [available_anim(current_anim()), dir])
	if _restart and current_anim() == _oneshot:
		_restart = false
		_sprite.play(anim_name)
		_sprite.frame = 0
	elif _sprite.animation != anim_name:
		var frame := _sprite.frame
		var same_anim := String(_sprite.animation).get_slice("_", 0) == String(anim_name).get_slice("_", 0)
		_sprite.play(anim_name)
		if same_anim:  # 방향만 바뀌면 프레임 이어서
			_sprite.frame = mini(frame, _sprite.sprite_frames.get_frame_count(anim_name) - 1)
	var tint := Color(1, 1, 1)
	var ds := player.hero.dash_style if player.hero else null
	if player.skill_invuln_left() > 0.0 and not player.is_dashing():
		tint = Color(1.0, 0.9, 0.55)
	elif player.is_dashing():
		tint = ds.body_tint if ds else Color(0.75, 0.9, 1.0)
		tint.a = ds.body_alpha if ds else 1.0  # 광개토 번개 순간이동·사임당 먹으로 흩어짐
	_sprite.modulate = hurt_tint(tint)
	var cur := current_anim()
	_sprite.speed_scale = run_anim_speed() if cur == "run" else (Feedback.feel_data().idle_anim_speed if cur == "idle" else 1.0)
	if _hitstop_left > 0.0 and current_anim() == _oneshot:
		_sprite.speed_scale = 0.0
	if player.hero:
		_pose(delta)


## 대시 착지 (무게감): 발 기준 눌림, 그림 잠깐 멈칫, 발밑 먹 튐, 무거운 영웅은 흔들림·화면 밀림.
func on_land() -> void:
	var h := player.hero if player else null
	if h == null:
		return
	_land_left = h.land_time
	_land_hold_left = h.land_hold
	var fb := Feedback.instance
	if fb == null:
		return
	var dir := player.get_dash_direction()
	if fb.kill_fx and h.land_drops > 0:
		fb.kill_fx.drops(player.global_position, dir, h.land_drops)
	if h.land_trauma > 0.0:
		fb.add_trauma(ImpactFx.capped_trauma(fb.trauma, h.land_trauma, fb.feel.impact_data().trauma_cap), dir)
	if h.land_kick_px > 0.0:
		fb.kick(dir, h.land_kick_px)


## 그림 자세 (무게감, 판정·이동은 그대로): 착지 눌림 + 멈출 때 앞쏠림. 발(원점)은 제자리.
func _pose(delta: float) -> void:
	var h := player.hero
	_land_left = maxf(_land_left - delta, 0.0)
	_land_hold_left = maxf(_land_hold_left - delta, 0.0)
	var has_input := player.move_input.length() > 0.1
	var v := player.walk_velocity()
	if _had_input and not has_input and v.length() > player.move_speed * 0.5 and h.stop_slide_time > 0.0:
		_slide_left = h.stop_slide_time
		_slide_dir = v.normalized()
	_had_input = has_input
	_slide_left = maxf(_slide_left - delta, 0.0)
	var k := _land_left / maxf(h.land_time, 0.001)
	var sq := Vector2.ONE.lerp(h.land_squash, k * k)
	_sprite.scale = Vector2.ONE * h.sprite_scale * sq
	var lean := _slide_dir * h.stop_slide_px * sin(PI * (1.0 - _slide_left / maxf(h.stop_slide_time, 0.001))) 		if _slide_left > 0.0 else Vector2.ZERO
	_sprite.position = Vector2(h.sprite_offset.x, h.sprite_offset.y * sq.y) + lean
	if _land_hold_left > 0.0:
		_sprite.speed_scale = 0.0


## 피격 표시 (R3): 맞은 순간 붉게, 무적 동안 깜빡임 (대시 중에는 대시 색 그대로).
func hurt_tint(tint: Color) -> Color:
	if player.hurt_time_left() <= 0.0 or player.is_dashing() or player.is_dead():
		return tint
	var d := Feedback.feel_data().reaction_data()
	var t := player.hurt_elapsed()
	var c := d.hero_flash_color if t < d.hero_flash_time else tint
	if t >= d.hero_flash_time and int(t * d.blink_hz) % 2 == 1:
		c.a = tint.a * d.blink_alpha
	return c


## 달리기 동작 속도: 실제로 빨리 갈수록 빨리 (가속 중엔 천천히 → 발이 땅에 붙어 보인다).
func run_anim_speed() -> float:
	var ratio := player.walk_velocity().length() / maxf(player.move_speed, 1.0)
	var feel := Feedback.feel_data()
	return clampf(ratio, feel.run_anim_min, feel.run_anim_max)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	if _sprite:
		_update_sprite(delta)
	if player.is_dashing():
		_trail.append(player.global_position)
		if _trail.size() > 8:
			_trail.remove_at(0)
	elif _trail.size() > 0:
		_trail.remove_at(0)
	queue_redraw()


func _trail_color() -> Color:
	var ds := player.hero.dash_style if player.hero else null
	return ds.trail_color if ds else Ink.WATER


func _draw() -> void:
	if player == null:
		return
	var r := player.body_radius
	# 대시 잔상: 물빛 먹 번짐
	for i in (_trail.size() if player.hero == null or player.hero.dash_style == null else 0):  # 회피 띠가 있으면 동그라미 자취 없음
		var a := float(i + 1) / float(_trail.size() + 1)
		Ink.blob(self, to_local(_trail[i]) + Vector2(0, -r * 0.4), r * (0.5 + 0.4 * a), Color(_trail_color(), 0.28 * a), i)
	var hd := player.hero
	if hd:  # 무게감 먹 그림자 (착지 순간 살짝 넓게)
		var spread := 1.0 + 0.25 * (_land_left / maxf(hd.land_time, 0.001))
		Ink.weight_shadow(self, Vector2(0, r * 0.8), r * hd.shadow_scale * spread, hd.shadow_alpha)
	else:
		Ink.shadow(self, Vector2(0, r * 0.8), r * 1.1)
	if _sprite:
		return  # 몸은 스프라이트가 그린다
	var robe := player.hero.body_color if player.hero else Ink.INDIGO
	if player.is_dashing():
		robe = Ink.WATER
	if player.skill_invuln_left() > 0.0 and not player.is_dashing():
		robe = Ink.GOLD  # 회피 무적: 금빛
	var hurt := player.hurt_time_left()
	if hurt > 0.0 and not player.is_dashing() and int(hurt * 20.0) % 2 == 0:
		robe = Ink.SEAL
	var sway := sin(_t * 6.0) * 2.0 * minf(player.move_input.length(), 1.0)
	# 두루마기 (아래가 넓은 덩어리)
	Ink.blob(self, Vector2(sway * 0.5, -r * 0.2), r * 0.95, robe, 2.0, 0.14, 1.15)
	# 얼굴과 갓
	var head := Vector2(sway, -r * 1.25)
	draw_circle(head, r * 0.38, Color(0.95, 0.88, 0.76))
	Ink.blob(self, head + Vector2(0, -r * 0.12), r * 0.75, Ink.INK, 5.0, 0.05, 0.22)  # 갓 챙
	draw_circle(head + Vector2(0, -r * 0.32), r * 0.3, Ink.INK)  # 갓 모자
	# 검: 바라보는 방향으로 먹 획 + 푸른 날
	var hand := Vector2(0, -r * 0.4) + player.facing * r * 0.6
	var tip := hand + player.facing * r * 1.4
	Ink.stroke(self, hand, tip, 7.0, Ink.INK)
	draw_line(hand + player.facing * 4.0, tip, Color(0.75, 0.9, 1.0), 2.0)
