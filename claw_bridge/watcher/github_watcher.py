# -*- coding: utf-8 -*-
"""
github_watcher.py - claw_bridge add-on v1.0
Watch GitHub repo public API for new .bat/.cmd in pending_trigger/
Pull to C:\\coze-scheduler\\claw_bridge\\pending\\
NO PAT needed (public repo)
"""
import os
import sys
import time
import json
import urllib.request
import urllib.error

REPO = "xiaoxiaochen2020/coze-v0.3"
BRANCH = "main"
TRIGGER_DIR = "claw_bridge/pending_trigger"
PENDING_DIR = r"C:\coze-scheduler\claw_bridge\pending"
STATE_FILE = r"C:\coze-scheduler\claw_bridge\watcher_state.txt"
API_URL = f"https://api.github.com/repos/{REPO}/contents/{TRIGGER_DIR}?ref={BRANCH}"
RAW_URL = f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/{TRIGGER_DIR}"
POLL_SEC = 45
LOG_FILE = r"C:\coze-scheduler\claw_bridge\watcher.log"


def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}\n"
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass
    try:
        sys.stdout.write(line)
        sys.stdout.flush()
    except Exception:
        pass


def load_state():
    seen = set()
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line:
                        seen.add(line)
        except Exception as e:
            log(f"state read err: {e}")
    return seen


def save_state(seen):
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            for name in sorted(seen):
                f.write(name + "\n")
    except Exception as e:
        log(f"state save err: {e}")


def list_trigger_files():
    """List .bat/.cmd files in TRIGGER_DIR via GitHub Contents API."""
    req = urllib.request.Request(
        API_URL,
        headers={"User-Agent": "claw-github-watcher/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        log(f"api http {e.code}: {e.reason}")
        return []
    except Exception as e:
        log(f"api err: {e}")
        return []
    if not isinstance(data, list):
        return []
    return [item for item in data
            if item.get("type") == "file"
            and (item.get("name", "").endswith(".bat")
                 or item.get("name", "").endswith(".cmd"))]


def pull_file(name):
    """Download file from raw.githubusercontent.com to PENDING_DIR."""
    url = RAW_URL + "/" + name
    dst = os.path.join(PENDING_DIR, name)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "claw-github-watcher/1.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            content = resp.read()
        with open(dst, "wb") as f:
            f.write(content)
        log(f"pulled: {name} ({len(content)} bytes)")
        return True
    except Exception as e:
        log(f"pull err {name}: {e}")
        return False


def is_already_running():
    """Avoid double-launch via lock file."""
    lock = r"C:\coze-scheduler\claw_bridge\watcher.lock"
    if os.path.exists(lock):
        try:
            with open(lock, "r") as f:
                old_pid = int(f.read().strip())
            import ctypes
            PROCESS_QUERY_LIMITED = 0x1000
            STILL_ACTIVE = 259
            h = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_LIMITED, False, old_pid)
            if h:
                code = ctypes.c_ulong()
                ctypes.windll.kernel32.GetExitCodeProcess(h, ctypes.byref(code))
                ctypes.windll.kernel32.CloseHandle(h)
                if code.value == STILL_ACTIVE:
                    return True
        except Exception:
            pass
    try:
        with open(lock, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass
    return False


def main():
    log(f"WATCHER_START pid={os.getpid()}")
    if is_already_running():
        log("another watcher running, exit")
        return
    if not os.path.exists(PENDING_DIR):
        os.makedirs(PENDING_DIR, exist_ok=True)
    seen = load_state()
    log(f"loaded state: {len(seen)} known files")
    while True:
        try:
            files = list_trigger_files()
            log(f"api returned {len(files)} .bat/.cmd files")
            for item in files:
                name = item.get("name", "")
                if not name or name in seen:
                    continue
                if pull_file(name):
                    seen.add(name)
            if files:
                save_state(seen)
        except Exception as e:
            log(f"loop err: {e}")
        time.sleep(POLL_SEC)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("WATCHER_STOP")
    except Exception as e:
        log(f"FATAL: {e}")
