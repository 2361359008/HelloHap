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

// 日程 HAP（schedulehap-lite）在板端的工程绝对路径。restore agent 的工作目录是它
// 自己的工作区（…/workspace-restore），并不是这个工程目录，所以提示词里必须用绝对路径
// 定位文件，否则 agent 会在自己工作区里找不到 Index.ets。
export const ADVANCED_PROJECT_ROOT: string = '/data/local/tmp/advanced-hapbuild/project';
export const ADVANCED_INDEX_ETS: string = '/data/local/tmp/advanced-hapbuild/project/entry/src/main/ets/pages/Index.ets';

// 改完文件后让 OpenClaw 自己执行的「编译/签名/安装/启动」包装脚本（先确保 linux-env 容器再就地编译），
// 用来在板上直接看到还原效果。仿简单关练习关「全流程」按钮的做法，由还原 agent 在同一轮里跑完。
export const ADVANCED_BUILD_SCRIPT: string = '/data/local/tmp/advanced-hapbuild/build_advanced_with_env.sh';

// 进入自由开发「初始化身份」那一轮顺带执行的「装回最原始基线 HAP」脚本：只卸载+安装+启动，
// 不编译不签名（直接装预先备份好的基线签名包 schedule-initial-signed.hap），所以很快。
// 目的：每次进入自由开发都把板上已安装的 HAP 还原成最原始模板（项目初始化效果）。
export const ADVANCED_INSTALL_INITIAL_SCRIPT: string = '/data/local/tmp/advanced-hapbuild/install_initial_advanced.sh';

// 还原提示词统一追加的「改完即编译装包并汇报」步骤。
function buildAndReportStep(): string {
  return `

改完文件后，立刻执行下面这一条命令，把改动编译/签名/安装到板上并启动 schedulehap-lite（用于在板上查看还原效果）：
sh ${ADVANCED_BUILD_SCRIPT}
要求：
1. 只执行这一条命令，不要执行任何额外命令。
2. 等待命令执行完毕（编译较慢，请耐心等待）。
3. 命令成功则回复：还原已完成并已编译安装到板上，并附上你改动的代码片段与所在行。
4. 命令失败则回复：编译失败，并原样附上脚本的关键输出（尤其是报错那几行）。`;
}

// 进入「自由开发」时发送的简短问候：会话已绑定还原 agent，这里只让它用一句话确认身份。
// 不再执行 set-identity（该命令只改昵称/头像，不切行为）；身份由还原 agent 工作区文件决定。
export function buildScheduleIdentityPrompt(): string {
  return `你好，请用一句话确认你当前的身份和任务（把日程 HAP 分身按主项目设计还原）。

确认身份后、在等待具体还原提示词之前，请先做一次「项目初始化」：执行下面这一条命令，把板上已安装的日程 HAP 还原成最原始模板（只卸载+安装+启动，不编译不签名，很快）：
sh ${ADVANCED_INSTALL_INITIAL_SCRIPT}
要求：
1. 只执行这一条命令，不要执行任何额外命令，也不要改动任何文件。
2. 命令成功则回复：日程 HAP 还原身份已就位，板上 HAP 已初始化为最原始模板，等待提示词。
3. 命令失败则回复：身份已就位，但初始化安装失败，并原样附上脚本关键输出（尤其报错那几行）。`;
}

// 提示词①：还原「类型」行的下拉菜单。
export function buildRestoreTypeMenuPrompt(): string {
  return `按你身份里记录的主项目设计，把「类型」行从静态展示还原成下拉菜单。

工程根目录：${ADVANCED_PROJECT_ROOT}（注意：你的工作目录是你自己的 agent 工作区，不是这个工程目录，务必用下面的绝对路径定位文件，不要在自己工作区里找 schedulehap-lite/Index.ets）。

只动 ${ADVANCED_INDEX_ETS}，最小改动：
1. 定位：新建/编辑界面里的「类型」行 Row（结构为 Text('类型') + Blank() + Text(this.category) + Text('›')），行属性为 .width('100%').height(62).padding({ left: 20, right: 18 })。
2. 把 .bindMenu 加在**右侧的值文本 Text(this.category) 上**（不要加在整行 Row 上，也不要加在 Text('类型') 上）。三个选项写回 this.category：普通 / 工作 / 学习（对应分类色 #F08C46 / #1677FF / #58B879，颜色用于值文本/标记的既有逻辑，不要新增样式）。
   关键：菜单必须从右侧「类型」当前值（普通日程）的正下方弹出，而不是屏幕左上角——所以 .bindMenu 一定要绑在右侧那个值 Text 上，并传 { placement: Placement.Bottom } 让它在该值下方展开。
3. 复用现有 this.category（@State 已存在），不新增状态、不改默认值，不碰别的行/文件。
4. 改完做括号配平自检，确保 assembleHap 能编译。

参考写法（照此还原；.bindMenu 绑在右侧值文本上、从其下方弹出，选项文案与顺序需与主项目一致）：
\`\`\`ts
Row() {
  Text('类型')// …原有样式不动
  Blank()
  Text(this.category)// …原有样式不动
    .bindMenu([
      { value: '普通', action: () => { this.category = '普通' } },
      { value: '工作', action: () => { this.category = '工作' } },
      { value: '学习', action: () => { this.category = '学习' } }
    ], { placement: Placement.Bottom })
  Text('›')// …原有样式不动
}
.width('100%')
.height(62)
.padding({ left: 20, right: 18 })
\`\`\`
完成后回贴改动后的这段代码，并说明改了哪几行。` + buildAndReportStep();
}

// 提示词②：还原「提醒」下拉与「响铃提醒」开关。
export function buildRestoreReminderPrompt(): string {
  return `按你身份里记录的主项目设计，把分身中被整段删除的「提醒」下拉行与「响铃提醒」开关行整段加回。

工程根目录：${ADVANCED_PROJECT_ROOT}（注意：你的工作目录是你自己的 agent 工作区，不是这个工程目录，务必用下面的绝对路径定位文件，不要在自己工作区里找 schedulehap-lite/Index.ets）。

只动 ${ADVANCED_INDEX_ETS}，最小改动：
1. 定位：在「更多设置」卡片中、原本紧邻「重复」行之后的位置，加回两行（顺序：先「提醒」下拉行，再「响铃提醒」开关行）。
2. 「提醒」行：结构 Text('提醒') + Blank() + Text(this.reminderMode) + Text('›')，.width('100%').height(62).padding({ left: 20, right: 18 })。把 .bindMenu 加在**右侧的值文本 Text(this.reminderMode) 上**（不要加在整行 Row 上），并传 { placement: Placement.Bottom } 让菜单从该值正下方弹出（不要弹到屏幕左上角）。选项写回 this.reminderMode：不提醒 / 准时 / 15 分钟前 / 1 小时前（半角空格必须一致）。
3. 「响铃提醒」行：结构 Text('响铃提醒') + Blank() + this.ToggleSwitch(this.ringReminder, () => { this.ringReminder = !this.ringReminder })，行高 66、padding({ left: 20, right: 18 })。
4. 复用现有 this.reminderMode 与 this.ringReminder（@State 已存在），不新增状态、不改默认值，不碰别的行/文件。
5. 改完做括号配平自检，确保 assembleHap 能编译。

参考写法（照此还原，文案/顺序/数值需与主项目一致）：
\`\`\`ts
Row() {
  Text('提醒').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#161616')
  Blank()
  Text(this.reminderMode).fontSize(15).fontColor('#777B82')
    .bindMenu([
      { value: '不提醒', action: () => { this.reminderMode = '不提醒' } },
      { value: '准时', action: () => { this.reminderMode = '准时' } },
      { value: '15 分钟前', action: () => { this.reminderMode = '15 分钟前' } },
      { value: '1 小时前', action: () => { this.reminderMode = '1 小时前' } }
    ], { placement: Placement.Bottom })
  Text('›').fontSize(25).fontColor('#B5B8BD')
}
.width('100%')
.height(62)
.padding({ left: 20, right: 18 })

Row() {
  Text('响铃提醒').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#161616')
  Blank()
  this.ToggleSwitch(this.ringReminder, () => { this.ringReminder = !this.ringReminder })
}
.width('100%')
.height(66)
.padding({ left: 20, right: 18 })
\`\`\`
完成后回贴改动后的这两段代码，并说明加在了哪一行之后。` + buildAndReportStep();
}
