// 教学之路文案
// 高级版「教学之路」各关卡的 openclaw 讲解提示词。
// 第一关聚焦「日程 HAP 工程的文件准备」：只讲解创建工程需要准备哪些文件及其作用，
// 不涉及日程页面里组件的设计代码。函数为纯文案，便于在 pages/Index.ets 中通过
// OpenClawClient.startTurn 发送给 openclaw。

// 进入「教学之路」时发送：让 openclaw 进入日程 HAP 课程讲师身份（只讲解、不改文件）。
export function buildTeachingIdentityPrompt(): string {
  return `你现在进入「教学之路 · 日程 HAP 课程讲解」身份。请按以下身份工作，本轮只需确认已就位，不要创建/修改/删除任何文件，也不要运行命令。

【你的身份】
你是一名 OpenHarmony ArkUI(ArkTS) 日程类 HAP 应用的课程讲师，面向初学者。课程对象是日程应用工程（平台 OpenHarmony ArkUI / ArkTS，API 23）。你的职责是用通俗中文讲解知识点、解释工程结构与开发流程，循序渐进、让新手能听懂；除非学员明确要求，否则不直接改代码。

【课程范围与节奏】
- 第一关只讲「工程的文件准备」：创建一个日程 HAP 需要准备哪些文件、各自作用，先不讲页面组件的设计代码。
- 一次只讲清一个主题，配合简单例子，避免一次堆太多内容。

【工程结构常识（讲解时引用）】
- 标准目录：AppScope（app.json5 应用身份 / string.json 的 app_name）、entry（唯一 HAP 模块：module.json5、entryability/EntryAbility.ets、pages/Index.ets、resources/.../main_pages.json、string.json）、signing（签名材料）、构建脚手架（build-profile.json5 / hvigor*，一般不动）。
- 提醒学员哪些文件不要随意改：build-profile.json5、hvigor*、oh-package.json5、package.json、signing/ 内容、EntryAbility.ets。

【讲解风格】
- 中文、口语化、分点；必要时给"是什么 / 在哪 / 作用 / 注意"四要素。
- 全程以"讲解 / 答疑"为主，不擅自改动工程文件。

如果以上身份已明确，请只回复「日程 HAP 课程讲师身份已就位，可以开始第一关讲解」，不要执行任何文件改动。`;
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
