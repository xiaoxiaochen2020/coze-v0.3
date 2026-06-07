@echo off
REM ============================================================
REM  ClawBridgeGuard v1.0 - PyInstaller 打包脚本
REM  主人电脑自己跑：C:\Python314\python.exe -m pip install pyinstaller
REM                   然后 build_exe.bat
REM  输出：dist\ClawBridgeGuard.exe (~8-10 MB)
REM ============================================================

setlocal

set "PYTHON_EXE=C:\Python314\python.exe"
set "SCRIPT=claw_bridge_guard.py"
set "EXE_NAME=ClawBridgeGuard"

echo === ClawBridgeGuard v1.0 build ===

REM --- 0) Python 检测 ---
if not exist "%PYTHON_EXE%" (
    echo [ERR] Python not found at %PYTHON_EXE%
    pause
    exit /b 1
)
echo [OK] Python: %PYTHON_EXE%
%PYTHON_EXE% --version

REM --- 1) 安装 PyInstaller ---
echo === Installing PyInstaller ===
%PYTHON_EXE% -m pip install --upgrade pip >nul 2>&1
%PYTHON_EXE% -m pip install pyinstaller
if %errorlevel% neq 0 (
    echo [ERR] pip install pyinstaller failed
    pause
    exit /b 1
)

REM --- 2) 清理旧构建 ---
if exist "build" rmdir /S /Q "build"
if exist "dist"  rmdir /S /Q "dist"
if exist "%EXE_NAME%.spec" del /Q "%EXE_NAME%.spec"

REM --- 3) PyInstaller 打包 ---
echo === PyInstaller --onefile ===
%PYTHON_EXE% -m PyInstaller ^
    --onefile ^
    --name "%EXE_NAME%" ^
    --console ^
    --clean ^
    "%SCRIPT%"

if %errorlevel% neq 0 (
    echo [ERR] PyInstaller failed
    pause
    exit /b 1
)

REM --- 4) 验证 EXE ---
if not exist "dist\%EXE_NAME%.exe" (
    echo [ERR] dist\%EXE_NAME%.exe not found
    pause
    exit /b 1
)

echo.
echo === BUILD SUCCESS ===
echo EXE: dist\%EXE_NAME%.exe
dir "dist\%EXE_NAME%.exe"
echo.
echo Next: run install.bat to install as scheduled task.
pause
