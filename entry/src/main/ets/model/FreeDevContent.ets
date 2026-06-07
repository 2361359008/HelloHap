// 自由开发（高级关卡）文案
// 高级版「自由开发」入口的 openclaw 协同内容：
// 1) 身份初始化提示词：进入自由开发时发给 openclaw，建立其在日程 HAP（schedulehap）
//    还原任务中的身份与设计约束。
// 2) 两个还原提示词：分别还原「类型」下拉菜单、还原「提醒」下拉与「响铃提醒」开关。
// 这些函数不依赖组件状态，仅返回固定文案，便于在 pages/Index.ets 中通过
// OpenClawClient.startTurn 发送给 openclaw。

// 「日程 HAP 还原（知时）」专属 agent 的 id（其人格、设计约束与逐字设计令牌来自该 agent
// 工作区的 IDENTITY/SOUL/AGENTS 文件，在 agent 启动时由 OpenClaw 注入，无需每轮对话再切换身份）。
// 自由开发会话通过 sessions.create 的 agentId 绑定到该 agent，与其它会话隔离。
export const FREEDEV_AGENT_ID: string = 'restore';

// 进入「自由开发」时发送的简短问候：会话已绑定还原 agent，这里只让它用一句话确认身份。
// 不再执行 set-identity（该命令只改昵称/头像，不切行为）；身份由还原 agent 工作区文件决定。
export function buildScheduleIdentityPrompt(): string {
  return `你好，请用一句话确认你当前的身份和任务（把日程 HAP 分身按主项目设计还原），然后回复「日程 HAP 还原身份已就位，等待提示词」。在收到具体提示词前不要改动任何文件。`;
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
