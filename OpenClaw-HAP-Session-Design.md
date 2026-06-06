# OpenClaw HAP 会话设计

## 目标

HAP 教学应用需要直接接入板子上的 OpenClaw 能力，但不能再用自己拼接历史消息的方式模拟上下文。会话、历史、消息顺序和最终回答都应交给 OpenClaw Gateway 的原生会话机制处理，保持和 OpenClaw Web UI 一致。

核心目标有三点：

1. HAP 不嵌入 OpenClaw Web UI 页面，而是在自己的教学界面里显示对话。
2. HAP 不使用自定义 `/v1/chat/completions` 历史拼接方案。
3. HAP 使用 OpenClaw Web UI 同款 Gateway RPC 协议，让 OpenClaw 自己维护会话上下文。

## 已确认的 Web UI 原生机制

OpenClaw Web UI 不是靠每次 HTTP 请求附带完整历史来实现上下文，而是通过 Gateway WebSocket RPC 工作。

连接方式：

```text
ws://127.0.0.1:18800
```

Web UI 的请求外壳：

```json
{
  "type": "req",
  "id": "uuid",
  "method": "chat.send",
  "params": {}
}
```

Gateway 的响应外壳：

```json
{
  "type": "res",
  "id": "uuid",
  "ok": true,
  "payload": {}
}
```

Gateway 的事件外壳：

```json
{
  "type": "event",
  "event": "chat",
  "payload": {}
}
```

Web UI 发送消息的关键流程：

1. WebSocket 连接 Gateway。
2. 发送 `connect` 握手，声明 `operator` 角色、权限 scopes、客户端信息和 token。
3. 调用 `chat.history`，传入 `sessionKey`，拿到当前 `sessionId` 和历史消息。
4. 调用 `chat.send`，传入 `sessionKey`、`sessionId`、`message`、`deliver: false`、`idempotencyKey`。
5. 监听 `chat` 事件。
6. `state: "delta"` 时可显示流式中间内容。
7. `state: "final"` 时把最终 assistant 消息写入 UI，并解锁输入框。
8. `state: "error"` 或 `state: "aborted"` 时显示失败，并保持顺序控制。

## HAP 应采用的会话策略

HAP 可以开新的对话，但这个新对话必须是 OpenClaw 原生 session，而不是 HAP 自己创造的伪上下文。

推荐策略：

1. 进入课程或第一次呼叫 OpenClaw 时，创建一个 HAP 专属课程会话。
2. 第一关、第二关、第三关都复用这个课程会话。
3. 切换关卡不新建会话，不清空 OpenClaw 上下文。
4. 点击“重置课程”时，才创建新的课程会话。
5. 不固定使用 Web UI 的 `main` 会话，避免教学 HAP 和 Web UI 主聊天互相污染。

也就是说：

```text
一次课程流程 = 一个 OpenClaw 原生 session
一个课程内的多个关卡 = 同一个 OpenClaw 原生 session
重置课程 = 新建一个 OpenClaw 原生 session
```

## 为什么不固定到 agent:main:main

`agent:main:main` 是 Web UI 当前 main 聊天线。固定使用它可以最大程度复用 Web UI 当前上下文，但副作用明显：

1. HAP 教学消息会混入用户在 Web UI 的主聊天。
2. Web UI 主聊天里的旧内容会影响 HAP 教学流程。
3. 多次教学演示之间不容易隔离。
4. 学员看到的课程上下文可能被非课程消息污染。

因此，HAP 不应该默认固定到 `agent:main:main`。更合适的是使用 OpenClaw 原生 `sessions.create` 创建 HAP 专属 session。

## HAP 专属 session 的生命周期

### 首次开始课程

当用户点击第一关的“呼叫 OpenClaw 协同开发”时：

1. 如果本地没有 `openClawSessionKey`，先调用 `sessions.create`。
2. 保存返回的 `sessionKey`。
3. 调用 `chat.history` 获取对应 `sessionId`。
4. 调用 `chat.send` 发送第一句预置教学问题。

### 关卡切换

进入第二关或第三关时：

1. 保留 `openClawSessionKey`。
2. 不清空 OpenClaw 原生上下文。
3. 发送下一关预置教学问题时继续使用同一个 `sessionKey`。

这样第二关可以看到第一关已经发生过什么，符合完整教学流程记忆。

### 学员自由提问

第一句预置教学问题完成前，输入框应锁定。

OpenClaw 返回 `state: "final"` 后：

1. 解锁左下角学员输入框。
2. 学员可以自由提问。
3. 每次提问继续使用同一个 `sessionKey` 和当前 `sessionId`。
4. AI 处理中禁止再次发送，避免消息顺序错乱。

### 重置课程

点击“重置课程”时：

1. 本地课程状态回到第一关。
2. 清空 HAP UI 当前展示的教学消息。
3. 清空本地保存的 `openClawSessionKey` 和 `sessionId`。
4. 下一次呼叫 OpenClaw 时创建新的 OpenClaw 原生 session。

## UI 显示原则

当前设计中只保留左下角输入框。

右侧区域：

1. 整块作为 OpenClaw 对话显示区。
2. 显示用户发送的问题。
3. 显示 OpenClaw 返回的回答。
4. 不再放第二个输入框。
5. 不显示“这里会接入本应用内置的 OpenClaw 主对话区”这类占位文案。

左下角区域：

1. 只保留学员输入框和发送按钮。
2. 第一句预置教学问题完成前禁用。
3. OpenClaw 正在处理时禁用。
4. 回答完成后解锁。

## 失败处理原则

不再用本地教学答案兜底。

如果 OpenClaw 调用失败，应明确显示失败原因。因为本项目要验证的是“确实调用到了 OpenClaw”，本地兜底会掩盖真实连接问题。

失败时应该显示：

```text
OpenClaw 调用失败：<错误信息>
```

并保持输入锁定或允许用户重试，不能伪装成 AI 已经完成回答。

## 实现待办

1. 用 WebSocket RPC 替换当前 HTTP `/v1/chat/completions` 调用。
2. 实现 `connect` 握手。
3. 实现 `sessions.create`，用于创建 HAP 专属课程 session。
4. 实现 `chat.history`，获取当前 `sessionId`。
5. 实现 `chat.send`，发送预置教学问题和学员自由提问。
6. 监听 `chat` 事件，处理 `delta`、`final`、`error`、`aborted`。
7. 用 `openClawBusy` 控制发送锁，避免连续发送导致顺序错乱。
8. 重置课程时清除本地 session key，使下一轮课程创建新 session。

## 结论

HAP 应该“新开一个 OpenClaw 原生课程会话”，而不是固定写入 Web UI 的 main 会话，也不是自己拼接消息历史。

这样既能像 Web UI 一样拥有真实上下文，又能避免污染用户的主聊天记录。
