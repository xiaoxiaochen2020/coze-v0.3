@echo off
chcp 65001 > nul
REM ============================================
REM  主人电脑自拉 v2.0 (OneClickMCP) 套件
REM  沙箱 DNS 拉黑, 主 Agent 端推不到, 主人电脑自拉
REM  2026-06-07 08:36 立
REM ============================================

setlocal

set BASE=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/OneClickMCP
set DST1=C:\coze-scheduler\StartMCPGuard
set DST2=C:\coze-scheduler\OneClickMCP
set DESK=%USERPROFILE%\Desktop

echo.
echo === 准备目录 ===
if not exist "%DST1%" mkdir "%DST1%"
if not exist "%DST2%" mkdir "%DST2%"

echo.
echo === 拉 v2.0 源码 (12209 bytes) ===
curl -sS --max-time 30 -L -o "%DST1%\one_click_mcp.py" "%BASE%/one_click_mcp.py"
if errorlevel 1 goto FAIL_SRC

echo.
echo === 拉 v2.0 spec (1613 bytes) ===
curl -sS --max-time 30 -L -o "%DST1%\one_click_mcp.spec" "%BASE%/one_click_mcp.spec"
if errorlevel 1 goto FAIL_SPEC

echo.
echo === 拉 build_oneclick.bat (1717 bytes) ===
curl -sS --max-time 30 -L -o "%DST2%\build_oneclick.bat" "%BASE%/build_oneclick.bat"
if errorlevel 1 goto FAIL_BUILD

echo.
echo === 拉 拉OneClickMCP.bat (2012 bytes) ===
curl -sS --max-time 30 -L -o "%DESK%\拉OneClickMCP.bat" "%BASE%/%E6%8B%89OneClickMCP.bat"
if errorlevel 1 goto FAIL_PULL

echo.
echo === 拉 运行OneClickMCP.bat (1587 bytes) ===
curl -sS --max-time 30 -L -o "%DESK%\运行OneClickMCP.bat" "%BASE%/%E8%BF%90%E8%A1%8COneClickMCP.bat"
if errorlevel 1 goto FAIL_RUN

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
goto :EOF

:FAIL_SRC
echo FAIL: 拉 one_click_mcp.py
exit /b 1
:FAIL_SPEC
echo FAIL: 拉 one_click_mcp.spec
exit /b 1
:FAIL_BUILD
echo FAIL: 拉 build_oneclick.bat
exit /b 1
:FAIL_PULL
echo FAIL: 拉 拉OneClickMCP.bat
exit /b 1
:FAIL_RUN
echo FAIL: 拉 运行OneClickMCP.bat
exit /b 1
