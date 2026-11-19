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
## 녹음된 효과음 (CC0). 없는 종류는 SfxSynth 합성음.
@export var bank: SoundBank
## 배경 음악 음량(dB).
@export var music_volume_db: float = -14.0

## 0~1. 흔들림 크기 = trauma^2.
var trauma: float = 0.0
var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
## 같은 소리가 한 프레임에 겹쳐 터지지 않게 (소리별 마지막 재생 시각).
var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## 음악 재생기는 장면 밖(트리 루트)에 하나만 두어, 다시 시작(장면 다시 불러오기)해도 곡이 이어진다.
static var _music: AudioStreamPlayer
static var _music_tween: Tween


func _ready() -> void:
	instance = self
	for kind in SfxSynth.DURATIONS.keys():
		_sounds[kind] = SfxSynth.make(kind)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # 인트로·영웅 고르기(일시정지 중)에도 단추 소리
		add_child(p)
		_players.append(p)
	if _music == null or not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		_music.name = "HanulMusic"
		_music.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(_music)
	_music.volume_db = music_volume_db
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
	if not sfx_enabled or not (_sounds.has(kind) or (bank and bank.has(kind))):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(kind, -INF)) < min_gap:
		return
	_last_played[kind] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	if bank and bank.has(kind):
		p.stream = bank.pick(kind, _rng)
		p.volume_db = sfx_volume_db + bank.db(kind)
		p.pitch_scale = _rng.randf_range(0.94, 1.06)  # 같은 소리 반복이 덜 거슬리게
	else:
		p.stream = _sounds[kind]
		p.volume_db = sfx_volume_db
		p.pitch_scale = 1.0
	p.play()


## 무대 음악 (같은 곡이면 이어서). null이면 멈춘다.
## fade > 0이면 지금 곡을 그만큼 줄인 뒤 새 곡을 같은 시간 동안 키운다 (보스 등장·판 끝).
func play_music(stream: AudioStream, fade: float = 0.0) -> void:
	if _music == null:
		return
	# 새 요청은 진행 중인 전환을 먼저 끊는다 (보스 전환 도중 재시작 → 무대 음악이 이겨야 한다).
	var was_switching := _music_tween != null and _music_tween.is_valid()
	if was_switching:
		_music_tween.kill()
		_music_tween = null
	if stream == _music.stream and _music.playing:
		_music.volume_db = music_volume_db  # 줄어들던 소리 되돌리기
		return
	if fade > 0.0 and _music.playing and _music.is_inside_tree():
		_music_tween = _music.create_tween()
		_music_tween.tween_property(_music, "volume_db", -40.0, fade)
		_music_tween.tween_callback(_start_music.bind(stream))
		_music_tween.tween_property(_music, "volume_db", music_volume_db, fade)
		return
	_start_music(stream)



func _start_music(stream: AudioStream) -> void:
	_music.stream = stream
	_music.volume_db = music_volume_db
	if stream == null:
		_music.stop()
	elif _music.is_inside_tree():
		_music.play()
	else:
		_music.play.call_deferred()  # 방금 만들어 아직 트리에 붙기 전


## 지금 틀고 있는 곡 (없으면 null).
static func current_music() -> AudioStream:
	return _music.stream if _music != null and is_instance_valid(_music) else null


func music_playing() -> bool:
	return _music != null and is_instance_valid(_music) and (_music.playing or _music.stream != null)


func _on_skill_cast(slot: SkillCaster.Slot, hits: int) -> void:
	var def := skill_caster.def_of(slot) if skill_caster else null
	if def and def.sfx != &"":  # 기술마다 정한 소리 (세종·사임당 = 마법)
		play(def.sfx, 0.0)
		add_trauma(0.7 if slot == SkillCaster.Slot.COUNTER else 0.2)
		return
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


## 단추·인장 소리 (인트로·영웅 고르기·성장).
static func ui() -> void:
	if instance:
		instance.play(&"ui", 0.0)


static func player_hurt() -> void:
	if instance:
		instance.play(&"hurt", 0.0)
		instance.add_trauma(0.4)
