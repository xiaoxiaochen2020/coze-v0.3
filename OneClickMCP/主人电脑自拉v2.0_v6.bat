@echo off
REM ============================================================
REM OneClickMCP v2.0 终极版自拉 BAT v6 (兼容老 curl 7.55.1 - Win 10 19041 默认)
REM 主 Agent 端 09:53 推 GitHub (铁律 4: 学完 4 源整合)
REM 上一版 v5 (5613b) 主人电脑报 "--retry-all-errors: is unknown" + 可能 "--tls-max 1.2" 也不认
REM 根因: Win 10 19041 默认 curl 7.55.1 (2017-08), 而:
REM   --tls-max            加于 7.66.0 (2019-09)  <- 不认
REM   --retry-all-errors   加于 7.66.0 (2019-09)  <- 不认
REM   --retry-connrefused  加于 7.66.0 (2019-09)  <- 不认
REM   --http1.1            OK 7.55+
REM   --ssl-no-revoke      OK 7.55+
REM   --connect-timeout    OK 7.55+
REM   --max-time           OK 7.55+
REM   --retry              OK 7.55+
REM   --retry-delay        OK 7.55+
REM 来源: curl.se/ch/7.66.0.html + curl.se/windows/microsoft.html + pg-fl.jp/doscmd/curl.en.htm
REM
REM 设计: 先探测 curl 版本
REM   7.66+ (新 curl)  -> 走完整 9 救命参数
REM   < 7.66  (老 curl) -> 走 5 老兼容参数 + 优先 PowerShell fallback
REM 备用通道: PowerShell HttpClient (主) + BITS
REM ============================================================

setlocal enabledelayedexpansion
chcp 65001 >nul

set "DESKTOP=%USERPROFILE%\Desktop"
set "LOG=%DESKTOP%\OneClickMCP_自拉错误.log"
set "RAW_BASE=https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/OneClickMCP"

echo ============================================================
echo OneClickMCP v2.0 终极版自拉 v6 (09:53 GitHub 推)
echo 兼容老 curl 7.55.1 (Win 10 19041 默认), 新 curl 自动用 9 救命参数
echo ============================================================
echo.

> "%LOG%" 2>nul

REM 探测 curl 版本
for /f "delims=" %%V in ('curl --version 2^>nul') do (
    set "CURL_VER_LINE=%%V"
    goto :got_curl_ver
)
:got_curl_ver
REM 提取 "curl 7.x" 数字
set "CURL_MAJOR=0"
set "CURL_MINOR=0"
for /f "tokens=2 delims=." %%A in ("!CURL_VER_LINE!") do set "CURL_MAJOR=%%A"
for /f "tokens=3 delims= " %%B in ("!CURL_VER_LINE!") do set "CURL_MINOR=%%B"
echo 探测到 curl 版本: !CURL_VER_LINE!

REM 判断版本
set "USE_NEW_PARAMS=0"
if !CURL_MAJOR! gtr 7 set "USE_NEW_PARAMS=1"
if !CURL_MAJOR! equ 7 if !CURL_MINOR! geq 66 set "USE_NEW_PARAMS=1"

if !USE_NEW_PARAMS! equ 1 (
    echo [OK] curl 7.66+ 检测通过, 走完整 9 救命参数
    set "CURL_OPTS=--http1.1 --tls-max 1.2 --ssl-no-revoke --connect-timeout 15 --max-time 90 --retry 5 --retry-delay 3 --retry-all-errors --retry-connrefused"
) else (
    echo [WARN] curl 7.55-7.65 太老, 不支持 --tls-max/--retry-all-errors/--retry-connrefused
    echo        走 5 老兼容参数 + 优先 PowerShell fallback
    set "CURL_OPTS=--http1.1 --ssl-no-revoke --connect-timeout 15 --max-time 90 --retry 5"
)
echo 使用的 curl 参数: !CURL_OPTS!
echo.

set "FILE_LIST=one_click_mcp.py|one_click_mcp.spec|build_oneclick.bat|拉OneClickMCP.bat|运行OneClickMCP.bat"
set "OK_COUNT=0"
set "FAIL_COUNT=0"

for %%F in ("%FILE_LIST:|=+=%") do (
    set "FN=%%F"
    call :url_encode "%%F" ENC
    set "URL=%RAW_BASE%/!ENC!"
    set "OUT=%DESKTOP%\!FN!"

    echo [拉] !FN!

    REM 首选: curl (新/老参数按版本自适应)
    curl !CURL_OPTS! -sS -L -o "!OUT!" "!URL!"
    if !errorlevel! equ 0 (
        for %%S in ("!OUT!") do (
            if %%~zS gtr 100 (
                echo     [OK] curl 成功 (%%~zS bytes)
                set /a OK_COUNT+=1
                goto :file_done
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
                    goto :file_done
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
                        goto :file_done
                    ) else (
                        echo     [FAIL] BITS 文件太小
                        echo [FAIL] !FN! BITS 文件太小 >> "%LOG%"
                        set /a FAIL_COUNT+=1
                        goto :file_done
                    )
                )
            ) else (
                echo     [FAIL] BITS 失败
                type "%TEMP%\bits_result.txt"
                echo [FAIL] !FN! 三道防线全失败 >> "%LOG%"
                echo       URL: !URL! >> "%LOG%"
                echo       curl: errorlevel=!errorlevel! >> "%LOG%"
                echo       curl 版本: !CURL_VER_LINE! >> "%LOG%"
                type "%TEMP%\ps_result.txt" >> "%LOG%" 2>nul
                type "%TEMP%\bits_result.txt" >> "%LOG%" 2>nul
                echo. >> "%LOG%"
                set /a FAIL_COUNT+=1
            )
        )
    )
    :file_done
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
