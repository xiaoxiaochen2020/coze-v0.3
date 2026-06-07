# ClawBridgeGuard v2.0 — 本地 AGENT

**v2.0 是一次质变**：从"被动看门狗"升级为"主动工人"。云端主 Agent 写 GitHub → guard 自动读 → 跑命令 → 写 GitHub 回报。**主人 0 操作**。

## 链路

```
云端主 Agent (我)
    │  写命令
    ▼
GitHub: claw_bridge/inbox.jsonl
    │  30s 轮询
    ▼
ClawBridgeGuard v2.0 (主人电脑)
    │  跑命令
    ▼
主人电脑: PowerShell / 文件 / 进程 / 端口
    │  回报
    ▼
GitHub: claw_bridge/outbox.jsonl
    │  30s 轮询
    ▼
云端主 Agent 拿结果
```

## 支持的命令

| action | args | 说明 |
|--------|------|------|
| `shell` | `{command, timeout}` | 跑 PowerShell 命令（默认 5 分钟超时） |
| `read_file` | `{path}` | 读文件（容错 forward/backslash） |
| `write_file` | `{path, content}` | 写文件（自动 mkdir -p） |
| `list_processes` | `{filter}` | 列出进程（filter 模糊匹配名） |
| `kill_process` | `{name}` 或 `{pid}` | 杀进程 |
| `port_check` | `{host, port, timeout}` | TCP 端口探活 |

## inbox 命令格式

每行一条 JSON：

```json
{"cmd_id": "uuid-or-任意字符串", "action": "shell", "args": {"command": "Get-Process python | Format-Table"}, "ts": "2026-06-07T16:00:00"}
```

## outbox 回报格式

每行一条 JSON：

```json
{"cmd_id": "对应命令的 id", "status": "ok|error", "result": {...}, "ts_in": "...", "ts_out": "...", "duration_s": 1.23, "guard_version": "2.0"}
```

## 安装（主人电脑 0 操作）

1. **第一次**：双击 `install.bat`
   - 输入 GitHub PAT（ghp_ 开头）→ 永久写入 `HKCU\Environment`
   - 复制 guard 源码到 `C:\coze-scheduler\claw_bridge\`
   - 启 EXE 或 pythonw
   - 30s 内首次心跳推 `mcp_url.json` 到 GitHub
2. **以后**：guard 自启 + 自保活 tunnel，**主人无感**

## 升级到 EXE（可选，更稳）

1. 双击 `build_exe.bat` → 生成 `dist\ClawBridgeGuard.exe`
2. 双击 `install.bat` → 优先用 EXE 启动

## 调试

- **看日志**：`C:\coze-scheduler\claw_bridge\guard.log`
- **看 URL**：`C:\coze-scheduler\claw_bridge\current_url.txt`
- **看 OCR 备份**：`C:\coze-scheduler\claw_bridge\current_url_ocr.txt`
- **看历史**：`C:\coze-scheduler\claw_bridge\url_history.jsonl`
- **看 state**：`C:\coze-scheduler\claw_bridge\guard_state.json`
- **看已处理命令**：`C:\coze-scheduler\claw_bridge\processed_cmds.json`

## GitHub 文件清单

- `claw_bridge/mcp_url.json` — 当前 MCP 通道 URL（guard 心跳写）
- `claw_bridge/inbox.jsonl` — 主 Agent 写命令的队列
- `claw_bridge/outbox.jsonl` — guard 回报结果的队列

## 关键设计

- **GitHub 唯一链路**：inbox/outbox/heartbeat 全走 GitHub，**沙箱 outbound 稳定 + 主人电脑无需 inbound**
- **30s 轮询**：GitHub API 60/h 免费额度足够（inbox + heartbeat + url push = ~3/h）
- **命令去重**：guard 持久化 `processed_cmds.json` 防重复
- **outbox append** = 旧内容读 + append + PUT（PUT 走 Basic Auth + sha 拿）
- **5 分钟命令超时**：防 guard 卡死
- **保活 tunnel**：v1.1 能力完整保留（fail_count 2 次 → 杀进程 → 重启 StartRemoteMCP_v3.bat）
- **0 个 `ghp_` 字面量在源码/BAT**：GH_TOKEN 走环境变量，避 GitHub secret scanning
