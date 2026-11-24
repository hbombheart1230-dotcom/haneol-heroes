class_name HitReactionData
extends Resource
## 맞는 반응 수치 (docs/research/game_feel_benchmark.md R1·R2·R3·B1·C2).
## 적: 구워 둔 맞는 동작·잡몹 경직·그림만 움찔·흰 번쩍임. 영웅: 붉은 번쩍임·무적 깜빡임·화면 가장자리·숨 돌릴 틈.

@export_group("적 맞는 동작")
## 구운 "hit" 동작을 보여 주는 시간(초, 개별 멈춤이 끝난 뒤부터). 3프레임 12fps = 0.25초.
@export var hit_anim_time: float = 0.25
## 정예는 한 번에 최대체력의 이 비율 이상을 잃을 때만 맞는 동작 (Diablo II 1/16 규칙). 보스는 boss_flinch일 때만.
@export var elite_flinch_hp_frac: float = 0.0625
@export var boss_flinch: bool = false

@export_group("잡몹 경직")
## 잡몹(정예·보스 아님)이 맞으면 이 시간 동안 쫓아오지 않고 넉백만 받는다 (Vampire Survivors 120ms).
@export var stagger_time: float = 0.15
## 경직이 풀린 뒤 stagger_guard초 동안은 맞아도 다시 경직되지 않는다 (피해·움찔·넉백은 그대로).
## 넓은 범위로 계속 때려도 적이 다가오고 칠 틈이 생기게 (사임당 붓질·세종 연사에 묶여 아무것도 못 하던 것).
## 한 번에 이어지는 경직도 stagger_chain_max초까지. 0이면 끔.
@export var stagger_chain_max: float = 0.9
@export var stagger_guard: float = 0.6
## 한 번 휘두름에 여럿이 맞으면 경직이 짧아진다: 경직 × 1 / (1 + (맞은 수 − 1) × crowd_stagger_falloff), 최소 crowd_stagger_min배.
## 넓게 베는 영웅(사임당 230px·110°/원형)이 떼 전체를 늘 묶지 않게 — 한 놈을 노린 연타는 그대로. falloff 0이면 끔.
@export var crowd_stagger_falloff: float = 0.4
@export var crowd_stagger_min: float = 0.3

@export_group("움찔 (그림만, 판정은 그대로)")
## 발 기준 눌림 (가로, 세로)과 원래대로 돌아오는 시간(초).
@export var squash: Vector2 = Vector2(1.12, 0.88)
@export var squash_time: float = 0.08
## 맞은 방향으로 젖혀지는 거리(px)·기울기(도)와 돌아오는 시간(초).
@export var lean_px: float = 8.0
@export var tilt_deg: float = 6.0
@export var lean_time: float = 0.14
## 정예·보스 움찔 크기 배율 (무거워 보이게).
@export var heavy_flinch_scale: float = 0.4

@export_group("흰 번쩍임 (셰이더)")
## 처음 아주 밝은 구간(CombatFeelData.flash_peak_time)에 흰색을 섞는 비율, 그 뒤 시작 비율 (0으로 줄어듦).
@export var flash_white: float = 0.85
@export var flash_white_tail: float = 0.45
## 번쩍임 횟수 (GDQuest juicy-attack: 0.15초에 2번). 2 이상이면 CombatFeelData.flash_time을 켜짐·꺼짐 칸으로
## 고르게 나눠 켜진 칸마다 flash_white로 (1이면 예전처럼 한 번 밝았다 줄어듦).
@export var flash_blinks: int = 2
## 맞은 순간 몸 색 (사용자가 고를 비교안): 0 = 흰 번쩍임 (flash_blinks), 1 = 붉은 실루엣 한 칸 (하데스식),
## 2 = 먹빛 실루엣 + 인주색 테두리 한 칸 (수묵 톤), 3 = 흰 번쩍임 + 인주색 테두리 (flash_blinks),
## 4 = 한지색 실루엣 + 먹 테두리 한 칸 (기본: 사용자 선택, 네 무대 바닥에서 확인). 1·2·4는 flash_frame_time초 동안만 꽉 차게.
@export_enum("white", "red", "ink_seal", "white_seal", "hanji_ink") var hit_flash_style: int = 4
@export var flash_frame_time: float = 0.035
@export var red_silhouette: Color = Color(0.86, 0.08, 0.05)
@export var ink_silhouette: Color = Color(0.07, 0.05, 0.05)
@export var seal_rim: Color = Color(0.82, 0.16, 0.1, 1.0)
@export var hanji_silhouette: Color = Color(0.95, 0.91, 0.82)
@export var ink_rim: Color = Color(0.07, 0.05, 0.05, 1.0)


## 맞은 순간 몸 색 (셰이더 flash_color). 배열을 만들지 않게 색 하나씩.
func flash_body() -> Color:
	match hit_flash_style:
		1:
			return red_silhouette
		2:
			return ink_silhouette
		4:
			return hanji_silhouette
	return Color.WHITE


## 맞은 순간 테두리 색 (셰이더 flash_rim, 알파 0 = 그대로).
func flash_rim() -> Color:
	match hit_flash_style:
		2, 3:
			return seal_rim
		4:
			return ink_rim
	return Color(0, 0, 0, 0)


## 흰 번쩍임처럼 깜빡이는 방식인지 (0·3), 아니면 한 칸 꽉 찬 실루엣인지 (1·2·4).
func blinks() -> bool:
	return hit_flash_style == 0 or hit_flash_style == 3

@export_group("영웅 피격")
## 맞은 순간 붉은 번쩍임 시간(초)과 색 (스프라이트 modulate).
@export var hero_flash_time: float = 0.1
@export var hero_flash_color: Color = Color(1.5, 0.45, 0.4)
## 맞는 동작을 보여 주는 시간(초).
@export var hero_hit_anim_time: float = 0.25
## 무적 동안 깜빡임: 초당 켜고 끄기 횟수와 꺼질 때 투명도.
@export var blink_hz: float = 12.0
@export var blink_alpha: float = 0.4
## 화면 가장자리 붉은 빛: 시간(초)·진하기·색.
@export var vignette_time: float = 0.35
@export var vignette_alpha: float = 0.55
@export var vignette_color: Color = Color(0.6, 0.02, 0.02)

@export_group("숨 돌릴 틈")
## 맞으면 이 반경(px, 영웅 중심) 안 적을 바깥으로 민다. 가까울수록 세게 (가장자리에서 절반).
@export var breathe_radius: float = 90.0
@export var breathe_impulse: float = 240.0
## 피격 무적 = 영웅 hurt_invuln_time × (min_ratio ~ 1). 최대체력의 full_hp_frac 이상 잃으면 전체 (Brotato식).
@export var invuln_min_ratio: float = 0.67
@export var invuln_full_hp_frac: float = 0.15
