@echo off
chcp 65001 >nul
title 打包 OneClickMCP v2.0 (--onedir 修内存)
echo ============================================
echo  PyInstaller --onedir 打包 OneClickMCP v2.0
echo ============================================
echo.

set "PYTHON=C:\Python314\python.exe"
set "SCRIPT=C:\coze-scheduler\StartMCPGuard\one_click_mcp.py"
set "SPEC=C:\coze-scheduler\StartMCPGuard\one_click_mcp.spec"
set "OUTDIR=C:\coze-scheduler\OneClickMCP"
set "PYI=C:\Users\Administrator\AppData\Roaming\Python\Python314\Scripts\pyinstaller.exe"

if not exist "%PYTHON%" (
    echo [X] 找不到 python: %PYTHON%
    pause
    exit /b 1
)
if not exist "%SCRIPT%" (
    echo [X] 找不到 v2.0 源码, 请先双击 拉OneClickMCP.bat
    pause
    exit /b 1
)
if not exist "%PYI%" (
    echo [X] 找不到 pyinstaller, 先装: %PYTHON% -m pip install --user pyinstaller
    pause
    exit /b 1
)

echo [1/3] 杀旧 OneClickMCP
taskkill /F /IM OneClickMCP.exe 2>nul
timeout /t 2 /nobreak >nul

echo [2/3] 清旧 dist
if exist "%OUTDIR%\dist\OneClickMCP" rmdir /S /Q "%OUTDIR%\dist\OneClickMCP"
if exist "%OUTDIR%\build" rmdir /S /Q "%OUTDIR%\build"
if exist "%OUTDIR%\OneClickMCP.spec" del /Q "%OUTDIR%\OneClickMCP.spec"

echo [3/3] pyinstaller --onedir (走 spec, console=False, --noconsole 隐含)
cd /d "%OUTDIR%"
"%PYI%" --clean --noconfirm "%SPEC%"
if errorlevel 1 (
    echo.
    echo [X] 打包失败, 看上面错误
    pause
    exit /b 1
)

echo.
echo ============================================
echo  EXE 打包完成 (--onedir, 不一次性解压修内存)
echo  位置: %OUTDIR%\dist\OneClickMCP\OneClickMCP.exe
echo  下一步: 双击 桌面\运行OneClickMCP.bat
echo ============================================
pause
