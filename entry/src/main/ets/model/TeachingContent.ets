// 教学之路文案
// 高级版「教学之路」各关卡的 openclaw 讲解提示词。
// 当前流程聚焦「日志 HAP 开发流程」：先从已经设计好的日志 HAP 开始，
// 再按工程初始化、页面搭建、日志功能、构建部署顺序讲解。函数为纯文案，便于在 pages/Index.ets 中通过
// OpenClawClient.startTurn 发送给 openclaw。

// 「日志 HAP 课程讲师」专属 agent 的 id（其人格来自该 agent 工作区的 IDENTITY/SOUL/AGENTS 文件，
// 在 agent 启动时由 OpenClaw 注入，无需每轮对话再切换身份）。
// 教学会话通过 sessions.create 的 agentId 绑定到该 agent，与其它会话隔离。
export const TEACHING_AGENT_ID: string = 'teaching';

// 日志 HAP 课程对象工程在板端的绝对路径（讲师只讲解、不改文件；如需对照真实工程举例，
// 用此绝对路径，因为讲师 agent 的工作目录是它自己的工作区，不是这个工程目录）。
export const TEACHING_PROJECT_ROOT: string = '/data/local/tmp/advanced-hapbuild/project';

// 进入「教学之路」时发送的简短问候：会话已绑定讲师 agent，这里只让它用一句话确认身份。
// 不再执行 set-identity（该命令只改昵称/头像，不切行为）；身份由讲师 agent 工作区文件决定。
export function buildTeachingIdentityPrompt(): string {
  return `你好，请用一句话确认你当前的身份和职责，然后回复「日志 HAP 课程讲师身份已就位，可以开始开发流程讲解」。在学员未明确要求前，只讲解、不改动任何工程文件。`;
}

// 开发流程：让 openclaw 讲解日志 HAP 的开发步骤（只讲解，不改任何文件）。
export function buildLogHapFlowPrompt(): string {
  return `这是教学讲解任务，不是改代码任务。请只用中文讲解，不要创建、修改或删除任何文件，也不要运行命令。

（如需对照真实工程举例，课程对象工程在 ${TEACHING_PROJECT_ROOT}；你的工作目录是你自己的 agent 工作区，不是这个工程目录。本流程只讲解、不改文件。）

开场请先说：欢迎来到日志 HAP 的开发教学流程，你可以看到目前日志 HAP 已经设计好的样子，接下来我将深度介绍该 HAP 的开发流程。

讲解主题：以已经设计好的日志 HAP 为对象，按开发流程介绍它从工程初始化到构建部署的实现路径。不要再用“第一关”叙述，要用“流程第一步、第二步……”的方式推进。

请按下面的顺序，逐项用通俗语言讲清楚（每项说明：是什么 / 放在哪 / 作用 / 开发时要注意什么）：
1. 初始化日志项目：AppScope / entry / resources / signing / 构建脚本分别承担什么职责，为什么日志 HAP 需要先建立工程骨架。
2. 应用身份与资源：AppScope/app.json5、AppScope/resources/base/element/string.json 如何确定日志 HAP 的包名、版本、应用显示名和基础资源。
3. 模块入口配置：entry/src/main/module.json5 如何声明 EntryAbility、页面入口、权限边界。
4. 页面结构搭建：entry/src/main/ets/entryability/EntryAbility.ets、entry/src/main/ets/pages/Index.ets、main_pages.json 在页面启动与路由中的作用，并说明日志列表、输入区、状态提示等 UI 大致会落在哪里。
5. 日志功能实现：用 ArkTS 状态变量、事件处理和组件组合解释日志条目的新增、展示、筛选或状态反馈，不需要写完整代码。
6. 构建签名与部署：signing/、build-profile.json5、hvigor 脚手架、安装启动脚本如何把日志 HAP 打包成可运行应用，以及哪些文件不要随意改。

最后用 3~5 句话总结"日志 HAP 的推荐开发流程"。全程只讲解，不要修改文件，不要写完整页面代码。`;
}
