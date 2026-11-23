class_name CampaignSlot
extends Resource
## 영웅 전장 목록의 한 칸 (HeroCampaign). id로 무대(StageTheme)를 찾고, 아직 없는 무대면 "곧 열림" 자리.
## 이름·연도는 무대가 있으면 무대 것을 쓰고, 없을 때만 여기 값 (비어 있어도 화면이 성립한다).

@export var id: StringName = &""
@export var title: String = ""
@export var year_label: String = ""
