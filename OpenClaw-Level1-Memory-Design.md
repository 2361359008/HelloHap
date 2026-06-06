# OpenClaw 第一关记忆拆分设计

## 目标

第一关不再使用一份“大而全”的记忆文件同时承担执行和答疑。现在拆成两类记忆：

- 动作记忆：只用于关卡触发，要求 OpenClaw 严格执行第一关任务。
- 答疑记忆：只用于第一关完成后的学生自由提问，帮助 OpenClaw 解释概念、目录、脚本和产物。

这样可以避免第一关执行时提前做第二关、第三关的事情，也能避免学生追问时重新触发编译、签名、安装或启动。

## 第一关动作记忆

板端文件：

```text
/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md
```

用途：

- 只在学生点击第一关的“呼叫 OpenClaw 协同开发”时使用。
- 只允许执行第一关编译动作。
- 重点是运行已有脚本，不再要求 OpenClaw 修改 ArkUI 源码。

动作边界：

```text
1. 读取 /data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md
2. 运行 sh /data/local/tmp/oh61-hapbuild/compile_unsigned.sh
3. 验证 /data/local/tmp/entry-unsigned.hap 是否存在
4. 向学生报告真实执行结果
```

禁止行为：

```text
不得修改源码
不得签名
不得安装
不得启动应用
不得读取第二关或第三关记忆文件
不得提前推进后续关卡
```

## 第一关答疑记忆

板端文件：

```text
/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile-qa.md
```

用途：

- 只在第一关已经完成后使用。
- 只在学生停留于第一关完成页面并发送自由问题时使用。
- 负责解释 HAP 工程、ArkUI 页面结构、Hvigor、Docker 编译环境、未签名 HAP 产物等内容。

答疑边界：

```text
只解释学生问题
不重新执行编译
不触发签名
不安装应用
不启动应用
不改变当前关卡进度
```

## HAP 侧触发规则

HAP 页面里第一关的提问分成两种：

1. 关卡触发提问

   学生点击“呼叫 OpenClaw 协同开发”时，HAP 发送第一关预置任务提示词。这个提示词要求 OpenClaw 先读取动作记忆，再运行编译脚本。

2. 课后自由提问

   第一关完成后，学生在聊天输入框继续提问。聊天气泡仍然显示学生原问题，但真正发送给 OpenClaw 的内容会在后台包装一层提示：

```text
请先读取第一关答疑记忆文件：
/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile-qa.md。
本轮是学生课后自由提问，不是关卡触发任务。
请只解释问题，不要重新编译、签名、安装或启动应用。

学生问题：<学生原始问题>
```

## 一次性注入规则

第一关答疑记忆提示只在满足以下条件时触发：

```text
selectedTaskIndex == 1
tutorialStep == 3
highestCompletedLevel >= 1
level1QaPromptInjected == false
```

触发后立即将：

```text
level1QaPromptInjected = true
```

这样可以保证：

- 只有第一关完成页会触发第一关答疑包装。
- 第二关、第三关不会误用第一关答疑记忆。
- 第一关完成后的第一次自由提问会显式引导 OpenClaw 读取 QA 记忆。
- 后续提问继续沿用同一个 OpenClaw 会话上下文，不重复塞同一段系统提示。

## 与 OpenClaw Web UI 会话的关系

HAP 不自己实现一套独立记忆系统，而是继续把消息发送到 OpenClaw 原生会话机制中。

当前设计重点是：

- HAP 负责在合适时机组装提示词。
- OpenClaw 负责维护同一个会话上下文。
- 关卡切换不主动清空上下文，因为三关本身是连续教学流程。
- 只有“关卡动作”和“课后答疑”的入口不同，底层仍走同一个 OpenClaw 对话链路。

## 后续关卡迁移建议

第二关和第三关也建议按同样方式拆分：

```text
oh61-level2-sign.md        // 第二关动作记忆
oh61-level2-sign-qa.md     // 第二关答疑记忆
oh61-level3-deploy.md      // 第三关动作记忆
oh61-level3-deploy-qa.md   // 第三关答疑记忆
```

动作记忆要强约束，只写“本关必须执行什么、禁止执行什么”。

答疑记忆要偏解释，只写“学生问到概念时如何说明、相关文件在哪里、每一步为什么这样做”。

这套拆分能让 OpenClaw 在教学流程里更稳定：执行任务时不跑偏，学生追问时又能保留完整上下文。
