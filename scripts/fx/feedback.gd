class_name Feedback
extends Node
## 타격감 허브: 화면 흔들림, 데미지 숫자, 효과음.
## 게임 로직은 static 함수만 호출한다 (씬에 Feedback 노드가 없으면 아무 일도 안 함 → 테스트 안전).

static var instance: Feedback

@export var camera: Camera2D
@export var fx: FxLayer
@export var player: Player
@export var skill_caster: SkillCaster
## 화면 흔들림 최대 이동(px)과 감쇠(초당 trauma).
@export var max_shake: float = 18.0
@export var shake_decay: float = 2.5
@export var sfx_enabled: bool = true
@export var sfx_volume_db: float = -8.0

## 0~1. 흔들림 크기 = trauma^2.
var trauma: float = 0.0
var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
## 같은 소리가 한 프레임에 겹쳐 터지지 않게 (소리별 마지막 재생 시각).
var _last_played: Dictionary = {}


func _ready() -> void:
	instance = self
	for kind in SfxSynth.DURATIONS.keys():
		_sounds[kind] = SfxSynth.make(kind)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_players.append(p)
	if player:
		player.dash_started.connect(func(_d: Vector2) -> void: play(&"dash"))
		player.evaded.connect(func() -> void: play(&"evade"))
	if skill_caster:
		skill_caster.skill_cast.connect(_on_skill_cast)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	if camera:
		var s := trauma * trauma * max_shake
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s)) if s > 0.01 else Vector2.ZERO


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func play(kind: StringName, min_gap: float = 0.04) -> void:
	if not sfx_enabled or not _sounds.has(kind):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(kind, -INF)) < min_gap:
		return
	_last_played[kind] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sounds[kind]
	p.play()


func _on_skill_cast(slot: SkillCaster.Slot, hits: int) -> void:
	match slot:
		SkillCaster.Slot.COUNTER:
			add_trauma(0.7)
			play(&"counter", 0.0)
		SkillCaster.Slot.TAP, SkillCaster.Slot.CHARGE:
			add_trauma(0.25 if hits > 0 else 0.1)
			play(&"slash", 0.0)
		SkillCaster.Slot.DASH:
			add_trauma(0.2)
			play(&"slash", 0.0)


# --- 게임 로직에서 부르는 static 진입점 ---

static func enemy_hit(pos: Vector2, amount: int) -> void:
	if instance == null:
		return
	if instance.fx:
		instance.fx.add_number(pos, amount, amount >= 40)
	instance.play(&"hit")


## 기술이 부르는 화면 흔들림 (0~1).
static func shake(amount: float) -> void:
	if instance:
		instance.add_trauma(amount)


static func enemy_died(_pos: Vector2) -> void:
	if instance:
		instance.play(&"die")
		instance.add_trauma(0.05)


static func player_hurt() -> void:
	if instance:
		instance.play(&"hurt", 0.0)
		instance.add_trauma(0.4)
