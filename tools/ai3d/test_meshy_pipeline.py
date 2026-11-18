"""Meshy 파이프라인 오프라인 테스트 (네트워크·크레딧 사용 없음).

  python -m unittest tools/ai3d/test_meshy_pipeline.py
"""
import argparse
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshy_api as api  # noqa: E402
import meshy_pipeline as mp  # noqa: E402

LIB = [
    {"action_id": 4, "name": "Attack", "key": "attack"},
    {"action_id": 11, "name": "Idle_3", "key": "idle_3"},
    {"action_id": 14, "name": "Running", "key": "running"},
    {"action_id": 20, "name": "Dodge_Roll", "key": "dodge_roll"},
    {"action_id": 30, "name": "Hit_Reaction", "key": "hit_reaction"},
    {"action_id": 40, "name": "Dead", "key": "death"},
]
HERO_TRES = """[gd_resource type="Resource" script_class="HeroData" format=3]

[ext_resource type="Resource" uid="uid://abc" path="res://assets/sprites/knight/knight.tres" id="8_sheet"]

[resource]
sprite_sheet = ExtResource("8_sheet")
"""


def fake_library(search: str = "", category: str = "") -> list:
    s = search.lower()
    return [e for e in LIB if s in e["name"].lower() or s in e["key"]]


class FakeMeshy:
    def __init__(self):
        self.created = []

    def create(self, kind, body):
        self.created.append((kind, body))
        return f"{kind}-task"

    def wait(self, kind, task_id, **_):
        return {
            "image-to-3d": {"model_urls": {"glb": "https://x/model.glb"}},
            "rigging": {"result": {"rigged_character_glb_url": "https://x/rigged.glb"}},
            "animations": {"result": {"animation_glb_url": "https://x/anim.glb"}},
        }[kind]


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.tmp, "data/heroes"))
        os.makedirs(os.path.join(self.tmp, "assets/concept"))
        with open(os.path.join(self.tmp, "data/heroes/h.tres"), "w") as f:
            f.write(HERO_TRES)
        with open(os.path.join(self.tmp, "assets/concept/front.png"), "wb") as f:
            f.write(b"\x89PNG fake")
        with open(os.path.join(mp.ROOT, "tools/ai3d/heroes/yi_sun_sin.json"), encoding="utf-8") as f:
            self.cfg = json.load(f)
        self.cfg.update({"name": "hero_t", "image": "assets/concept/front.png", "hero_data": "data/heroes/h.tres"})
        self.root = mock.patch.object(mp, "ROOT", self.tmp)
        self.root.start()
        self.lib = mock.patch.object(api, "library", side_effect=fake_library)
        self.lib.start()

    def tearDown(self):
        mock.patch.stopall()
        shutil.rmtree(self.tmp)

    def args(self, **kw):
        base = {"yes": True, "restart": None, "no_bake": True, "godot": ""}
        base.update(kw)
        return argparse.Namespace(**base)

    def test_resolve_actions_by_id_and_search(self):
        picked = {a["key"]: a["action_id"] for a in mp.resolve_actions(self.cfg)}
        self.assertEqual(picked, {"idle": 11, "run": 14, "dash": 20, "attack": 4, "hit": 30, "death": 40})

    def test_missing_action_is_an_error(self):
        self.cfg["anims"] = [{"key": "x", "search": "no_such_move"}]
        with self.assertRaises(api.MeshyError):
            mp.resolve_actions(self.cfg)

    def test_run_refuses_paid_work_without_yes(self):
        with self.assertRaises(SystemExit):
            mp.run(self.cfg, self.args(yes=False))

    def test_run_chains_tasks_saves_state_and_bake_job(self):
        fake = FakeMeshy()
        with mock.patch.object(api, "create", fake.create), mock.patch.object(api, "wait", fake.wait), \
                mock.patch.object(api, "download") as dl:
            mp.run(self.cfg, self.args())
        kinds = [k for k, _ in fake.created]
        self.assertEqual(kinds, ["image-to-3d", "rigging", "animations"])
        self.assertTrue(fake.created[0][1]["image_url"].startswith("data:image/png;base64,"))
        self.assertEqual(fake.created[1][1]["input_task_id"], "image-to-3d-task")
        self.assertEqual(fake.created[2][1]["rig_task_id"], "rigging-task")
        self.assertEqual(fake.created[2][1]["action_ids"], [11, 14, 20, 4, 30, 40])
        self.assertEqual(dl.call_count, 3)
        job = json.load(open(os.path.join(self.tmp, "tools/bake/jobs/hero_t.json"), encoding="utf-8"))
        self.assertEqual(job["model"], "res://assets/models/meshy/hero_t/animated.glb")
        self.assertEqual([a["src"] for a in job["anims"]][:2], ["Idle_3", "Running"])
        # 다시 실행해도 유료 작업을 다시 요청하지 않는다
        fake2 = FakeMeshy()
        with mock.patch.object(api, "create", fake2.create), mock.patch.object(api, "wait", fake2.wait), \
                mock.patch.object(api, "download"):
            mp.run(self.cfg, self.args(yes=False))
        self.assertEqual(fake2.created, [])

    def test_restart_from_anim_only_redoes_animations(self):
        fake = FakeMeshy()
        with mock.patch.object(api, "create", fake.create), mock.patch.object(api, "wait", fake.wait), \
                mock.patch.object(api, "download"):
            mp.run(self.cfg, self.args())
            fake.created.clear()
            mp.run(self.cfg, self.args(restart="anim"))
        self.assertEqual([k for k, _ in fake.created], ["animations"])

    def test_apply_to_hero_swaps_sheet_path(self):
        mp.apply_to_hero(self.cfg)
        text = open(os.path.join(self.tmp, "data/heroes/h.tres"), encoding="utf-8").read()
        self.assertIn('path="res://assets/sprites/hero_t/hero_t.tres" id="8_sheet"', text)
        self.assertNotIn("knight", text)

    def test_missing_key_message(self):
        with mock.patch.dict(os.environ, {"MESHY_API_KEY": ""}):
            with self.assertRaises(api.MeshyError):
                api.api_key()


if __name__ == "__main__":
    unittest.main()
