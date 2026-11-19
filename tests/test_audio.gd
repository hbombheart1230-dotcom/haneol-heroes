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
	assert_object(STAGE.music).is_not_null()
	assert_bool((STAGE.music as AudioStreamOggVorbis).loop).is_true()


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
