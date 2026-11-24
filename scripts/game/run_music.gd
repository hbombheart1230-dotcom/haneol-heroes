class_name RunMusic
extends RefCounted
## 판 음악 (Main에서 분리): 무대마다 그 무대의 노래(StageSong) — 만주는 광개토 노래 (사용자 결정).
## 영웅은 늘 자기 무대에서 시작하므로 영웅 이야기 음악은 그 영웅 자기 무대의 노래.
## 평소 = 본편(verse), 보스 = 보스 판(boss, 없으면 후렴), 승리·패배 = 짧은 곡(Main.victory_track/defeat_track) 또는 후주·전주.
## 메뉴(입장·공통 이야기·영웅 고르기) = Main.menu_track.

const SONG_SECTION := {&"stage": &"verse", &"boss": &"chorus", &"victory": &"outro", &"defeat": &"intro"}

var main: Node
## 마지막 음악 신호 (설정에서 노랫소리를 바꿀 때 같은 장면을 다시 틀기 위해).
var _kind: StringName = &""


func _init(m: Node) -> void:
	main = m


## 음악 신호: &"stage" / &"boss" / &"victory" / &"defeat".
func cue(kind: StringName) -> void:
	_kind = kind  # 승리·패배 짧은 곡도 기록: 결과 화면에서 설정을 바꿔도 판 음악이 되살아나지 않게
	var jingle: AudioStream = {&"victory": main.victory_track, &"defeat": main.defeat_track}.get(kind)
	if jingle and Feedback.instance:
		Feedback.instance.play_music(jingle, 0.4)
		return
	var cfg: RunConfig = main.run_config
	var song: StageSong = cfg.stage.song if cfg and cfg.stage else null
	var off := vocal_off_stream(kind, song)
	if off and Feedback.instance:  # 노랫소리 끔: 판 중(무대·우두머리)만 반주 반복, 우두머리 전환은 짧게 겹쳐 넘김
		Feedback.instance.play_music(off, song.boss_fade * 0.5)
	elif song:
		MusicDirector.play(song, section_for(kind, song))
	elif Feedback.instance and stage_track(kind):
		Feedback.instance.play_music(stage_track(kind), 0.6)


## 노랫소리 끔일 때 판 중(&"stage"·&"boss") 음악. 해당 없으면 null (원곡 그대로).
static func vocal_off_stream(kind: StringName, song: StageSong) -> AudioStream:
	if GameSettings.vocals_enabled or song == null or not (kind == &"stage" or kind == &"boss"):
		return null
	return song.vocal_off_stream(kind == &"boss")


## 설정에서 노랫소리를 바꿨을 때: 판 중이면 지금 장면의 음악을 다시 (페이드로) 튼다.
func refresh() -> void:
	if _kind == &"stage" or _kind == &"boss":
		cue(_kind)


## 신호 → 구간. 보스는 보스 판이 있으면 그것, 없으면 후렴.
static func section_for(kind: StringName, song: StageSong) -> StringName:
	if kind == &"boss" and song and song.boss:
		return &"boss"
	return SONG_SECTION[kind]


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
