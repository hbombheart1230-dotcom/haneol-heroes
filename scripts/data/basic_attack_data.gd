class_name BasicAttackData
extends Resource
## 자동 기본 공격 수치 (근접 부채꼴 + 원거리 투사체).

@export_group("평타 종류")
## 영웅 역할 (사용자: "근접은 근접만 원거리는 세종만", 사임당은 중거리): 근접 평타를 쓰는지, 원거리 평타를 쓰는지.
## 근접만이면 사거리 밖 적에게는 자동으로 아무것도 안 한다 (다가가야 한다). 원거리만이면 붙은 적에게도 쏜다.
@export var use_melee: bool = true
@export var use_ranged: bool = true
@export_group("근접")
@export var melee_interval: float = 0.55
@export var melee_range: float = 110.0
@export var melee_arc_degrees: float = 140.0
@export var melee_damage: int = 12
## 근접 베기 그림 색 (CombatFeelData.crescent_art에 곱함).
@export var swing_color: Color = Color(0.55, 0.85, 1.0, 0.9)
## 근접 적중 시 적을 밀어내는 힘 (피격 반응).
@export var melee_knockback: float = 140.0
## 근접 적중 시 플레이어가 반대로 살짝 밀리는 거리(px). 칼이 닿은 반동 (Hollow Knight식).
@export var melee_recoil: float = 0.0
## 휘두르기 시작부터 피해까지(초): 칼이 닿는 프레임에 맞는다 (W2). 0이면 바로, 음수면 시트의
## 맞닿는 프레임 ÷ fps를 CombatFeelData.melee_delay_min~max로.
@export var melee_delay: float = 0.0
## 근접 우선 (A1): 근접 사거리 × engage_mult 안에 적이 있으면 원거리를 참고 붙기를 기다린다.
## 1이면 끔 (원거리 영웅). 그래도 engage_hold_max초 넘게 근접이 안 나가면 쏜다 (거리 두는 궁수 등).
@export var engage_mult: float = 1.0
@export var engage_hold_max: float = 0.5
## 평타 연계 (B4): chain_window초 안에 이어진 근접 chain_len번째가 강타 (0이면 끔).
## 강타: 피해·넉백 배율, 잡몹 넘어짐. 시트에 attack2·attack3가 있으면 그 동작으로.
@export var chain_len: int = 3
@export var chain_window: float = 1.2
@export var heavy_damage_mult: float = 1.6
@export var heavy_knockback_mult: float = 2.0
## 0보다 크면 3타 강타는 넉백 대신 이만큼(px) 크게 날린다 (사임당 중거리 3타 원 붓질). 0이면 넉백·넘어짐.
@export var heavy_launch_px: float = 0.0
## 타별 넉백 배율 (1타부터, 3타 강타는 heavy_knockback_mult와 곱). 1·2타를 "툭 밀리고 멈춤"으로 (약 35px).
@export var step_knockback_mults: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0])

@export_group("연타 흐름 (타별, 1타부터)")
## 손 평타(탭) 간격 배율: 이 타를 치기 전 최소 간격 = 평타 간격 × 값 (빠름·빠름·묵직). 비면 kit.tap_min_gap_mult.
@export var step_gap_mults: PackedFloat32Array = PackedFloat32Array([0.55, 0.6, 1.0])
## 앞 타가 맞닿은 뒤 이만큼(초) 지나면 다음 탭이 그 동작의 회복을 끊고 들어간다 (캔슬 구간).
@export var cancel_after: float = 0.06
## 손 평타를 휘두르는 동안 이동 속도 배율과 시간(초) (하데스 SwordSelfSlowFire: 12프레임 동안 35%). 움직이며 쳐도
## 휘두르는 동작이 보이고 발이 미끄러지지 않게 (M1). 대시는 언제든 휘두름을 끊고 나간다.
@export var swing_move_mult: float = 0.35
@export var swing_slow_time: float = 0.2
## 타별 모으기(초): 휘두르기 전 첫 칸에서 잠깐 멈춘다 (3타 앞).
@export var step_windup_pause: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.08])
## 타별 판정 모양: 부채꼴 각도·사거리 배율 (3타 = 좁고 길게).
@export var step_arc_mults: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.6])
@export var step_range_mults: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.2])
## 타별 궤적 방향 (1 = 그대로, -1 = 뒤집어 반대쪽에서 베기).
@export var step_trail_flip: PackedFloat32Array = PackedFloat32Array([1.0, -1.0, 1.0])
## 타별 전진(px, 손 평타만). 앞 적 몸 안으로는 들어가지 않고, 적 예고가 영웅을 덮고 있으면 생략.
@export var step_in_px: PackedFloat32Array = PackedFloat32Array([10.0, 14.0, 26.0])
@export var step_in_max: float = 30.0
@export var step_in_time: float = 0.1
## 끄면 전진 없음.
@export var step_in_enabled: bool = true
## 마무리(4타) 전진(px, 0 = 없음). 대상 쪽, 같은 제한 (사용자 2026-11-25 "근접 연타에 실제 전진").
@export var finisher_step_in_px: float = 0.0
## 대상이 없을 때 전진 배율 (바라보는 쪽으로 조금만).
@export var step_in_no_target_mult: float = 1.0
## 이동 막대가 치는 쪽과 이 내적보다 반대면 전진하지 않는다 (-2 = 끔).
@export var step_in_against_input: float = -2.0
## 타별 내딛는 그림 (px): 휘두를 때 영웅 그림이 치는 쪽으로 나갔다 돌아온다 (판정·위치는 그대로, 자동 평타에도).
@export var lunge_px: PackedFloat32Array = PackedFloat32Array([14.0, 18.0, 30.0])
## 타별 찌르기 자국 (1 = 초승달 대신 칼끝 쪽 곧은 획, 사용자 9e19cfb "순신 찌르기 잘 안 보여"): 그림·길이(사거리 배율)·폭(px).
@export var step_thrust: PackedFloat32Array = PackedFloat32Array()
@export var thrust_art: Texture2D
@export var thrust_reach: float = 1.15
@export var thrust_width: float = 46.0
## 나가는 시간·돌아오는 시간 (초).
@export var lunge_out: float = 0.07
@export var lunge_back: float = 0.2
## 원거리 연타 (세종): 타별 탄 수·퍼짐(도)·글자 크기 배율. 시트에 throw2·throw3가 있으면 그 동작.
@export var ranged_step_count: PackedFloat32Array = PackedFloat32Array([1.0, 2.0, 1.0])
@export var ranged_step_spread: float = 10.0
@export var ranged_step_scale: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.5])
## 무기 타격음 (B9): 근접이 맞을 때 겹치는 소리, 강타에 더 겹치는 소리 (사운드 뱅크 이름, 비면 없음).
@export var melee_hit_sfx: StringName = &""
@export var heavy_hit_sfx: StringName = &""

@export_group("원거리")
@export var ranged_interval: float = 0.8
@export var ranged_range: float = 480.0
@export var ranged_damage: int = 10
@export var ranged_speed: float = 700.0
@export var ranged_lifetime: float = 0.8
## 원거리 적중 시 넉백 (근접의 절반 정도).
@export var ranged_knockback: float = 0.0
## 비어 있지 않으면 원거리 투사체를 이 글자들로 차례로 그린다 (세종 문자탄).
@export var ranged_glyphs: String = ""

@export_group("원거리 탄 그림")
## 영웅마다 다른 탄 그림 (오른쪽 = 날아가는 방향, assets/vfx/proj_*.png). 비면 먹 획.
@export var proj_art: Texture2D
## 탄 그림 길이·두께(px), 글자 탄 글자 크기(px).
@export var proj_size: Vector2 = Vector2(96, 36)
@export var glyph_px: int = 40
## 뒤 자취 자취 색과 길이(px).
@export var proj_trail_color: Color = Color(0.3, 0.55, 0.9, 0.6)
@export var proj_trail_len: float = 60.0
## 던지는 동작: 쏘기 시작 후 손을 떠나기까지(초)와 손 위치 (앞으로 x px, 위로 y px).
## 음수면 시트의 던지는 동작 맞닿는 프레임 ÷ fps를 CombatFeelData.release_delay_min~max로 (근접 melee_delay와 같은 방식).
@export var release_delay: float = 0.0
## 던질 때 재생할 동작 (시트 이름). 비우면 동작 없이 손에서 나간다.
@export var ranged_anim: StringName = &"attack"
## 던지는 동작을 보여 주는 시간(초). 동작 길이(프레임 수 ÷ fps)에 맞춘다.
@export var ranged_anim_time: float = 0.35
@export var release_offset: Vector2 = Vector2.ZERO
