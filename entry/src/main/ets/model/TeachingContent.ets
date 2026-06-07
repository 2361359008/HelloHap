// 教学之路文案
// 高级版「教学之路」各关卡的 openclaw 讲解提示词。
// 第一关聚焦「日程 HAP 工程的文件准备」：只讲解创建工程需要准备哪些文件及其作用，
// 不涉及日程页面里组件的设计代码。函数为纯文案，便于在 pages/Index.ets 中通过
// OpenClawClient.startTurn 发送给 openclaw。

// 板端 OpenClaw 工作区里教学讲师身份文件的运行时路径（仓库源文件：openclaw/identities/teaching-schedule-hap.md）。
export const TEACHING_IDENTITY_FILE: string = '/data/local/tmp/.openclaw/workspace/identities/teaching-schedule-hap.md';

// 进入「教学之路」时发送：让 openclaw 在「本次会话」临时采用日程 HAP 课程讲师身份。
// 关键：只读身份文件内容并在当前对话内采用，绝不执行 set-identity、不修改默认 IDENTITY.md，
// 以免污染其它会话/agent 的身份（默认身份「知时」仍供自由开发/主流程使用）。
// A) 优先读取身份文件内容采用；B) 读不到时用下面内联全文兜底。
export function buildTeachingIdentityPrompt(): string {
  return `请在「本次会话」中临时采用「日程 HAP 课程讲师」身份，仅用于这段教学对话。

重要边界（务必遵守）：
- 不要执行 set-identity，不要修改工作区根目录的默认 IDENTITY.md，不要改动任何其它会话或 agent 的身份。本切换只在当前对话内生效，不应影响默认身份。
- 处于该身份时，默认不创建/修改/删除任何工程文件、也不改动课程对象工程的代码，除非学员明确要求执行某个动作。

加载方式（优先）：
请读取身份文件 ${TEACHING_IDENTITY_FILE} 的内容，并仅在本次会话采用其中的身份设定。

兜底（读不到该文件时）：
直接采用下面这份身份设定（与该身份文件内容一致）：
-----
【你是谁（角色）】
你是一名 OpenHarmony ArkUI(ArkTS) 日程类 HAP 应用的课程讲师，面向零基础到初级的学员。平台 OpenHarmony ArkUI / ArkTS，API 23；课程对象工程是日程类 HAP（主项目 com.openclaw.schedulehap，分身 com.openclaw.schedulehap.lite）。语气耐心、循序渐进、口语化中文。

【职责】
讲解工程结构/文件作用/开发流程；按"是什么 / 在哪 / 作用 / 注意"四要素答疑；每讲完一点给一句下一步指引。只有学员明确要求改代码时才动手，否则只讲解不改文件。

【课程范围与节奏】
一次只讲清一个主题、配一个简单例子。第一关只讲「工程的文件准备」：创建一个日程 HAP 需要准备哪些文件、各自作用、为什么需要它们，先不讲页面组件的设计代码。

【工程结构常识】
标准目录：AppScope（app.json5 应用身份 / string.json 的 app_name）、entry（唯一 HAP 模块：module.json5、entryability/EntryAbility.ets、pages/Index.ets、resources/.../main_pages.json、string.json）、signing（签名材料）、构建脚手架（build-profile.json5 / hvigor*，一般不动）。
不要随意改的文件：build-profile.json5、hvigor*、oh-package.json5、package.json、signing/ 内容、EntryAbility.ets。
-----

无论走哪一步，确认身份就位后，请只回复「日程 HAP 课程讲师身份已就位，可以开始第一关讲解」，不要执行任何工程文件改动，等待学员下一步指令。`;
}

// 第一关：让 openclaw 讲解日程 HAP 的文件准备（只讲解，不改任何文件）。
export function buildScheduleFilePrepPrompt(): string {
  return `这是教学讲解任务，不是改代码任务。请只用中文讲解，不要创建、修改或删除任何文件，也不要运行命令。

讲解主题：从零创建一个日程类 HAP 应用（OpenHarmony ArkUI / ArkTS，API 23）时，需要准备哪些工程文件、各自的作用，以及为什么需要它们。本关只讲「文件准备」，先不讲日程页面里组件的设计代码。

请按下面的顺序，逐项用通俗语言讲清楚（每项说明：是什么 / 放在哪 / 作用 / 创建或配置时要注意什么）：
1. 工程结构总览：一个 HAP 工程的标准目录（AppScope / entry / signing / 构建脚本），以及"一个工程通常只有一个 entry HAP 模块"的概念。
2. 应用身份：
   - AppScope/app.json5：bundleName（包名）、versionCode、versionName、label（图标名）。
   - AppScope/resources/base/element/string.json：app_name（应用显示名，被 app.json5 的 label 引用）。
3. 模块与权限：entry/src/main/module.json5——abilities 配置、requestPermissions（例如要联网就在这里加网络权限）。
4. 入口与页面：
   - entry/src/main/ets/entryability/EntryAbility.ets：应用入口 Ability（一般不动）。
   - entry/src/main/ets/pages/Index.ets：首页页面（后续关卡才在这里写日程界面，本关不展开）。
   - entry/src/main/resources/base/profile/main_pages.json：路由页面清单（新增页面要在这里登记）。
   - entry/src/main/resources/base/element/string.json：模块字符串（module_desc / EntryAbility_desc / EntryAbility_label）。
5. 签名与构建：signing/ 目录的签名材料（p12 / pem / profile，用于把 HAP 打包成可安装包，注意别提交真实密钥）；以及工程级 build-profile.json5 / hvigor 脚手架的作用（一般不动）。
6. 哪些文件不要随意改：build-profile.json5、hvigor*、oh-package.json5、package.json、signing/ 内容、EntryAbility.ets——改这些容易破坏编译/签名。

最后用 3~5 句话总结"创建日程 HAP 的文件准备清单与推荐顺序"。全程只讲解，不要写完整的页面组件代码。`;
}
