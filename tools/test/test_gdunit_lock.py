"""gdunit_lock·tiers 시험: python -m unittest tools/test/test_gdunit_lock.py"""
import os, subprocess, sys, tempfile, time, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gdunit_lock, tiers  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


class LockTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.path = os.path.join(self.dir, "gdunit.lock")
        self.stop = os.path.join(self.dir, "gdunit.stop")

    def mk(self, **kw):
        return gdunit_lock.Lock("t", "x", path=self.path, stop_file=self.stop, parent_pid=os.getpid(), log=lambda *_: None, **kw)

    def test_second_taker_cannot_overwrite(self):
        a = self.mk()
        a.acquire()
        before = open(self.path).read()
        with self.assertRaises(SystemExit):
            self.mk().acquire()
        self.assertEqual(open(self.path).read(), before)  # 남이 덮어쓰지 못했다
        a.release()
        self.assertFalse(os.path.exists(self.path))

    def test_only_my_pid_lock_is_removed(self):
        a = self.mk()
        a.acquire()
        with open(self.path, "w") as f:  # 다른 프로세스가 잠금을 넘겨받았다
            f.write("other pid=99999999 until=%d\n" % (time.time() + 999))
        a.release()
        self.assertTrue(os.path.exists(self.path))  # 남의 잠금은 안 지운다

    def test_stale_lock_with_no_gdunit_is_taken_over(self):
        with open(self.path, "w") as f:
            f.write("old pid=1 until=%d\n" % (time.time() - 99999))
        orig = gdunit_lock.gdunit_running
        gdunit_lock.gdunit_running = lambda: 0
        try:
            a = self.mk()
            a.acquire()
            self.assertTrue(a.owned_by_me())
            a.release()
        finally:
            gdunit_lock.gdunit_running = orig

    def test_fresh_lock_is_not_taken_over(self):
        with open(self.path, "w") as f:
            f.write("old pid=1 until=%d\n" % (time.time() + 999))
        with self.assertRaises(SystemExit):
            self.mk().acquire()

    def test_stop_file_and_orphan_request_stop(self):
        a = self.mk()
        self.assertFalse(a.should_stop())
        open(self.stop, "w").close()
        self.assertTrue(a.should_stop())
        os.remove(self.stop)
        p = subprocess.Popen([sys.executable, "-c", "pass"])
        p.wait()
        b = gdunit_lock.Lock("t", "x", path=self.path, stop_file=self.stop, parent_pid=p.pid)
        self.assertTrue(b.orphaned())  # 부모(이미 끝난 프로세스)가 없다

    def test_hhmm_until_is_not_mistaken_for_a_unix_time(self):
        """통합 보고: until=11:04 (시:분)을 유닉스초 11로 읽어 살아 있는 남의 잠금을 지웠다."""
        now = time.mktime((2026, 11, 27, 10, 45, 0, 0, 0, -1))
        self.assertAlmostEqual(gdunit_lock.parse_until("x until=11:04 started=10:44", now), now + 19 * 60, delta=1)
        self.assertAlmostEqual(gdunit_lock.parse_until("x until=00:10", now), now - (10 * 3600 + 35 * 60), delta=1)  # 오늘 00:10
        self.assertIsNone(gdunit_lock.parse_until("until=soon", now))
        self.assertEqual(gdunit_lock.parse_until("pid=5 until=1795744035", now), 1795744035)
        with open(self.path, "w") as f:
            f.write("formation session until=%s started=x\n" % time.strftime("%H:%M", time.localtime(time.time() + 600)))
        gdunit_lock.gdunit_running, orig = (lambda: 0), gdunit_lock.gdunit_running
        try:
            a = self.mk()
            self.assertFalse(a._stale())  # 기한 안 (HH:MM)
            with open(self.path, "w") as f:
                f.write("formation session until=garbage\n")
            self.assertFalse(a._stale())  # 못 읽으면 살아 있음
            with open(self.path, "w") as f:
                f.write("x pid=%d until=%d\n" % (os.getpid(), time.time() - 99999))
            self.assertFalse(a._stale())  # 기한은 지났어도 적힌 pid가 살아 있다
        finally:
            gdunit_lock.gdunit_running = orig

    def test_kill_tree_ends_the_child(self):
        p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        gdunit_lock.kill_tree(p.pid)
        p.wait(timeout=10)
        self.assertIsNotNone(p.returncode)


class TierTest(unittest.TestCase):
    def test_tier_lists_name_existing_suites_without_overlap_issues(self):
        t = tiers.load()
        suites = set(tiers.all_suites(ROOT))
        for key in ("fast", "sim"):
            for s in t[key]:
                self.assertIn(s, suites, "tiers.json의 %s에 없는 스위트 %s" % (key, s))

    def test_full_is_everything_and_tiers_are_nested(self):
        suites = tiers.all_suites(ROOT)
        self.assertEqual(tiers.select("full", ROOT), suites)
        fast = set(tiers.select("fast", ROOT))
        rel = set(tiers.select("related", ROOT, base="HEAD"))
        sim = set(tiers.select("sim", ROOT, base="HEAD"))
        self.assertTrue(fast <= rel <= sim <= set(suites))

    def test_related_picks_suites_that_mention_the_changed_file(self):
        suites = ["test_a", "test_b"]
        words = tiers.stems(ROOT, ["scripts/ui/hero_badge.gd", "tools/x.py", "README.md"])
        self.assertIn("hero_badge", words)
        self.assertIn("HeroBadge", words)
        self.assertNotIn("x", words)
        self.assertEqual(suites, suites)


if __name__ == "__main__":
    unittest.main()
