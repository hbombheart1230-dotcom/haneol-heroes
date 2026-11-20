class_name UpgradeDef
extends Resource
## 레벨업 때 고르는 성장 하나 (기술 변형·능력치). 수치 변화는 mods에 데이터로 적는다.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## 인장에 그릴 아이콘 (없으면 color 원 + 제목 첫 글자).
@export var icon: Texture2D
@export var color: Color = Color(0.3, 0.5, 0.8)
## 한 판에 최대 몇 번까지 고를 수 있는지.
@export var max_stacks: int = 3
## 선택지에 나올 가중치.
@export var weight: float = 1.0
@export var mods: Array[StatMod] = []
## 이 성장이 건드린 기술의 이펙트 강화 단계를 얼마나 올리는지 (큰 변형은 크게).
@export var vfx_level_gain: int = 1
