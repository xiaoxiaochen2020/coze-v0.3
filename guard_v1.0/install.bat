@echo off
REM ============================================================
REM  ClawBridgeGuard v1.0 - 主人电脑一键安装脚本
REM  1) 检测 Python
REM  2) 安装依赖（requests / pyinstaller 由 build_exe.bat 处理）
REM  3) 复制 guard.py 到 C:\coze-scheduler\claw_bridge\
REM  4) 创建计划任务（开机自启 + 失败重启）
REM ============================================================

setlocal enabledelayedexpansion

set "PYTHON_EXE=C:\Python314\python.exe"
set "PYTHONW_EXE=C:\Python314\pythonw.exe"
set "BASE_DIR=C:\coze-scheduler\claw_bridge"
set "GUARD_PY=%BASE_DIR%\claw_bridge_guard.py"
set "TASK_NAME=ClawBridgeGuard"

echo === ClawBridgeGuard v1.0 installer ===

REM --- 0) 路径 ---
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%"

REM --- 1) Python 检测 ---
if not exist "%PYTHON_EXE%" (
    echo [ERR] Python not found at %PYTHON_EXE%
    echo       Please install Python 3.10+ and ensure C:\Python314 exists.
    pause
    exit /b 1
)
echo [OK] Python: %PYTHON_EXE%
%PYTHON_EXE% --version

REM --- 2) 复制 guard.py ---
if not exist "claw_bridge_guard.py" (
    echo [ERR] claw_bridge_guard.py not found in current dir
    echo       Run this from the folder where the script is.
    pause
    exit /b 1
)
copy /Y "claw_bridge_guard.py" "%GUARD_PY%" >nul
echo [OK] Copied guard.py to %GUARD_PY%

REM --- 3) 写 GITHUB_PAT 环境变量（用户在 install.bat 同目录建 pat.txt）---
if exist "pat.txt" (
    set /p GH_TOKEN=<pat.txt
    echo [OK] pat.txt loaded, len=!GH_TOKEN_LEN:~0,6!...
) else (
    echo [WARN] pat.txt not found. guard will skip GitHub push until you set GITHUB_PAT env var.
)

REM --- 4) 杀旧 guard 进程 ---
echo === Killing old guard (if any) ===
taskkill /F /IM claw_bridge_guard.exe 2>nul
taskkill /F /IM ClawBridgeGuard.exe 2>nul
timeout /t 2 /nobreak >nul

REM --- 5) 创建计划任务 ---
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

REM --- 6) 立即启动一次 ---
echo === Starting guard now ===
schtasks /run /tn "%TASK_NAME%"
timeout /t 3 /nobreak >nul

echo.
echo === DONE ===
echo 1. Guard runs in background (pythonw, no window)
echo 2. Log: %BASE_DIR%\guard.log
echo 3. State: %BASE_DIR%\guard_state.json
echo 4. To uninstall: schtasks /delete /tn "%TASK_NAME%" /f
echo.
pause
