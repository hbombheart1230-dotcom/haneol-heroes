"""python -m unittest tools/vfx/test_black_to_vfx.py"""
import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import black_to_vfx as b  # noqa: E402


class BlackToVfxTest(unittest.TestCase):
    def test_black_is_clear_bright_is_solid(self):
        rgb = np.array([[[0, 0, 0], [0.05, 0.02, 0.0], [1.0, 0.1, 0.0], [0.2, 0.5, 1.0]]], np.float32)
        a = b.key_black(rgb)
        self.assertEqual(a[0, 0, 3], 0.0)
        self.assertEqual(a[0, 1, 3], 0.0)
        self.assertEqual(a[0, 2, 3], 1.0)
        self.assertEqual(a[0, 3, 3], 1.0)
        np.testing.assert_allclose(a[0, 2, :3], rgb[0, 2])

    def test_dim_edge_keeps_hue(self):
        rgb = np.array([[[0.1, 0.2, 0.3]]], np.float32)  # 어두운 파랑 가장자리: 반투명, 색은 밝혀서
        a = b.key_black(rgb)
        self.assertGreater(a[0, 0, 3], 0.0)
        self.assertLess(a[0, 0, 3], 1.0)
        self.assertGreater(a[0, 0, 2], rgb[0, 0, 2])
        self.assertGreater(a[0, 0, 2], a[0, 0, 0])

    def test_trim_square_centres_and_sizes(self):
        rgba = np.zeros((100, 200, 4), np.float32)
        rgba[40:60, 20:60] = [1, 1, 1, 1]
        img = b.trim_square(rgba, 32)
        self.assertEqual(img.size, (32, 32))
        al = np.asarray(img)[..., 3]
        ys, xs = np.nonzero(al > 128)
        self.assertAlmostEqual((xs.min() + xs.max()) / 2, 15.5, delta=1.5)
        self.assertAlmostEqual((ys.min() + ys.max()) / 2, 15.5, delta=1.5)


if __name__ == "__main__":
    unittest.main()
