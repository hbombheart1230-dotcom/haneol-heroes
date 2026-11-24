class_name MusicCrossfade
extends RefCounted
## 곡 바꿀 때 소리가 줄었다 커지지 않고 겹쳐 넘어간다: 새 곡을 바로 틀어 키우면서, 옛 곡은 따로 한 플레이어에 이어 틀어 줄인다.
## 두 소리의 세기를 cos/sin으로 곱해 겹치는 동안에도 전체 세기가 일정하다 (등전력).
## 옛 곡 플레이어는 스스로 줄어들다 사라지므로, 전환이 중간에 끊겨도 남지 않는다.


## 옛 곡을 다른 플레이어에 이어 틀 수 있는지. 인터랙티브·동기화 곡(무대 노래, MusicDirector)은 새 재생이 처음 구절·0초에서
## 시작해 지금 들리는 부분을 잇지 못하므로 겹쳐 넘기지 않는다 (줄였다 바꿔 키우는 예전 방식, Feedback.play_music).
static func can_copy(stream: AudioStream) -> bool:
	return stream != null and not (stream is AudioStreamInteractive or stream is AudioStreamSynchronized)


## player의 곡을 stream으로 바꾼다. 돌려주는 Tween은 새 곡을 키우는 것 (끊으면 새 곡 세기를 직접 되돌려야 한다).
static func start(player: AudioStreamPlayer, stream: AudioStream, fade: float, base_db: float) -> Tween:
	var old := AudioStreamPlayer.new()
	old.stream = player.stream
	old.bus = player.bus
	old.process_mode = Node.PROCESS_MODE_ALWAYS
	old.volume_db = player.volume_db
	player.get_parent().add_child(old)
	old.play(player.get_playback_position())
	var old_db := old.volume_db
	var old_tween := old.create_tween()
	old_tween.tween_method(func(t: float) -> void: old.volume_db = old_db + _db(cos(t * PI * 0.5)), 0.0, 1.0, fade)
	old_tween.tween_callback(old.queue_free)
	player.stream = stream
	player.volume_db = -80.0
	if stream == null:
		player.stop()
		return null
	player.play()
	var tween := player.create_tween()
	tween.tween_method(func(t: float) -> void: player.volume_db = base_db + _db(sin(t * PI * 0.5)), 0.0, 1.0, fade)
	return tween


static func _db(gain: float) -> float:
	return maxf(linear_to_db(gain), -80.0)
