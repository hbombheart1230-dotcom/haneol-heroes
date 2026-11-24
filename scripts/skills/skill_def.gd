class_name SkillDef
extends Resource
## 기술 하나의 데이터 + 발동 로직 (영웅별 기술은 이 클래스를 상속).
## 수치는 .tres에서 조정한다. 런타임 상태(쿨타임 등)는 여기 두지 않는다 (공유 리소스).

@export var id: StringName = &""
@export var display_name: String = ""
@export var cooldown: float = 4.0
## 스킬 버튼에 표시할 색.
@export var color: Color = Color(0.2, 0.5, 0.9)
## 전투 이펙트 색 (버튼 색과 별개).
@export var fx_color: Color = Color(0.4, 0.8, 1.0)
## 스킬 아이콘 (없으면 색 원으로 표시).
@export var icon: Texture2D
## 발동 소리 (SoundBank 종류). 비우면 칸에 따라 기본 (베기·반격).
@export var sfx: StringName = &""
## 기술 성질 (무대 장치 반응: 만주 들불은 thunder·meteor가 붙이고 water가 끈다). 비우면 반응 없음.
@export var element: StringName = &""
@export_group("시전 동작")
## 영웅 시트의 시전 동작 이름 (비거나 시트에 없으면 연타 1타 "attack"). 피해는 지금처럼 누르는 순간 나가므로,
## 동작은 맞닿는 칸(시트 strike_frames) cast_lead초 앞에서 시작해 칼이 닿는 그림이 피해와 거의 같이 보인다.
@export var cast_anim: StringName = &""
## 맞닿는 칸 앞에서 보여 줄 시간(초). 음수면 첫 칸부터 (휘감는 기술: 도는 동안이 곧 베기).
@export var cast_lead: float = 0.06
## 재생 속도 배율.
@export var cast_speed: float = 1.0
## 충전 기술만: 모으는 동안 시전 동작 첫 칸(모으는 자세)을 붙잡는다 (서 있을 때).
@export var charge_pose: bool = true
@export_group("조준 보정")
## 방향 기술만: 바라보는 방향 ± 이 각도의 절반 안에 적이 있으면 그쪽으로 (0이면 끔). 사거리(px),
## 부채꼴 안에 없을 때 가장 가까운 적 쪽으로 돌릴지.
@export var aim_assist_deg: float = 0.0
@export var aim_assist_range: float = 600.0
@export var aim_fallback_nearest: bool = false
## 충전 기술만: 모으는 동안 이동 손가락(조이스틱)으로 잡은 방향으로 곧게 (조준 보정·유도 없음, ChargeAim).
## 방향을 안 잡으면 모으기 시작할 때 바라보던 방향.
@export var charge_aim: bool = false
## charge_aim과 함께: 끌지 않으면 예전 자동 (조준 보정·주변 자동·영웅 자리), 끌면 그 방향·자리가 중심 (낙뢰·성좌진·화폭).
@export var charge_aim_auto: bool = false
## 충전 기술만: 모은 시간 비례 곡선·마디 (ChargeScaling, 공통). 기술이 자기 최소·최대 값을 이 곡선으로 잇는다.
@export var charge_scaling: ChargeScaling
@export_group("이펙트")
## 발동 순간 영웅 자리에서 (바라보는 방향으로) 터지는 이펙트.
@export var vfx_cast: SkillVfxData
## 적이 맞을 때마다 그 자리에서 터지는 이펙트.
@export var vfx_hit: SkillVfxData
## 기술이 내리꽂히는 자리(범위 중심·벼락·별똥별)에서 터지는 이펙트. 번개 줄기 설정도 여기.
@export var vfx_impact: SkillVfxData
## 강화 단계 (이번 판 성장으로 오른다: 보통 +1, 큰 변형 +UpgradeDef.vfx_level_gain). 클수록 이펙트가 크고 화려하다.
@export var vfx_level: int = 0
## 켜면 강화 단계(SkillGrowthData)에 따라 판정·그림이 같이 커진다 (기본은 작게, 큰 강화/만렙은 크고 화려하게).
@export var growth: bool = false
@export_group("연출 · 컷인과 소리 층")
## true면 발동할 때 먹 띠 + 영웅 그림 + 기술 이름 컷인 (큰 기술: 반격 계열). 간격 상한은 SkillStageFeel.
@export var cutin: bool = false
## 발동 순간 더 겹쳐 울리는 소리 (국악기 등, SoundBank 종류).
@export var sfx_layers: Array[StringName] = []
## 내리꽂히는 순간(SkillContext.impact) 울리는 소리.
@export var impact_sfx: StringName = &""
## 이 기술이 적을 맞힐 때마다 더 겹치는 소리 (영웅 공통 재질음 위에).
@export var hit_layer_sfx: StringName = &""


## 발동. charge는 0~1 (충전 기술에만 의미).
## 반환: 진행 상태. 즉시 끝나는 기술은 SkillRun.instant(hits).
## 조준 보정된 방향 (aim_assist_deg 0이면 바라보는 방향).
func aim(ctx: SkillContext) -> Vector2:
	if charge_aim and (ctx.aim_steered or not charge_aim_auto):  # 잡은 방향 그대로 (보정 없음)
		return ctx.aim_dir.normalized() if ctx.aim_dir.length_squared() > 0.0001 else ctx.player.facing
	return Targeting.assist_dir(ctx.enemies(), ctx.player.global_position, ctx.player.facing,
		aim_assist_deg, aim_assist_range, aim_fallback_nearest)


func cast(_ctx: SkillContext, _charge: float) -> SkillRun:
	return SkillRun.instant(0)


## 시전 연출(vfx_cast)이 터지는 자리. 기본은 영웅 몸, 적 자리에 펼쳐지는 기술(세종 정음진)은 그 자리.
func cast_point(ctx: SkillContext) -> Vector2:
	return ctx.player.global_position


## 충전 조준 길 표시 (charge_aim 기술): 충전 c에서 닿는 거리(px)와 맞는 폭(px). 0이면 길을 그리지 않는다.
func aim_length(_c: float) -> float:
	return 0.0


func aim_width(_c: float) -> float:
	return 0.0


## 충전 조준 표시를 기술 범위 모양으로 (영웅 발밑 기준, dir = 잡은 방향). 그렸으면 true, 아니면 길 띠 (aim_length·aim_width).
## 이 기술은 성장 배율이 들어간 사본 (SkillGrowthData.scaled_def)이라 그린 모양 = 판정.
func draw_aim(_canvas: CanvasItem, _c: float, _dir: Vector2, _d: ChargeMarkerData) -> bool:
	return false
