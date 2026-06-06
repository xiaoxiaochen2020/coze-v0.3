@echo off
chcp 65001 >nul
REM 主人 2026-06-07 07:52 立 B+F+D 方案
REM 从 GitHub 拉 v1.7 源码, 覆盖到 C:\coze-scheduler\StartMCPGuard\
echo === 拉 v1.7 新源码 ===

if not exist "C:\coze-scheduler\StartMCPGuard" mkdir "C:\coze-scheduler\StartMCPGuard"

curl.exe -L -o "C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py" "https://raw.githubusercontent.com/xiaoxiaochen2020/coze-v0.3/main/StartMCPGuard/start_mcp_guard.py"
if errorlevel 1 (
    echo X 拉失败
    pause
    exit /b 1
)

echo + 文件大小:
dir "C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py"

echo.
echo === 验活: 关键字 ===
findstr /C:"StartMCPGuard v1.7" "C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py" >nul && echo + v1.7 FOUND
findstr /C:"NO_WINDOW = 0x08000000" "C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py" >nul && echo + NO_WINDOW FOUND
findstr /C:"SUBPROC_KW" "C:\coze-scheduler\StartMCPGuard\start_mcp_guard.py" >nul && echo + SUBPROC_KW FOUND

echo.
echo === 下一步 ===
echo 1. 双击 运行StartMCPGuard_v17.bat (启 pythonw + v1.7)
echo 2. 不要双击原来的 运行StartMCPGuard.bat (又 EXE 版)
echo.
pause
