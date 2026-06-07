@echo off
chcp 65001 > nul
REM ============================================
REM  主人电脑自拉 v2.0 (OneClickMCP) 套件 [DOUBLE-SAFE]
REM  curl schannel 失败自动 fallback PowerShell HttpClient
REM  2026-06-07 09:35 立
REM ============================================

setlocal

set BASE=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/OneClickMCP
set DST1=C:\coze-scheduler\StartMCPGuard
set DST2=C:\coze-scheduler\OneClickMCP
set DESK=%USERPROFILE%\Desktop
set PS_OK=0

REM ---------- 工具函数: 拉文件 (curl 先, 失败走 PowerShell) ----------
goto :MAIN

:PULL
REM 参数: %1=URL %2=输出路径 %3=标签
setlocal
set "URL=%~1"
set "OUT=%~2"
set "TAG=%~3"
echo.
echo === 拉 %TAG% ===
curl -sS --max-time 30 --tls-max 1.2 -L -o "%OUT%" "%URL%"
if not errorlevel 1 if exist "%OUT%" (
    for %%S in ("%OUT%") do echo   OK  %%~nxF  %%~zF bytes  (curl)
    endlocal & set "RET=0"
    goto :EOF
)
echo   curl 失败, fallback PowerShell HttpClient...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%URL%' -OutFile '%OUT%' -UseBasicParsing -ErrorAction Stop; exit 0 } catch { Write-Host ('  PS FAIL: ' + $_.Exception.Message); exit 1 }"
if not errorlevel 1 if exist "%OUT%" (
    for %%S in ("%OUT%") do echo   OK  %%~nxF  %%~zF bytes  (PowerShell)
    endlocal & set "RET=0"
    goto :EOF
)
echo   FAIL  %TAG%
endlocal & set "RET=1"
goto :EOF

:MAIN

echo.
echo === 准备目录 ===
if not exist "%DST1%" mkdir "%DST1%"
if not exist "%DST2%" mkdir "%DST2%"

call :PULL "%BASE%/one_click_mcp.py" "%DST1%\one_click_mcp.py" "v2.0 源码 (12209 bytes)"
if "%RET%"=="1" goto :FAIL

call :PULL "%BASE%/one_click_mcp.spec" "%DST1%\one_click_mcp.spec" "v2.0 spec (1613 bytes)"
if "%RET%"=="1" goto :FAIL

call :PULL "%BASE%/build_oneclick.bat" "%DST2%\build_oneclick.bat" "build_oneclick.bat (1717 bytes)"
if "%RET%"=="1" goto :FAIL

call :PULL "%BASE%/%E6%8B%89OneClickMCP.bat" "%DESK%\拉OneClickMCP.bat" "拉OneClickMCP.bat (2012 bytes)"
if "%RET%"=="1" goto :FAIL

call :PULL "%BASE%/%E8%BF%90%E8%A1%8COneClickMCP.bat" "%DESK%\运行OneClickMCP.bat" "运行OneClickMCP.bat (1587 bytes)"
if "%RET%"=="1" goto :FAIL

echo.
echo === 验证 ===
for %%F in (
  "%DST1%\one_click_mcp.py"
  "%DST1%\one_click_mcp.spec"
  "%DST2%\build_oneclick.bat"
  "%DESK%\拉OneClickMCP.bat"
  "%DESK%\运行OneClickMCP.bat"
) do (
  if exist %%F (
    for %%S in (%%F) do echo   %%~nxF  %%~zF bytes  OK
  ) else (
    echo   %%~nxF  MISSING
  )
)

echo.
echo === 完成 ===
echo  接下来 3 步:
echo   1. 一次性设 GH_PAT (新 cmd 跑, PAT 主 Agent 端给):
echo      setx GH_PAT "PASTE_PAT_FROM_AGENT"
echo   2. 打 EXE: 双击 C:\coze-scheduler\OneClickMCP\build_oneclick.bat
echo   3. 启 EXE: 双击桌面 运行OneClickMCP.bat
echo.
echo === 全部完成, 按任意键关闭窗口 ===
pause > nul
exit /b 0

:FAIL
echo.
echo === 全部失败, 按任意键退出, 请把上方错误截图给主 Agent 端 ===
pause
exit /b 1
