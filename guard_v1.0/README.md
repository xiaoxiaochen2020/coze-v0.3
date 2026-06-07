# ClawBridgeGuard v1.0 - 一键安装 + 打包说明

## 概述
守护壳，监测 MCP 通道，断线自动拉起新 trycloudflare URL 并推 GitHub。

## 文件清单
| 文件 | 作用 |
|------|------|
| `claw_bridge_guard.py` | 守护壳主程序（Python） |
| `build_exe.bat` | 主人电脑 PyInstaller 打包 → `dist\ClawBridgeGuard.exe` |
| `install.bat` | 一键安装：部署 + 计划任务 + 启动 |
| `pat.txt`（可选） | 你的 GitHub PAT，新建空文件，粘贴 PAT 内容进去 |

## 安装步骤（顺序）

### 第 1 步：准备 pat.txt（可选）
```cmd
notepad pat.txt
# 粘贴你的 GitHub PAT (ghp_xxxx)
# 保存
```
如果省略 pat.txt，guard 不会推 GitHub（仅本地日志）。

### 第 2 步：打包 EXE
```cmd
cd <本目录>
build_exe.bat
```
**首次约需 3-5 分钟**（pip install pyinstaller + 打包）。输出 `dist\ClawBridgeGuard.exe`。

### 第 3 步：安装守护
```cmd
cd <本目录>
install.bat
```
- 复制 guard.py → `C:\coze-scheduler\claw_bridge\claw_bridge_guard.py`
- 杀旧 guard
- 创建计划任务 `ClawBridgeGuard`（onlogon，highest）
- 立即启动

## 验证
1. `tasklist /FI "IMAGENAME eq ClawBridgeGuard.exe"` → 应有进程
2. `type C:\coze-scheduler\claw_bridge\guard.log` → 应有启动日志
3. GitHub 仓库 `xiaoxiaochen2020/coze-v0.3` 的 `claw_bridge/mcp_url.json` → 应有 JSON 内容

## 卸载
```cmd
schtasks /delete /tn "ClawBridgeGuard" /f
taskkill /F /IM ClawBridgeGuard.exe
```

## 故障
- **无 trycloudflare URL 出现**：StartRemoteMCP 启动后把 URL 写到 GUI / 剪贴板，guard 暂未解析 UI（v1.0 简化）。如要支持，可加 v1.1：从 `StartRemoteMCP` 日志或注册表读 URL
- **GitHub push 失败**：检查 `pat.txt` 内容（不含 ghp_ 字面量报错的话，PowerShell 内部处理）；看 guard.log
- **断线判定过激**：编辑 guard.py 改 `FAIL_THRESHOLD = 3`（连续 3 次失败才判定 = 180s 内恢复）
