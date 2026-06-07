# ClawBridgeGuard v1.1 - 守护壳

## 概述
监测 MCP 通道（`localhost:8090` + trycloudflare 公网），断了自动 taskkill + 重启 `StartRemoteMCP_v3.bat`，把新 URL 写到 `current_url.txt` + 推 GitHub 通知沙箱。

## v1.1 相对 v1.0 的修订
1. **路径改对**：从 `C:\Program Files\StartRemoteMCP\StartRemoteMCP.exe` → 主人电脑真实的 `C:\Users\Administrator\Desktop\StartRemoteMCP_v3.bat`（含 winremote-mcp + cloudflared 两条启动命令）
2. **URL 给沙箱走 txt**（主人决策 ①）：guard 写 `C:\coze-scheduler\claw_bridge\current_url.txt`，沙箱 MCP `FileRead` 直接读
3. **OCR 兜底**（主人决策 ②）：guard 用 PowerShell + 剪贴板/窗口标题抓 cloudflared URL，备份到 `current_url_ocr.txt`
4. **端口探活**：`localhost:8090` listen 状态 = winremote-mcp 健康指标
5. **历史审计**：`url_history.jsonl` 每次 URL 变更追加一行

## 文件清单
| 文件 | 作用 |
|------|------|
| `claw_bridge_guard.py` | 守护壳主程序（Python） |
| `build_exe.bat` | 主人电脑 PyInstaller 打包 → `dist\ClawBridgeGuard.exe` |
| `install.bat` | 一键安装：部署 + 计划任务 + 启 guard |
| `pat.txt`（可选） | 你的 GitHub PAT，新建空文件，粘贴 PAT 内容进去 |

## 安装步骤

### 第 1 步：建 pat.txt（可选，省略则不推 GitHub）
```cmd
notepad pat.txt
# 粘贴你的 GitHub PAT (ghp_xxxx)
# 保存
```

### 第 2 步：打包 EXE
```cmd
cd <本目录>
build_exe.bat
```
首次约需 3-5 分钟（pip install pyinstaller + 打包）。输出 `dist\ClawBridgeGuard.exe`。

### 第 3 步：安装守护
```cmd
cd <本目录>
install.bat
```
- 复制 guard.py → `C:\coze-scheduler\claw_bridge\claw_bridge_guard.py`
- 杀旧 guard + 旧 winremote-mcp + 旧 cloudflared
- 创建计划任务 `ClawBridgeGuard`（onlogon, highest）
- 立即启动
- 写 `GITHUB_PAT` 到用户环境变量（setx，**新会话生效**）

## 验证
1. `tasklist /FI "IMAGENAME eq ClawBridgeGuard.exe"` → 应有进程
2. `type C:\coze-scheduler\claw_bridge\guard.log` → 应有启动日志
3. `type C:\coze-scheduler\claw_bridge\current_url.txt` → 应有 trycloudflare URL
4. `type C:\coze-scheduler\claw_bridge\current_url_ocr.txt` → 应有 OCR 原始 JSON（windows/clipboard）
5. GitHub 仓库 `xiaoxiaochen2020/coze-v0.3/claw_bridge/mcp_url.json` → 应有 JSON

## 沙箱侧读 URL
MCP 通道握手后：
```
FileRead: path = "C:\coze-scheduler\claw_bridge\current_url.txt"
```
返回内容格式：
```
https://xxx.trycloudflare.com
# source=restart_ocr
# ts=2026-06-07 15:30:00
# host=SD-20251012OJYT
```

## 卸载
```cmd
schtasks /delete /tn "ClawBridgeGuard" /f
taskkill /F /IM ClawBridgeGuard.exe
```

## 故障
- **GITHUB_PAT 不生效**：setx 写的是**新会话**用的环境变量。当前后台跑的 guard 不会自动拿到——需要**重新登录**或重启 guard。临时办法：手动 `setx GITHUB_PAT <pat>` 后 `schtasks /run /tn ClawBridgeGuard`
- **OCR 抓不到 URL**：cloudflared GUI 窗口可能没在桌面（被最小化）。guard 兜底逻辑：连续 2 次失败 → 重启 bat → OCR 重试
- **断线判定过激**：编辑 `claw_bridge_guard.py` 改 `FAIL_THRESHOLD = 3`（连续 3 次失败才判定 = 180s 内恢复）
