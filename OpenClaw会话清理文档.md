# OpenClaw 历史测试会话清理指南

在进行 HAP 接入与 AI 协同开发调测时，频繁地发起连接和测试会生成大量的历史会话、日志和轨迹文件。
当历史会话过多时，会在 OpenClaw Web UI 中产生堆积，影响查阅最新调试会话。

本篇文档记录了如何在 OpenHarmony 开发板端**安全、干净、无损地彻底清理历史测试会话**，并重置会话列表。

---

## 一、会话存储原理

在 OpenClaw Gateway 架构中，所有的会话元数据（索引、对话轨迹、流式富文本）均被隔离存储在：
- **会话存储根目录**：`/data/local/tmp/.openclaw/agents/main/sessions/`
- **核心文件组成**：
  - `sessions.json`：存储会话的总索引与历史会话卡片。
  - `*.jsonl`：每个会话的具体历史对话文本。
  - `*.trajectory.jsonl`：每个会话完整的 agent 决策与工具链调用执行轨迹。

由于这些文件相对独立，直接通过文件系统清空该文件夹，是重置会话列表最彻底、最高效的手段。

---

## 二、核心清理指令（推荐）

通过 hdc 远程连接工具在电脑终端中下发以下组合拳指令，可一键完成**“清空历史会话 ➔ 热重启 OpenClaw ➔ 释放缓存”**：

```bash
# 1. 彻底清除所有的历史会话数据文件（保留配置）
hdc shell "rm -rf /data/local/tmp/.openclaw/agents/main/sessions/*"

# 2. 安全杀死旧的 node gateway 服务进程
hdc shell "pkill -f openclaw.mjs"

# 3. 稍等 1 秒后，执行 boot 脚本重新拉起服务（热重载 openclaw.json 配置并刷新内存会话缓存）
hdc shell "sleep 1; /data/local/tmp/bin/openclaw-boot.sh &"
```

---

## 三、常用运维管理指令

### 3.1 查询当前存储的会话列表

在板端查询已有的会话时，必须显式指定 `HOME` 变量为 `/data/local/tmp`，否则 OpenClaw 会在系统根目录进行多余的空查询。

```bash
hdc shell "export HOME=/data/local/tmp; /data/local/tmp/node /data/local/tmp/openclaw/openclaw.mjs sessions"
```

* **清理成功后的预期输出**：
  ```text
  Session store: /data/local/tmp/.openclaw/agents/main/sessions/sessions.json
  Sessions listed: 0
  No sessions found.
  ```

### 3.2 运行内置的安全容量裁剪（Cleanup）

若不想完全清除会话，只想按照 OpenClaw 配置的淘汰策略执行一次过期清理，可以使用内置的 `cleanup` 指令：

```bash
hdc shell "export HOME=/data/local/tmp; /data/local/tmp/node /data/local/tmp/openclaw/openclaw.mjs sessions cleanup --enforce"
```

---

## 四、注意事项
1. **保留配置文件**：切勿对 `/data/local/tmp/.openclaw/` 目录直接执行 `rm -rf`，否则会误删白名单核心配置文件 `openclaw.json`（其中包含我们好不容易打通的 `allowInsecureAuth` 认证配置）。请务必指定细化子目录 `/agents/main/sessions/*`。
2. **清理完毕后重开客户端**：会话清空并热重启网关后，物理开发板上的 HAP 应用也建议退回到桌面并重新打开，以确保 WebSocket 握手自动拿到完全干净、纯正的全新 Session ID。
