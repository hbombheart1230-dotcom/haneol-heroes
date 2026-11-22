"""python -m unittest tools/vfx/test_make_trail_band.py"""
import unittest

from tools.vfx import make_trail_band as mt


class TrailBandTest(unittest.TestCase):
    def test_outer_edge_solid_inner_edge_breaks_up(self):
        a = mt.band()[..., 3] / 255.0
        self.assertGreater(a[:4].mean(), 0.9)  # 칼끝 쪽은 꽉 차고
        self.assertLess(a[-6:].mean(), 0.3)  # 안쪽 끝은 거의 사라지고
        self.assertGreater(a[30:40].std(), 0.05)  # 가운데는 마른 붓 결이 보인다

    def test_same_seed_same_image(self):
        self.assertTrue((mt.band() == mt.band()).all())


if __name__ == "__main__":
    unittest.main()
