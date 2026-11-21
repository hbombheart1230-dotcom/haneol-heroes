class_name SoundBank
extends Resource
## 효과음 묶음: 종류 이름 → 여러 변형 (재생할 때 하나를 무작위로). 없는 종류는 Feedback이 합성음으로 대신한다.
## 소리 파일은 tools/audio/prepare_audio.py가 CC0 원본에서 만든다.

## { &"slash": [AudioStream, ...], ... }
@export var sounds: Dictionary = {}
## 종류별 음량 보정(dB). 없으면 0.
@export var volume_db: Dictionary = {}
## 종류별 우선순위 (클수록 중요, 없으면 1). 재생기가 모자라면 낮은 것부터 끊는다 (SfxVoices).
@export var priority: Dictionary = {}
## 종류별 동시에 울릴 수 있는 최대 수 (없거나 0이면 제한 없음).
@export var max_voices: Dictionary = {}
## 피치 무작위 범위 (배율). 같은 소리 반복이 덜 거슬리게.
@export var pitch_range: Vector2 = Vector2(0.94, 1.06)

var _last_pick: Dictionary = {}


func has(kind: StringName) -> bool:
	return sounds.has(kind) and not (sounds[kind] as Array).is_empty()


## 무작위로 하나, 바로 전과 같은 것은 피한다 (같은 소리 연달아 → 기관총 같음).
func pick(kind: StringName, rng: RandomNumberGenerator) -> AudioStream:
	var list: Array = sounds.get(kind, [])
	if list.is_empty():
		return null
	var i := rng.randi() % list.size()
	if list.size() > 1 and i == int(_last_pick.get(kind, -1)):
		i = (i + 1 + rng.randi() % (list.size() - 1)) % list.size()
	_last_pick[kind] = i
	return list[i]


func db(kind: StringName) -> float:
	return float(volume_db.get(kind, 0.0))


func prio(kind: StringName) -> int:
	return int(priority.get(kind, 1))


func max_of(kind: StringName) -> int:
	return int(max_voices.get(kind, 0))
