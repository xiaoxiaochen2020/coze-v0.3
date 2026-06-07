@echo off
REM ============================================================
REM  ClawBridgeGuard v1.1 - PyInstaller 打包脚本
REM ============================================================

setlocal

set "PYTHON_EXE=C:\Python314\python.exe"
set "SCRIPT=claw_bridge_guard.py"
set "EXE_NAME=ClawBridgeGuard"

echo === ClawBridgeGuard v1.1 build ===

if not exist "%PYTHON_EXE%" (
    echo [ERR] Python not found at %PYTHON_EXE%
    pause
    exit /b 1
)
echo [OK] Python: %PYTHON_EXE%
%PYTHON_EXE% --version

echo === Installing PyInstaller ===
%PYTHON_EXE% -m pip install --upgrade pip >nul 2>&1
%PYTHON_EXE% -m pip install pyinstaller
if %errorlevel% neq 0 (
    echo [ERR] pip install pyinstaller failed
    pause
    exit /b 1
)

if exist "build" rmdir /S /Q "build"
if exist "dist"  rmdir /S /Q "dist"
if exist "%EXE_NAME%.spec" del /Q "%EXE_NAME%.spec"

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
