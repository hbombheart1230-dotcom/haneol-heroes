class_name Feedback
extends Node
## 타격감 허브: 화면 흔들림, 데미지 숫자, 효과음.
## 게임 로직은 static 함수만 호출한다 (씬에 Feedback 노드가 없으면 아무 일도 안 함 → 테스트 안전).

static var instance: Feedback
const FEEL_PATH := "res://data/feel/combat_feel.tres"

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
## 동시에 울릴 수 있는 효과음 수 (명중 몸통 + 영웅 재질 겹 + 확인음).
@export var sfx_voices: int = 12
## 배경 음악 음량(dB).
@export var music_volume_db: float = -14.0
## 타격감 공통 수치 (멈춤·처치 날림·먹물·방향 흔들림).
@export var feel: CombatFeelData = preload("res://data/feel/combat_feel.tres")

## 0~1. 흔들림 크기 = trauma^shake_exponent × max_shake.
var trauma: float = 0.0
var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _voices: SfxVoices
var _playing: Array[bool] = []
## 같은 소리가 한 프레임에 겹쳐 터지지 않게 (소리별 마지막 재생 시각).
var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## 처치·먹물 이펙트 (fx 아래에 만든다).
var kill_fx: KillFx
## 기술 이펙트 입자 (fx 아래에 만든다).
var skill_vfx: SkillVfx
## 그려진 기술 이펙트 (물결·번개·유성·꽃잎 그림).
var decals: VfxDecals
## 방향 흔들림: 마지막으로 민 방향과, 돌아오는 밀림 오프셋(px).
var _shake_dir: Vector2 = Vector2.ZERO
var _kick: Vector2 = Vector2.ZERO
var _last_kill_freeze: float = -INF
var _last_haptic: float = -INF
## 음악 재생기는 장면 밖(트리 루트)에 하나만 두어, 다시 시작(장면 다시 불러오기)해도 곡이 이어진다.
static var _music: AudioStreamPlayer
static var _music_tween: Tween


func _ready() -> void:
	instance = self
	if feel == null:
		feel = CombatFeelData.new()
	if fx:
		kill_fx = KillFx.new(feel)
		fx.add_child(kill_fx)
		decals = VfxDecals.new(feel)
		fx.add_child(decals)
		skill_vfx = SkillVfx.new(feel)
		fx.add_child(skill_vfx)
	for kind in SfxSynth.DURATIONS.keys():
		_sounds[kind] = SfxSynth.make(kind)
	_voices = SfxVoices.new(sfx_voices)
	_playing.resize(sfx_voices)
	for i in sfx_voices:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"  # 설정 "효과음 크기"
		p.volume_db = sfx_volume_db
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # 인트로·영웅 고르기(일시정지 중)에도 단추 소리
		add_child(p)
		_players.append(p)
	if _music == null or not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		_music.name = "HanulMusic"
		_music.bus = &"Music"  # 설정 "음악 크기"
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
	_kick = _kick * maxf(1.0 - feel.kick_return * delta, 0.0)
	if _kick.length_squared() < 0.01:
		_kick = Vector2.ZERO
	if camera:
		camera.offset = shake_offset() + _kick
		camera.position_smoothing_speed = follow_speed(camera.position_smoothing_speed,
			player != null and player.is_dashing(), feel, delta)


## 카메라 따라가기 빠르기 (순수 계산): 대시 중엔 바로 dash_follow_speed, 끝나면 follow_return_rate로 평소 값까지.
static func follow_speed(now: float, dashing: bool, f: CombatFeelData, delta: float) -> float:
	if dashing:
		return maxf(now, f.dash_follow_speed)
	return move_toward(now, f.follow_speed, f.follow_return_rate * delta)


## 이번 프레임 흔들림 오프셋. 방향 흔들림이면 마지막 방향으로 주로 떨리고 옆으로는 조금만.
func shake_offset() -> Vector2:
	var s := pow(trauma, feel.shake_exponent) * max_shake
	if s <= 0.01:
		return Vector2.ZERO
	if feel.directional_shake and _shake_dir != Vector2.ZERO:
		return _shake_dir * randf_range(-s, s) + _shake_dir.orthogonal() * randf_range(-s, s) * feel.shake_side_ratio
	return Vector2(randf_range(-s, s), randf_range(-s, s))


## dir이 있으면 그 방향으로 흔들림이 치우친다.
func add_trauma(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	if dir.length_squared() > 0.0001:
		_shake_dir = dir.normalized()


## 화면을 dir 쪽으로 px만큼 밀었다가 돌아오게 한다.
func kick(dir: Vector2, px: float) -> void:
	if dir.length_squared() > 0.0001 and px > 0.0:
		_kick += dir.normalized() * px
		_shake_dir = dir.normalized()


## pitch = 음높이 배율 (연타 1 → 2 → 3타로 올라가는 퍽 소리 등).
func play(kind: StringName, min_gap: float = 0.04, pitch: float = 1.0, min_pitch: float = 0.0) -> void:
	if not sfx_enabled or not (_sounds.has(kind) or (bank and bank.has(kind))):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(kind, -INF)) < min_gap:
		return
	for k in _players.size():  # 미리 만든 배열을 채워 쓴다 (소리마다 새 배열을 만들지 않게)
		_playing[k] = _players[k].playing
	var i := _voices.pick(kind, bank.prio(kind) if bank else 1, bank.max_of(kind) if bank else 0, now, _playing)
	if i < 0:
		return  # 더 중요한 소리로 꽉 참
	_last_played[kind] = now
	var p := _players[i]
	if bank and bank.has(kind):
		p.stream = bank.pick(kind, _rng)
		p.volume_db = sfx_volume_db + bank.db(kind)
		p.pitch_scale = _rng.randf_range(bank.pitch_range.x, bank.pitch_range.y)
	else:
		p.stream = _sounds[kind]
		p.volume_db = sfx_volume_db
		p.pitch_scale = 1.0
	p.pitch_scale = maxf(p.pitch_scale * pitch, min_pitch)  # min_pitch: 무작위 폭으로 이 밑으로 내려가지 않게 (낮은 음 끊김)
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
		add_trauma(skill_trauma_for(slot, hits))
		return
	add_trauma(skill_trauma_for(slot, hits))
	play(&"counter" if slot == SkillCaster.Slot.COUNTER else &"slash", 0.0)


## 기술 시전 흔들림 (CombatFeelData): 반격은 크게, 맞혔으면 보통, 헛치면 작게.
func skill_trauma_for(slot: SkillCaster.Slot, hits: int) -> float:
	if slot == SkillCaster.Slot.COUNTER:
		return feel.counter_trauma
	return feel.skill_trauma if hits > 0 else feel.skill_trauma_miss


# --- 게임 로직에서 부르는 static 진입점 ---

## dir: 맞은 방향 (공격자 → 적). 먹물이 그쪽으로 튄다. style: 피해 숫자 모양 (EnemyHits.number_style),
## bonus: 반격·뒤치기 글자 (HitBonus 깃발).
static func enemy_hit(pos: Vector2, amount: int, dir: Vector2 = Vector2.ZERO, style: int = -1, bonus: int = 0) -> void:
	if instance == null:
		return
	if instance.fx:
		instance.fx.add_number(pos, amount, style if style >= 0 else int(amount >= instance.feel.big_hit_damage))
		ImpactFx.hit_label(instance, pos, bonus)
	if instance.kill_fx:
		instance.kill_fx.drops(pos, dir, instance.feel.drops_for(amount))
	instance._play_hit(amount)


## 명중 소리 겹 (S1·S2): 공통 몸통 + 영웅 재질 (HeroData.hit_sfx) + 큰 타격 확인음·국악 양념.
func _play_hit(amount: int) -> void:
	play(&"hit")
	for kind in hit_layers():
		play(kind)
	if amount >= feel.big_hit_damage:
		play(&"confirm_big", 0.08)
		play(&"gugak_big", 0.12)  # 국악 꽹과리 (파일이 있을 때만 울린다)


## 지금 영웅의 명중 재질 소리 (없으면 빈 배열).
func hit_layers() -> Array[StringName]:
	return player.hero.hit_sfx if player and player.hero else ([] as Array[StringName])


## 정예 갑옷 깨짐 · 보스 휘청 (B3): 확인음 + 흔들림 + 진동.
static func poise_broken(_pos: Vector2, armor: bool) -> void:
	if instance == null:
		return
	instance.play(&"confirm_big" if armor else &"confirm_kill", 0.0)
	instance.add_trauma(instance.feel.poise_trauma)
	instance.haptic(instance.feel.haptic_impact_ms, instance.feel.haptic_impact_amp)


## 타격 진동 (Haptics → 설정 "타격 진동"을 따름). haptic_min_gap 안에 다시 오면 무시. 진동했으면 true.
func haptic(ms: int, amplitude: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_haptic < feel.haptic_min_gap:
		return false
	if not Haptics.pulse(ms, amplitude):
		return false
	_last_haptic = now
	return true


## 기술이 내리꽂는 순간 짧은 진동.
static func impact_haptic() -> void:
	if instance:
		instance.haptic(instance.feel.haptic_impact_ms, instance.feel.haptic_impact_amp)


## 기술 이펙트 터뜨리기 (Feedback이 없으면 아무 일도 안 함 → 테스트 안전).
## level = 기술 강화 단계 (SkillDef.vfx_level).
## fit_radius > 0이면 그림 지름을 그 판정 반경에 맞춘다.
static func vfx_burst(data: SkillVfxData, pos: Vector2, dir: Vector2 = Vector2.ZERO, level: int = 0,
		fit_radius: float = 0.0) -> void:
	if instance == null or data == null:
		return
	if instance.decals:
		instance.decals.burst(data, pos, dir, level, fit_radius)
	if instance.skill_vfx:
		instance.skill_vfx.burst(data, pos, dir, level)


## 경로를 따라 펼쳐지는 그림 띠 (직선 기술은 SkillVfxData, 회피 자취는 직접).
static func vfx_strip_for(data: SkillVfxData, a: Vector2, b: Vector2, level: int = 0) -> void:
	if instance and instance.decals:
		instance.decals.strip_for(data, a, b, level)


## 붓 획 하나 (세종 금빛 회피 자취 등).
static func vfx_stroke(a: Vector2, b: Vector2, width: float, time: float, color: Color) -> void:
	if instance and instance.fx:
		instance.fx.add_slash(a, b, width, time, color)


static func vfx_strip(tex: Texture2D, a: Vector2, b: Vector2, width: float, time: float, reveal: float) -> void:
	if instance and instance.decals:
		instance.decals.strip(tex, a, b, width, time, reveal)


## 공통 타격감 수치 (Feedback이 없으면 기본값 → 테스트 안전).
static func feel_data() -> CombatFeelData:
	if instance and instance.feel:
		return instance.feel
	if _default_feel == null:  # Feedback가 없을 때(테스트·도구)도 같은 데이터 (붓 그림 포함)
		_default_feel = load(FEEL_PATH) as CombatFeelData
		if _default_feel == null:
			_default_feel = CombatFeelData.new()
	return _default_feel


static var _default_feel: CombatFeelData


## 기술이 부르는 화면 흔들림 (0~1).
static func shake(amount: float) -> void:
	if instance:
		instance.add_trauma(amount)


## 적 처치: 시체를 dir 쪽으로 날리고, 정예·보스면 슬로모션.
static func enemy_died(e: Enemy, dir: Vector2, last_damage: int) -> void:
	if instance == null:
		return
	instance._on_enemy_died(e, dir, last_damage)


func _on_enemy_died(e: Enemy, dir: Vector2, last_damage: int) -> void:
	play(&"die")
	var d := e.data
	var finisher := d != null and (d.is_boss or d.is_elite)
	var elem := DeathCause.burst(self, e, last_damage, finisher)  # 처치한 영웅의 속성 모습 (물·번개·글자·먹)
	if kill_fx:
		var tex := EnemySprite3D.corpse_texture(e)  # 3D 적은 구운 칸 (화면 텍스처는 적과 함께 지워진다)
		kill_fx.launch(e.global_position, dir, last_damage, tex, d.sprite_scale if d else 1.0,
			d.sprite_offset if d else Vector2.ZERO, d.sprite_tint if d else Color.WHITE,
			&"none" if elem else (d.death_style if d else &"smoke"), d.launch_scale if d else 1.0, finisher)
	if finisher:
		play(&"confirm_kill", 0.0)
		play(&"gugak_kill", 0.0)  # 국악 북·징 (파일이 있을 때만)
		haptic(feel.haptic_finisher_ms, feel.haptic_finisher_amp)
		add_trauma(feel.finisher_trauma, dir)
		kick(dir, feel.finisher_kick_px)
		if is_inside_tree():
			GameTime.stop(get_tree(), feel.finisher_time, feel.finisher_time_scale)
			ImpactFx.finisher(self)  # 확대·흰 번쩍임 (B7)
		return
	add_trauma(feel.kill_trauma, dir)
	kick(dir, feel.kill_kick_px)
	var now := Time.get_ticks_msec() / 1000.0
	# 칼이 박힌 멈춤 중이면 처치 멈춤을 더 얹지 않는다 (휘두름 한 번에 멈춤 한 번, BladeBite)
	if feel.kill_freeze > 0.0 and now - _last_kill_freeze >= feel.kill_freeze_min_gap and is_inside_tree() 			and not BladeBite.is_biting():
		_last_kill_freeze = now
		GameTime.stop(get_tree(), feel.kill_freeze)


## 단추·인장 소리 (인트로·영웅 고르기·성장).
static func ui() -> void:
	if instance:
		instance.play(&"ui", 0.0)


static func player_hurt() -> void:
	if instance:
		instance.play(&"hurt", 0.0)
		instance.add_trauma(instance.feel.hurt_trauma)
		instance.haptic(instance.feel.haptic_hurt_ms, instance.feel.haptic_hurt_amp)
