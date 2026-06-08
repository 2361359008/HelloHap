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

export function getLogHapFlowChatTitle(step: number): string {
  switch (step) {
    case 0:
      return '初始化日志项目';
    case 1:
      return '应用身份与资源';
    case 2:
      return '模块入口配置';
    case 3:
      return '页面结构搭建';
    case 4:
      return '日志功能实现';
    case 5:
      return '构建签名与部署';
    default:
      return '日志 HAP 开发流程';
  }
}

export function getLogHapFlowTitle(step: number): string {
  switch (step) {
    case 0:
      return '① 初始化日志项目';
    case 1:
      return '② 应用身份与资源';
    case 2:
      return '③ 模块入口配置';
    case 3:
      return '④ 页面结构搭建';
    case 4:
      return '⑤ 日志功能实现';
    case 5:
      return '⑥ 构建签名与部署';
    default:
      return '日志 HAP 开发流程';
  }
}

export function getLogHapFlowBody(step: number): string {
  switch (step) {
    case 0:
      return '欢迎来到日志 HAP 的开发教学流程。你可以看到目前日志 HAP 已经设计好的样子，接下来我将深度介绍该 HAP 的开发流程。第一步先建立工程视角：它由 AppScope、entry、resources、signing 与构建脚本共同组成。';
    case 1:
      return 'AppScope/app.json5：bundleName（包名）、versionCode、versionName、label（应用名引用）。\nAppScope/resources/base/element/string.json：app_name（应用显示名）。这一步确定日志 HAP 的应用身份、名称与基础资源。';
    case 2:
      return 'entry/src/main/module.json5：配置 abilities（应用能力入口）与 requestPermissions（申请的系统权限）。日志 HAP 的页面启动入口、路由能力和必要权限都从这里开始对齐。';
    case 3:
      return 'entryability/EntryAbility.ets：应用入口 Ability（一般不动）。\npages/Index.ets：日志 HAP 的主页面，负责展示列表、输入区、状态提示等核心 UI。\nresources/base/profile/main_pages.json：路由页面清单，新增页面要在这里登记。';
    case 4:
      return '围绕日志条目的新增、展示、筛选和状态反馈梳理 ArkTS 状态变量、事件处理与组件布局。这里开始从"看见设计好的样子"过渡到"理解它是怎么被写出来的"。';
    case 5:
      return 'signing/、build-profile.json5、hvigor 脚手架和安装启动脚本负责把日志 HAP 打包成可运行应用。后续流程会继续讲清楚编译、签名、安装和启动的边界。';
    default:
      return '日志 HAP 开发流程已完成。';
  }
}

// 开发流程：让 openclaw 分步讲解日志 HAP 的开发步骤（只讲解，不改任何文件）。
export function buildLogHapFlowPrompt(step: number): string {
  let title = getLogHapFlowTitle(step);
  let body = getLogHapFlowBody(step);
  return `这是教学讲解任务，不是改代码任务。请只用中文讲解，不要创建、修改或删除任何文件，也不要运行命令。

（如需对照真实工程举例，课程对象工程在 ${TEACHING_PROJECT_ROOT}；你的工作目录是你自己的 agent 工作区，不是这个工程目录。本流程只讲解、不改文件。）

当前讲解流程：${title}

页面卡片内容：${body}

请只围绕这一个流程点讲解，不要把后续流程一次性全部展开。讲解时说明：是什么、放在哪、作用、开发时要注意什么。`;
}
