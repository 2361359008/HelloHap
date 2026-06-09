// 多元开发（高级关卡）模型与文案
// 把多个可自由开发的 HAP 工程聚合到一个「多元开发」入口。每个工程是一套独立的
// 「自由开发」流水线：进入即还原该工程基线 + 安装该工程的初始签名 HAP + 初始化其
// 绑定的 OpenClaw agent 身份，之后与 AI 协同开发。
//
// 板端配套（每个工程需对应存在）：
// - openclaw.json 中配好 agentId 对应的 agent（否则身份初始化报 Agent '...' no longer exists）；
// - projectRoot 下放可编辑工程源码（由 resetUrl 端点从基线 tar 还原）；
// - installUrl 端点把该工程的初始签名 HAP 卸载+安装+启动；
// - buildScript 供 AI 改完源码后编译/签名/安装/启动以在板上查看效果。

import { ADVANCED_BUILD_SCRIPT, buildRestoreTypeMenuPrompt, buildRestoreReminderPrompt } from './FreeDevContent';

// 一个预设提示词按钮。日程有 2 条；扫雷/视频/计算器/俄罗斯方块各 1 条「一句话提示词」
// （label 为展示用一句话，prompt 为发给 OpenClaw 的具体指令）；随心(blank)暂为空。
export class MultiDevPrompt {
  label: string;
  prompt: string;
  accent: string;

  constructor(label: string, prompt: string, accent: string) {
    this.label = label;
    this.prompt = prompt;
    this.accent = accent;
  }
}

export class MultiDevProject {
  id: string;            // 'schedule' | 'minesweeper' | 'blank'
  title: string;         // 卡片/页面标题
  subtitle: string;      // 卡片副标题（一句话介绍）
  accent: string;        // 主题色
  bundleName: string;    // 板上应用包名
  agentId: string;       // OpenClaw 会话绑定的 agent id
  projectRoot: string;   // 板端可编辑工程绝对路径
  resetUrl: string;      // shell-bridge 还原基线端点（完整 URL）
  installUrl: string;    // shell-bridge 安装初始签名 HAP 端点（完整 URL）
  buildScript: string;   // AI 改完后执行的编译/签名/安装/启动脚本
  welcome: string;       // 进入后的欢迎语
  boundary: string;      // 改动边界提示
  presets: MultiDevPrompt[]; // 预设提示词按钮（可为空）

  constructor(id: string, title: string, subtitle: string, accent: string,
    bundleName: string, agentId: string, projectRoot: string,
    resetUrl: string, installUrl: string, buildScript: string,
    welcome: string, boundary: string, presets: MultiDevPrompt[]) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.accent = accent;
    this.bundleName = bundleName;
    this.agentId = agentId;
    this.projectRoot = projectRoot;
    this.resetUrl = resetUrl;
    this.installUrl = installUrl;
    this.buildScript = buildScript;
    this.welcome = welcome;
    this.boundary = boundary;
    this.presets = presets;
  }
}

const BRIDGE: string = 'http://127.0.0.1:7681';

// ===== 工程定义 =====
// 注意：扫雷/随心的 agentId 默认值需与板上 openclaw.json 中实际存在的 agent 对应。

// 1) 日程 HAP 自由开发（即原高级关卡「自由开发」，参数/端点保持不变）。
export const SCHEDULE_PROJECT: MultiDevProject = new MultiDevProject(
  'schedule',
  '日程 HAP 自由开发',
  '在日程 HAP 工程上和 AI 协同自由开发/扩展功能（类型下拉、提醒开关等）。',
  '#89b4fa',
  'com.openclaw.schedulehap.lite',
  'restore',
  '/data/local/tmp/advanced-hapbuild/project',
  BRIDGE + '/reset-advanced',
  BRIDGE + '/install-initial',
  ADVANCED_BUILD_SCRIPT,
  '欢迎来到日程 HAP 自由开发界面，工程已加载初始模板。可直接对话，或用下方提示词驱动 OpenClaw 协同开发。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，99% 的改动只动这一个文件。绝对别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signing/、EntryAbility.ets。',
  [
    new MultiDevPrompt('① 自由开发：类型下拉菜单', buildRestoreTypeMenuPrompt(), '#89b4fa'),
    new MultiDevPrompt('② 自由开发：提醒 + 响铃开关', buildRestoreReminderPrompt(), '#a6e3a1')
  ]
);

// 2) 扫雷 HAP 自由开发（用户自研扫雷，源码 examples/minesweeper-hap）。
export const MINESWEEPER_PROJECT: MultiDevProject = new MultiDevProject(
  'minesweeper',
  '扫雷 HAP 自由开发',
  '在扫雷游戏 HAP 上自由发挥：改棋盘、雷数、配色、交互……和 AI 一起迭代。',
  '#f38ba8',
  'com.openclaw.minesweeper',
  'minesweeper',
  '/data/local/tmp/minesweeper-hapbuild/project',
  BRIDGE + '/reset-minesweeper',
  BRIDGE + '/install-minesweeper',
  '/data/local/tmp/minesweeper-hapbuild/build_minesweeper.sh',
  '欢迎来到扫雷 HAP 自由开发界面，扫雷工程已加载初始模板并装到板上。尽情发挥，和 AI 助手一起把这个扫雷游戏改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  [
    new MultiDevPrompt('一句话改造：顶部显示「剩余雷数」',
      '请只修改扫雷工程的 entry/src/main/ets/pages/Index.ets，在顶部信息栏（笑脸/计时附近）新增一处「剩余雷数」显示，数值＝总雷数 − 已插旗数（复用现有 flagCount 状态），不改扫雷核心逻辑、不动其它文件；改完执行 sh /data/local/tmp/minesweeper-hapbuild/build_minesweeper.sh 编译装板，并把改动回贴给我。',
      '#f38ba8'),
    new MultiDevPrompt('一句话改造：胜负弹层显示本局用时',
      '请只修改扫雷工程的 entry/src/main/ets/pages/Index.ets，在游戏结束的结算弹层（status===1 胜利 / status===2 踩雷那块）里新增一行「本局用时 X 秒」，X 复用现有计时状态 elapsed，不改扫雷核心逻辑、不动其它文件；改完执行 sh /data/local/tmp/minesweeper-hapbuild/build_minesweeper.sh 编译装板，并把改动回贴给我。',
      '#f38ba8'),
    new MultiDevPrompt('一句话改造：插旗格子高亮为红色',
      '请只修改扫雷工程的 entry/src/main/ets/pages/Index.ets，让已插旗的格子（flags[r][c] 为 true）背景或文字用醒目的红色高亮，未插旗保持原样，仅调整格子渲染的配色（参考现有 cellText / 格子样式写法），不改扫雷核心逻辑、不动其它文件；改完执行 sh /data/local/tmp/minesweeper-hapbuild/build_minesweeper.sh 编译装板，并把改动回贴给我。',
      '#f38ba8')
  ]
);

// 3) 随心自由开发（完全空白的 HAP 工程基线，从零开发）。
export const BLANK_PROJECT: MultiDevProject = new MultiDevProject(
  'blank',
  '随心自由开发',
  '一个完全空白的 HAP 工程基线，从零开始，想做什么就和 AI 一起做什么。',
  '#a6e3a1',
  'com.openclaw.blankhap',
  'blank',
  '/data/local/tmp/blank-hapbuild/project',
  BRIDGE + '/reset-blank',
  BRIDGE + '/install-blank',
  '/data/local/tmp/assemble_deploy.sh',
  '欢迎来到随心自由开发界面。当前是你选中的空白工程副本（每个工程相互独立、永久保留）。没有任何预设功能，请尽情发挥想象，把你想要的应用和 AI 助手一起从零开发出来。',
  '只在「当前激活的这个工程副本目录」里改 entry/src/main/ets/pages/Index.ets，绝不动只读模板 template/、绝不删别的工程副本。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。改完用万能脚本 assemble_deploy.sh <当前工程目录> 出包上板。',
  // 随心新建：以下 3 条是「开发目标模板」——点击会填入下方输入框作为你的第一句话（开发目标），
  // 可直接发送或编辑后发送，再由 AI 校验并创建工程。prompt 即作为目标原文填入。
  [
    new MultiDevPrompt('模板：做一个待办清单 HAP',
      '做一个待办清单 HAP：能输入并添加待办、点击条目勾选完成（带删除线），可删除条目，列表实时刷新。',
      '#a6e3a1'),
    new MultiDevPrompt('模板：做一个秒表计时器 HAP',
      '做一个秒表计时器 HAP：有「开始/暂停/清零」按钮，居中大字显示 分:秒.毫秒，计时实时刷新。',
      '#a6e3a1'),
    new MultiDevPrompt('模板：做一个本地记账 HAP',
      '做一个本地记账 HAP：能输入金额和备注添加一条支出，列表显示每条明细，并实时合计总支出。',
      '#a6e3a1')
  ]
);

// 4) 视频播放器 HAP 自由开发（最小可播放基线工程 examples/video-player-hap）。
export const VIDEOPLAYER_PROJECT: MultiDevProject = new MultiDevProject(
  'videoplayer',
  '视频播放器 HAP 自由开发',
  '在一个能播放本地/网络视频的播放器 HAP 上自由发挥：播放控制、进度、列表、配色……和 AI 一起迭代。',
  '#fab387',
  'com.openclaw.videoplayer',
  'videoplayer',
  '/data/local/tmp/videoplayer-hapbuild/project',
  BRIDGE + '/reset-videoplayer',
  BRIDGE + '/install-videoplayer',
  '/data/local/tmp/videoplayer-hapbuild/build_videoplayer.sh',
  '欢迎来到视频播放器 HAP 自由开发界面，播放器工程已加载初始模板并装到板上。尽情发挥，和 AI 助手一起把这个播放器改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  [
    new MultiDevPrompt('一句话改造：新增「快进 15 秒」按钮',
      '请只修改视频播放器工程的 entry/src/main/ets/pages/Index.ets，在播放控制区仿照现有按钮新增一个「快进 15 秒」按钮，点击后让播放进度在 currentTime 基础上前进 15 秒（复用现有播放控件写法），不动其它文件；改完执行 sh /data/local/tmp/videoplayer-hapbuild/build_videoplayer.sh 编译装板，并把改动回贴给我。',
      '#fab387'),
    new MultiDevPrompt('一句话改造：新增「后退 15 秒」按钮',
      '请只修改视频播放器工程的 entry/src/main/ets/pages/Index.ets，在播放控制区仿照现有「播放/暂停」按钮新增一个「后退 15 秒」按钮，点击后让播放进度在 currentTime 基础上后退 15 秒（不小于 0），并调用 controller 跳转到该时间（复用现有播放控件写法），不动其它文件；改完执行 sh /data/local/tmp/videoplayer-hapbuild/build_videoplayer.sh 编译装板，并把改动回贴给我。',
      '#fab387'),
    new MultiDevPrompt('一句话改造：显示播放进度百分比',
      '请只修改视频播放器工程的 entry/src/main/ets/pages/Index.ets，在现有「当前时间 / 总时长」文本附近新增一处播放进度百分比显示，数值＝currentTime ÷ durationTime × 100，保留整数并加「%」，durationTime 为 0 时显示 0%（复用现有 currentTime / durationTime 状态），不动其它文件；改完执行 sh /data/local/tmp/videoplayer-hapbuild/build_videoplayer.sh 编译装板，并把改动回贴给我。',
      '#fab387')
  ]
);

// 5) 计算器 HAP 自由开发（自适应计算器基线工程 examples/calculator-hap）。
export const CALCULATOR_PROJECT: MultiDevProject = new MultiDevProject(
  'calculator',
  '计算器 HAP 自由开发',
  '在一个自适应布局的计算器 HAP 上自由发挥：按键、运算、科学计算、配色……和 AI 一起迭代。',
  '#94e2d5',
  'com.openclaw.calculator',
  'calculator',
  '/data/local/tmp/calculator-hapbuild/project',
  BRIDGE + '/reset-calculator',
  BRIDGE + '/install-calculator',
  '/data/local/tmp/calculator-hapbuild/build_calculator.sh',
  '欢迎来到计算器 HAP 自由开发界面，计算器工程已加载初始模板并装到板上。尽情发挥，和 AI 助手一起把这个计算器改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  [
    new MultiDevPrompt('一句话改造：新增百分号(%)按键',
      '请只修改计算器工程的 entry/src/main/ets/pages/Index.ets，仿照现有按键新增一个百分号「%」按键，按下时把当前显示数字 display 除以 100 并刷新显示（复用现有按键布局与运算写法），不动其它文件；改完执行 sh /data/local/tmp/calculator-hapbuild/build_calculator.sh 编译装板，并把改动回贴给我。',
      '#94e2d5'),
    new MultiDevPrompt('一句话改造：新增正负号(±)按键',
      '请只修改计算器工程的 entry/src/main/ets/pages/Index.ets，仿照现有按键新增一个正负号「±」按键，按下时把当前显示数字 display 取相反数并刷新显示（"0" 时保持 0，复用现有 display 状态与 formatNumber 写法），不动其它文件；改完执行 sh /data/local/tmp/calculator-hapbuild/build_calculator.sh 编译装板，并把改动回贴给我。',
      '#94e2d5'),
    new MultiDevPrompt('一句话改造：新增退格(⌫)按键',
      '请只修改计算器工程的 entry/src/main/ets/pages/Index.ets，仿照现有按键新增一个退格「⌫」按键，按下时删除当前显示 display 的最后一位字符，删到只剩一位或为空时显示回 "0"（复用现有 display 状态写法），不动其它文件；改完执行 sh /data/local/tmp/calculator-hapbuild/build_calculator.sh 编译装板，并把改动回贴给我。',
      '#94e2d5')
  ]
);

// 6) 俄罗斯方块 HAP 自由开发（俄罗斯方块基线工程 examples/tetris-hap）。
export const TETRIS_PROJECT: MultiDevProject = new MultiDevProject(
  'tetris',
  '俄罗斯方块 HAP 自由开发',
  '在俄罗斯方块游戏 HAP 上自由发挥：方块、速度、计分、配色、操作……和 AI 一起迭代。',
  '#cba6f7',
  'com.openclaw.tetris',
  'tetris',
  '/data/local/tmp/tetris-hapbuild/project',
  BRIDGE + '/reset-tetris',
  BRIDGE + '/install-tetris',
  '/data/local/tmp/tetris-hapbuild/build_tetris.sh',
  '欢迎来到俄罗斯方块 HAP 自由开发界面，俄罗斯方块工程已加载初始模板并装到板上。尽情发挥，和 AI 助手一起把这个游戏改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  [
    new MultiDevPrompt('一句话改造：右侧信息区显示「最高分」',
      '请只修改俄罗斯方块工程的 entry/src/main/ets/pages/Index.ets，在右侧信息区（分数/等级附近）新增一处「最高分」显示，并在分数 score 刷新时同步更新最高分（新增一个 @State 保存即可），不改游戏核心逻辑、不动其它文件；改完执行 sh /data/local/tmp/tetris-hapbuild/build_tetris.sh 编译装板，并把改动回贴给我。',
      '#cba6f7'),
    new MultiDevPrompt('一句话改造：右侧显示「已消除行数」',
      '请只修改俄罗斯方块工程的 entry/src/main/ets/pages/Index.ets，在右侧信息区（分数/等级附近）新增一处「已消除行数」显示，数值复用现有 lines 状态（消行时已在累加），不改游戏核心逻辑、不动其它文件；改完执行 sh /data/local/tmp/tetris-hapbuild/build_tetris.sh 编译装板，并把改动回贴给我。',
      '#cba6f7'),
    new MultiDevPrompt('一句话改造：新增「暂停/继续」按钮',
      '请只修改俄罗斯方块工程的 entry/src/main/ets/pages/Index.ets，在操作区新增一个「暂停/继续」按钮：暂停时停止下落计时（参考现有 killTimers），继续时恢复循环（参考现有 startLoop），并用一个 @State 标记当前是否暂停以切换按钮文案，仅在游戏进行中（status===0）生效，不改其它游戏核心逻辑、不动其它文件；改完执行 sh /data/local/tmp/tetris-hapbuild/build_tetris.sh 编译装板，并把改动回贴给我。',
      '#cba6f7')
  ]
);

// 多元开发工程列表（菜单按此顺序展示）。
export const MULTIDEV_PROJECTS: MultiDevProject[] = [
  SCHEDULE_PROJECT,
  MINESWEEPER_PROJECT,
  VIDEOPLAYER_PROJECT,
  CALCULATOR_PROJECT,
  TETRIS_PROJECT,
  BLANK_PROJECT
];

// 按 id 取工程（找不到回退到日程工程）。
export function getMultiDevProject(id: string): MultiDevProject {
  for (let i = 0; i < MULTIDEV_PROJECTS.length; i++) {
    if (MULTIDEV_PROJECTS[i].id === id) {
      return MULTIDEV_PROJECTS[i];
    }
  }
  return SCHEDULE_PROJECT;
}

// 进入工程时发给其 agent 的轻量身份确认问候（与日程一致：只让 agent 一句话确认身份）。
export function buildMultiDevIdentityPrompt(): string {
  return `你好，请用一句话确认你当前的身份。`;
}

// ===== 随心（blank）A 方案：副本隔离的多工程 =====
// 模板只读；每个工程一个独立副本目录 projects/<名字>/；current.txt 指当前激活工程。
// 新建流程：点「新建空白工程」→ 直接进对话(自动命名) → 用户第一句话=开发目标 →
// AI 校验(是否为 HAP 开发需求) → 合规则调 blank_new.sh scaffold + 按目标开发 + assemble_deploy 出包。

// 随心新建工程 · 第一句话目标组合 prompt（发给 blank agent）。
// name=自动生成的工程名, dir=板端项目绝对路径, goal=用户原话。
export function buildBlankGoalPrompt(name: string, dir: string, goal: string): string {
  return '用户想从零开发一个 HAP，目标如下。请严格判断这是否是一个「要开发某种功能的鸿蒙 HAP 应用」的需求：\n\n'
    + '━ 如果**不是**（如闲聊、与开发 HAP 无关、无法理解要做什么应用）：只回复一句「不符合我的要求：请用一句话描述你想开发的 HAP 应用功能，例如"做一个待办清单 HAP"。」不要执行任何脚本、不要创建工程。\n\n'
    + '━ 如果**是**，请按下面步骤创建并开发这个 HAP：\n'
    + '  1) 先执行初始化脚本创建工程副本：sh /data/local/tmp/blank-hapbuild/blank_new.sh ' + name + '\n'
    + '  2) 仅在 ' + dir + '/entry/src/main/ets/pages/Index.ets 内按目标开发（ArkUI/ArkTS），不动 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets，也不动 template/ 或 projects/ 下其它工程。\n'
    + '  3) 开发完执行出包上板：sh /data/local/tmp/assemble_deploy.sh ' + dir + '\n'
    + '  4) 完成后简要汇报你创建了什么、改了哪些内容。\n\n'
    + '用户目标：' + goal;
}

// shell-bridge 随心多工程端点。
export const BLANK_LIST_URL: string = BRIDGE + '/blank-list';
export function buildBlankNewUrl(name: string): string {
  return BRIDGE + '/blank-new?name=' + encodeURIComponent(name);
}
export function buildBlankSelectUrl(name: string): string {
  return BRIDGE + '/blank-select?name=' + encodeURIComponent(name);
}
// 删除单个随心工程副本。
export function buildBlankDeleteUrl(name: string): string {
  return BRIDGE + '/blank-delete?name=' + encodeURIComponent(name);
}
// 一键清空所有随心工程副本。
export const BLANK_CLEAR_ALL_URL: string = BRIDGE + '/blank-clear-all';

// 一个随心工程副本的信息（由 /blank-list 返回的 JSON 解析而来）。
export class BlankProjectInfo {
  name: string;     // 工程名（projects/ 下的目录名）
  path: string;     // 板上绝对路径
  isCurrent: boolean; // 是否为当前激活工程

  constructor(name: string, path: string, isCurrent: boolean) {
    this.name = name;
    this.path = path;
    this.isCurrent = isCurrent;
  }
}
