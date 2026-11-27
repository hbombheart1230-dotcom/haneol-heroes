"""구운 한 동작 시트(<이름>_jump 등)를 기존 영웅 SpriteSheetSet(.tres)에 동작 하나로 합친다.

사용: python tools/bake/merge_sheet_anim.py <영웅> <동작키> <굽기폴더이름>
예:   python tools/bake/merge_sheet_anim.py yi_sun_sin jump_leap yi_sun_sin_jump
      (굽기 폴더가 없으면 뒤에 프레임수 fps를 더 준다: ... 12 12.0)
- assets/sprites/<굽기폴더>/<동작키>.png 를 assets/sprites/<영웅>/ 으로 옮기고
  <영웅>.tres 의 배열(anim_names, textures, frame_counts, fps, loops, strike_frames, tips) 끝에 붙인다.
- 이미 같은 키가 있으면 덮어쓰지 않고 종료한다. 프레임 수·fps는 굽기 .tres에서 읽는다.
"""
import re
import shutil
import sys
from pathlib import Path


def _field(text: str, name: str) -> str:
	m = re.search(r"^%s = (.*)$" % re.escape(name), text, re.M)
	if not m:
		raise SystemExit("필드 없음: " + name)
	return m.group(1)


def _append(text: str, name: str, item: str) -> str:
	"""`name = X(... )` 배열 끝에 item을 덧붙인다 (마지막 닫는 괄호 앞)."""
	line = _field(text, name)
	if line.endswith("])"):
		new = line[:-2] + ", " + item + "])"
	elif line.endswith(")"):
		new = line[:-1] + ", " + item + ")"
	else:
		raise SystemExit("형식 이상: " + name)
	return text.replace("%s = %s" % (name, line), "%s = %s" % (name, new), 1)


def main() -> None:
	hero, key, src = sys.argv[1], sys.argv[2], sys.argv[3]
	root = Path("assets/sprites")
	tres = root / hero / (hero + ".tres")
	src_tres = root / src / (src + ".tres")
	text = tres.read_text(encoding="utf-8")
	if '"%s"' % key in _field(text, "anim_names"):
		raise SystemExit("이미 있음: " + key)
	if src_tres.exists():
		stext = src_tres.read_text(encoding="utf-8")
		names = re.findall(r'"([^"]+)"', _field(stext, "anim_names"))
		i = names.index(key)
		counts = [int(v) for v in _field(stext, "frame_counts")[len("PackedInt32Array("):-1].split(",")]
		fps = [v.strip() for v in _field(stext, "fps")[len("PackedFloat32Array("):-1].split(",")]
		frames, rate = counts[i], fps[i]
		shutil.move(str(root / src / (key + ".png")), str(root / hero / (key + ".png")))
	else:  # 굽기 폴더가 이미 없으면(재합치기) 인자로 받은 프레임 수·fps를 쓴다
		frames, rate = int(sys.argv[4]), sys.argv[5]
	imp = root / src / (key + ".png.import")
	if imp.exists():
		imp.unlink()
	n = len(re.findall(r'id="t\d+"', text))
	rid = "t%d" % n
	ext = '[ext_resource type="Texture2D" path="res://assets/sprites/%s/%s.png" id="%s"]' % (hero, key, rid)
	last = re.findall(r"^\[ext_resource .*$", text, re.M)[-1]
	text = text.replace(last, last + "\n" + ext, 1)
	text = _append(text, "anim_names", '"%s"' % key)
	text = _append(text, "textures", 'ExtResource("%s")' % rid)
	text = _append(text, "frame_counts", str(frames))
	text = _append(text, "fps", rate)
	text = _append(text, "loops", "false")
	text = _append(text, "strike_frames", "-1")
	text = _append(text, "tips", "PackedVector2Array()")
	tres.write_text(text, encoding="utf-8")
	print("합침:", hero, key, frames, "프레임", rate, "fps")


main()
