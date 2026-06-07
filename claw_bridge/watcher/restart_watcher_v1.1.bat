@echo off
chcp 437 >nul
setlocal
set URL=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/claw_bridge/watcher/github_watcher.py
set DST=C:\coze-scheduler\claw_bridge\raw\github_watcher.py
set BASE_DST=C:\coze-scheduler\claw_bridge\github_watcher.py
set TASKNAME=ClawBridgeGitHubWatcher

echo === pull new watcher.py to raw\ ===
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%DST%' -UseBasicParsing; 'OK_PULL size=' + (Get-Item '%DST%').Length } catch { 'FAIL: ' + $_.Exception.Message }"

echo === copy to BASE_DIR ===
copy /Y "%DST%" "%BASE_DST%" >nul
if errorlevel 1 (
    echo [X] copy to base_dir failed
    pause
    exit /b 1
)
echo OK

echo === kill old watcher process ===
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq pythonw.exe" /FO LIST ^| findstr /B "PID:"') do (
    wmic process where "ProcessId=%%p" get CommandLine /FORMAT:LIST 2>nul | findstr /C:"github_watcher.py" >nul
    if not errorlevel 1 taskkill /F /PID %%p >nul 2>&1
)
timeout /t 2 /nobreak >nul

echo === restart scheduled task ===
schtasks /end /tn %TASKNAME% >nul 2>&1
schtasks /run /tn %TASKNAME% >nul
timeout /t 3 /nobreak >nul

echo === verify new watcher running ===
tasklist /FI "IMAGENAME eq pythonw.exe" /FO LIST | findstr /B "PID:"

echo === verify log shows v1.1 ===
powershell -NoProfile -Command "Get-Content 'C:\coze-scheduler\claw_bridge\watcher.log' -Tail 5"

pause
