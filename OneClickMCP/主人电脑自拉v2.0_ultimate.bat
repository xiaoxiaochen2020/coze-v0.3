@echo off
REM ============================================================
REM OneClickMCP v2.0 终极版自拉 BAT (5 救命参数 + 3 备用通道)
REM 主 Agent 端 09:38 推 GitHub (SHA 待推)
REM 设计: curl 5 救命参数 (--tls-max 1.2 --ssl-no-revoke --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 2)
REM      + PowerShell HttpClient fallback + BITS fallback + 桌面错误日志
REM 救命优先级 (铁律 4): GitHub 学习 > 自己猜测修复
REM 已知坑: Win 10 19041 schannel 不支持 TLS 1.3, 必须 --tls-max 1.2
REM       + Schannel 默认查 CRL/OCSP, 必须 --ssl-no-revoke
REM       + BAT 失败必须 pause, 否则闪退无线索
REM ============================================================

setlocal enabledelayedexpansion
chcp 65001 >nul

REM 主人电脑桌面路径
set "DESKTOP=%USERPROFILE%\Desktop"
set "LOG=%DESKTOP%\OneClickMCP_自拉错误.log"
set "REPO=coze-v0.3"
set "BRANCH=main"
set "OWNER=xiaoxiaochen2020"
set "RAW_BASE=https://raw.githubusercontent.com/%OWNER%/%REPO%/%BRANCH%/OneClickMCP"

echo ============================================================
echo OneClickMCP v2.0 终极版自拉 (09:38 GitHub 推)
echo 救命参数: --tls-max 1.2 --ssl-no-revoke --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 2
echo 备用通道: curl ^> PowerShell ^> BITS
echo ============================================================
echo.

REM 清空旧错误日志
> "%LOG%" 2>nul

REM 5 个文件清单 (用 GBK URL 编码避免 BAT 中文转义坑)
set "FILE_LIST=one_click_mcp.py|one_click_mcp.spec|build_oneclick.bat|拉OneClickMCP.bat|运行OneClickMCP.bat"

REM 计数器
set "OK_COUNT=0"
set "FAIL_COUNT=0"

for %%F in ("%FILE_LIST:|=+=%") do (
    set "FN=%%F"
    set "ENC=%%F"
    REM 简单 URL 编码 (BAT 里的 Python 编码)
    call :url_encode "%%F" ENC
    set "URL=%RAW_BASE%/!ENC!"
    set "OUT=%DESKTOP%\!FN!"

    echo [拉] !FN!
    echo     URL: !URL!
    echo     OUT: !OUT!

    REM 首选: curl 5 个救命参数
    curl --tls-max 1.2 --ssl-no-revoke --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 2 ^
         -sS -L -o "!OUT!" "!URL!"
    if !errorlevel! equ 0 (
        REM 验证文件大小 > 100 bytes (避免空文件)
        for %%S in ("!OUT!") do (
            if %%~zS gtr 100 (
                echo     [OK] curl 成功 (%%~zS bytes)
                set /a OK_COUNT+=1
            ) else (
                echo     [WARN] curl 返回文件太小 (%%~zS bytes), 尝试 PowerShell
                goto :try_powershell
            )
        )
    ) else (
        echo     [FAIL] curl errorlevel=!errorlevel!, 尝试 PowerShell fallback...
        :try_powershell
        powershell -NoProfile -Command "$ErrorActionPreference='Stop'; try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!URL!' -OutFile '!OUT!' -UseBasicParsing; 'OK' } catch { 'FAIL: ' + $_.Exception.Message }" > "%TEMP%\ps_result.txt" 2>&1
        findstr /C:"OK" "%TEMP%\ps_result.txt" >nul
        if !errorlevel! equ 0 (
            for %%S in ("!OUT!") do (
                if %%~zS gtr 100 (
                    echo     [OK] PowerShell 成功 (%%~zS bytes)
                    set /a OK_COUNT+=1
                ) else (
                    echo     [WARN] PowerShell 返回文件太小, 尝试 BITS
                    goto :try_bits
                )
            )
        ) else (
            echo     [FAIL] PowerShell 失败: 
            type "%TEMP%\ps_result.txt"
            echo     尝试 BITS fallback...
            :try_bits
            powershell -NoProfile -Command "Start-BitsTransfer -Source '!URL!' -Destination '!OUT!'" > "%TEMP%\bits_result.txt" 2>&1
            if !errorlevel! equ 0 (
                for %%S in ("!OUT!") do (
                    if %%~zS gtr 100 (
                        echo     [OK] BITS 成功 (%%~zS bytes)
                        set /a OK_COUNT+=1
                    ) else (
                        echo     [FAIL] BITS 返回文件太小
                        echo [FAIL] !FN! BITS 返回文件太小 >> "%LOG%"
                        set /a FAIL_COUNT+=1
                    )
                )
            ) else (
                echo     [FAIL] BITS 也失败: 
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
    echo 错误日志已写入: %LOG%
    echo 请把错误日志发给主 Agent 端诊断。
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] 5 个文件全部下载到桌面!
echo.
echo 下一步:
echo   1. cmd 跑: setx GH_PAT "你的Token(主 Agent 端会单独发给你)"
echo   2. 双击 build_oneclick.bat 打 EXE
echo   3. 双击 运行OneClickMCP.bat 启 EXE
echo.
pause
exit /b 0

REM ============================================================
REM 子函数: URL 编码 (用 PowerShell 避免 BAT 中文转义坑)
REM 调用: call :url_encode "input" OUTPUT_VAR
REM ============================================================
:url_encode
set "_INPUT=%~1"
for /f "delims=" %%E in ('powershell -NoProfile -Command "[uri]::EscapeDataString('%_INPUT%')"') do (
    set "%2=%%E"
)
goto :eof
