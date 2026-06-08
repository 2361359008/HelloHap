# HelloHap 教学应用 — 项目进度报告

> 面向后续开发的交接文档。截至 PR #3（分支 `devin/1780809639-freedev-openclaw`）。
> 仓库：https://github.com/2361359008/HelloHap

---

## 1. 项目概述

HelloHap 是一个运行在 OpenHarmony（RK3588 板端）上的 **HAP 教学应用**，通过应用内 UI 驱动板上的 **OpenClaw Agent 网关**，做「AI 协同开发教学」。分两套课程：

- **基础课程（简单关）**：闯关式教学，第 1~3 关分别讲「编译 / 签名 / 部署」，第 4 关为练习关。学生点按钮触发 OpenClaw 完成真实的编译/签名/安装/启动全流程。
- **高级课程（高级关）**：两个入口
  - **教学之路**：进入后初始化「讲师身份」，第一关讲解日程 HAP 的项目文件准备。
  - **自由发挥（自由开发）**：进入后初始化「还原身份」，提供两个还原提示词按钮（① 还原「类型」下拉菜单 ② 还原「提醒」下拉 + 「响铃提醒」开关）；OpenClaw 改完代码后自动编译/签名/安装到板上看效果。

板上被教学/还原操作的目标工程是 **`schedulehap-lite`（日程 HAP）**，每次进入或重置都会刷回最原始模板。

---

## 2. 代码架构

原先单文件 `Index.ets` 已按职责拆分为 model / service / view / pages（见 PR #1）：

```
entry/src/main/ets/
├── pages/
│   └── Index.ets              # 主页面/状态机：所有 @State、流程编排、事件处理（最大文件）
├── service/
│   └── OpenClawClient.ets     # 传输层：HTTP 取 token、WebSocket 连接、RPC 收发、会话管理、一轮对话
├── model/
│   ├── OpenClawTypes.ets      # RPC 参数/请求类型（OpenClawSendParams / AbortParams / CreateSessionParams 等）
│   ├── CourseContent.ets      # 基础课程文案/提示词
│   ├── TeachingContent.ets    # 高级·教学之路文案/提示词（含 TEACHING_AGENT_ID）
│   └── FreeDevContent.ets     # 高级·自由开发文案/提示词（含 FREEDEV_AGENT_ID、板端路径常量）
└── view/
    ├── HomeEntryView.ets      # 首页入口（基础/高级选择）
    ├── AdvancedMenuView.ets   # 高级版菜单（教学之路 / 自由发挥 入口）
    ├── TeachingPathView.ets   # 教学之路页（6 张讲解卡片 + 讲解按钮 + 底部输入框）
    ├── FreeDevView.ets        # 自由开发页（还原①② 按钮 + 底部输入框 + 全屏初始化遮罩）
    └── WorkspaceView.ets      # 工作区（OpenClaw 对话 / 源码 Source / 日志 三个 Tab）
```

板端配套（仓库根目录，需部署到板上）：

```
shell-bridge.mjs                 # 板端 Node 服务（:7681）：发 token、跑脚本、暴露 /reset-course /reset-advanced
build_advanced_with_env.sh       # 高级版「编译/签名/安装/启动」全流程脚本（OpenClaw 还原后自动调用）
install_initial_advanced.sh      # 只「卸载+安装+启动」基线签名包，不编译不签名（进入自由开发时装回最原始 HAP）
restore_advanced_project.sh      # 高级版工程源码还原（从 backups/course-initial/project.tar 解包）
restore_course_project.sh        # 基础版工程源码还原
build_sign_install_run.sh        # 基础版全流程脚本
freedev-prompts.txt              # 自由发挥提示词草稿本（部署时拷进日程工程根目录，可在源码浏览器查看）
openclaw/                        # OpenClaw 多 agent 身份文件（部署到各 agent 工作区）
```

---

## 3. OpenClaw 多 Agent 身份体系

两入口绑定到**独立 agent**，工作区隔离，身份由各自工作区的 `IDENTITY.md`/`SOUL.md` 决定（agent 启动时注入，无需每轮切换）：

| 入口 | Agent ID | 工作区 | 身份文件（仓库内源） |
|------|----------|--------|---------------------|
| 自由发挥 | `restore` | `/data/local/tmp/.openclaw/workspace-restore` | `openclaw/agents/restore/{IDENTITY,SOUL}.md` |
| 教学之路 | `teaching` | `/data/local/tmp/.openclaw/workspace-teaching` | `openclaw/agents/teaching/{IDENTITY,SOUL}.md` |
| 默认 | `main`(空) | `…/workspace` | `openclaw/IDENTITY.md`（官方干净模板，不承载业务） |

会话通过 `sessions.create` 的 `agentId` 绑定到对应 agent。

---

## 4. 板端依赖与部署前提（关键路径）

| 用途 | 板端路径 |
|------|----------|
| 高级版工程根目录 | `/data/local/tmp/advanced-hapbuild/project` |
| 待还原的 Index.ets | `…/advanced-hapbuild/project/entry/src/main/ets/pages/Index.ets` |
| 工程初始备份 | `…/advanced-hapbuild/backups/course-initial/project.tar` |
| 全流程构建脚本 | `…/advanced-hapbuild/build_advanced_with_env.sh` |
| 基线安装脚本 | `…/advanced-hapbuild/install_initial_advanced.sh` |
| **最原始基线签名包** | `…/advanced-hapbuild/schedule-initial-signed.hap`（独立命名，不被构建产物覆盖） |
| shell-bridge 端口 | `http://127.0.0.1:7681`（/token、/reset-course、/reset-advanced） |
| OpenClaw 网关 | `ws://127.0.0.1:18800` |
| 目标应用包名 | `com.openclaw.schedulehap.lite` |

**首次部署 checklist**（详见 PR #3 描述）：
1. 把 `freedev-prompts.txt` 拷进 `schedulehap-lite` 工程根目录（与 oh-package.json5 同级），
   再在该干净状态下做基线备份（`tar -cf backups/course-initial/project.tar project`）。
   这样该文件被打进基线、每次还原后仍在工程里，可在 HAP「源码文件浏览器(Source)」中查看。
   ```sh
   # PC 端示例（hdc 推送 + 重建基线 tar）：
   hdc file send freedev-prompts.txt /data/local/tmp/advanced-hapbuild/project/freedev-prompts.txt
   hdc shell "cd /data/local/tmp/advanced-hapbuild && tar -cf backups/course-initial/project.tar project"
   ```
   日常更新提示词：改完仓库里的 `freedev-prompts.txt` 后重跑上面两条命令即可（也可纳入你的部署脚本）。
2. 上传 `restore_advanced_project.sh` / `install_initial_advanced.sh` / `build_advanced_with_env.sh`，转 LF 并 `chmod 755`。
3. 上传**最原始签名包**到 `schedule-initial-signed.hap`。
4. 用最新 `shell-bridge.mjs` 覆盖板端并重启（提供 `/reset-advanced`）。
5. 板端脚本均需 LF 换行（仓库已用 `.gitattributes` 强制 `*.sh eol=lf`）。

---

## 5. 会话生命周期与竞态防护（本阶段重点）

> 背景问题：进入自由发挥点还原①后，OpenClaw 会自动跑编译（约 100s）。若在这期间「重置课程」并立刻再进自由发挥，旧 run 仍在网关上跑、旧 async 流程继续推进，导致「粘在上一个会话 / 旧提示词结果晚回来覆盖板上 HAP / 对话框残留」。

防护分三层（都已实现）：

1. **重置时无条件清会话**（`Index.resetCourse`）：`clearCourseState()`（含 `client.reset()`）提到工程还原 HTTP **之前**无条件执行。此前它被放在 HTTP 成功之后，高级版还原脚本重、易超时失败 → 清理被跳过 → 复用旧会话。这是「简单关能开新会话、高级版粘旧会话」的根因。

2. **客户端 reset 代际（`OpenClawClient.resetEpoch`）**：`reset()` 自增 epoch；`startTurn / ensureSession / sendRpcRequest` 在每个 `await` 后、**尤其 `chat.send` 前**校验 epoch，不一致立刻抛 `Course reset`，旧 async 绝不再用旧 session 建会话/发旧提示词。

3. **页面层代际（`Index.courseEpoch`）**：`clearCourseState()` 自增；`enterFreeDev/enterTeaching` 在 `restoreAdvancedProject()`（HTTP 往返）返回后校验，`initFreeDevIdentity/initTeachingIdentity` 在 `startTurn` 返回后校验；**所有 startTurn 的 catch** 在 push 失败文案前校验代际——被重置则直接 return，不再往刚清空的对话补「失败：Course reset」残留。

辅助机制：
- **chat.abort 带 sessionKey + runId**（`OpenClawAbortParams`）：网关要求 sessionKey，否则报 `must have required property 'sessionKey'`，旧 run 中止不成功。reset 在清空 sessionKey 前发 abort。
- **旧 socket 事件守卫**：`message/close/error` 处理器比对 `socket !== this.ws`，丢弃旧连接的残留流式事件。旧连接先摘下（`this.ws=null`）→ 发 abort → 600ms 后再 close。
- **NO_REPLY 兜底**：提示词里硬性要求「执行完必须返回完整中文总结，严禁 NO_REPLY」；HAP 侧 `final` 事件若 text 为空/NO_REPLY，不清空气泡——有过程文案则保留并补「本轮已执行完成」，否则显示「已执行完成，但本轮未返回文字总结…」。

---

## 6. UI 细节（已对齐简单关）

- 自由开发页顶部去掉多余空隙、底部加用户输入框（按当前模式路由到对应 agent）、还原①②按钮采用练习关样式。
- **项目初始化全屏聚焦遮罩**：进入自由开发/教学时整屏压暗 + 中间聚焦卡片转圈「正在初始化项目」，OpenClaw 一开始返回内容（首个流式事件）即关闭，不等整轮跑完。
- 下拉菜单 `.bindMenu` 绑在右侧值文本上并加 `Placement.Bottom`，从值正下方弹出。

---

## 7. 后续开发指引 / 注意事项

- **无法在 CI/本机编译**：本仓库需 OpenHarmony SDK + DevEco，开发机/Devin VM 上没有，改完必须在本地 DevEco 编译装板验证。
- **ArkTS 严格空检查**：闭包内不认 `if (x)` 的类型收窄，需先取出非空局部变量（见 `OpenClawClient.reset` 里 `wsToClose`）。
- **板端脚本换行**：新增/修改 `*.sh` 必须 LF；上传后 `sed -i 's/\r$//'` + `chmod 755` + `sh -n` 自检。
- **改提示词不需重发板端**：提示词文案编译进 HAP；但改 `openclaw/agents/**` 身份文件需重新部署到板端 agent 工作区。
- **基线包命名**：基线签名包用 `schedule-initial-signed.hap`，与 `build_advanced_with_env.sh` 产出的 `schedule-signed.hap` 区分，避免被覆盖。
- **会话调试**：板端 `/data/local/tmp/.openclaw/agents/{restore,teaching}/sessions/` 下有 `*.jsonl`（对话）、`sessions.json`（状态，看 `runtimeMs`/`endedAt`/`abortedLastRun`）。

### 可能的后续工作
- 教学之路目前只有第一关，可扩展第二/三关。
- 自由发挥可增加更多还原提示词按钮（参考 `FreeDevContent.ets` 的 `buildRestore*Prompt` 模式）。
- 把板端部署 checklist 脚本化（一键 push 脚本 + 基线包 + 重启 shell-bridge）。

---

## 8. PR #3 变更汇总

24 个提交，19 文件，+1302/-48。核心：高级版教学之路第一关 + 自由开发 OpenClaw 协同 + 工程/HAP 还原 + 全屏初始化遮罩 + 会话竞态三层防护 + NO_REPLY 兜底 + 重置后对话刷新干净。
