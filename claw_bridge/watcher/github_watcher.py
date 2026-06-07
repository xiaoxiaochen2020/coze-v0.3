# -*- coding: utf-8 -*-
"""
github_watcher.py v1.1 - claw_bridge add-on
Watch GitHub repo public API for new .bat/.cmd in pending_trigger/
Pull to C:\\coze-scheduler\\claw_bridge\\pending\\
Use PowerShell Invoke-WebRequest (TLS 1.2 compatible) via subprocess
NO PAT needed (public repo)
"""
import os
import sys
import time
import json
import subprocess
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
    """List .bat/.cmd files in TRIGGER_DIR via GitHub Contents API (urllib)."""
    req = urllib.request.Request(
        API_URL,
        headers={"User-Agent": "claw-github-watcher/1.1"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return []  # path not exist yet, normal
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


def pull_file_ps(name):
    """Download file via PowerShell Invoke-WebRequest (TLS 1.2 friendly)."""
    url = RAW_URL + "/" + name
    dst = os.path.join(PENDING_DIR, name).replace("\\", "\\\\")
    ps_cmd = (
        f"try {{ "
        f"Invoke-WebRequest -Uri '{url}' -OutFile '{dst}' -UseBasicParsing; "
        f"Write-Output ('OK_' + (Get-Item '{dst}').Length) "
        f"}} catch {{ "
        f"Write-Output ('FAIL_' + $_.Exception.Message) "
        f"}}"
    )
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_cmd],
            capture_output=True, text=True, timeout=30,
        )
        out = (result.stdout or "").strip()
        if out.startswith("OK_"):
            size = int(out[3:])
            log(f"pulled: {name} ({size} bytes)")
            return True
        log(f"ps pull fail {name}: {out}")
        return False
    except Exception as e:
        log(f"subprocess err {name}: {e}")
        return False


def is_already_running():
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
                if pull_file_ps(name):
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
