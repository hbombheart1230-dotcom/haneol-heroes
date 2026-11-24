"""python -m unittest tools/vfx/test_ink_tone.py"""
import unittest

import numpy as np
from PIL import Image

from tools.vfx import ink_tone as it


class InkToneTest(unittest.TestCase):
    def test_sat_scale_only_lowers_vivid_art(self):
        self.assertEqual(it.sat_scale(0.2), 1.0)
        self.assertAlmostEqual(it.sat_scale(0.72), 0.5)

    def test_tone_keeps_alpha_and_mutes_colour(self):
        a = np.zeros((32, 32, 4), dtype=np.uint8)
        a[8:24, 8:24] = (20, 90, 255, 255)
        out = np.asarray(it.tone(Image.fromarray(a, "RGBA"))).astype(np.float32) / 255.0
        self.assertTrue(np.array_equal(np.asarray(it.tone(Image.fromarray(a, "RGBA")))[..., 3], a[..., 3]))
        before = it.mean_saturation(a[..., :3].astype(np.float32) / 255.0, a[..., 3] / 255.0)
        centre = out[14:18, 14:18, :3]
        mx = centre.max(-1)
        after = float(((mx - centre.min(-1)) / mx).mean())
        self.assertLess(after, before)
        self.assertGreater(after, 0.15)  # 색이 남아 있다 (영웅별 기술 색 구별)

    def test_white_highlight_goes_to_paper(self):
        a = np.full((16, 16, 4), 255, dtype=np.uint8)
        out = np.asarray(it.tone(Image.fromarray(a, "RGBA")))[8, 8]
        self.assertLess(int(out[2]), int(out[0]))  # 순백 → 한지색 (파랑이 빠짐)


if __name__ == "__main__":
    unittest.main()
