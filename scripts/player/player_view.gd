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
	if attack:
		attack.melee_swung.connect(_on_auto_swing)
	var caster := player.get_node_or_null("SkillCaster") as SkillCaster
	if caster:
		caster.skill_cast.connect(func(_s: SkillCaster.Slot, _h: int) -> void: play_oneshot("attack", 0.35))


## 자동 공격 동작은 서 있을 때만. 달리는 중엔 다리를 멈추지 않고 검기 이펙트만 보인다
## (0.55초마다 달리기가 끊겨 끊겨 보이던 원인).
func _on_auto_swing(_d: Vector2, _h: int) -> void:
	if not is_moving():
		play_oneshot("attack", 0.35)


## 실제 걷기 속도 기준으로 달리는 중인지 (문턱 두 개로 깜빡임 방지).
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


## 지금 보여줄 애니메이션 이름 (상태 우선순위: 사망 > 대시 > 피격 > 공격 > 달리기 > 대기).
func current_anim() -> String:
	if player.is_dead():
		return "death"
	if player.is_dashing():
		return "dash"
	if player.hurt_time_left() > player.hurt_invuln_time - 0.25:
		return "hit"
	if _oneshot_left > 0.0:
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
	_oneshot_left = maxf(_oneshot_left - delta, 0.0)
	_dir = _sheet.dir_index_sticky(player.facing, _dir, Feedback.feel_data().dir_margin_deg)
	var dir := _dir
	var anim_name := StringName("%s_%d" % [available_anim(current_anim()), dir])
	if _sprite.animation != anim_name:
		var frame := _sprite.frame
		var same_anim := String(_sprite.animation).get_slice("_", 0) == String(anim_name).get_slice("_", 0)
		_sprite.play(anim_name)
		if same_anim:  # 방향만 바뀌면 프레임 이어서
			_sprite.frame = mini(frame, _sprite.sprite_frames.get_frame_count(anim_name) - 1)
	var tint := Color(1, 1, 1)
	if player.skill_invuln_left() > 0.0 and not player.is_dashing():
		tint = Color(1.0, 0.9, 0.55)
	elif player.is_dashing():
		tint = Color(0.75, 0.9, 1.0)
	_sprite.modulate = tint
	_sprite.speed_scale = run_anim_speed() if current_anim() == "run" else 1.0


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


func _draw() -> void:
	if player == null:
		return
	var r := player.body_radius
	# 대시 잔상: 물빛 먹 번짐
	for i in _trail.size():
		var a := float(i + 1) / float(_trail.size() + 1)
		Ink.blob(self, to_local(_trail[i]) + Vector2(0, -r * 0.4), r * (0.5 + 0.4 * a), Color(Ink.WATER, 0.28 * a), i)
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
