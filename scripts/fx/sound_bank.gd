class_name SoundBank
extends Resource
## 효과음 묶음: 종류 이름 → 여러 변형 (재생할 때 하나를 무작위로). 없는 종류는 Feedback이 합성음으로 대신한다.
## 소리 파일은 tools/audio/prepare_audio.py가 CC0 원본에서 만든다.

## { &"slash": [AudioStream, ...], ... }
@export var sounds: Dictionary = {}
## 종류별 음량 보정(dB). 없으면 0.
@export var volume_db: Dictionary = {}


func has(kind: StringName) -> bool:
	return sounds.has(kind) and not (sounds[kind] as Array).is_empty()


func pick(kind: StringName, rng: RandomNumberGenerator) -> AudioStream:
	var list: Array = sounds.get(kind, [])
	if list.is_empty():
		return null
	return list[rng.randi() % list.size()]


func db(kind: StringName) -> float:
	return float(volume_db.get(kind, 0.0))
