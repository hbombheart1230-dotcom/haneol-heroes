class_name ImpactFeelData
extends Resource
## 던파식 타격감 수치 (docs/research/dnf_benchmark.md): 반격·뒤치기, 잡몹 끊김, 넘어짐, 영웅 멈춤(역경직),
## 3타째 강타, 피해 숫자 모양, 마무리 확대·번쩍임. CombatFeelData.impact에 붙는다.

@export_group("반격 · 뒤치기 (B2·B5)")
## 적이 공격 예고 중일 때 맞히면 피해 배율과 글자.
@export var counter_mult: float = 1.5
@export var counter_label: String = "반격!"
@export var counter_color: Color = Color(0.86, 0.2, 0.12)
## 적 등 뒤 back_arc_deg 안에서 맞히면 피해 배율과 글자 (적이 보는 방향 = 겨눈 방향 또는 걷는 방향).
@export var back_mult: float = 1.25
@export var back_arc_deg: float = 120.0
@export var back_label: String = "뒤치기!"
@export var back_color: Color = Color(0.3, 0.42, 0.85)
## 반격·뒤치기가 겹쳐도 이 배율을 넘지 않는다 (1.5 × 1.25 = 1.875 → 1.75, 한 방에 판이 기울지 않게).
@export var bonus_mult_cap: float = 1.75
## 글자는 화면 전체에서 이 간격(초)보다 자주 띄우지 않는다 (보스 예고 중 연타로 글자가 쌓이지 않게).
@export var label_min_gap: float = 0.3

@export_group("잡몹 끊김 (B1)")
## 슈퍼아머 없는 잡몹은 예고 중 맞으면 예고가 끊기고 이만큼 경직(초).
@export var interrupt_stagger: float = 0.28
## 끊긴 뒤 다시 예고하기까지 최소(초).
@export var interrupt_cooldown: float = 0.6
## 한 번 끊긴 적의 다음 예고는 이 시간(초) 동안 끊기지 않는다 (계속 묶여 위협이 사라지지 않게).
@export var interrupt_rearm: float = 1.5
## 맞아서 공격 대기를 처음부터 다시 셀 때(EnemyData.hit_resets_attack)의 상한: 마지막 공격(또는 등장) 뒤
## cooldown × 이 값 안에는 다시 준비된다. 연타로 붙잡아도 공격이 영영 안 나오지 않게 (실측: open_data_benchmark.md).
@export var reset_max_gap_mult: float = 1.3

@export_group("넘어짐 (B8)")
## 3타째 강타에 맞은 잡몹: 떠올랐다 누웠다 일어나는 시간(초). 그동안 움직이지도 치지도 않는다.
@export var down_time: float = 1.0
## 떠오르는 높이(px)와 그 시간(초, down_time 앞부분).
@export var down_lift_px: float = 28.0
@export var down_lift_time: float = 0.3
## 넘어짐 동작이 없는 시트: 맞는 동작 마지막 칸을 이만큼 눕힌다(도).
@export var down_tilt_deg: float = 75.0
## 일어난 뒤 이 시간(초) 동안은 다시 넘어지지 않는다.
@export var down_rearm: float = 2.0

@export_group("영웅 멈춤 · 3타째 (B3·B4)")
## 근접이 맞으면 영웅 동작도 멈춘다 (역경직): base + 맞은 수 × per, 최대 max. 3타째는 heavy.
@export var hero_hitstop_base: float = 0.04
@export var hero_hitstop_per: float = 0.01
@export var hero_hitstop_max: float = 0.08
@export var hero_hitstop_heavy: float = 0.1
## 3타째: 맞은 적 개별 멈춤(초), 화면 흔들림, 화면 밀림(px).
@export var heavy_freeze: float = 0.1
@export var heavy_trauma: float = 0.3
@export var heavy_kick_px: float = 8.0
## 3타째 흔들림은 지금 흔들림(trauma)이 이 값보다 크면 더하지 않는다 (기술·처치 흔들림과 겹쳐 과해지지 않게).
@export var trauma_cap: float = 0.55
## 3타 강타의 늦은 감속 (하데스 SwordWeapon3 HitSimSlowParameters): 닿고 delay초(실제) 뒤 게임 속도 scale,
## hold초 머문 뒤 back초에 걸쳐 돌아온다. hold 0이면 끔. 맞은 적 멈춤·영웅 멈춤과 함께 걸린다.
@export var heavy_slow_delay: float = 0.05
@export var heavy_slow_scale: float = 0.1
@export var heavy_slow_hold: float = 0.05
@export var heavy_slow_back: float = 0.07
## 3타째 국악 덧소리 (꽹과리 한 타, 파일이 없으면 조용히 건너뜀)와 최소 간격(초).
@export var heavy_gugak: StringName = &"gugak_big"
@export var heavy_gugak_gap: float = 0.5

@export_group("피해 숫자 (B6)")
@export var number_time: float = 0.9
@export var number_rise: float = 60.0
@export var number_size: int = 26
@export var number_size_big: int = 42
@export var number_size_heavy: int = 50
@export var label_size: int = 30
@export var number_outline: int = 6
@export var number_color: Color = Color(0.96, 0.93, 0.86)
## 숫자 외곽선 색 (한지색 숫자에 먹 테두리: 어두워진 바닥에서 읽히게).
@export var number_outline_color: Color = Color(0.1, 0.08, 0.07)
@export var number_color_big: Color = Color(0.72, 0.13, 0.1)
@export var number_color_heavy: Color = Color(0.9, 0.55, 0.08)
## 화면에 동시에 떠 있는 숫자·글자 최대 (떼거리에서 숫자가 화면을 덮지 않게, 넘으면 새 숫자는 생략).
@export var max_numbers: int = 18

@export_group("마무리 일격 (B7)")
## 정예·보스 처치: 카메라 확대 배율, 들어가는 시간·돌아오는 시간(실제 초), 화면 번쩍임 세기·시간·색.
## 한얼: 흰 섬광 대신 한지색 먹 번짐 (수묵 톤, 눈부시지 않게).
@export var finisher_zoom: float = 1.15
@export var finisher_zoom_in: float = 0.08
@export var finisher_zoom_out: float = 0.4
@export var finisher_flash_alpha: float = 0.35
@export var finisher_flash_time: float = 0.15
@export var finisher_flash_color: Color = Color(0.92, 0.88, 0.79)


## 영웅 멈춤 시간 (맞은 수 hits, 3타째면 heavy). 안 맞았으면 0.
func hero_hitstop(hits: int, heavy: bool) -> float:
	if hits <= 0:
		return 0.0
	if heavy:
		return hero_hitstop_heavy
	return minf(hero_hitstop_base + hero_hitstop_per * (hits - 1), hero_hitstop_max)
