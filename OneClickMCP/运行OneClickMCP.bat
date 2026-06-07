@echo off
chcp 65001 >nul
title 一键启 OneClickMCP v2.0
echo ============================================
echo  启动 OneClickMCP v2.0 EXE
echo ============================================
echo.

set "EXE=C:\coze-scheduler\OneClickMCP\dist\OneClickMCP\OneClickMCP.exe"

:: 检查 EXE
if not exist "%EXE%" (
    echo [X] 找不到 EXE, 请先:
    echo     1. 双击 拉OneClickMCP.bat
    echo     2. 双击 build_oneclick.bat
    echo.
    pause
    exit /b 1
)

:: 检查 GH_PAT
if "%GH_PAT%"=="" (
    echo [!!] GH_PAT 环境变量未设置
    echo     EXE 能跑, watchdog 探活正常
    echo     但 GitHub 推送 URL 会失败 (主 Agent 端不能自动发现)
    echo.
    echo     一次性设置 (cmd 管理员):
    echo       setx GH_PAT "你的 Classic PAT, ghp 开头"
    echo       然后重启 EXE
    echo.
    set /p CONT=按回车继续 (不强求 GH_PAT)...
)

:: 杀旧
echo [1/2] 杀旧
taskkill /F /IM OneClickMCP.exe 2>nul
taskkill /F /IM cloudflared.exe 2>nul
timeout /t 2 /nobreak >nul

:: 启 EXE
echo [2/2] 启 OneClickMCP v2.0 EXE (应无 console 窗口)
start "" "%EXE%"
timeout /t 5 /nobreak >nul

echo.
echo ============================================
echo  OneClickMCP v2.0 已启动
echo.
echo  状态查:
echo    - 看 桌面\当前MCP通道状态.txt
echo    - 任务管理器查 OneClickMCP.exe (无窗口 = OK)
echo    - 日志: C:\coze-scheduler\OpenClaw\logs\OneClickMCP.log
echo.
echo  关闭:
echo    - 任务管理器结束 OneClickMCP.exe
echo    - 同时结束 cloudflared.exe
echo ============================================
pause
