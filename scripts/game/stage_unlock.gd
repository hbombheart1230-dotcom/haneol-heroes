class_name StageUnlock
extends RefCounted
## 무대 차례대로 열기: 첫 무대는 늘 열림, 다음 무대는 앞 무대를 이기면 열린다.
## 시험판(디버그 빌드나 "unlock_all" 기능 태그를 단 APK)은 전부 열림.


static func flags(stages: Array[StageTheme], cleared: PackedStringArray, all: bool) -> Array[bool]:
	var out: Array[bool] = []
	for i in stages.size():
		out.append(all or i == 0 or (stages[i - 1] != null and cleared.has(String(stages[i - 1].id))))
	return out


## 시험판인지: 엔진이 디버그 빌드이거나, 내보내기 설정에 "unlock_all" 기능 태그가 있을 때.
static func test_build() -> bool:
	return OS.is_debug_build() or OS.has_feature("unlock_all")
