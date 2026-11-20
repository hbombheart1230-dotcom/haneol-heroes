class_name MusicDirector
extends RefCounted
## 무대 노래(StageSong)를 구간 단위로 튼다. Feedback의 상주 음악 플레이어(장면이 바뀌어도 이어짐)를 쓴다.
## 같은 노래가 이미 나오면 구간만 바꾸고(마디 끝 전환), 다른 노래면 그 구간부터 새로 시작한다.


static func player() -> AudioStreamPlayer:
	var p := Feedback._music
	return p if p != null and is_instance_valid(p) else null


## 노래의 한 구간을 튼다 (&"intro" / &"verse" / &"chorus" / &"outro"). 바꿨으면 true.
static func play(song: StageSong, section: StringName, fade: float = 0.6) -> bool:
	var p := player()
	if p == null or song == null or not StageSong.SECTIONS.has(section):
		return false
	var stream := song.interactive()
	if p.stream == stream and p.playing:
		var pb := p.get_stream_playback() as AudioStreamPlaybackInteractive
		if pb == null:
			return false
		pb.switch_to_clip_by_name(section)
		return true
	stream.initial_clip = StageSong.SECTIONS.find(section)
	if Feedback.instance:
		Feedback.instance.play_music(stream, fade)
	else:
		p.stream = stream
		p.play()
	return true


## 지금 나오는 구간 이름 (노래가 아니면 &"").
static func current_section() -> StringName:
	var p := player()
	if p == null or not (p.stream is AudioStreamInteractive) or not p.playing:
		return &""
	var pb := p.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return &""
	var i := pb.get_current_clip_index()
	return StageSong.SECTIONS[i] if i >= 0 and i < StageSong.SECTIONS.size() else &""
