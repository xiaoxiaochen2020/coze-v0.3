@echo off
REM ===== ClawBridgeGuard v2.0 install =====
REM 主人电脑用：双击此 bat 安装 guard v2.0
REM 路径自定位（%~dp0）→ 主人双击从哪都行

setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================
echo  ClawBridgeGuard v2.0 installer
echo  %date% %time%
echo ============================================

REM --- 0. 自检文件 ---
if not exist "claw_bridge_guard.py" (
    echo [ERR] claw_bridge_guard.py not found in %cd%
    echo       请确认 install.bat 和 .py 在同目录
    exit /b 1
)

REM --- 1. 注入 GITHUB_PAT 到用户环境变量（持久，主人以后不用每次设）---
if defined GITHUB_PAT (
    echo [STEP 1] GITHUB_PAT 已在当前 session
) else (
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v GITHUB_PAT 2^>nul') do (
        set "GITHUB_PAT=%%b"
    )
    if defined GITHUB_PAT (
        echo [STEP 1] GITHUB_PAT 已在用户环境变量
    ) else (
        echo.
        echo ============================================================
        echo  [NEED] 请输入 GitHub Personal Access Token (ghp_ 开头)
        echo         用途: guard 推 URL 状态 + 轮询 inbox 命令
        echo         创建: https://github.com/settings/tokens ^&^& 勾 repo
        echo ============================================================
        set /p "GITHUB_PAT=PAT> "
        if not defined GITHUB_PAT (
            echo [ERR] 未输入 PAT，中止安装
            exit /b 1
        )
        setx GITHUB_PAT "%GITHUB_PAT%" >nul
        if !errorlevel! neq 0 (
            echo [ERR] setx 失败
            exit /b 1
        )
        echo [STEP 1] GITHUB_PAT 已写入 HKCU\Environment（永久）
    )
)

REM --- 2. 创建工作目录 ---
if not exist "C:\coze-scheduler\claw_bridge" (
    mkdir "C:\coze-scheduler\claw_bridge"
    echo [STEP 2] mkdir C:\coze-scheduler\claw_bridge
) else (
    echo [STEP 2] C:\coze-scheduler\claw_bridge 已存在
)

REM --- 3. 复制 guard v2.0 源码到工作目录 ---
copy /Y "claw_bridge_guard.py" "C:\coze-scheduler\claw_bridge\claw_bridge_guard.py" >nul
if %errorlevel% neq 0 (
    echo [ERR] copy guard 源码失败
    exit /b 1
)
echo [STEP 3] guard v2.0 源码已复制

REM --- 4. 停止旧版 guard（如果有）---
taskkill /F /IM pythonw.exe /FI "WINDOWTITLE eq ClawBridgeGuard*" 2>nul >nul
taskkill /F /IM ClawBridgeGuard.exe 2>nul >nul
echo [STEP 4] 已停旧版 guard（如果有）

REM --- 5. 启动新 guard（用 EXE 优先，回退 pythonw）---
set "EXE_PATH=%~dp0dist\ClawBridgeGuard.exe"
if exist "%EXE_PATH%" (
    echo [STEP 5] 启动 EXE: %EXE_PATH%
    start "" "%EXE_PATH%"
) else (
    echo [STEP 5] EXE 不存在，用 pythonw 启动源码
    if exist "C:\Python314\pythonw.exe" (
        start "" "C:\Python314\pythonw.exe" "C:\coze-scheduler\claw_bridge\claw_bridge_guard.py"
    ) else (
        start "" pythonw "C:\coze-scheduler\claw_bridge\claw_bridge_guard.py"
    )
)

REM --- 6. 等待首次心跳 ---
echo [STEP 6] 等待 10s 让 guard 跑首次心跳推 GitHub...
timeout /t 10 /nobreak >nul

echo.
echo ============================================
echo  [DONE] ClawBridgeGuard v2.0 已启动
echo  日志: C:\coze-scheduler\claw_bridge\guard.log
echo  心跳: https://github.com/xiaoxiaochen2020/coze-v0.3/blob/main/claw_bridge/mcp_url.json
echo ============================================
echo.
echo 主人操作: 不需要任何操作
echo         云端 Agent 会自动通过 GitHub 指挥 guard
echo.

endlocal
exit /b 0
