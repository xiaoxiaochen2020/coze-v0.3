@echo off
chcp 65001 >nul
REM StartMCPGuard v1.7 - pythonw 版 (绕过 EXE 内存问题)
REM 主人 2026-06-07 07:49 立 A 方案
REM 退出: 任务管理器杀 pythonw.exe, 或重启电脑

REM 设环境变量 GH_PAT (PAT 不写源码/BAT, GitHub secret scanning 禁)
REM 第一次跑前, 主人电脑手动 setx (持久):
REM   setx GH_PAT "<主人的 Classic Token, ghp 开头>"
REM 或在本 BAT 跑前临时设:
REM   set GH_PAT=<主人的 Classic Token, ghp 开头>
if "%GH_PAT%"=="" (
    echo [WARN] GH_PAT 没设! GitHub 推送不会工作
    echo 你必须先 setx GH_PAT, 然后重新跑这个 BAT
    pause
    exit /b 1
)

cd /d "C:\coze-scheduler\StartMCPGuard"

REM 退出旧 pythonw
taskkill /F /IM pythonw.exe /FI "WINDOWTITLE eq StartMCPGuard*" 2>nul >nul
echo === 启 pythonw + v1.7 ===

start "" "C:\Python314\pythonw.exe" "C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py"
echo + pythonw 已发起, PID 查任务管理器
echo.
echo 等 10s 看 watchdog 日志:
echo   C:\coze-scheduler\OpenClaw\logs\start_mcp_guard.log
echo.
echo 查|监控 URL:
echo   type C:\coze-scheduler\OpenClaw\data\current_mcp_url.txt
echo.
pause
