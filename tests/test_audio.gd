extends GdUnitTestSuite
## 효과음·음악: CC0 녹음 묶음, 기술별 소리, 무대 음악.

const BANK := preload("res://data/audio/sfx_bank.tres")
const STAGE := preload("res://data/stages/manchuria_395.tres")


func test_bank_covers_every_synth_kind_plus_magic_and_ui() -> void:
	for kind in SfxSynth.DURATIONS.keys():
		assert_bool(BANK.has(kind)).override_failure_message(String(kind)).is_true()
	assert_bool(BANK.has(&"magic")).is_true()
	assert_bool(BANK.has(&"ui")).is_true()
	var rng := RandomNumberGenerator.new()
	for k in BANK.sounds.keys():
		assert_object(BANK.pick(k, rng)).is_not_null()


func test_stage_music_loops() -> void:
	# 무대 음악은 노래(구간 넘나들기)의 본편: 판 중에 반복된다. music(대체 곡)은 그 무대 노래의 본편 파일.
	assert_object(STAGE.song).is_not_null()
	assert_bool((STAGE.song.interactive().get_clip_stream(1) as AudioStreamOggVorbis).loop).is_true()
	assert_str(STAGE.music.resource_path).is_equal(STAGE.song.verse.resource_path)


func test_mage_heroes_cast_with_magic_sound() -> void:
	for path in ["sejong", "shin_saimdang"]:
		var kit: SkillKit = (load("res://data/heroes/%s.tres" % path) as HeroData).kit
		assert_str(String(kit.tap.sfx)).is_equal("magic")
		assert_str(String(kit.counter.sfx)).is_equal("")  # 반격은 기본 반격 소리


func test_feedback_plays_bank_sound_and_music() -> void:
	var fb: Feedback = auto_free(Feedback.new())
	fb.bank = BANK
	add_child(fb)
	fb.play(&"slash", 0.0)
	assert_bool(BANK.sounds[&"slash"].has(fb._players[0].stream)).is_true()
	fb.play_music(STAGE.music)
	await get_tree().process_frame
	assert_bool(fb.music_playing()).is_true()
	# Codex: 다시 시작(새 Feedback)해도 같은 곡은 처음부터 다시 틀지 않는다
	var player_before: AudioStreamPlayer = Feedback._music
	var fb2: Feedback = auto_free(Feedback.new())
	fb2.bank = BANK
	add_child(fb2)
	fb2.play_music(STAGE.music)
	assert_object(Feedback._music).is_same(player_before)
	assert_bool(Feedback._music.get_parent() == get_tree().root).is_true()
	fb.play(&"ui", 0.0)
	assert_object(fb._players[1].stream).is_same(BANK.sounds[&"ui"][0])


func test_stage_music_falls_back_and_switches_with_fade() -> void:
	var main_script := preload("res://scripts/game/main.gd")
	var m: Node2D = auto_free(main_script.new())
	m.run_config = preload("res://data/runs/default_run.tres")
	# 보스·승리·패배 곡이 비어 있으면 무대 곡
	for k in [&"stage", &"boss", &"victory", &"defeat"]:
		assert_object(m.stage_music(k)).is_same(STAGE.music)
	var custom := STAGE.duplicate()
	var boss := AudioStreamOggVorbis.new()
	custom.boss_music = boss
	var cfg := RunConfig.new()
	cfg.stage = custom
	m.run_config = cfg
	assert_object(m.stage_music(&"boss")).is_same(boss)
	assert_object(m.stage_music(&"victory")).is_same(STAGE.music)
	var fb: Feedback = auto_free(Feedback.new())
	add_child(fb)
	fb.play_music(STAGE.music)
	await get_tree().process_frame
	await get_tree().process_frame
	fb.play_music(boss, 0.05)
	await get_tree().create_timer(0.2).timeout
	assert_object(Feedback.current_music()).is_same(boss)


func test_restart_during_boss_fade_keeps_stage_music() -> void:
	# Codex 191d995 회귀: 보스 곡으로 줄어드는 도중 재시작이 무대 곡을 다시 부르면 무대 곡이 남아야 한다.
	var fb: Feedback = auto_free(Feedback.new())
	add_child(fb)
	fb.play_music(STAGE.music)
	await get_tree().process_frame
	await get_tree().process_frame
	var boss := AudioStreamOggVorbis.new()
	fb.play_music(boss, 0.2)
	await get_tree().create_timer(0.05).timeout
	fb.play_music(STAGE.music, 0.2)
	await get_tree().create_timer(0.6).timeout
	assert_object(Feedback.current_music()).is_same(STAGE.music)
	assert_float(Feedback._music.volume_db).is_equal_approx(fb.music_volume_db, 0.01)


func test_music_switch_crossfades_without_a_silent_gap() -> void:
	var fb: Feedback = auto_free(Feedback.new())
	add_child(fb)
	fb.play_music(STAGE.music)
	await get_tree().process_frame
	await get_tree().process_frame
	var kids := fb.get_tree().root.get_child_count()
	var boss := AudioStreamOggVorbis.new()
	fb.play_music(boss, 0.4)
	assert_object(Feedback.current_music()).is_same(boss)  # 새 곡이 바로 시작
	assert_int(fb.get_tree().root.get_child_count()).is_equal(kids + 1)  # 옛 곡이 따로 이어 줄어드는 중
	await get_tree().create_timer(0.2).timeout
	assert_float(Feedback._music.volume_db).is_greater(-20.0)  # 겹치는 한가운데서 새 곡은 이미 들린다 (줄었다 커지는 구간이 없다)
	await get_tree().create_timer(0.5).timeout
	assert_int(fb.get_tree().root.get_child_count()).is_equal(kids)  # 옛 곡 플레이어는 스스로 사라진다
	assert_float(Feedback._music.volume_db).is_equal_approx(fb.music_volume_db, 0.01)


## 무대 노래(인터랙티브 곡)에서 넘어갈 때는 옛 곡을 새 플레이어로 다시 틀지 않는다 (처음 구절부터 다시 들리던 결함).
## 지금 플레이어가 지금 구간을 그대로 줄이고, 다 줄어든 뒤 새 곡으로 바뀐다.
func test_interactive_song_is_not_restarted_on_switch() -> void:
	var fb: Feedback = auto_free(Feedback.new())
	add_child(fb)
	var song: AudioStream = (load("res://data/stages/hansan_1592.tres") as StageTheme).song.interactive()
	assert_bool(song is AudioStreamInteractive).is_true()
	assert_bool(MusicCrossfade.can_copy(song)).is_false()
	assert_bool(MusicCrossfade.can_copy(AudioStreamOggVorbis.new())).is_true()
	fb.play_music(song)
	await get_tree().process_frame
	await get_tree().process_frame
	var kids := fb.get_tree().root.get_child_count()
	var jingle := AudioStreamOggVorbis.new()
	fb.play_music(jingle, 0.3)
	assert_int(fb.get_tree().root.get_child_count()).is_equal(kids)  # 옛 곡을 다시 트는 플레이어가 없다
	assert_object(Feedback.current_music()).is_same(song)  # 아직 지금 곡을 줄이는 중
	await get_tree().create_timer(0.8).timeout
	assert_object(Feedback.current_music()).is_same(jingle)
