class_name BladeBiteData
extends Resource
## 무기가 몹에 박히는 느낌 (역경직): 칼이 몹 몸과 겹친 장면에서 멈추고(타마다 길이), 영웅·맞은 몹이 잘게 떨고,
## 풀리면서 동작이 잠깐 빨라지며 그때 몹이 밀린다 (멈춤 → 밀림). 닿을 때 퍽, 풀릴 때 쉭. 검기도 접점에서 굵고 밝게.
## HeroData.blade_bite에 붙인다 (없으면 꺼짐 = 예전 방식). 지금은 순신만.

@export var enabled: bool = true
## 1·2·3타 멈춤(초, 실제 시간 아닌 게임 시간). 휘두름 한 번에 한 번, 맞은 수와 상관없이.
@export var stop_times: PackedFloat32Array = PackedFloat32Array([0.05, 0.05, 0.1])
## 넷째 탭 마무리 (기술 명중 멈춤을 이 길이로 고정, SkillHitStop).
@export var finisher_stop: float = 0.1
## 멈춘 동안 떨림 (px, 영웅 그림·맞은 몹 그림 좌우, 물리 프레임마다 번갈아).
@export var jitter_px: float = 2.5
## 풀리면서 빨라짐: 재생 배율. 빨라지는 시간은 멈춘 만큼을 되찾을 때까지 (멈춤 ÷ (배율 − 1)) → 한 번 휘두르는 전체 길이는 그대로.
@export var release_speed: float = 1.6
## 그 시간의 상한(초).
@export var release_max: float = 0.2
## 클립별 접점 시각(초) 덮어쓰기 (2D 구운 그림: 비면 시트 strike_frames ÷ fps). {&"attack": 0.19, ...}
@export var clip_contact: Dictionary = {}
## 접점 시각 안전 범위(초): 모르는 클립·이상한 값은 이 안으로.
@export var contact_min: float = 0.05
@export var contact_max: float = 0.4
## 평타 동작(attack·attack2·attack3) 재생 배율: 칼이 닿는 시각 = 접점 ÷ 이 값 (순신 1.25 → 0.19초가 광개토·사임당과 같은 0.15초).
@export var swing_speed: float = 1.0
## 닿을 때 둔탁한 퍽은 HitImpactData.thud_sfx (이미 남), 거기 더 겹칠 소리 (비우면 없음). 풀릴 때 가르는 쉭 (SoundBank 종류, 비우면 없음)과 음높이.
@export var bite_sfx: StringName = &""
@export var release_sfx: StringName = &"slash"
@export var release_pitch: float = 1.15
## 멈춘 동안 검기: 폭·밝기 배율 (닿은 자리에서 잠깐 굵고 밝게).
@export var trail_flare_width: float = 1.5
@export var trail_flare_bright: float = 1.6
## 멈춤 중 대시는 기억했다가 풀릴 때 바로 (끄면 멈춤 중에도 바로 대시).
@export var buffer_dash: bool = true


func stop_for(step: int) -> float:
	if stop_times.is_empty():
		return 0.0
	return stop_times[clampi(step - 1, 0, stop_times.size() - 1)]


## 멈춘 만큼 되찾는 빨라짐 시간(초).
func release_time(stop: float) -> float:
	if release_speed <= 1.0:
		return 0.0
	return minf(stop / (release_speed - 1.0), release_max)
