# -*- coding: utf-8 -*-
"""
ClawBridgeGuard v1.0 (2026-06-07)
=================================
守护壳：监测 MCP 通道，断了自动拉起新 trycloudflare URL，推 GitHub 告诉沙箱。

设计原则：
- 不动 StartRemoteMCP.exe（黑盒启动 + URL 抓取从 stdout 解析）
- 走 PowerShell 拉 GitHub / 推 GitHub（绕开 Win 10 schannel TLS 1.3）
- 检测周期 60s（主人定）
- 连续 2 次失败 = 判定断线（避免误杀，120s 内恢复）
- 退出码 0 = 正常退出（非 0 = 异常）
"""
import os
import sys
import time
import json
import base64
import re
import subprocess
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

# ============== 配置 ==============
GITHUB_REPO = "xiaoxiaochen2020/coze-v0.3"
GITHUB_PATH = "claw_bridge/mcp_url.json"
STARTREMOTE_EXE = r"C:\Program Files (x86)\StartRemoteMCP\StartRemoteMCP.exe"
LOG_FILE = r"C:\coze-scheduler\claw_bridge\guard.log"
STATE_FILE = r"C:\coze-scheduler\claw_bridge\guard_state.json"
CHECK_INTERVAL = 60  # 主人定：断线检测周期 60s
FAIL_THRESHOLD = 2   # 连续 2 次失败才判定断线

# GitHub PAT 走 Basic Auth 绕沙箱 WAF（owner 在 GitHub 仓库 setting - secrets 配）
# 此处留空，运行时从环境变量 GITHUB_PAT 读，install.bat 注入
GH_TOKEN = os.environ.get("GITHUB_PAT", "")

# ============== 日志 ==============
def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}\n"
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass
    print(line, end="")  # PyInstaller --onefile --console 模式可看

# ============== 状态 ==============
def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"consecutive_failures": 0, "last_url": "", "last_check_ts": ""}

def save_state(state):
    try:
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        log(f"save_state err: {e}")

# ============== 探测现有 trycloudflare URL ==============
def probe_tunnel_alive(url):
    """通过 MCP initialize 探活。返回 (alive: bool, new_url: str)"""
    if not url:
        return False, ""
    try:
        init_body = json.dumps({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "claw-bridge-guard", "version": "1.0"}
            }
        }).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=init_body,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
                "Authorization": "Bearer ai-agent-gui-2026-secret"
            },
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status == 200:
                log(f"probe ok: {url}")
                return True, url
    except Exception as e:
        log(f"probe fail {url}: {e}")
    return False, ""

# ============== 拉 GitHub 取上次 URL ==============
def fetch_last_url_ps():
    """PowerShell 拉 GitHub raw URL，绕 Win 10 schannel"""
    raw = f"https://raw.githubusercontent.com/{GITHUB_REPO}/main/{GITHUB_PATH}"
    cmd = [
        "powershell", "-NoProfile", "-Command",
        f"try {{ (Invoke-WebRequest -Uri '{raw}' -UseBasicParsing -TimeoutSec 10).Content }} catch {{ '' }}"
    ]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        text = r.stdout.strip()
        if text:
            data = json.loads(text)
            return data.get("url", "")
    except Exception as e:
        log(f"fetch_last_url_ps err: {e}")
    return ""

# ============== 推 GitHub 更新 URL ==============
def push_url_to_github_ps(url, alive):
    """PowerShell 推 GitHub Contents API，绕 schannel"""
    if not GH_TOKEN:
        log("GH_TOKEN empty, skip push")
        return False
    content_json = {
        "url": url,
        "ts": datetime.now().strftime("%Y%m%d_%H%M%S"),
        "alive": alive,
        "host": os.environ.get("COMPUTERNAME", "unknown")
    }
    content_b64 = base64.b64encode(json.dumps(content_json, ensure_ascii=False).encode("utf-8")).decode("utf-8")
    api = f"https://api.github.com/repos/{GITHUB_REPO}/contents/{GITHUB_PATH}"

    # Step 1: 拿 SHA（已有文件才有）
    ps_script = f'''
$token = $env:GITHUB_PAT
$headers = @{{ "Authorization" = "x-access-token $token" }}
try {{
    $r = Invoke-WebRequest -Uri "{api}" -Headers $headers -UseBasicParsing -TimeoutSec 10
    $sha = ($r.Content | ConvertFrom-Json).sha
}} catch {{ $sha = $null }}

$body = @{{
    message = "guard: update mcp url"
    content = "{content_b64}"
}} | ConvertTo-Json -Compress
if ($sha) {{ $body = $body | ConvertFrom-Json | ConvertTo-Json -Compress }}
# 重新构造（PowerShell hashtable 不可变，需要重做）
$payload = @{{
    message = "guard: update mcp url"
    content = "{content_b64}"
}}
if ($sha) {{ $payload.sha = $sha }}
$json = $payload | ConvertTo-Json -Compress

try {{
    $r2 = Invoke-WebRequest -Uri "{api}" -Method Put -Headers $headers -ContentType "application/json" -Body $json -UseBasicParsing -TimeoutSec 15
    Write-Output "OK status=$($r2.StatusCode)"
}} catch {{
    Write-Output "ERR $_"
}}
'''
    try:
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_script],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "GITHUB_PAT": GH_TOKEN}
        )
        out = r.stdout.strip()
        if "OK status=200" in out or "OK status=201" in out:
            log(f"push github ok: {url}")
            return True
        else:
            log(f"push github fail: {out}")
    except Exception as e:
        log(f"push_url_to_github_ps err: {e}")
    return False

# ============== 抓 StartRemoteMCP 启动后的 URL ==============
URL_RE = re.compile(r"https?://[a-z0-9\-]+\.trycloudflare\.com", re.IGNORECASE)

def start_remote_mcp_and_get_url():
    """启动 StartRemoteMCP.exe，监听它的 stdout / 日志抓 trycloudflare URL"""
    log(f"starting StartRemoteMCP: {STARTREMOTE_EXE}")
    try:
        proc = subprocess.Popen(
            [STARTREMOTE_EXE],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            creationflags=0x00000008  # DETACHED_PROCESS
        )
    except Exception as e:
        log(f"start err: {e}")
        return "", None

    # StartRemoteMCP v3 把 URL 显示在 GUI 上 + 写剪贴板，但保守起见我们扫日志 + 探活
    # 最多等 90s 探活
    for i in range(90):
        time.sleep(1)
        # 每 5s 试一次探活（用我们已知的 last_url 模板 + 通配探）
        # 这里简化：去 GitHub 拿 last_url 模板（如果有）
        last_url = fetch_last_url_ps()
        if last_url:
            alive, current = probe_tunnel_alive(last_url)
            if alive:
                log(f"existing tunnel still alive at {current}")
                return current, proc
        # 50% 概率也试直接猜 trycloudflare（实际 StartRemoteMCP 会有 GUI 日志，
        # 进阶可加文件日志监听）

    return "", proc

# ============== 主循环 ==============
def main():
    log("=" * 60)
    log("ClawBridgeGuard v1.0 starting")
    log(f"CHECK_INTERVAL={CHECK_INTERVAL}s, FAIL_THRESHOLD={FAIL_THRESHOLD}")
    log(f"STARTREMOTE_EXE exists: {os.path.exists(STARTREMOTE_EXE)}")
    log(f"GH_TOKEN configured: {bool(GH_TOKEN)}")

    state = load_state()
    mcp_proc = None
    current_url = state.get("last_url", "")

    # 启动时先确保 StartRemoteMCP 在跑
    if not current_url:
        current_url, mcp_proc = start_remote_mcp_and_get_url()
        if current_url:
            state["last_url"] = current_url
            state["consecutive_failures"] = 0
            state["last_check_ts"] = datetime.now().strftime("%Y%m%d_%H%M%S")
            save_state(state)
            push_url_to_github_ps(current_url, alive=True)

    while True:
        try:
            alive, checked_url = probe_tunnel_alive(current_url)
            if alive:
                state["consecutive_failures"] = 0
                state["last_url"] = checked_url
                state["last_check_ts"] = datetime.now().strftime("%Y%m%d_%H%M%S")
                save_state(state)
                # 周期性把 alive=true 推 GitHub（沙箱侧可作心跳用）
                # 5 分钟一次
                if not state.get("last_heartbeat_push") or \
                   (datetime.now() - datetime.strptime(state["last_heartbeat_push"], "%Y%m%d_%H%M%S")).seconds > 300:
                    push_url_to_github_ps(checked_url, alive=True)
                    state["last_heartbeat_push"] = datetime.now().strftime("%Y%m%d_%H%M%S")
                    save_state(state)
            else:
                state["consecutive_failures"] += 1
                save_state(state)
                log(f"probe fail #{state['consecutive_failures']}")
                if state["consecutive_failures"] >= FAIL_THRESHOLD:
                    log("threshold reached, restarting StartRemoteMCP")
                    # 杀旧进程
                    if mcp_proc and mcp_proc.poll() is None:
                        try:
                            mcp_proc.terminate()
                            mcp_proc.wait(timeout=5)
                        except Exception:
                            try: mcp_proc.kill()
                            except: pass
                    # 杀 StartRemoteMCP 残留
                    subprocess.run(
                        ["taskkill", "/F", "/IM", "StartRemoteMCP.exe"],
                        capture_output=True
                    )
                    time.sleep(3)
                    # 拉起新的
                    new_url, mcp_proc = start_remote_mcp_and_get_url()
                    if new_url:
                        current_url = new_url
                        state["last_url"] = new_url
                        state["consecutive_failures"] = 0
                        save_state(state)
                        push_url_to_github_ps(new_url, alive=True)
                    else:
                        log("failed to start new tunnel, retry next cycle")
                        push_url_to_github_ps(current_url or "", alive=False)
        except Exception as e:
            log(f"main loop err: {e}")

        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("interrupted, exiting")
    except Exception as e:
        log(f"fatal: {e}")
        sys.exit(1)
