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
        self.cfg["anims"] = self.cfg["anims"][:6]  # 기본 여섯 동작만 (연계 자르기는 따로 시험)
        # 실제 설정은 Meshy 동작 번호를 고정해 두므로, 테스트는 가짜 라이브러리(LIB)에 맞춘 동작 목록을 쓴다
        for a, how in zip(self.cfg["anims"], [{"search": "idle"}, {"search": "run"}, {"search": "dodge"},
                                              {"action_id": 4}, {"search": "hit"}, {"search": "death"}]):
            a.pop("action_id", None)
            a.pop("search", None)
            a.update(how)
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

    def _glb(self, name):
        path = os.path.join(self.tmp, name)
        with open(path, "wb") as f:
            f.write(b"glTF")
        return path

    def test_import_single_file_uses_match_lists(self):
        mp.import_files(self.cfg, [self._glb("Meshy Model (1).glb")])
        job = json.load(open(os.path.join(self.tmp, "tools/bake/jobs/hero_t.json"), encoding="utf-8"))
        self.assertEqual(job["model"], "res://assets/models/meshy/hero_t/Meshy_Model__1_.glb")
        self.assertEqual(len(job["anims"]), 6)
        self.assertTrue(all("from" not in a for a in job["anims"]))
        self.assertEqual(job["anims"][2]["src"], "dodge|roll|dash|run")

    def test_import_per_animation_files(self):
        files = [self._glb(n) for n in ("hero_Idle.glb", "hero_Running.glb", "hero_Attack.glb")]
        mp.import_files(self.cfg, files)
        job = json.load(open(os.path.join(self.tmp, "tools/bake/jobs/hero_t.json"), encoding="utf-8"))
        by_key = {a["key"]: a for a in job["anims"]}
        self.assertTrue(job["model"].endswith("hero_Idle.glb"))
        self.assertNotIn("from", by_key["idle"])
        self.assertTrue(by_key["run"]["from"].endswith("hero_Running.glb"))
        self.assertTrue(by_key["dash"]["from"].endswith("hero_Running.glb"))  # 회피 없으면 달리기
        self.assertTrue(by_key["attack"]["from"].endswith("hero_Attack.glb"))
        self.assertNotIn("hit", by_key)  # 파일 없는 동작은 건너뜀 (게임은 대기로 대신)

    def test_name_matching_is_word_based(self):
        self.assertTrue(mp.name_matches("hero_Running", "run"))
        self.assertTrue(mp.name_matches("HitReaction", "hit"))
        for text, cand in (("soldier", "die"), ("prerunner", "run"), ("white", "hit")):
            self.assertFalse(mp.name_matches(text, cand), (text, cand))

    def test_import_sanitised_name_collision_keeps_both(self):
        files = [self._glb("a b.glb"), self._glb("a?b.glb") if os.name != "nt" else self._glb("a#b.glb")]
        mp.import_files(self.cfg, files)
        out = sorted(os.listdir(os.path.join(self.tmp, "assets/models/meshy/hero_t")))
        self.assertEqual(out, ["a_b.glb", "a_b_2.glb"])

    def _ran_once(self):
        fake = FakeMeshy()
        with mock.patch.object(api, "create", fake.create), mock.patch.object(api, "wait", fake.wait),                 mock.patch.object(api, "download"):
            mp.run(self.cfg, self.args())
        self.cfg["anims"].append({"key": "kick", "search": "kick", "frames": 4, "fps": 12.0, "loop": False})
        LIB.append({"action_id": 77, "name": "Kick", "key": "kick"})
        self.addCleanup(LIB.pop)

    def _add(self, rig_status: dict, **kw):
        fake = FakeMeshy()
        os.makedirs(os.path.join(self.tmp, "assets/models/meshy/hero_t"), exist_ok=True)
        with open(os.path.join(self.tmp, "assets/models/meshy/hero_t/model.glb"), "wb") as f:
            f.write(b"glTF")
        get = mock.Mock(return_value=rig_status) if not isinstance(rig_status, Exception)             else mock.Mock(side_effect=rig_status)
        with mock.patch.object(api, "create", fake.create), mock.patch.object(api, "wait", fake.wait),                 mock.patch.object(api, "get", get), mock.patch.object(api, "download"):
            mp.add_anims(self.cfg, self.args(**kw))
        return fake

    def test_add_anims_requests_only_new_actions_with_live_rig(self):
        self._ran_once()
        fake = self._add({"status": "SUCCEEDED", "expires_at": 0})
        self.assertEqual([k for k, _ in fake.created], ["animations"])
        self.assertEqual(fake.created[0][1]["action_ids"], [77])
        self.assertEqual(fake.created[0][1]["rig_task_id"], "rigging-task")
        job = json.load(open(os.path.join(self.tmp, "tools/bake/jobs/hero_t.json"), encoding="utf-8"))
        kick = [a for a in job["anims"] if a["key"] == "kick"][0]
        self.assertTrue(kick["from"].endswith("animated_extra1.glb"))
        self.assertNotIn("from", job["anims"][0])
        again = self._add({"status": "SUCCEEDED", "expires_at": 0})  # 두 번째엔 새 동작 없음
        self.assertEqual(again.created, [])

    def test_clip_of_reuses_one_paid_clip_for_several_cuts(self):
        self._ran_once()
        self.cfg["anims"] += [
            {"key": "combo", "search": "kick", "frames": 6, "fps": 16.0, "loop": False, "skip_bake": True},
            {"key": "attack2", "clip_of": "combo", "frames": 6, "fps": 16.0, "loop": False, "start": 0.8, "end": 1.6},
            {"key": "attack3", "clip_of": "combo", "frames": 6, "fps": 16.0, "loop": False, "start": 2.0, "end": 3.4}]
        fake = self._add({"status": "SUCCEEDED", "expires_at": 0})
        self.assertEqual(fake.created[0][1]["action_ids"], [77, 77])  # kick + combo만 돈을 낸다 (자르기는 무료)
        job = json.load(open(os.path.join(self.tmp, "tools/bake/jobs/hero_t.json"), encoding="utf-8"))
        keys = {a["key"]: a for a in job["anims"]}
        self.assertNotIn("combo", keys)  # 원본은 굽지 않는다
        self.assertEqual(keys["attack2"]["src"], "Kick")
        self.assertEqual(keys["attack3"]["start"], 2.0)
        self.assertTrue(keys["attack3"]["from"].endswith("animated_extra1.glb"))

    def test_add_anims_rerigs_from_saved_model_after_expiry(self):
        self._ran_once()
        fake = self._add(api.MeshyError("404"))
        self.assertEqual([k for k, _ in fake.created], ["rigging", "animations"])
        self.assertTrue(fake.created[0][1]["model_url"].startswith("data:model/gltf-binary;base64,"))

    def test_rerig_rejects_over_limit_model_without_calling_api(self):
        self._ran_once()
        with mock.patch.object(mp, "DATA_URI_LIMIT", 10):  # 작은 한도로 흉내
            with self.assertRaises(api.MeshyError):
                self._add(api.MeshyError("404"))

    def test_add_anims_needs_yes(self):
        self._ran_once()
        with self.assertRaises(SystemExit):
            self._add({"status": "SUCCEEDED", "expires_at": 0}, yes=False)

    def test_apply_skips_hero_without_data(self):
        self.cfg["hero_data"] = "data/heroes/not_yet.tres"
        mp.apply_to_hero(self.cfg)  # 예외 없이 건너뜀

    def test_import_rejects_non_glb(self):
        with self.assertRaises(SystemExit):
            mp.import_files(self.cfg, [self._glb("model.fbx")])

    def test_missing_key_message(self):
        with mock.patch.dict(os.environ, {"MESHY_API_KEY": ""}):
            with self.assertRaises(api.MeshyError):
                api.api_key(os.path.join(self.tmp, "no.env"))

    def test_key_from_env_file_and_env_var_wins(self):
        env = os.path.join(self.tmp, ".env")
        with open(env, "w", encoding="utf-8") as f:
            f.write('# 주석\n\nMESHY_API_KEY="msy_file_key"\nOTHER=1\n')
        with mock.patch.dict(os.environ, {"MESHY_API_KEY": ""}):
            self.assertEqual(api.api_key(env), "msy_file_key")
        with mock.patch.dict(os.environ, {"MESHY_API_KEY": "msy_env_key"}):
            self.assertEqual(api.api_key(env), "msy_env_key")

    def test_env_file_is_gitignored(self):
        root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
        with open(os.path.join(root, ".gitignore"), encoding="utf-8") as f:
            self.assertIn(".env", [line.strip() for line in f])



class ClearDownloadsTest(unittest.TestCase):
    def test_refuses_paths_outside_the_meshy_folder(self):
        for bad in [os.path.join(mp.meshy_dir(), "..", "x"), os.path.join(mp.meshy_dir(), "a", "..", "..", "b"),
                    os.path.join(mp.meshy_dir(), "Bad-Name"), tempfile.gettempdir()]:
            with self.assertRaises(SystemExit):
                mp.clear_downloads(bad, "model")

    def test_deletes_only_restarted_stage_files(self):
        d = os.path.join(mp.meshy_dir(), "zz_test_clear")
        os.makedirs(d, exist_ok=True)
        try:
            for f in ("model.glb", "rigged.glb", "animated.glb", "state.json"):
                open(os.path.join(d, f), "w").close()
            mp.clear_downloads(d, "rig")
            self.assertEqual(sorted(os.listdir(d)), ["model.glb", "state.json"])
        finally:
            shutil.rmtree(d)


if __name__ == "__main__":
    unittest.main()
