@echo off
chcp 65001 >nul
REM 主人 2026-06-07 07:52 立 D 方案
REM 跑 onedir 版 StartMCPGuard EXE (修内存, 不弹一闪没)
cd /d "C:\coze-scheduler\StartMCPGuard\dist\StartMCPGuard"
start "" "C:\coze-scheduler\StartMCPGuard\dist\StartMCPGuard\StartMCPGuard.exe"
echo + EXE 已启, PID 查任务管理器
echo.
echo 退出: 任务管理器杀 StartMCPGuard.exe (2 个: bootloader + main)
echo.
pause
