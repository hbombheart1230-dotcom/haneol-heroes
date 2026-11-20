class_name CombatFeelData
extends Resource
## 타격감 공통 수치 (docs/game_feel_research.md ①②③ + 방향 흔들림).
## 영웅별 수치는 BasicAttackData·HeroData, 적 종류별은 EnemyData에 둔다.

@export_group("피격 (적 개별 멈춤)")
## 맞은 적만 잠깐 멈추고 떨린다 (내 이동은 안 끊김). 피해가 heavy_damage 이상이면 heavy 쪽.
@export var hit_freeze: float = 0.05
@export var hit_freeze_heavy: float = 0.08
@export var heavy_damage: int = 20
## 멈춤 동안 좌우 떨림 폭(px).
@export var hit_shake_px: float = 4.0
## 피격 밝아짐 전체 시간과, 그중 아주 밝게 보이는 처음 구간(초).
@export var flash_time: float = 0.08
@export var flash_peak_time: float = 0.03
## 피격 먹물 방울 수 (약/강).
@export var hit_drops: int = 3
@export var hit_drops_heavy: int = 5

@export_group("처치 날림")
## 시체가 포물선으로 날아가는 시간(초), 거리 = base + 마지막 피해 × per_damage (최대 max).
@export var launch_time: float = 0.42
@export var launch_base: float = 80.0
@export var launch_per_damage: float = 3.0
@export var launch_max: float = 320.0
## 날아가는 높이(px, 가상 Z)와 회전 수.
@export var launch_height: float = 60.0
@export var launch_spins: float = 1.5
## 동시에 날아가는 시체 최대 수 (넘으면 가장 오래된 것부터 사라짐).
@export var max_corpses: int = 12
## 땅에 남는 먹 자국이 옅어지는 시간(초).
@export var mark_time: float = 0.8
## 처치 시 먹물 방울 수.
@export var kill_drops: int = 10
## 화면 전체 먹물 방울 최대 수.
@export var max_drops: int = 60
## 먹물·죽음 모양 세부 수치 (비우면 기본값).
@export var burst: InkBurstData

@export_group("처치 반응")
## 일반 처치 흔들림(trauma)과 방향 밀림(px).
@export var kill_trauma: float = 0.12
@export var kill_kick_px: float = 6.0
## 일반 처치 전체 멈춤(초). 연속 처치로 화면이 끊기지 않게 min_gap마다 한 번만.
@export var kill_freeze: float = 0.03
@export var kill_freeze_min_gap: float = 0.25
## 정예·보스 마무리: 게임 속도 배율, 실제 시간(초), 흔들림.
@export var finisher_time_scale: float = 0.25
@export var finisher_time: float = 0.35
@export var finisher_trauma: float = 0.6

@export_group("카메라")
## true면 흔들림이 맞은 방향으로 밀리는 쪽으로 치우친다 (무작위 대신).
@export var directional_shake: bool = true
## 방향 흔들림에서 옆으로 떨리는 비율 (0 = 정확히 한 방향).
@export var shake_side_ratio: float = 0.3
## 방향 밀림이 돌아오는 빠르기(초당 감쇠율).
@export var kick_return: float = 14.0


@export_group("영웅 동작")
## 근접 반동이 이어지는 시간(초).
@export var recoil_time: float = 0.06
## 달리기 ↔ 대기 전환 문턱 (최고 속도 대비). 들어갈 때와 나올 때를 다르게 해 깜빡임 방지.
@export var run_enter: float = 0.2
@export var run_exit: float = 0.08
## 달리기 동작 재생 속도 = 실제 속도 비율, 이 범위로 제한 (발이 미끄러져 보이지 않게).
@export var run_anim_min: float = 0.6
@export var run_anim_max: float = 1.15
## 방향 그림을 바꾸려면 칸 경계를 이만큼(도) 넘어야 한다.
@export var dir_margin_deg: float = 10.0


@export_group("기술 이펙트")
## 화면 전체 기술 이펙트 입자 최대 수 (넘으면 가장 오래된 것부터 사라짐).
@export var max_vfx_particles: int = 160
## 수묵 셰이더: 가장자리 갉기 세기, 가장자리 먹 물들임, 잡음 배율.
@export var vfx_roughness: float = 0.35
@export var vfx_edge_ink: float = 0.4
@export var vfx_noise_scale: float = 0.02
## 번개 줄기 그리기: 빛 두께·투명도, 몸통 두께, 흰 심지 두께 (모두 줄기 폭 대비), 사라지며 가늘어지는 비율.
@export var bolt_glow_width: float = 2.2
@export var bolt_glow_alpha: float = 0.45
@export var bolt_body_width: float = 0.8
@export var bolt_core_width: float = 0.25
@export var bolt_thin: float = 0.5
## 그려진 이펙트(shaders/ink_decal.gdshader): 동시 최대 수, 사라지는 가장자리 폭·먹 물들임·잡음 배율.
@export var max_decals: int = 24
## 직선 기술·회피 띠 동시 최대 수.
@export var max_strips: int = 12
## 코드로 그린 동그라미·선 대신 쓰는 무채색 붓 그림 (기술 색을 곱해 그린다, tools/vfx/make_neutral.py).
## 고리(범위·예고), 붓 획(검기·선), 튐(타격), 웅덩이(장판), 초승달(근접 베기).
@export var ring_art: Texture2D
@export var stroke_art: Texture2D
@export var splat_art: Texture2D
@export var pool_art: Texture2D
@export var crescent_art: Texture2D
@export var decal_edge: float = 0.12
## 수명이 이 비율 아래로 내려가면 번지기 시작한다.
@export var decal_dissolve_from: float = 0.5
@export var decal_edge_ink: float = 0.6
@export var decal_noise_uv: float = 1.7
## 겹친 그림이 한 겹마다 작아지는 비율과 돌아가는 각도(라디안).
@export var decal_layer_shrink: float = 0.8
@export var decal_layer_turn: float = 0.9
## 금빛 고리 (강화 단계 ring_level부터): 크기 배율·시간·두께.
@export var flourish_ring_scale: float = 0.45
@export var flourish_ring_time: float = 0.45
@export var flourish_ring_width: float = 10.0
## 고리 세로 눌림 비율과 동시 최대 수.
@export var flourish_ring_squash: float = 0.6
@export var max_flourish_rings: int = 6


@export_group("타격 진동")
## 진동 길이(ms)와 세기(0~1). 일반 자동 공격에는 울리지 않는다 (너무 자주 옴). 설정 "타격 진동"을 따른다.
@export var haptic_hurt_ms: int = 40
@export var haptic_hurt_amp: float = 0.6
@export var haptic_finisher_ms: int = 60
@export var haptic_finisher_amp: float = 0.8
@export var haptic_impact_ms: int = 25
@export var haptic_impact_amp: float = 0.5
## 진동 사이 최소 간격(초).
@export var haptic_min_gap: float = 0.12


func burst_data() -> InkBurstData:
	if burst == null:
		burst = InkBurstData.new()
	return burst


func freeze_for(damage: int) -> float:
	return hit_freeze_heavy if damage >= heavy_damage else hit_freeze


func drops_for(damage: int) -> int:
	return hit_drops_heavy if damage >= heavy_damage else hit_drops


## 마지막 피해로 날아갈 거리 (적 종류 배율 포함).
func launch_distance(last_damage: int, scale: float = 1.0) -> float:
	return minf(launch_base + maxf(last_damage, 0) * launch_per_damage, launch_max) * scale
