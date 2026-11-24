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
## 일반 처치 흔들림(trauma)과 방향 밀림(px). 하데스는 평타·일반 처치에 화면 흔들림이 없다 (영상 분당 약 5번,
## 한얼 약 130번, docs/research/hades_data.md §8) → 둘 다 0. 강타·정예/보스 처치·기술·피격·반격·보스 단계에만.
@export var kill_trauma: float = 0.0
@export var kill_kick_px: float = 0.0
## 일반 처치 전체 멈춤(초). 연속 처치로 화면이 끊기지 않게 min_gap마다 한 번만.
@export var kill_freeze: float = 0.03
@export var kill_freeze_min_gap: float = 0.25
## 정예·보스 마무리: 게임 속도 배율, 실제 시간(초), 흔들림.
@export var finisher_time_scale: float = 0.25
@export var finisher_time: float = 0.35
@export var finisher_trauma: float = 0.6
## 정예·보스 마무리 방향 밀림(px, 예전 일반 처치 밀림의 두 배).
@export var finisher_kick_px: float = 12.0
## 영웅이 맞았을 때 흔들림.
@export var hurt_trauma: float = 0.4

@export_group("카메라")
## true면 흔들림이 맞은 방향으로 밀리는 쪽으로 치우친다 (무작위 대신).
@export var directional_shake: bool = true
## 방향 흔들림에서 옆으로 떨리는 비율 (0 = 정확히 한 방향).
@export var shake_side_ratio: float = 0.3
## 방향 밀림이 돌아오는 빠르기(초당 감쇠율).
@export var kick_return: float = 14.0
## 카메라 따라가기 빠르기 (Camera2D position_smoothing_speed): 평소, 대시 중 (하데스는 대시의 약 80%를 0.17초 안에
## 따라감, 한얼 8에서는 약 45%), 대시 뒤 평소로 돌아오는 속도 (초당 줄어드는 양, 연속 대시에서 출렁이지 않게).
@export var follow_speed: float = 8.0
@export var dash_follow_speed: float = 14.0
@export var follow_return_rate: float = 15.0
## 흔들림 크기 = trauma^exponent × 최대. 2면 작은 값(처치·작은 기술)이 1px도 안 돼 사라져서 1.5.
@export var shake_exponent: float = 1.5
## 기술 시전 흔들림: 맞힘·헛침·반격 (기술마다 정한 소리가 있는 영웅도 같음).
@export var skill_trauma: float = 0.35
@export var skill_trauma_miss: float = 0.12
@export var counter_trauma: float = 0.7
## 정예 갑옷 깨짐·보스 휘청 흔들림.
@export var poise_trauma: float = 0.4


@export_group("영웅 동작")
## 근접 피해 지연 자동값의 범위(초): 맞닿는 프레임까지 기다리되 손맛이 둔해지지 않게.
@export var melee_delay_min: float = 0.05
@export var melee_delay_max: float = 0.15
## 원거리 손을 떠나는 시각 범위(초): release_delay가 음수인 영웅은 던지는 동작의 맞닿는 프레임에서.
@export var release_delay_min: float = 0.06
@export var release_delay_max: float = 0.25
## 근접 반동이 이어지는 시간(초).
@export var recoil_time: float = 0.06
## 연타 흐름: 공격 동작이 끝난 뒤 마지막 자세를 이만큼(초) 붙잡는다 (다음 타 전에 대기 자세로 돌아가 튀지 않게).
@export var combo_hold_time: float = 0.35
## 기술 그림 위에 그리는 시전 동작(SkillDef.hero_over_fx)의 영웅 z: FxLayer(5) 위, 보상 그림(7) 아래.
@export var cast_over_fx_z: int = 6
## 연계 흐름 (사용자: "연계가 뚝뚝 끊어지는것"): 동작이 바뀔 때 앞 그림을 겹쳐 흐리게 지우는 시간(초)·처음 진하기,
## 타 사이에 내딛은 그림 위치를 유지할지 (예전: 타마다 제자리로 돌아왔다 다시 나가 덜컥거림).
@export var anim_blend_time: float = 0.08
@export var anim_blend_alpha: float = 0.6
@export var lunge_hold_combo: bool = true
## 크게 날리기 곡선 (EnemyLaunch): 맞고 거의 제자리인 시간, 그 뒤 튀어 감속하는 시간(초). 하데스 실측 약 3칸 + 0.3초.
@export var big_push_hold: float = 0.05
@export var big_push_time: float = 0.3
## 멈춤(hold) 동안 갈 거리 비율 (나머지는 튀어 감속하며).
@export var big_push_hold_share: float = 0.04

@export_group("하데스 슬라이스")
## 물결 마지막 처치 슬로모션 (실제 초·게임 속도).
## 하데스 LastKillPresentation: 35% 속도로 0.6초, 0.4초에 걸쳐 복귀 (wave_end_slow_time은 복귀 포함 전체가 아니라 머무는 시간).
@export var wave_end_slow_time: float = 0.6
@export var wave_end_slow_scale: float = 0.35
@export var wave_end_slow_back: float = 0.4
## 적 등장 예고 그림 (먹 번짐 원, 비면 붓 고리 ring_art)과 크기(px).
@export var spawn_warn_art: Texture2D
@export var spawn_warn_size: float = 150.0
## 붓 효과 그림의 먹 외곽선 (같은 그림을 조금 크게·먹색으로 먼저 깐다). 0이면 끔.
@export var fx_ink_outline: float = 0.55
@export var fx_ink_outline_scale: float = 1.12
## 적 발밑 먹 그림자 (무게감): 몸 반지름 배율, 보통·큰 적 진하기, 큰 적 기준 반지름(px, 몸 × 크기 배율).
@export var enemy_shadow_scale: float = 1.1
@export var enemy_shadow_alpha: float = 0.26
@export var enemy_shadow_alpha_big: float = 0.42
@export var enemy_shadow_big_radius: float = 34.0
## 달리기 ↔ 대기 전환 문턱 (최고 속도 대비). 들어갈 때와 나올 때를 다르게 해 깜빡임 방지.
@export var run_enter: float = 0.2
@export var run_exit: float = 0.08
## 달리기 동작 재생 속도 = 실제 속도 비율, 이 범위로 제한 (발이 미끄러져 보이지 않게).
@export var run_anim_min: float = 0.6
@export var run_anim_max: float = 1.15
## 서 있는 동작(숨쉬기) 재생 속도 배율. 1 = 구운 그대로, 낮출수록 덜 껄떡인다, 0 = 멈춤.
@export var idle_anim_speed: float = 0.35
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
## 평타 검기 크기 배율 (전체, 타별 곱). 3타는 더 크게.
@export var crescent_scale: float = 1.5
@export var crescent_step_scales: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.35])
## 초승달 바깥 가장자리 = 판정 사거리 × crescent_reach, 두께 = 사거리 × crescent_depth × 타별 배율 (그림을 판정에 맞춘다).
@export var crescent_reach: float = 1.05
@export var crescent_depth: float = 0.85
## 검기 영웅색을 밝히는 정도, 밝은 심의 진하기와 흰빛 섞는 비율 (어두운 바닥에서 보이게).
@export var crescent_lighten: float = 0.25
@export var crescent_core_alpha: float = 0.85
@export var crescent_core_white: float = 0.6
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


@export_group("맞는 반응·판정")
## 이 피해 이상이면 큰 타격: 피해 숫자 강조 + 확인음 "팅" (+ 국악 양념).
@export var big_hit_damage: int = 40
## 적·영웅 맞는 반응 수치 (비우면 기본값).
@export var reaction: HitReactionData
## 던파식 타격감 (반격·뒤치기·끊김·넘어짐·영웅 멈춤·3타째·피해 숫자·마무리 확대).
@export var impact: ImpactFeelData
## 한 타 충격 (닿는 자리 섬광·튐 줄기·퍽 소리·진동, HitImpact).
@export var hit_impact: HitImpactData
## 기술 명중 멈춤 (D3, SkillHitStop): 길이 = base + 피해 × per_damage (최대 cap, 최소 min),
## 한 번에 맞힌 적이 하나 늘 때마다 × multi, 멈춤 사이 최소 간격(초), 멈춤 중 게임 속도.
@export var skill_stop_base: float = 0.03
@export var skill_stop_per_damage: float = 0.0015
@export var skill_stop_cap: float = 0.12
## 휘감는 기술(해룡참·해시계): 적마다 멈추지 않고, 휘감기가 끝날 때 skill_stop_cap × 이 값으로 한 번 크게 (0이면 예전처럼 적마다).
@export var sweep_final_stop: float = 1.0
## 그 마지막 멈춤의 게임 속도 (멈춤 대신 느리게: 회전 동작이 한 칸에 서 있지 않게).
@export var sweep_final_scale: float = 0.3
@export var skill_stop_min: float = 0.03
@export var skill_stop_multi: float = 0.85
@export var skill_stop_min_gap: float = 0.2
@export var skill_stop_scale: float = 0.05
## 기술 판정에 더하는 적 몸 반경 배율 (가장자리 판정, LoL식). 0이면 중심점만.
@export var skill_edge_scale: float = 1.0


func reaction_data() -> HitReactionData:
	if reaction == null:
		reaction = HitReactionData.new()
	return reaction


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


func hit_impact_data() -> HitImpactData:
	if hit_impact == null:
		hit_impact = HitImpactData.new()
	return hit_impact


func impact_data() -> ImpactFeelData:
	if impact == null:
		impact = ImpactFeelData.new()
	return impact
