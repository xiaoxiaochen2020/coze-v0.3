@echo off
REM ===== ClawBridgeGuard v2.0 build =====
REM 沙箱/主人电脑用：pip install pyinstaller + 打 EXE → dist\ClawBridgeGuard.exe
REM 必须在和 claw_bridge_guard.py 同目录执行

setlocal
cd /d "%~dp0"

echo ============================================
echo  ClawBridgeGuard v2.0 builder
echo  %date% %time%
echo ============================================

if not exist "claw_bridge_guard.py" (
    echo [ERR] claw_bridge_guard.py not found
    exit /b 1
)

REM --- 1. pip install pyinstaller ---
echo [STEP 1] pip install pyinstaller
python -m pip install --upgrade pip >nul 2>&1
python -m pip install pyinstaller >nul 2>&1
if errorlevel 1 (
    echo [ERR] pip install pyinstaller 失败
    exit /b 1
)
echo [STEP 1] OK

REM --- 2. 清理旧 build ---
if exist "build" rmdir /s /q "build"
if exist "dist" rmdir /s /q "dist"
if exist "ClawBridgeGuard.spec" del /q "ClawBridgeGuard.spec"

REM --- 3. pyinstaller ---
echo [STEP 2] pyinstaller --onefile --console
python -m PyInstaller --onefile --name ClawBridgeGuard --console --clean claw_bridge_guard.py
if errorlevel 1 (
    echo [ERR] pyinstaller 失败
    exit /b 1
)
if not exist "dist\ClawBridgeGuard.exe" (
    echo [ERR] dist\ClawBridgeGuard.exe 未生成
    exit /b 1
)
echo [STEP 2] OK
echo.
echo ============================================
echo  [DONE] dist\ClawBridgeGuard.exe 已生成
echo  用 install.bat 安装运行
echo ============================================

endlocal
exit /b 0
