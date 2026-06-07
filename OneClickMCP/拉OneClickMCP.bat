@echo off
chcp 65001 >nul
title 拉取 OneClickMCP v2.0 源码
echo ============================================
echo  拉取 OneClickMCP v2.0 (一键启 MCP)
echo ============================================
echo.

set "DEST_DIR=C:\coze-scheduler\StartMCPGuard"
set "OUTDIR=C:\coze-scheduler\OneClickMCP"
set "BASE=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/OneClickMCP"

if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

echo [1/3] 拉 v2.0 源码 + spec
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%BASE%/one_click_mcp.py' -OutFile '%DEST_DIR%\one_click_mcp.py' -UseBasicParsing -ErrorAction Stop; Write-Host '    [OK] one_click_mcp.py' } catch { Write-Host '    [FAIL]' $_.Exception.Message }"
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%BASE%/one_click_mcp.spec' -OutFile '%DEST_DIR%\one_click_mcp.spec' -UseBasicParsing -ErrorAction Stop; Write-Host '    [OK] one_click_mcp.spec' } catch { Write-Host '    [FAIL]' $_.Exception.Message }"

echo.
echo [2/3] 拉 build_oneclick.bat
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%BASE%/build_oneclick.bat' -OutFile '%OUTDIR%\build_oneclick.bat' -UseBasicParsing -ErrorAction Stop; Write-Host '    [OK] build_oneclick.bat' } catch { Write-Host '    [FAIL]' $_.Exception.Message }"

echo.
echo [3/3] 验活
findstr /C:"OneClickMCP v2.0" "%DEST_DIR%\one_click_mcp.py" >nul && echo     [OK] one_click_mcp.py 关键字 || echo     [FAIL] one_click_mcp.py 关键字
findstr /C:"exclude_binaries=True" "%DEST_DIR%\one_click_mcp.spec" >nul && echo     [OK] one_click_mcp.spec --onedir || echo     [FAIL] one_click_mcp.spec --onedir

echo.
echo ============================================
echo  拉取完成
echo  下一步:
echo    1. cmd 跑: setx GH_PAT "<你的 Classic PAT, ghp 开头>"
echo    2. 双击 桌面\build_oneclick.bat 打 EXE
echo    3. 双击 桌面\运行OneClickMCP.bat 启 EXE
echo ============================================
pause
