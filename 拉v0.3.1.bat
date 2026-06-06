@echo off
chcp 65001 >nul
REM ============================================================
REM 拉 v0.3.1（修 [hidden] CSS 覆盖 bug + ESC/遮罩关闭 + 错误带 statusText）
REM 走 GitHub raw URL，避开脆弱的 MCP 通道
REM
REM 用法：把这个 BAT 放在任意位置双击即可
REM       BAT 会自动：1) 把自己复制到桌面
REM                   2) 探测 OpenClaw 目录（C:\coze-scheduler\OpenClaw 或 D:\coze-scheduler\OpenClaw）
REM                   3) 从 GitHub raw URL 拉 3 文件
REM                   4) 关键字串验活
REM ============================================================
setlocal

set "BASE=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/app/static"
set "DESK=%USERPROFILE%\Desktop"

REM --- 1) 复制自己到桌面（如果不在桌面）---
echo [STEP 1] 复制 BAT 到桌面
set "MY_PATH=%~f0"
set "DESK_BAT=%DESK%\拉v0.3.1.bat"
if /i not "%MY_PATH%"=="%DESK_BAT%" (
  copy /Y "%MY_PATH%" "%DESK_BAT%" >nul
  if errorlevel 1 (
    echo   [WARN] 复制到桌面失败：%DESK_BAT%
  ) else (
    echo   [OK]   桌面入口已就位：%DESK_BAT%
  )
) else (
  echo   [OK]   已在桌面
)

REM --- 2) 探测 OpenClaw 目录 ---
echo.
echo [STEP 2] 探测 OpenClaw 目录
set "TARGET="
for %%D in (C D E F) do (
  if exist "%%D:\coze-scheduler\OpenClaw\app\static" set "TARGET=%%D:\coze-scheduler\OpenClaw\app\static"
)
if "%TARGET%"=="" (
  echo   [ERR] 没找到 OpenClaw\app\static（C/D/E/F 盘都试过）
  echo   请确认 OpenClaw 装在哪个目录
  pause
  exit /b 1
)
echo   [OK] 找到：%TARGET%

REM --- 3) 拉 3 文件 ---
echo.
echo [STEP 3] 从 GitHub 拉 3 文件到 %TARGET%
set "FAIL=0"
for %%F in (index.html app.css app.js) do (
  echo   --- 下载 %%F ---
  curl.exe -sS -L -o "%TARGET%\%%F" "%BASE%/%%F"
  if errorlevel 1 (
    echo     [FAIL] %%F 下载失败
    set "FAIL=1"
  ) else (
    echo     [OK]   %%F 已覆盖
  )
)
if "%FAIL%"=="1" (
  echo.
  echo   [ERR] 有文件下载失败，主人电脑可能访问不到 raw.githubusercontent.com
  echo   试开浏览器：https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/app/static/index.html
  pause
  exit /b 1
)

REM --- 4) 关键字串验活 ---
echo.
echo [STEP 4] 验活（grep 关键字串）
findstr /C:"?v=0.3.1" "%TARGET%\index.html" >nul && echo   [OK] index.html 含 ?v=0.3.1 || echo   [FAIL] index.html
findstr /C:"[hidden] { display: none !important; }" "%TARGET%\app.css" >nul && echo   [OK] app.css 含 [hidden] !important || echo   [FAIL] app.css
findstr /C:"Escape" "%TARGET%\app.js" >nul && echo   [OK] app.js 含 ESC 关闭 || echo   [FAIL] app.js

echo.
echo ============================================
echo   拉完。桌面入口：%DESK_BAT%
echo   强刷浏览器：http://127.0.0.1:8765/  (Ctrl+F5)
echo   测 4 件：ESC 关弹窗 / 遮罩关弹窗 / 取消按钮 / 保存切换
echo ============================================
echo.
pause
endlocal
