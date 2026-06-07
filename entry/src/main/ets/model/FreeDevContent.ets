// 自由开发（高级关卡）文案
// 高级版「自由开发」入口的 openclaw 协同内容：
// 1) 身份初始化提示词：进入自由开发时发给 openclaw，建立其在日程 HAP（schedulehap）
//    还原任务中的身份与设计约束。
// 2) 两个还原提示词：分别还原「类型」下拉菜单、还原「提醒」下拉与「响铃提醒」开关。
// 这些函数不依赖组件状态，仅返回固定文案，便于在 pages/Index.ets 中通过
// OpenClawClient.startTurn 发送给 openclaw。

// 板端 OpenClaw 工作区里自由开发「还原（知时）」身份文件的运行时路径
//（仓库源文件：openclaw/identities/freedev-schedule-restore.md）。
export const FREEDEV_IDENTITY_FILE: string = '/data/local/tmp/.openclaw/workspace/identities/freedev-schedule-restore.md';

// 进入「自由开发」时发送：让 openclaw 用原生 set-identity 切换到独立的「日程 HAP 还原（知时）」身份文件。
// A) 主用 openclaw agents set-identity --identity-file <还原身份文件>（切到独立身份文件，不改默认 IDENTITY.md）。
// B) 命令不可用/文件不存在时，用下面内联全文兜底采纳。
export function buildScheduleIdentityPrompt(): string {
  return `请切换到「日程 HAP 还原（知时）」身份。

加载方式（优先，使用 OpenClaw 原生身份机制）：
执行命令切换到这份独立的还原身份文件：
  openclaw agents set-identity --identity-file ${FREEDEV_IDENTITY_FILE}
说明：该文件是独立身份文件，不是工作区根目录的默认 IDENTITY.md；执行后你切换到还原身份，默认身份本身不被修改。命令成功即采用该文件中的身份设定。

兜底（仅当上面命令不可用或文件不存在时）：
直接采用下面这份身份与设计约束（与该身份文件内容一致）：
-----
【你的身份】
你是日程类 HAP 应用的协同开发助手。主项目为完整版 com.openclaw.schedulehap，分身（还原起点）为 com.openclaw.schedulehap.lite（目录 schedulehap-lite/）。平台 OpenHarmony ArkUI(ArkTS)，API 23。你的任务是按主项目设计，把分身逐步还原成完整版，且视觉、文案、代码风格与主项目逐字一致。

【工程结构与改动边界】
- 全部 UI 与逻辑都在唯一文件：entry/src/main/ets/pages/Index.ets，99% 的改动只动这一个文件。
- 仅在明确需要系统权限时才动 entry/src/main/module.json5。
- 绝对别碰：build-profile.json5、hvigor*、oh-package.json5、package.json、signing/、EntryAbility.ets。

【分身与主项目的差异（仅三处，都在 Index.ets）】
1. 「类型」行：分身是静态展示（无 .bindMenu）→ 还原 = 补回下拉菜单。
2. 「重复」行：分身是静态展示（无 .bindMenu）→ 还原 = 补回下拉菜单。
3. 「提醒」下拉 +「响铃提醒」开关：分身整段删除 → 还原 = 整段加回。

【设计令牌（必须逐字复用）】
- 主蓝 #1677FF；分类色 普通/工作/学习 = #F08C46 / #1677FF / #58B879。
- 卡片背景 #FFFFFF；页面背景 #F1F2F4；分割线 #ECEDEF。
- 主文字 #161616(或 #171717)；次要文字 #777B82；箭头「›」#B5B8BD。
- 卡片圆角 16；设置行高 选择行 62 / 开关行 66；行内边距 { left: 20, right: 18 }。
- 字号 标签 17(Medium) / 值 15 / 箭头 25；时区固定显示 GMT+08:00 北京。

【ArkUI 写法（点名复用，不要自创）】
- 下拉菜单：在 Row(){ Text(标签) Blank() Text(当前值) Text('›') } 上链式 .bindMenu([{ value, action }, ...])，action 内写回对应 @State 字段。
- 开关：this.ToggleSwitch(this.字段, () => { this.字段 = !this.字段 })。
- 通用设置行：this.SettingRow('标签', '值', () => {})。
- 复用现有 @State（如 category / repeatMode / reminderMode / ringReminder），不新增状态、不改默认值。

【通用约束】
- 一次只做一个可独立验证的小改动；最小改动，不重排属性、不改无关行、不"优化"既有代码。
- 中文文案中的半角空格必须保持一致（如「15 分钟前」「1 小时前」，不要写成「15分钟前」）。
- 每次改完做括号 {} () [] 配平自检，确保 assembleHap 能编译，并回贴改动后的代码片段。
-----

无论走哪一步，确认身份就位后，请只回复「日程 HAP 还原身份已就位，等待提示词」，不要执行任何文件改动。`;
}

// 提示词①：还原「类型」行的下拉菜单。
export function buildRestoreTypeMenuPrompt(): string {
  return `按你身份里记录的主项目设计，把「类型」行从静态展示还原成下拉菜单。

只动 entry/src/main/ets/pages/Index.ets，最小改动：
1. 定位：新建/编辑界面里的「类型」行 Row（结构为 Text('类型') + Blank() + Text(this.category) + Text('›')），行属性为 .width('100%').height(62).padding({ left: 20, right: 18 })。
2. 在该行 .padding(...) 之后追加 .bindMenu，三个选项写回 this.category：普通 / 工作 / 学习（对应分类色 #F08C46 / #1677FF / #58B879，颜色用于值文本/标记的既有逻辑，不要新增样式）。
3. 复用现有 this.category（@State 已存在），不新增状态、不改默认值，不碰别的行/文件。
4. 改完做括号配平自检，确保 assembleHap 能编译。

参考写法（照此还原，选项文案与顺序需与主项目一致）：
\`\`\`ts
.width('100%')
.height(62)
.padding({ left: 20, right: 18 })
.bindMenu([
  { value: '普通', action: () => { this.category = '普通' } },
  { value: '工作', action: () => { this.category = '工作' } },
  { value: '学习', action: () => { this.category = '学习' } }
])
\`\`\`
完成后回贴改动后的这段代码，并说明改了哪几行。`;
}

// 提示词②：还原「提醒」下拉与「响铃提醒」开关。
export function buildRestoreReminderPrompt(): string {
  return `按你身份里记录的主项目设计，把分身中被整段删除的「提醒」下拉行与「响铃提醒」开关行整段加回。

只动 entry/src/main/ets/pages/Index.ets，最小改动：
1. 定位：在「更多设置」卡片中、原本紧邻「重复」行之后的位置，加回两行（顺序：先「提醒」下拉行，再「响铃提醒」开关行）。
2. 「提醒」行：结构 Text('提醒') + Blank() + Text(this.reminderMode) + Text('›')，.width('100%').height(62).padding({ left: 20, right: 18 })，并在 .padding(...) 后追加 .bindMenu，选项写回 this.reminderMode：不提醒 / 准时 / 15 分钟前 / 1 小时前（半角空格必须一致）。
3. 「响铃提醒」行：结构 Text('响铃提醒') + Blank() + this.ToggleSwitch(this.ringReminder, () => { this.ringReminder = !this.ringReminder })，行高 66、padding({ left: 20, right: 18 })。
4. 复用现有 this.reminderMode 与 this.ringReminder（@State 已存在），不新增状态、不改默认值，不碰别的行/文件。
5. 改完做括号配平自检，确保 assembleHap 能编译。

参考写法（照此还原，文案/顺序/数值需与主项目一致）：
\`\`\`ts
Row() {
  Text('提醒').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#161616')
  Blank()
  Text(this.reminderMode).fontSize(15).fontColor('#777B82')
  Text('›').fontSize(25).fontColor('#B5B8BD')
}
.width('100%')
.height(62)
.padding({ left: 20, right: 18 })
.bindMenu([
  { value: '不提醒', action: () => { this.reminderMode = '不提醒' } },
  { value: '准时', action: () => { this.reminderMode = '准时' } },
  { value: '15 分钟前', action: () => { this.reminderMode = '15 分钟前' } },
  { value: '1 小时前', action: () => { this.reminderMode = '1 小时前' } }
])

Row() {
  Text('响铃提醒').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#161616')
  Blank()
  this.ToggleSwitch(this.ringReminder, () => { this.ringReminder = !this.ringReminder })
}
.width('100%')
.height(66)
.padding({ left: 20, right: 18 })
\`\`\`
完成后回贴改动后的这两段代码，并说明加在了哪一行之后。`;
}
