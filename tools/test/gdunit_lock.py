"""gdUnit 전체 시험 잠금과 프로세스 정리 (통합 세션의 run_full 스크립트 규칙을 파이썬으로).

잠금 파일 한 줄: `<주인> <내용> <시각> pid=<pid> until=<epoch> ...`
 - 한 번에 하나만 만든다 (O_EXCL). 동시에 둘이 잡을 수 없다.
 - 자기 pid가 적힌 잠금만 지운다 (멈춘 남의 프로세스가 나중에 남의 잠금을 지우거나 덮어쓰지 않게).
 - 남의 잠금은 until이 30분 넘게 지났고 gdUnit 프로세스가 하나도 없을 때만 치운다.
 - 부모 셸이 죽으면(고아) 스스로 끝낸다. 끝날 때 Godot 자식 나무를 taskkill /T로 다 끝낸다.
 - STOP 파일이 생기면 몇 초 안에 멈춘다.
"""
import os, re, subprocess, sys, threading, time

HOLD_SECS = 7800  # 한 번 잡는 기한 (until)
STALE_SECS = 1800
BEAT_SECS = 600


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def default_lock():
    return os.path.join(os.environ.get("HH_MAIN_REPO", r"C:\Haneol-Heroes"), "build", "gdunit.lock")


def pid_alive(pid):
    if sys.platform == "win32":
        import ctypes
        k = ctypes.windll.kernel32
        h = k.OpenProcess(0x00100000, False, pid)  # SYNCHRONIZE
        if not h:
            return False
        alive = k.WaitForSingleObject(h, 0) == 0x102  # WAIT_TIMEOUT
        k.CloseHandle(h)
        return alive
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def kill_tree(pid):
    """프로세스와 그 자식 나무를 모두 끝낸다."""
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        try:
            os.kill(pid, 9)
        except OSError:
            pass


def gdunit_running():
    """GdUnitCmdTool을 돌리는 Godot 프로세스 수 (남의 잠금이 정말 죽은 것인지 볼 때)."""
    if sys.platform != "win32":
        return 0
    ps = ("@(Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | "
          "Where-Object { $_.CommandLine -match 'GdUnitCmdTool' }).Count")
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
    digits = re.sub(r"\D", "", out)
    return int(digits) if digits else 0


class Lock:
    """with Lock(...) as lock: ... — lock.should_stop()이 참이면 일을 멈추고 정리한다."""

    def __init__(self, owner, note, path=None, stop_file=None, wait_secs=0, parent_pid=None, log=print):
        self.owner = owner
        self.note = note
        self.path = path or default_lock()
        self.stop_file = stop_file or os.path.join(os.path.dirname(self.path), "gdunit.stop")
        self.wait_secs = wait_secs
        self.parent = parent_pid if parent_pid is not None else os.getppid()
        self.log = log
        self.mine = False
        self._beat = None
        self._done = threading.Event()

    # --- 멈춤 요청 ---
    def orphaned(self):
        return self.parent > 0 and not pid_alive(self.parent)

    def should_stop(self):
        return os.path.exists(self.stop_file) or self.orphaned()

    # --- 잠금 ---
    def line(self):
        until = int(time.time()) + HOLD_SECS
        return "%s %s %s pid=%d until=%d" % (self.owner, self.note, time.strftime("%Y-%m-%dT%H:%M:%S"), os.getpid(), until)

    def owned_by_me(self):
        try:
            return "pid=%d " % os.getpid() in _read(self.path) + " "
        except OSError:
            return False

    def _try_create(self):
        try:
            fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            return False
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(self.line() + "\n")
        return True

    def _stale(self):
        try:
            txt = _read(self.path)
        except OSError:
            return False
        m = re.search(r"until=(\d+)", txt)
        return bool(m) and time.time() - int(m.group(1)) > STALE_SECS and gdunit_running() == 0

    def acquire(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        t_end = time.time() + self.wait_secs
        while True:
            if self.should_stop():
                raise SystemExit("멈춤 요청 (STOP 파일 또는 부모 종료)")
            if self._try_create():
                self.mine = True
                break
            if self._stale():
                self.log("낡은 잠금(기한 지남, gdUnit 없음)을 치운다: %s" % _read(self.path).strip())
                try:
                    os.remove(self.path)
                except OSError:
                    pass
                continue
            if time.time() >= t_end:
                txt = _read(self.path).strip() if os.path.exists(self.path) else "?"
                raise SystemExit("gdunit.lock이 잠겨 있다: %s\n(기다리려면 --wait-minutes N)" % txt)
            time.sleep(5)
        self._beat = threading.Thread(target=self._heartbeat, daemon=True)
        self._beat.start()

    def _heartbeat(self):
        while not self._done.wait(BEAT_SECS):
            if self.owned_by_me():
                try:
                    with open(self.path, "w", encoding="utf-8") as f:
                        f.write(self.line() + "\n")
                except OSError:
                    pass

    def release(self):
        self._done.set()
        if self.mine and self.owned_by_me():
            try:
                os.remove(self.path)
            except OSError:
                pass
        self.mine = False

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self, *exc):
        self.release()
        return False
