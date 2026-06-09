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

// 一个预设提示词按钮（仅日程工程使用；扫雷/随心为纯自由对话，无预设）。
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
  '在日程 HAP 工程上和 AI 协同还原/扩展功能（类型下拉、提醒开关等）。',
  '#89b4fa',
  'com.openclaw.schedulehap.lite',
  'restore',
  '/data/local/tmp/advanced-hapbuild/project',
  BRIDGE + '/reset-advanced',
  BRIDGE + '/install-initial',
  ADVANCED_BUILD_SCRIPT,
  '欢迎来到日程 HAP 自由开发界面，工程已还原到初始模板。可直接对话，或用下方提示词驱动 OpenClaw 协同开发。',
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
  '欢迎来到扫雷 HAP 自由开发界面，扫雷工程已还原到初始模板并装到板上。尽情发挥，和 AI 助手一起把这个扫雷游戏改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  []
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
  '/data/local/tmp/blank-hapbuild/build_blank.sh',
  '欢迎来到随心自由开发界面，这是一个完全空白的 HAP 工程。没有任何预设功能，请尽情发挥想象，把你想要的应用和 AI 助手一起从零开发出来。',
  '工程入口与首页在 entry/src/main/ets/pages/Index.ets，从这里开始搭你的界面与逻辑。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  []
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
  '欢迎来到视频播放器 HAP 自由开发界面，播放器工程已还原到初始模板并装到板上。尽情发挥，和 AI 助手一起把这个播放器改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  []
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
  '欢迎来到计算器 HAP 自由开发界面，计算器工程已还原到初始模板并装到板上。尽情发挥，和 AI 助手一起把这个计算器改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  []
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
  '欢迎来到俄罗斯方块 HAP 自由开发界面，俄罗斯方块工程已还原到初始模板并装到板上。尽情发挥，和 AI 助手一起把这个游戏改成你想要的样子。',
  '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，改动尽量只动这一个文件。别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signature/、entryability/EntryAbility.ets。',
  []
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
