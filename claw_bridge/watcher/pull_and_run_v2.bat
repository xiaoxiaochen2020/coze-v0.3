@echo off
chcp 437 >nul
setlocal
set URL=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/claw_bridge/watcher/pull_and_run_watcher.bat
set DST=C:\coze-scheduler\claw_bridge\raw\pull_and_run_watcher.bat
set SETUP_URL=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/claw_bridge/watcher/setup_watcher.bat
set SETUP_DST=C:\coze-scheduler\claw_bridge\raw\setup_watcher.bat
set BASE=C:\coze-scheduler\claw_bridge
set RAW=%BASE%\raw

echo === mkdir raw dir ===
if not exist "%BASE%" (
    echo [X] BASE_DIR %BASE% missing, run setup_v2.bat first
    pause
    exit /b 1
)
if not exist "%RAW%" mkdir "%RAW%"
echo OK: %RAW%

echo === pull pull_and_run_watcher.bat ===
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%DST%' -UseBasicParsing; 'OK_PULL size=' + (Get-Item '%DST%').Length } catch { 'FAIL_PULL: ' + $_.Exception.Message }"

echo === pull setup_watcher.bat (standalone backup) ===
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%SETUP_URL%' -OutFile '%SETUP_DST%' -UseBasicParsing; 'OK_SETUP size=' + (Get-Item '%SETUP_DST%').Length } catch { 'FAIL_SETUP: ' + $_.Exception.Message }"

echo.
echo === run setup_watcher.bat ===
if exist "%SETUP_DST%" (
    call "%SETUP_DST%"
) else (
    echo [X] setup_watcher.bat missing, cannot run
)

echo.
echo === final state ===
tasklist /FI "IMAGENAME eq pythonw.exe" /FO LIST | findstr /B "PID:"
if exist "%BASE%\watcher.log" (
    echo --- watcher.log tail ---
    powershell -NoProfile -Command "Get-Content '%BASE%\watcher.log' -Tail 5"
) else (
    echo watcher.log not created
)

pause
