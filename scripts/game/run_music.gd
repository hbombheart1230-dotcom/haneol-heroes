class_name RunMusic
extends RefCounted
## 판 음악 (Main에서 분리): 무대마다 그 무대의 노래(StageSong) — 만주는 광개토 노래 (사용자 결정).
## 영웅은 늘 자기 무대에서 시작하므로 영웅 이야기 음악은 그 영웅 자기 무대의 노래.
## 평소 = 본편(verse), 보스 = 후렴(chorus), 승리·패배 = 짧은 곡(Main.victory_track/defeat_track) 또는 후주·전주.
## 메뉴(입장·공통 이야기·영웅 고르기) = Main.menu_track.

const SONG_SECTION := {&"stage": &"verse", &"boss": &"chorus", &"victory": &"outro", &"defeat": &"intro"}

var main: Node


func _init(m: Node) -> void:
	main = m


## 음악 신호: &"stage" / &"boss" / &"victory" / &"defeat".
func cue(kind: StringName) -> void:
	var jingle: AudioStream = {&"victory": main.victory_track, &"defeat": main.defeat_track}.get(kind)
	if jingle and Feedback.instance:
		Feedback.instance.play_music(jingle, 0.4)
		return
	var cfg: RunConfig = main.run_config
	var song: StageSong = cfg.stage.song if cfg and cfg.stage else null
	if song:
		MusicDirector.play(song, SONG_SECTION[kind])
	elif Feedback.instance and stage_track(kind):
		Feedback.instance.play_music(stage_track(kind), 0.6)


func menu() -> void:
	var stages: Array[StageTheme] = main.stages
	if main.menu_track and Feedback.instance:
		Feedback.instance.play_music(main.menu_track, 0.8)
	elif not stages.is_empty() and stages[0] and stages[0].song:
		MusicDirector.play(stages[0].song, &"intro")


## 영웅 이야기 음악: 그 영웅 노래의 본편 (판이 시작돼도 같은 곡이 이어진다).
func hero(h: HeroData) -> void:
	var song := hero_song(h)
	if song:
		MusicDirector.play(song, SONG_SECTION[&"stage"], 0.8)


## 영웅의 노래 = 그 영웅 자기 무대(home_stage)의 노래. 없으면 지금 무대의 노래.
func hero_song(h: HeroData) -> StageSong:
	var st: StageTheme = main.stage_by_id(h.home_stage) if h else null
	if st and st.song:
		return st.song
	var cfg: RunConfig = main.run_config
	return cfg.stage.song if cfg and cfg.stage else null


## 노래가 없을 때의 곡 (StageTheme.music 등).
func stage_track(kind: StringName) -> AudioStream:
	var cfg: RunConfig = main.run_config
	var st := cfg.stage if cfg else null
	if st == null:
		return null
	var s: AudioStream = {&"boss": st.boss_music, &"victory": st.victory_music, &"defeat": st.defeat_music}.get(kind)
	return s if s else st.music
