class_name SfxSynth
extends RefCounted
## 임시 효과음 합성 (엔진 기본 AudioStreamWAV, 파일·라이선스 불필요).
## 정식 효과음은 아트·사운드 단계에서 녹음/에셋으로 교체한다.

const RATE := 22050
const DURATIONS := {
	&"slash": 0.12, &"hit": 0.10, &"dash": 0.16, &"counter": 0.35,
	&"evade": 0.18, &"hurt": 0.16, &"die": 0.14,
}


static func make(kind: StringName) -> AudioStreamWAV:
	var duration: float = DURATIONS.get(kind, 0.05)
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(_sample(kind, float(i) / RATE, float(i) / n), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## t: 초, k: 0~1 진행률. 반환 -1~1.
static func _sample(kind: StringName, t: float, k: float) -> float:
	var decay := 1.0 - k
	match kind:
		&"slash":  # 짧은 바람 가르는 소리
			return _noise() * pow(decay, 3.0) * 0.5
		&"hit":  # 둔탁한 타격
			return (sin(TAU * lerpf(160.0, 60.0, k) * t) * 0.7 + _noise() * 0.3) * decay * decay * 0.8
		&"dash":  # 휙
			return _noise() * sin(PI * k) * 0.35
		&"counter":  # 금속성 강타
			var ring := sin(TAU * 880.0 * t) * 0.4 + sin(TAU * 1320.0 * t) * 0.3
			return (ring + _noise() * pow(decay, 6.0) * 0.6) * decay * decay * 0.8
		&"evade":  # 맑은 신호음
			return sin(TAU * lerpf(900.0, 1500.0, k) * t) * decay * 0.4
		&"hurt":  # 낮은 경고음
			return signf(sin(TAU * lerpf(220.0, 110.0, k) * t)) * decay * 0.25
		&"die":  # 짧은 소멸음
			return _noise() * decay * 0.3
	return 0.0


static func _noise() -> float:
	return randf() * 2.0 - 1.0
