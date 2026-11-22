class_name RangedFeelData
extends Resource
## 원거리 평타 한 발의 타격감 (RangedFeel): 쏘는 순간·날아가는 탄·맞는 순간·빗나가 사라질 때.
## 근접 "한 방"(HitImpactData)과 같은 계열을 쓰고, 여기에는 원거리에만 있는 값만 둔다.
## 배열은 원거리 연타 번호(1~3, 세종 글자 연사: 하나 → 둘 → 큰 글자)별. 피해·사거리·발사 간격은 건드리지 않는다.

const PATH := "res://data/feel/ranged_feel.tres"

## 이 연출을 쓰는 영웅 (HeroData.id). 비면 모두. 원거리 평타는 세종 전용으로 정해졌다
## (순신·광개토는 근접만, 사임당은 중거리 먹 털기로 바뀌어 RangedFeel.strike 등 공통 조각만 나중에 쓴다).
@export var heroes: PackedStringArray = PackedStringArray(["sejong"])

@export_group("쏘는 순간")
## 손·무기 끝 섬광: 심 반지름(px), 앞으로 뻗는 줄기 수·길이(px), 보이는 시간(초), 먹 방울 수.
@export var muzzle_core: PackedFloat32Array = PackedFloat32Array([18.0, 20.0, 26.0])
@export var muzzle_streaks: PackedInt32Array = PackedInt32Array([4, 4, 6])
@export var muzzle_length: PackedFloat32Array = PackedFloat32Array([40.0, 44.0, 60.0])
@export var muzzle_spread_deg: float = 50.0
@export var muzzle_time: float = 0.11
@export var muzzle_drops: PackedInt32Array = PackedInt32Array([2, 2, 4])
## 영웅 반동: 쏜 반대쪽으로 밀리는 거리(px)와 시간(초) (근접 lunge의 반대).
@export var recoil_px: PackedFloat32Array = PackedFloat32Array([5.0, 5.0, 9.0])
@export var recoil_time: float = 0.08
## 발사음 (짧고 또렷한 바람 소리)과 연타 번호별 음높이.
@export var launch_sfx: StringName = &"slash"
@export var launch_pitch: PackedFloat32Array = PackedFloat32Array([1.3, 1.36, 1.1])
@export var launch_gap: float = 0.03

@export_group("날아가는 탄")
## 탄 속도 배율. 수명은 같은 배율로 줄여 닿는 거리(사거리)는 그대로 (속도 × 수명).
## 하데스 활·창 던지기 3000 (한얼 척도 1500 px/초) 대비 한얼 650~800이라 날아가는 동안 맥이 빠졌다.
@export var speed_mult: float = 1.4
## 탄 밑에 까는 약한 빛 (더하기, 탄 그림 대비 크기·세기). 어두운 바닥에서 탄이 읽히게.
@export var glow_alpha: float = 0.3
@export var glow_scale: Vector2 = Vector2(1.1, 1.6)

@export_group("맞는 순간")
## 접점 섬광·줄기는 HitImpactData (근접과 같은 계열), 원거리 연타 번호를 근접 타 번호로 쓴다.
## 탄이 진행 방향으로 더 미는 힘 (BasicAttackData.ranged_knockback에 더함, 감쇠 8이면 약 힘/8 px).
@export var extra_knockback: PackedFloat32Array = PackedFloat32Array([70.0, 70.0, 160.0])
## 이 연타 번호부터 강타 (근접 3타와 같은 멈춤·넘어짐·늦은 감속·흔들림).
@export var heavy_step: int = 3
## 탄이 맞은 자리에서 부서져 흩어지는 시간(초)과 커지는 배율, 먹 방울 수.
@export var burst_time: float = 0.2
@export var burst_grow: float = 1.45
@export var burst_drops: PackedInt32Array = PackedInt32Array([3, 3, 6])

@export_group("빗나감")
## 맞지 않고 사라지는 탄: 먹으로 풀리는 시간(초), 먹 방울 수.
@export var fizzle_time: float = 0.2
@export var fizzle_drops: int = 2

@export_group("상한")
## 쏘는 섬광·부서짐·풀림을 합쳐 동시에 그리는 수 (풀링, 넘치면 가장 오래된 것부터 덮어씀).
@export var max_active: int = 16

static var _cached: RangedFeelData


static func get_default() -> RangedFeelData:
	if _cached == null:
		_cached = load(PATH) as RangedFeelData if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = RangedFeelData.new()
	return _cached


func applies_to(hero_id: StringName) -> bool:
	return heroes.is_empty() or heroes.has(String(hero_id))


func is_heavy(step: int) -> bool:
	return heavy_step > 0 and step >= heavy_step


func knock_extra(step: int) -> float:
	return HitImpactData.at_f(extra_knockback, step, 0.0)
