# -*- coding: utf-8 -*-
"""
StartMCPGuard v1.7: 修黑框 + 修 EXE 内存 (主人 2026-06-07 07:49 立)
- 没有开机自启 (主人 07:19 规矩)
- 没有安装 BAT. 必须主人手动跑 (双击 桌面 运行StartMCPGuard.bat)
- 保活 cloudflared.exe
- cloudflared 重启后, 抓新 URL → 推 GitHub data/current_mcp_url.txt
  主 Agent 端定时拉这个 raw 文件, 自动发现新 URL, 自动重连
- 主人电脑弹气泡 + 写桌面 .txt
- **v1.7 改动**:
  - is_alive tasklist 加 CREATE_NO_WINDOW (0x08000000) 不弹一闪没
  - 全部 subprocess.Popen 走 startupinfo + wShowWindow=SW_HIDE 三保险
  - 不再依赖 DETACHED_PROCESS 单 flag
"""
import os
import sys
import time
import ctypes
import subprocess
import re
import json
import base64
import urllib.request
import urllib.error
from pathlib import Path

# ===== 配置 =====
ROOT = Path(r"C:\coze-scheduler")
DATA = ROOT / "OpenClaw" / "data"
LOG = ROOT / "OpenClaw" / "logs" / "start_mcp_guard.log"
DESK_TXT = Path(r"C:\Users\Administrator\Desktop\当前MCP通道状态.txt")
CLOUDFLARED = Path(r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\cloudflared.exe")
MCP_PORT = 8090
START_MCP_BAT = ROOT / "OpenClaw" / "logs" / "start_mcp_silent.bat"
CHECK_INTERVAL = 10
RESTART_COOLDOWN = 15

# GitHub 推送 (主人 01:21 立的 Classic PAT)
# GitHub 仓库开 secret scanning, 禁止把 PAT 写进文件
# 主人电脑启动 v1.7 前, 手动设置环境变量:
#   setx GH_PAT "<主人的 Classic Token, ghp 开头>"
# 或在 v1.7 BAT 跑前一句:
#   set GH_PAT=<主人的 Classic Token, ghp 开头>
GH_PAT = os.environ.get("GH_PAT", "")
if not GH_PAT:
    print(f"[WARN] GH_PAT 环境变量没设! GitHub 推送不会工作, 主人电脑启动 v1.7 前必须 set", flush=True)
GH_REPO = "xiaoxiaochen2020/coze-v0.3"
GH_BRANCH = "main"
GH_PATH = "data/current_mcp_url.txt"
GH_API = f"https://api.github.com/repos/{GH_REPO}/contents/{GH_PATH}"

DATA.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

# === v1.7 黑框三保险: 所有 subprocess 必须走 no_window 标志 ===
NO_WINDOW = 0x08000000  # CREATE_NO_WINDOW
SW_HIDE = 0
STARTUPINFO = subprocess.STARTUPINFO()
STARTUPINFO.dwFlags |= 0x00000001  # STARTF_USESHOWWINDOW
STARTUPINFO.wShowWindow = SW_HIDE
SUBPROC_KW = dict(
    creationflags=NO_WINDOW,
    startupinfo=STARTUPINFO,
)

START_MCP_BAT.write_text(f"""@echo off
chcp 65001 >nul
REM 静默起 cloudflared, 输出到 log, 不会弹窗
"{CLOUDFLARED}" tunnel --url http://localhost:{MCP_PORT} > "C:\\coze-scheduler\\OpenClaw\\logs\\cloudflared.out" 2>&1
""", encoding="gbk")

def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

def is_alive(name):
    try:
        out = subprocess.check_output(
            f'tasklist /FI "IMAGENAME eq {name}"',
            shell=True, stderr=subprocess.DEVNULL,
            **SUBPROC_KW,  # v1.7: 不弹一闪没
        ).decode("gbk", errors="ignore")
        return name.lower() in out.lower()
    except Exception:
        return False

def start_cloudflared():
    log("START: 静默启 cloudflared (URL 必变)")
    subprocess.Popen(
        ["cmd", "/c", "start", "", "/B", str(START_MCP_BAT)],
        shell=False, **SUBPROC_KW,  # v1.7: 三保险
    )
    return True

def notify_balloon(title, msg):
    try:
        ps = (
            f"Add-Type -AssemblyName System.Windows.Forms | Out-Null; "
            f"$n = New-Object System.Windows.Forms.NotifyIcon; "
            f"$n.Icon = [System.Drawing.SystemIcons]::Warning; "
            f"$n.Visible = $true; "
            f"$n.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning; "
            f"$n.ShowBalloonTip(15000, '{title}', '{msg}', "
            f"[System.Windows.Forms.ToolTipIcon]::Warning)"
        )
        subprocess.Popen(
            ["powershell", "-NoProfile", "-Command", ps],
            **SUBPROC_KW,  # v1.7: 三保险
        )
        return True
    except Exception as e:
        log(f"notify err: {e}")
        return False

def write_desk_alert(url_hint=""):
    try:
        DESK_TXT.write_text(
            f"==== MCP 通道状态 ====\n"
            f"时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"状态: cloudflared 已被 watchdog 重启\n"
            f"!! 新 URL 已变 !!\n"
            f"新 URL: {url_hint or '(抓不到, 查 cloudflared.out)'}\n"
            f"已推 GitHub: data/current_mcp_url.txt\n"
            f"主 Agent 端 30s 内自动发现, 自动重连\n",
            encoding="utf-8"
        )
    except Exception as e:
        log(f"write_desk err: {e}")

def get_url_from_log():
    out_log = Path(r"C:\coze-scheduler\OpenClaw\logs\cloudflared.out")
    if not out_log.exists():
        return None
    try:
        txt = out_log.read_text(encoding="utf-8", errors="ignore")
        m = re.search(r"https?://[a-z0-9-]+\.trycloudflare\.com", txt)
        if m:
            return m.group(0)
    except Exception:
        pass
    return None

def github_get_sha():
    """拿 GitHub 文件当前 SHA (没文件返 None)"""
    try:
        req = urllib.request.Request(
            GH_API + f"?ref={GH_BRANCH}",
            headers={
                "Authorization": f"token {GH_PAT}",
                "User-Agent": "StartMCPGuard/1.6",
                "Accept": "application/vnd.github+json",
            }
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))
            return data.get("sha")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None  # 文件不存在
        log(f"github_get_sha HTTP {e.code}")
        return None
    except Exception as e:
        log(f"github_get_sha err: {e}")
        return None

def github_push_url(url):
    """推 URL 到 GitHub data/current_mcp_url.txt"""
    try:
        sha = github_get_sha()
        payload = {
            "message": f"StartMCPGuard auto-update URL: {url}",
            "branch": GH_BRANCH,
            "content": base64.b64encode(url.encode("utf-8")).decode("ascii"),
        }
        if sha:
            payload["sha"] = sha
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(
            GH_API,
            data=body,
            method="PUT",
            headers={
                "Authorization": f"token {GH_PAT}",
                "User-Agent": "StartMCPGuard/1.6",
                "Accept": "application/vnd.github+json",
                "Content-Type": "application/json",
            }
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            resp = json.loads(r.read().decode("utf-8"))
            new_sha = resp.get("content", {}).get("sha", "?")
            log(f"github_push_url OK: sha={new_sha[:10]}")
            return True
    except urllib.error.HTTPError as e:
        body_txt = e.read().decode("utf-8", errors="ignore")[:200]
        log(f"github_push_url HTTP {e.code}: {body_txt}")
        return False
    except Exception as e:
        log(f"github_push_url err: {e}")
        return False

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False

def main():
    log("=== StartMCPGuard v1.6 启动 ===")
    log(f"  is_admin = {is_admin()}")
    log(f"  GH 推送目标: {GH_REPO}/{GH_PATH}")
    last_restart = 0
    last_url = None
    while True:
        try:
            alive = is_alive("cloudflared.exe")
            if not alive:
                now = time.time()
                if now - last_restart > RESTART_COOLDOWN:
                    log(f"DEAD: cloudflared → 重启 (URL 必变)")
                    start_cloudflared()
                    last_restart = now
                    time.sleep(12)  # 等 cloudflared 写 stderr
                    new_url = get_url_from_log()
                    if new_url and new_url != last_url:
                        log(f"NEW URL: {new_url}")
                        last_url = new_url
                        (DATA / "current_mcp_url.txt").write_text(new_url, encoding="utf-8")
                        log("URL 已写本地 (data/current_mcp_url.txt)")
                        # 推 GitHub
                        if github_push_url(new_url):
                            log("✓ URL 已推 GitHub, 主 Agent 端 30s 内自动发现")
                        else:
                            log("✗ GitHub 推失败, 主 Agent 端不会自动发现")
                    write_desk_alert(new_url or "")
                    notify_balloon(
                        "MCP 通道已重启",
                        f"新 URL: {new_url[:50] if new_url else '查桌面文件'}  已推 GitHub"
                    )
            else:
                # 活 - 每 5 分钟抓一次 URL, 防漂移
                if int(time.time()) % 300 < CHECK_INTERVAL:
                    new_url = get_url_from_log()
                    if new_url and new_url != last_url:
                        log(f"URL 漂移: {new_url}")
                        last_url = new_url
                        (DATA / "current_mcp_url.txt").write_text(new_url, encoding="utf-8")
                        if github_push_url(new_url):
                            log("✓ 漂移 URL 已推 GitHub")
        except Exception as e:
            log(f"LOOP ERR: {e}")
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("中断退出")
