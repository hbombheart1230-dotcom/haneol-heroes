class_name CreditsData
extends Resource
## "만든 이들" 화면에 쓰는 출처·저작권 문구 (data/credits/credits.tres). 자산이 늘면 해당 목록에 한 줄을 더한다.
## 기관명·저작물명·영문 허가문은 원문 그대로 적는다. Godot 엔진과 엔진이 끼고 오는 제3자 고지는
## 엔진에서 직접 읽어 화면 끝에 붙인다 (CreditsScreen, Engine.get_license_text / get_copyright_info / get_license_info).

const PATH := "res://data/credits/credits.tres"

## 출처 표시 의무 (공공누리 등). 한 항목 = 한 줄 이상 ("\n"으로 줄 나눔).
@export var required: PackedStringArray = []
## 함께 넣는 소프트웨어 라이선스 전문 (MIT 등): 항목마다 "이름\n저작권 줄\n\n허가문 전문".
@export var licenses: PackedStringArray = []
## 감사 표기 (CC0·퍼블릭 도메인처럼 의무는 없음).
@export var thanks: PackedStringArray = []


static func load_default() -> CreditsData:
	return load(PATH) as CreditsData
