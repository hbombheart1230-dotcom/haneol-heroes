class_name StageSong
extends Resource
## 무대 노래 한 곡을 구간으로 나눈 것 (tools/audio/cut_song.py가 만든다).
## 전주(입장·이야기) → 1절(평소, 반복) → 후렴(보스, 반복) → 후주(승리). 구간 넘나들기는 마디 끝에서.

const SECTIONS: Array[StringName] = [&"intro", &"verse", &"chorus", &"outro"]

@export var intro: AudioStream
@export var verse: AudioStream
@export var chorus: AudioStream
@export var outro: AudioStream
## 빠르기와 한 마디의 박 수 (마디 끝 전환에 쓴다). 국악 12/8 장단이면 bar_beats = 4 (점4분 기준).
@export var bpm: float = 100.0
@export var bar_beats: int = 4
## 구간이 바뀔 때 겹쳐 넘어가는 박 수.
@export var fade_beats: float = 1.0

var _built: AudioStreamInteractive


func section_stream(name: StringName) -> AudioStream:
	return {&"intro": intro, &"verse": verse, &"chorus": chorus, &"outro": outro}.get(name)


## 구간 넘나드는 스트림 (한 번 만들어 재사용). 1절·후렴·전주는 반복, 후주는 한 번.
func interactive() -> AudioStreamInteractive:
	if _built:
		return _built
	var s := AudioStreamInteractive.new()
	s.clip_count = SECTIONS.size()
	for i in SECTIONS.size():
		var src := section_stream(SECTIONS[i])
		s.set_clip_name(i, SECTIONS[i])
		s.set_clip_stream(i, _timed(src, SECTIONS[i] != &"outro"))
	s.initial_clip = 1
	# 어디서든 → 후렴·후주·1절: 다음 마디 끝에서 겹쳐 넘어간다 (보스 등장·승리·다시 시작).
	for to in [1, 2, 3]:
		s.add_transition(AudioStreamInteractive.CLIP_ANY, to, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
			AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_CROSS, fade_beats)
	# 전주로는 바로 (패배·메뉴): 박자를 기다리지 않는다.
	s.add_transition(AudioStreamInteractive.CLIP_ANY, 0, AudioStreamInteractive.TRANSITION_FROM_TIME_IMMEDIATE,
		AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_CROSS, fade_beats)
	_built = s
	return s


## 박자 정보를 단 사본 (원본 파일 리소스는 건드리지 않는다).
func _timed(src: AudioStream, loop: bool) -> AudioStream:
	if src == null:
		return null
	var c := src.duplicate() as AudioStream
	if c is AudioStreamOggVorbis:
		var o := c as AudioStreamOggVorbis
		o.bpm = bpm
		o.bar_beats = bar_beats
		o.beat_count = int(round(o.get_length() * bpm / 60.0))
		o.loop = loop
	return c
