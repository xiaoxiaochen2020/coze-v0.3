@echo off
chcp 65001 >nul
REM 主人 2026-06-07 07:52 立 D 方案
REM 用 --onedir 重打 StartMCPGuard EXE (修 Not enough memory)
REM 输出: C:\coze-scheduler\StartMCPGuard\dist\StartMCPGuard\StartMCPGuard.exe

REM 检查 pyinstaller
where pyinstaller >nul 2>&1
if errorlevel 1 (
    echo pyinstaller 不在 PATH, 用绝对路径
    set PYI="C:\Users\Administrator\AppData\Roaming\Python\Python314\Scripts\pyinstaller.exe"
) else (
    set PYI=pyinstaller
)

REM 检查 .py 存在
if not exist "C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py" (
    echo X start_mcp_guard.py 不存在, 先双击 拉v1.7.bat
    pause
    exit /b 1
)

cd /d "C:\coze-scheduler\StartMCPGuard"

REM 清理旧产物
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
if exist StartMCPGuard.spec del StartMCPGuard.spec

echo === 装 pyinstaller (--user) ===
python -m pip install --user pyinstaller
if errorlevel 1 (
    echo X pip install 失败
    pause
    exit /b 1
)

echo.
echo === 打包 (--onedir --noconsole) ===
%PYI% --onedir --noconsole --name StartMCPGuard --distpath C:\coze-scheduler\StartMCPGuard\dist --workpath C:\coze-scheduler\StartMCPGuard\build --specpath C:\coze-scheduler\StartMCPGuard C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py
if errorlevel 1 (
    echo X 打包失败
    pause
    exit /b 1
)

echo.
echo === 验活 ===
if exist "C:\coze-scheduler\StartMCPGuard\dist\StartMCPGuard\StartMCPGuard.exe" (
    echo + EXE 已生成
    dir "C:\coze-scheduler\StartMCPGuard\dist\StartMCPGuard\StartMCPGuard.exe"
) else (
    echo X EXE 没生成
    pause
    exit /b 1
)

echo.
echo === 下一步 ===
echo 1. 测 EXE: 双击 桌面 运行StartMCPGuard_onedir.bat (主人电脑先拉)
echo 2. 没黑框 = OK, 删旧的 运行StartMCPGuard.bat
echo.
pause
