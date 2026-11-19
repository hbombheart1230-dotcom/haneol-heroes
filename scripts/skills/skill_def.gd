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


## 발동. charge는 0~1 (충전 기술에만 의미).
## 반환: 진행 상태. 즉시 끝나는 기술은 SkillRun.instant(hits).
func cast(_ctx: SkillContext, _charge: float) -> SkillRun:
	return SkillRun.instant(0)
