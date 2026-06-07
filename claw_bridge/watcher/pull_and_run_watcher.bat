@echo off
chcp 437 >nul
setlocal
set URL=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/claw_bridge/watcher/setup_watcher.bat
set DST=C:\Users\Administrator\Desktop\setup_watcher.bat
set RAW_DIR=C:\coze-scheduler\claw_bridge\raw

echo === pull to Desktop (for double-click) ===
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%DST%' -UseBasicParsing; 'OK_DESKTOP size=' + (Get-Item '%DST%').Length } catch { 'FAIL_DESKTOP: ' + $_.Exception.Message }"

echo.
echo === pull to BASE_DIR\raw\ (backup, runnable from cmd) ===
if not exist "%RAW_DIR%" mkdir "%RAW_DIR%"
set DST2=%RAW_DIR%\setup_watcher.bat
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%DST2%' -UseBasicParsing; 'OK_BASE size=' + (Get-Item '%DST2%').Length } catch { 'FAIL_BASE: ' + $_.Exception.Message }"

echo.
echo === verify both files exist ===
if exist "%DST%" (echo DESKTOP_EXIST size=%z% & for %%A in ("%DST%") do @echo size=%%~zA) else (echo DESKTOP_MISSING)
if exist "%DST2%" (for %%A in ("%DST2%") do @echo BASE_EXIST size=%%~zA) else (echo BASE_MISSING)

echo.
echo === run setup_watcher from BASE_DIR (auto run) ===
if exist "%DST2%" call "%DST2%"

echo.
echo === final state ===
tasklist /FI "IMAGENAME eq pythonw.exe" /FO LIST | findstr /B "PID:"
if exist C:\coze-scheduler\claw_bridge\watcher.log powershell -NoProfile -Command "Get-Content 'C:\coze-scheduler\claw_bridge\watcher.log' -Tail 5"

pause
