@echo off
chcp 437 >nul
setlocal
set PY=C:\Python314\pythonw.exe
set WATCHER=C:\coze-scheduler\claw_bridge\github_watcher.py
set TASKNAME=ClawBridgeGitHubWatcher

echo === Stop old task (if any) ===
schtasks /delete /tn %TASKNAME% /f >nul 2>&1

echo === Copy watcher.py to BASE_DIR ===
if not exist C:\coze-scheduler\claw_bridge mkdir C:\coze-scheduler\claw_bridge
copy /Y "%~dp0github_watcher.py" "%WATCHER%" >nul
if errorlevel 1 (
    echo [X] copy failed
    pause
    exit /b 1
)

echo === Kill old watcher process (if any) ===
for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq pythonw.exe" /FO LIST ^| findstr /B "PID:"') do (
    wmic process where "ProcessId=%%p" get CommandLine /FORMAT:LIST 2>nul | findstr /C:"github_watcher.py" >nul
    if not errorlevel 1 taskkill /F /PID %%p >nul 2>&1
)

echo === Create scheduled task (start at logon, restart on fail) ===
schtasks /create /tn %TASKNAME% /tr "\"%PY%\" \"%WATCHER%\"" /sc onlogon /rl highest /f >nul
if errorlevel 1 (
    echo [X] task create failed
    pause
    exit /b 1
)

echo === Start watcher now ===
schtasks /run /tn %TASKNAME% >nul
timeout /t 3 /nobreak >nul

echo === Verify process running ===
tasklist /FI "IMAGENAME eq pythonw.exe" /FO LIST | findstr /B "PID:"

echo === Verify log starts ===
if exist C:\coze-scheduler\claw_bridge\watcher.log (
    powershell -NoProfile -Command "Get-Content 'C:\coze-scheduler\claw_bridge\watcher.log' -Tail 3"
)

echo.
echo === DONE ===
echo 1. Watcher runs in background (pythonw, no window)
echo 2. To push from agent: upload .bat to GitHub xiaoxiaochen2020/coze-v0.3
echo    path: claw_bridge/pending_trigger/anyname.bat
echo 3. Watcher detects within 45s, pulls to pending\, watchdog runs within 60s
echo 4. Result at C:\coze-scheduler\claw_bridge\result\
pause
