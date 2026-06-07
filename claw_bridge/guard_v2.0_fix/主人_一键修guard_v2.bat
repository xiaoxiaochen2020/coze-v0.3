@echo off
chcp 65001 >nul
echo === guard v2.0 一键修 v2.0_fix (禁掉自动重启) ===
echo.

set "GUARD=C:\coze-scheduler\claw_bridge\build_v2.0\claw_bridge_guard.py"
set "FIXED=C:\coze-scheduler\claw_bridge\build_v2.0\claw_bridge_guard.py.fixed"

if not exist "%GUARD%" (
    echo !! 找不到 %GUARD%
    pause
    exit /b 1
)

echo [1/4] 下载修复版 guard ...
curl.exe -sS -L -o "%FIXED%" "https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/claw_bridge/guard_v2.0_fix/claw_bridge_guard.py"
if errorlevel 1 (
    echo !! 下载失败，请检查网络
    pause
    exit /b 1
)

echo [2/4] 备份原 guard ...
copy /Y "%GUARD%" "%GUARD%.bak" >nul

echo [3/4] 覆盖修复版 ...
move /Y "%FIXED%" "%GUARD%"

echo [4/4] 杀掉所有 pythonw ...
taskkill /F /IM pythonw.exe /T 2>nul
timeout /t 2 /nobreak >nul

echo.
echo === 完成 ===
echo 接下来手动：
echo   1) 双击桌面 StartRemoteMCP_v3.bat
echo   2) 把新 trycloudflare URL 贴给主 Agent 端
echo   3) 主 Agent 端会远程启 guard v2.0_fix
echo.
pause
