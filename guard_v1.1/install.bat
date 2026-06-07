@echo off
REM ============================================================
REM  ClawBridgeGuard v1.1 - 主人电脑一键安装脚本
REM ============================================================

setlocal enabledelayedexpansion

set "PYTHON_EXE=C:\Python314\python.exe"
set "PYTHONW_EXE=C:\Python314\pythonw.exe"
set "BASE_DIR=C:\coze-scheduler\claw_bridge"
set "GUARD_PY=%BASE_DIR%\claw_bridge_guard.py"
set "TASK_NAME=ClawBridgeGuard"

echo === ClawBridgeGuard v1.1 installer ===

if not exist "%BASE_DIR%" mkdir "%BASE_DIR%"

if not exist "%PYTHON_EXE%" (
    echo [ERR] Python not found at %PYTHON_EXE%
    pause
    exit /b 1
)
echo [OK] Python: %PYTHON_EXE%
%PYTHON_EXE% --version

if not exist "claw_bridge_guard.py" (
    echo [ERR] claw_bridge_guard.py not found in current dir
    pause
    exit /b 1
)
copy /Y "claw_bridge_guard.py" "%GUARD_PY%" >nul
echo [OK] Copied guard.py to %GUARD_PY%

REM --- 写 GITHUB_PAT（用户在同目录建 pat.txt 粘贴 PAT）---
set "GH_TOKEN_VALUE="
if exist "pat.txt" (
    for /f "usebackq delims=" %%i in ("pat.txt") do set "GH_TOKEN_VALUE=%%i"
    echo [OK] pat.txt loaded, len=DEFINED
) else (
    echo [WARN] pat.txt not found. guard will skip GitHub push.
)

REM --- 杀旧 guard 进程 ---
echo === Killing old guard (if any) ===
taskkill /F /IM claw_bridge_guard.exe 2>nul
taskkill /F /IM ClawBridgeGuard.exe 2>nul
timeout /t 2 /nobreak >nul

REM --- 写 GITHUB_PAT 到系统环境变量（user 级） ---
if defined GH_TOKEN_VALUE (
    echo === Setting GITHUB_PAT user env var ===
    setx GITHUB_PAT "!GH_TOKEN_VALUE!" >nul
    if !errorlevel! neq 0 (
        echo [WARN] setx GITHUB_PAT failed, guard may not push
    ) else (
        echo [OK] GITHUB_PAT user env var set (re-login required for new sessions)
    )
)

REM --- 杀旧守护 + 旧 remote ---
echo === Killing old remote processes ===
taskkill /F /IM winremote-mcp.exe 2>nul
taskkill /F /IM cloudflared.exe 2>nul
timeout /t 2 /nobreak >nul

REM --- 创建计划任务 ---
echo === Creating scheduled task ===
schtasks /delete /tn "%TASK_NAME%" /f 2>nul
schtasks /create ^
    /tn "%TASK_NAME%" ^
    /tr "\"%PYTHONW_EXE%\" \"%GUARD_PY%\"" ^
    /sc onlogon ^
    /rl highest ^
    /f
if %errorlevel% neq 0 (
    echo [ERR] schtasks /create failed
    pause
    exit /b 1
)
echo [OK] Task "%TASK_NAME%" created

REM --- 立即启动一次 ---
echo === Starting guard now ===
schtasks /run /tn "%TASK_NAME%"
timeout /t 3 /nobreak >nul

echo.
echo === DONE ===
echo 1. Guard runs in background (pythonw, no window)
echo 2. Log: %BASE_DIR%\guard.log
echo 3. State: %BASE_DIR%\guard_state.json
echo 4. URL output: %BASE_DIR%\current_url.txt
echo 5. OCR backup: %BASE_DIR%\current_url_ocr.txt
echo 6. To uninstall: schtasks /delete /tn "%TASK_NAME%" /f
echo.
echo NOTE: %TASK_NAME% scheduled task reads GITHUB_PAT user env var
echo       setx was used; if guard cannot push, re-login Windows first.
echo.

