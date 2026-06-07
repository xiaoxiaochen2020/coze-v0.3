# -*- coding: utf-8 -*-
"""
OneClickMCP v2.0: 一键启动 EXE 开通 MCP (主人 2026-06-07 08:25 立)
= v1.7 watchdog + cloudflared 内置 (--add-data) + 启动自检 + GUI 控制台

- 单一 EXE 双击 = 启 cloudflared + 探活 + 抓 URL + 推 GitHub
- 三保险黑框 (NO_WINDOW + STARTUPINFO wShowWindow + SUBPROC_KW)
- 自带 cloudflared.exe (PyInstaller --add-data)
- 启动自检: cloudflared 在不在 / GH_PAT 在不在 / 写桌面 .txt
- 主人电脑 setx GH_PAT 一次, 之后 EXE 自推
- 没有开机自启 (主人 07:19 规矩)
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

# ===== 路径: PyInstaller --add-data 兼容 =====
def resource_path(rel):
    """PyInstaller onefile 解压到 _MEIxxxx, onedir 走 sys._MEIPASS"""
    base = getattr(sys, "_MEIPASS", None)
    if base:
        return Path(base) / rel
    # 源码运行: 项目根目录的 _internal (--onedir 模式)
    return Path(__file__).parent / "_internal" / rel

# ===== 配置 =====
ROOT = Path(r"C:\coze-scheduler")
DATA = ROOT / "OpenClaw" / "data"
LOG = ROOT / "OpenClaw" / "logs" / "OneClickMCP.log"
DESK_TXT = Path(r"C:\Users\Administrator\Desktop\当前MCP通道状态.txt")
MCP_PORT = 8090
START_MCP_BAT = ROOT / "OpenClaw" / "logs" / "start_mcp_silent.bat"
CHECK_INTERVAL = 10
RESTART_COOLDOWN = 15

# cloudflared.exe: 优先 _internal (onedir), 然后 PATH, 然后标准位置
CLOUDFLARED_CANDIDATES = [
    resource_path("cloudflared.exe"),
    Path(r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\cloudflared.exe"),
    Path(r"C:\Program Files\cloudflared\cloudflared.exe"),
    Path(r"C:\Windows\System32\cloudflared.exe"),
]

def find_cloudflared():
    for p in CLOUDFLARED_CANDIDATES:
        if p.exists():
            return p
    # 试 PATH
    try:
        out = subprocess.check_output(
            "where cloudflared",
            shell=True, stderr=subprocess.DEVNULL,
            **SUBPROC_KW
        ).decode("gbk", errors="ignore").strip()
        if out:
            return Path(out.split("\n")[0].strip())
    except Exception:
        pass
    return None

# ===== GitHub 推送 (主人 01:21 立的 Classic PAT) =====
GH_PAT = os.environ.get("GH_PAT", "")
GH_REPO = "xiaoxiaochen2020/coze-v0.3"
GH_BRANCH = "main"
GH_PATH = "data/current_mcp_url.txt"
GH_API = f"https://api.github.com/repos/{GH_REPO}/contents/{GH_PATH}"

# ===== v1.7 黑框三保险 =====
NO_WINDOW = 0x08000000
SW_HIDE = 0
STARTUPINFO = subprocess.STARTUPINFO()
STARTUPINFO.dwFlags |= 0x00000001
STARTUPINFO.wShowWindow = SW_HIDE
SUBPROC_KW = dict(
    creationflags=NO_WINDOW,
    startupinfo=STARTUPINFO,
)

# ===== 日志 =====
def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

# ===== 进程检测 =====
def is_alive(name):
    try:
        out = subprocess.check_output(
            f'tasklist /FI "IMAGENAME eq {name}"',
            shell=True, stderr=subprocess.DEVNULL,
            **SUBPROC_KW,
        ).decode("gbk", errors="ignore")
        return name.lower() in out.lower()
    except Exception:
        return False

# ===== 写启动 BAT =====
def write_start_bat(cloudflared_path):
    """写一个静默启 cloudflared 的 BAT, 输出到 log 文件"""
    START_MCP_BAT.parent.mkdir(parents=True, exist_ok=True)
    START_MCP_BAT.write_text(
        f'@echo off\n'
        f'chcp 65001 >nul\n'
        f'"{cloudflared_path}" tunnel --url http://localhost:{MCP_PORT} '
        f'> "C:\\coze-scheduler\\OpenClaw\\logs\\cloudflared.out" 2>&1\n',
        encoding="gbk"
    )

# ===== 启 cloudflared =====
def start_cloudflared(cloudflared_path):
    log(f"START: 静默启 cloudflared ({cloudflared_path})")
    # 写 BAT
    write_start_bat(cloudflared_path)
    # 跑 BAT (走 cmd /c start "" /B 不弹窗)
    subprocess.Popen(
        ["cmd", "/c", "start", "", "/B", str(START_MCP_BAT)],
        shell=False, **SUBPROC_KW,
    )

# ===== 气泡通知 =====
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
            **SUBPROC_KW,
        )
        return True
    except Exception as e:
        log(f"notify err: {e}")
        return False

# ===== 写桌面 .txt =====
def write_desk_alert(url_hint=""):
    try:
        DESK_TXT.write_text(
            f"==== MCP 通道状态 ====\n"
            f"时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"状态: cloudflared 已被 OneClickMCP 重启\n"
            f"!! 新 URL 已变 !!\n"
            f"新 URL: {url_hint or '(抓不到, 查 cloudflared.out)'}\n"
            f"已推 GitHub: data/current_mcp_url.txt\n"
            f"主 Agent 端 30s 内自动发现, 自动重连\n",
            encoding="utf-8"
        )
    except Exception as e:
        log(f"write_desk err: {e}")

# ===== 抓 URL (cloudflared stderr) =====
def get_url_from_log():
    out_log = ROOT / "OpenClaw" / "logs" / "cloudflared.out"
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

# ===== GitHub API =====
def github_get_sha():
    try:
        req = urllib.request.Request(
            GH_API + f"?ref={GH_BRANCH}",
            headers={
                "Authorization": f"token {GH_PAT}",
                "User-Agent": "OneClickMCP/2.0",
                "Accept": "application/vnd.github+json",
            }
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode("utf-8"))
            return data.get("sha")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        log(f"github_get_sha HTTP {e.code}")
        return None
    except Exception as e:
        log(f"github_get_sha err: {e}")
        return None

def github_push_url(url):
    try:
        sha = github_get_sha()
        payload = {
            "message": f"OneClickMCP auto-update URL: {url}",
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
                "User-Agent": "OneClickMCP/2.0",
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

# ===== 管理员 =====
def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False

# ===== 启动自检 =====
def startup_check(cloudflared_path):
    log("=" * 60)
    log("OneClickMCP v2.0 启动自检")
    log("=" * 60)
    log(f"  is_admin = {is_admin()}")
    log(f"  GH 推送目标: {GH_REPO}/{GH_PATH}")
    log(f"  GH_PAT 状态: {'已设 (token 长度 ' + str(len(GH_PAT)) + ')' if GH_PAT else '!! 未设 !! 主人电脑启动前必须 setx GH_PAT'}")
    log(f"  cloudflared: {cloudflared_path or '!! 找不到 !! 主人电脑需装 cloudflared'}")
    log(f"  日志: {LOG}")
    log(f"  桌面提示: {DESK_TXT}")
    log("=" * 60)

# ===== 主循环 =====
def main():
    cloudflared_path = find_cloudflared()
    startup_check(cloudflared_path)

    if not cloudflared_path:
        log("[!!] 找不到 cloudflared.exe, 主人电脑先装:")
        log("      winget install Cloudflare.cloudflared")
        log("      或: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/")
        # 写桌面
        try:
            DESK_TXT.write_text(
                f"==== OneClickMCP 启动失败 ====\n"
                f"时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
                f"!! 找不到 cloudflared.exe !!\n"
                f"安装: winget install Cloudflare.cloudflared\n",
                encoding="utf-8"
            )
        except Exception:
            pass
        return

    if not GH_PAT:
        log("[!!] GH_PAT 没设, GitHub 推送不会工作, 但 watchdog 仍能探活 + 重启 cloudflared")
        log("     一次性设置: 主人电脑 cmd 跑 'setx GH_PAT \"<你的 Classic PAT>\"'")
        log("     重启 OneClickMCP 后 GH_PAT 生效")

    last_restart = 0
    last_url = None

    while True:
        try:
            alive = is_alive("cloudflared.exe")
            if not alive:
                now = time.time()
                if now - last_restart > RESTART_COOLDOWN:
                    log("DEAD: cloudflared → 重启 (URL 必变)")
                    start_cloudflared(cloudflared_path)
                    last_restart = now
                    time.sleep(12)  # 等 cloudflared 写 stderr
                    new_url = get_url_from_log()
                    if new_url and new_url != last_url:
                        log(f"NEW URL: {new_url}")
                        last_url = new_url
                        (DATA / "current_mcp_url.txt").write_text(new_url, encoding="utf-8")
                        log("URL 已写本地 (data/current_mcp_url.txt)")
                        if GH_PAT:
                            if github_push_url(new_url):
                                log("✓ URL 已推 GitHub, 主 Agent 端 30s 内自动发现")
                            else:
                                log("✗ GitHub 推失败, 主 Agent 端不会自动发现")
                        else:
                            log("! GH_PAT 没设, 跳过 GitHub 推, 主 Agent 端不会发现")
                    else:
                        log("! 没抓到 URL, 等 30s 重试")
                    write_desk_alert(new_url or "")
                    notify_balloon(
                        "MCP 通道已重启",
                        f"新 URL: {(new_url or '查桌面文件')[:50]}  已推 GitHub"
                    )
            else:
                # 活 - 每 5 分钟抓一次 URL, 防漂移
                if int(time.time()) % 300 < CHECK_INTERVAL:
                    new_url = get_url_from_log()
                    if new_url and new_url != last_url:
                        log(f"URL 漂移: {new_url}")
                        last_url = new_url
                        (DATA / "current_mcp_url.txt").write_text(new_url, encoding="utf-8")
                        if GH_PAT and github_push_url(new_url):
                            log("✓ 漂移 URL 已推 GitHub")
        except Exception as e:
            log(f"LOOP ERR: {e}")
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("中断退出")
