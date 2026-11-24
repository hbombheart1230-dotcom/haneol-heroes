class_name WaveBannerData
extends Resource
## 물결이 시작될 때 화면 가운데에 크게 띄우는 알림 ("첫째 물결"): 글과 보이는 시간·자리 (data/ui/wave_banner.tres).
## 우두머리 물결에는 이 알림을 쓰지 않는다 (우두머리 등장 띠가 그 몫).

const PATH := "res://data/ui/wave_banner.tres"
static var _cached: WaveBannerData

@export_group("글")
## 우리말 서수 (물결 번호 순). 모자라면 "N번째 물결".
@export var ordinals: PackedStringArray = PackedStringArray(["첫째", "둘째", "셋째", "넷째", "다섯째", "여섯째", "일곱째", "여덟째", "아홉째", "열째"])
@export var title_format: String = "%s 물결"
@export var fallback_format: String = "%d번째 물결"
## 중간 우두머리가 나오는 물결에 붙는 줄.
@export var elite_note: String = "중간 우두머리"
@export_group("보이는 모양")
## 보이는 시간(초): 앞 fade_in 동안 나타나고 끝 fade_out 동안 흐려진다.
@export var show_time: float = 1.5
@export var fade_in: float = 0.15
@export var fade_out: float = 0.4
## 자리: 화면 높이의 비율 (무대 시작 문구보다 조금 아래), 띠 높이, 글자 크기.
@export var y_ratio: float = 0.36
@export var band_height: float = 150.0
@export var title_size: int = 76
@export var note_size: int = 26


@export_group("중간 우두머리 무리 (우두머리 등장 띠·체력 띠)")
## 한꺼번에 나온 중간 우두머리의 이름을 모으는 시간(초): 등장 띠가 뜬 뒤 이 안에 나온 이웃도 같은 띠에 한 줄씩 적는다.
@export var group_collect_time: float = 0.8
## 이름이 둘 이상이면 한 줄에 하나씩: 글자 크기, 줄 간격, 양쪽 여백(px; 긴 이름은 이 안에 들게 줄인다).
@export var group_name_px: int = 60
@export var group_line_gap: float = 72.0
@export var group_side_margin: float = 60.0
## 위쪽 체력 띠 이름: 같이 나온 이웃이 더 있으면 붙는 말 ("이름 외 둘" 대신 숫자로).
@export var more_format: String = "%s 외 %d"


static func default() -> WaveBannerData:
	if _cached == null:
		_cached = load(PATH) as WaveBannerData
		if _cached == null:
			_cached = WaveBannerData.new()
	return _cached


## 물결 번호(0부터)의 알림 글.
func title_for(index: int) -> String:
	if index >= 0 and index < ordinals.size():
		return title_format % ordinals[index]
	return fallback_format % (index + 1)
