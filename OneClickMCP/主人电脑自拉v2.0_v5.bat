@echo off
REM ============================================================
REM OneClickMCP v2.0 终极版自拉 BAT v5 (curl 56 Send failure reset 修)
REM 主 Agent 端 09:48 推 GitHub (铁律 4: 学完 4 源整合)
REM 上一版 v4 (5807b) 主人电脑拉报 curl 56 Connection was reset
REM 根因: Win 10 19041 schannel 跟 GitHub HTTP/2 中间代理协商不稳 (沙箱端验: --http1.1 0.43s vs 默认 15.7s 差 36 倍)
REM 救命参数 (curl 官方 + fixdevs + CSDN + agirlamonggeeks 4 源):
REM   --http1.1            (强制 HTTP/1.1, 避 schannel HTTP/2 协商不稳)
REM   --tls-max 1.2        (避 TLS 1.3 握手失败 - 09:26 坑)
REM   --ssl-no-revoke      (避 CRL 拉不到 - 09:35 学习)
REM   --connect-timeout 15 (TCP 握手 15s, 比 10s 宽容)
REM   --max-time 90        (整个 90s, 比 60s 宽容)
REM   --retry 5            (5 次重试, 比 3 次稳)
REM   --retry-delay 3      (3s 间隔)
REM   --retry-all-errors   (关键: 56 TCP 错也重试, curl 7.66+ 支持)
REM   --retry-connrefused  (连接拒绝也重试)
REM 备用通道: PowerShell HttpClient + BITS
REM ============================================================

setlocal enabledelayedexpansion
chcp 65001 >nul

set "DESKTOP=%USERPROFILE%\Desktop"
set "LOG=%DESKTOP%\OneClickMCP_自拉错误.log"
set "RAW_BASE=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/OneClickMCP"

echo ============================================================
echo OneClickMCP v2.0 终极版自拉 v5 (09:48 GitHub 推)
echo 救命参数: --http1.1 --tls-max 1.2 --ssl-no-revoke --connect-timeout 15 --max-time 90 --retry 5 --retry-delay 3 --retry-all-errors --retry-connrefused
echo 备用通道: curl ^> PowerShell ^> BITS
echo ============================================================
echo.

> "%LOG%" 2>nul

set "FILE_LIST=one_click_mcp.py|one_click_mcp.spec|build_oneclick.bat|拉OneClickMCP.bat|运行OneClickMCP.bat"
set "OK_COUNT=0"
set "FAIL_COUNT=0"

for %%F in ("%FILE_LIST:|=+=%") do (
    set "FN=%%F"
    call :url_encode "%%F" ENC
    set "URL=%RAW_BASE%/!ENC!"
    set "OUT=%DESKTOP%\!FN!"

    echo [拉] !FN!

    REM 首选: curl 9 个救命参数 (含 --http1.1 + --retry-all-errors)
    curl --http1.1 --tls-max 1.2 --ssl-no-revoke --connect-timeout 15 --max-time 90 --retry 5 --retry-delay 3 --retry-all-errors --retry-connrefused ^
         -sS -L -o "!OUT!" "!URL!"
    if !errorlevel! equ 0 (
        for %%S in ("!OUT!") do (
            if %%~zS gtr 100 (
                echo     [OK] curl 成功 (%%~zS bytes)
                set /a OK_COUNT+=1
            ) else (
                echo     [WARN] curl 文件太小 (%%~zS bytes), PowerShell
                goto :try_powershell
            )
        )
    ) else (
        echo     [FAIL] curl errorlevel=!errorlevel!, PowerShell fallback...
        :try_powershell
        powershell -NoProfile -Command "$ErrorActionPreference='Stop'; try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!URL!' -OutFile '!OUT!' -UseBasicParsing; 'OK' } catch { 'FAIL: ' + $_.Exception.Message }" > "%TEMP%\ps_result.txt" 2>&1
        findstr /C:"OK" "%TEMP%\ps_result.txt" >nul
        if !errorlevel! equ 0 (
            for %%S in ("!OUT!") do (
                if %%~zS gtr 100 (
                    echo     [OK] PowerShell 成功 (%%~zS bytes)
                    set /a OK_COUNT+=1
                ) else (
                    echo     [WARN] PowerShell 文件太小, BITS
                    goto :try_bits
                )
            )
        ) else (
            echo     [FAIL] PowerShell: 
            type "%TEMP%\ps_result.txt"
            echo     BITS fallback...
            :try_bits
            powershell -NoProfile -Command "Start-BitsTransfer -Source '!URL!' -Destination '!OUT!'" > "%TEMP%\bits_result.txt" 2>&1
            if !errorlevel! equ 0 (
                for %%S in ("!OUT!") do (
                    if %%~zS gtr 100 (
                        echo     [OK] BITS 成功 (%%~zS bytes)
                        set /a OK_COUNT+=1
                    ) else (
                        echo     [FAIL] BITS 文件太小
                        echo [FAIL] !FN! BITS 文件太小 >> "%LOG%"
                        set /a FAIL_COUNT+=1
                    )
                )
            ) else (
                echo     [FAIL] BITS 失败
                type "%TEMP%\bits_result.txt"
                echo [FAIL] !FN! 三道防线全失败 >> "%LOG%"
                echo       URL: !URL! >> "%LOG%"
                echo       curl: errorlevel=!errorlevel! >> "%LOG%"
                type "%TEMP%\ps_result.txt" >> "%LOG%" 2>nul
                type "%TEMP%\bits_result.txt" >> "%LOG%" 2>nul
                echo. >> "%LOG%"
                set /a FAIL_COUNT+=1
            )
        )
    )
    echo.
)

echo ============================================================
echo 下载汇总: OK=!OK_COUNT!, FAIL=!FAIL_COUNT!
echo ============================================================

if !FAIL_COUNT! gtr 0 (
    echo.
    echo [ERROR] !FAIL_COUNT! 个文件下载失败!
    echo 错误日志: %LOG%
    echo 请把日志发给主 Agent 端。
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] 5 个文件全部下载到桌面!
echo 下一步:
echo   1. cmd: setx GH_PAT "你的Token"
echo   2. 双击 build_oneclick.bat 打 EXE
echo   3. 双击 运行OneClickMCP.bat 启 EXE
echo.
pause
exit /b 0

:url_encode
set "_INPUT=%~1"
for /f "delims=" %%E in ('powershell -NoProfile -Command "[uri]::EscapeDataString('%_INPUT%')"') do (
    set "%2=%%E"
)
goto :eof
