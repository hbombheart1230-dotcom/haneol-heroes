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
@export_group("조준 보정")
## 방향 기술만: 바라보는 방향 ± 이 각도의 절반 안에 적이 있으면 그쪽으로 (0이면 끔). 사거리(px),
## 부채꼴 안에 없을 때 가장 가까운 적 쪽으로 돌릴지.
@export var aim_assist_deg: float = 0.0
@export var aim_assist_range: float = 600.0
@export var aim_fallback_nearest: bool = false
@export_group("이펙트")
## 발동 순간 영웅 자리에서 (바라보는 방향으로) 터지는 이펙트.
@export var vfx_cast: SkillVfxData
## 적이 맞을 때마다 그 자리에서 터지는 이펙트.
@export var vfx_hit: SkillVfxData
## 기술이 내리꽂히는 자리(범위 중심·벼락·별똥별)에서 터지는 이펙트. 번개 줄기 설정도 여기.
@export var vfx_impact: SkillVfxData
## 강화 단계 (이번 판 성장으로 오른다: 보통 +1, 큰 변형 +UpgradeDef.vfx_level_gain). 클수록 이펙트가 크고 화려하다.
@export var vfx_level: int = 0
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
	return Targeting.assist_dir(ctx.enemies(), ctx.player.global_position, ctx.player.facing,
		aim_assist_deg, aim_assist_range, aim_fallback_nearest)


func cast(_ctx: SkillContext, _charge: float) -> SkillRun:
	return SkillRun.instant(0)
