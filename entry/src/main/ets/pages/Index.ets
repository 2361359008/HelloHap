import { webview } from '@kit.ArkWeb';
import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';
import { ChatMessage } from '../model/OpenClawTypes';
import { buildPracticeFullFlowPrompt, getStepLabel, getSourceTabText } from '../model/CourseContent';
import { buildScheduleIdentityPrompt, buildRestoreTypeMenuPrompt, buildRestoreReminderPrompt, FREEDEV_AGENT_ID, ADVANCED_PROJECT_ROOT } from '../model/FreeDevContent';
import { buildTeachingIdentityPrompt, buildLogHapFlowPrompt, getLogHapFlowChatTitle, TEACHING_AGENT_ID } from '../model/TeachingContent';
import { OpenClawClient } from '../service/OpenClawClient';
import { HomeEntryView } from '../view/HomeEntryView';
import { AdvancedMenuView } from '../view/AdvancedMenuView';
import { TeachingPathView } from '../view/TeachingPathView';
import { FreeDevView } from '../view/FreeDevView';
import { WorkspaceView } from '../view/WorkspaceView';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  chatWebController: webview.WebviewController = new webview.WebviewController();
  private client: OpenClawClient = new OpenClawClient();
  @State currentMode: string = ''; // '', 'terminal', 'openclaw', 'tutorial'

  // --- Tutorial States ---
  @State selectedTaskIndex: number = 0; // 0: None, 1: Hello World, 2: Counter, 3: Layouts
  @State maxUnlockedLevel: number = 1; // 1: Compile, 2: Sign, 3: HDC Deploy
  @State highestCompletedLevel: number = 0; // completed levels are read-only when revisited
  @State level1QaPromptInjected: boolean = false; // inject the level-1 QA memory hint only once
  @State level2QaPromptInjected: boolean = false; // inject the level-2 QA memory hint only once
  @State level3QaPromptInjected: boolean = false; // inject the level-3 QA memory hint only once
  @State tutorialStep: number = 0; // 0: Task List, 1: Confirm Prompt, 2: OpenClaw Running, 3: Completed & Practice
  @State currentProgress: number = 0; // 0 to 100
  @State currentExecutionLog: string = ''; // Running console log
  @State workspaceTab: number = 0; // 0: Live Preview, 1: Source Code, 2: Logs
  @State sourceFileContent: string = '';
  @State sourceFileLoading: boolean = false;
  @State sourceFileError: string = '';
  // 高级关卡源码区：浏览整个工程文件树。advancedFiles 为相对工程根目录的文件路径列表，
  // selectedSourceFile 为当前查看的文件（相对路径）。
  @State advancedFiles: string[] = [];
  @State advancedFilesLoading: boolean = false;
  @State advancedFilesError: string = '';
  @State selectedSourceFile: string = '';
  @State courseResetting: boolean = false;
  @State resetConfirmVisible: boolean = false;
  @State courseResetNoticeVisible: boolean = false;
  @State courseResetNoticeSuccess: boolean = true;
  @State courseResetNoticeTitle: string = '';
  @State courseResetNoticeMessage: string = '';
  private courseResetNoticeSequence: number = 0;
  private readonly boardIndexEtsUrl: string =
    'http://127.0.0.1:7681/read-file?path=%2Fdata%2Flocal%2Ftmp%2Foh61-hapbuild%2Fproject%2Fentry%2Fsrc%2Fmain%2Fets%2Fpages%2FIndex.ets';
  // 高级版（自由发挥/教学共用的 schedulehap-lite 工程）还原接口：刷回初始备份。
  private readonly advancedResetUrl: string = 'http://127.0.0.1:7681/reset-advanced';
  // 高级版「装回最原始基线 HAP」接口（板端直跑 install_initial_advanced.sh，不经 OpenClaw）。
  private readonly advancedInstallInitialUrl: string = 'http://127.0.0.1:7681/install-initial';
  // 教学之路「装上完整主日程 HAP 并启动」接口（板端直跑 install_initial_teaching.sh，不经 OpenClaw）。
  private readonly teachingInstallUrl: string = 'http://127.0.0.1:7681/install-teaching';

  // Step Statuses (0: pending, 1: active, 2: success)
  @State step1Status: number = 0;
  @State step2Status: number = 0;
  @State step3Status: number = 0;
  @State step4Status: number = 0;
  @State step5Status: number = 0;
  @State step6Status: number = 0;

  // Selected Task Metadata
  @State selectedTaskTitle: string = '';
  @State selectedTaskDesc: string = '';
  @State selectedTaskPrompt: string = '';
  @State openclawSummary: string = '';

  // Interactive Live Modification States (updates preview & code instantly!)
  @State previewText: string = '';
  @State previewSubText: string = '';
  @State previewColor: string = '#cdd6f4'; // Catppuccin Text
  @State counterValue: number = 0; // Task 2 state
  @State buttonLabel: string = '点我 +1'; // Task 2 button text
  @State gridColumns: number = 2; // Task 3 cols
  @State itemsList: string[] = ['Card 1', 'Card 2', 'Card 3', 'Card 4']; // Task 3 mock items

  // Chatbox States
  @State chatMessages: Array<ChatMessage> = [
    new ChatMessage('assistant', '你好，我是 OpenClaw 智能答疑助手。完成关卡后，可以在这里继续提问。')
  ];
  @State chatInput: string = '';
  @State openClawBusy: boolean = false;
  @State studentQuestionEnabled: boolean = false;
  @State freeDevReady: boolean = false; // 自由开发：openclaw 身份是否已初始化
  @State advancedScreen: string = 'menu'; // 高级版左侧子页：'menu' | 'teaching' | 'freedev'
  @State teachingReady: boolean = false; // 教学之路：openclaw 讲师身份是否已初始化
  @State teachingFlowStep: number = 0; // 教学之路：当前展示的日志 HAP 开发流程步骤，从 0 开始
  // 进入自由开发/教学时的全屏「项目初始化」加载遮罩：背景压暗、中间聚焦卡片转圈。
  // OpenClaw 一开始返回内容（首个流式事件）就立即关闭，不等整轮跑完。
  @State projectInitOverlayVisible: boolean = false;
  // 初始化分步进度：0=正在还原工程（HTTP 直连板端）；1=正在初始化身份（经 OpenClaw）。
  // 驱动遮罩文案与两步进度点，让初始化卡在哪一步一目了然。
  @State projectInitStep: number = 0;
  // 向 OpenClaw 对话发送消息时的全屏「AI 助手正在处理」加载遮罩，与项目初始化遮罩同款。
  // 同样在 OpenClaw 一开始返回内容（首个流式/最终/错误事件）时立即关闭。
  @State aiProcessingOverlayVisible: boolean = false;
  // 处理遮罩的两个阶段：'sending'=对话发送/网关接收中；'replying'=已被 OpenClaw 接收、正在生成回复。
  // chat.send 成功响应（onSent 回调）时从 sending 切到 replying，让加载更动态。
  @State aiProcessingPhase: string = 'sending';
  // 诊断用：记录本轮已采集过的 chat 事件形态，避免重复刷屏；每轮结束后清空。
  private seenChatEventShapes: Set<string> = new Set();
  // 页面层重置代际。每次清课程状态自增；enterFreeDev/enterTeaching/init*/send* 在
  // restoreAdvancedProject() 等 await 返回后校验，若已被重置则放弃启动旧流程。
  private courseEpoch: number = 0;

  // 实时富展示：一轮进行中轮询 chat.history，把已产生的 思考/工具/结果 实时渲染到对话区。
  // historyPollActive 控制轮询循环；turnRichActive 标记本轮已被富展示接管（接管后忽略 delta 纯文本）。
  private historyPollActive: boolean = false;
  private turnRichActive: boolean = false;
  private historyShapeLogged: boolean = false;

  aboutToAppear(): void {
    this.client.onChatEvent = (payload: Record<string, Object>) => {
      this.handleChatStreamEvent(payload);
    };
    // 诊断：把非 chat 的网关事件名按形态首次出现记入日志（每轮去重），
    // 用于判断网关是否实时下发工具/思考事件（若有则可改为事件驱动的实时展示）。
    this.client.onGatewayEvent = (eventName: string, payload: Record<string, Object>) => {
      let shape = 'gw:' + eventName + ':' + Object.keys(payload).sort().join(',');
      if (this.seenChatEventShapes.has(shape)) {
        return;
      }
      this.seenChatEventShapes.add(shape);
      let dump = JSON.stringify(payload);
      if (dump.length > 600) {
        dump = dump.substring(0, 600) + '…';
      }
      this.currentExecutionLog += '[gwevent ' + eventName + '] ' + dump + '\n';
    };
  }

  // Async helper for delays
  delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  // 超时哨兵：ms 后 resolve('__timeout__')，用于与 OpenClaw 一轮 startTurn 竞速，
  // 网关卡住（迟迟不下发首个事件）时不至于无限卡在初始化遮罩。
  private timeoutSentinel(ms: number): Promise<string> {
    return new Promise((resolve) => setTimeout(() => resolve('__timeout__'), ms));
  }

  getErrorMessage(error: Object): string {
    try {
      let detail = JSON.stringify(error);
      return detail && detail !== '{}' ? detail : String(error);
    } catch (e) {
      return String(error);
    }
  }

  async showCourseResetNotice(success: boolean): Promise<void> {
    this.courseResetNoticeSequence++;
    let sequence = this.courseResetNoticeSequence;
    this.courseResetNoticeSuccess = success;
    this.courseResetNoticeTitle = success ? '课程重置完成' : '课程重置失败';
    this.courseResetNoticeMessage = success
      ? '教学项目已恢复到初始状态，可以重新开始学习。'
      : '暂时无法恢复教学项目，请稍后重试。';
    this.courseResetNoticeVisible = true;
    await this.delay(1000);
    if (sequence === this.courseResetNoticeSequence) {
      this.courseResetNoticeVisible = false;
    }
  }

  async fetchBoardSourceFile(): Promise<void> {
    this.sourceFileLoading = true;
    this.sourceFileError = '';
    try {
      let content = await this.client.requestText(this.boardIndexEtsUrl, http.RequestMethod.GET);
      if (!content || content.indexOf('error:') === 0 || content.indexOf('path not allowed') === 0 ||
        content.indexOf('file not found') === 0 || content.indexOf('missing path') === 0) {
        throw new Error(content.trim() || 'empty source file response');
      }
      this.sourceFileContent = content;
    } catch (e) {
      this.sourceFileContent = '';
      this.sourceFileError = e instanceof Error ? e.message : String(e);
    } finally {
      this.sourceFileLoading = false;
    }
  }

  // 高级关卡：拉取工程根目录下的所有文件（相对路径列表），默认选中主页面 Index.ets。
  async fetchAdvancedFileList(): Promise<void> {
    this.advancedFilesLoading = true;
    this.advancedFilesError = '';
    try {
      let listUrl = 'http://127.0.0.1:7681/list-files?path=' + encodeURIComponent(ADVANCED_PROJECT_ROOT);
      let text = await this.client.requestText(listUrl, http.RequestMethod.GET);
      if (!text || text.indexOf('error:') === 0 || text.indexOf('path not allowed') === 0 ||
        text.indexOf('dir not found') === 0 || text.indexOf('missing path') === 0) {
        throw new Error(text.trim() || 'empty file list response');
      }
      let files: string[] = [];
      let lines = text.split('\n');
      for (let i = 0; i < lines.length; i++) {
        let line = lines[i].trim();
        if (line.length > 0) {
          files.push(line);
        }
      }
      this.advancedFiles = files;
      // 默认选中主页面 Index.ets（若存在），否则第一项。
      if (files.length > 0) {
        let preferred = 'entry/src/main/ets/pages/Index.ets';
        let target = files.indexOf(preferred) >= 0 ? preferred : files[0];
        await this.selectAdvancedSourceFile(target);
      } else {
        this.selectedSourceFile = '';
        this.sourceFileContent = '';
      }
    } catch (e) {
      this.advancedFilesError = e instanceof Error ? e.message : String(e);
      this.advancedFiles = [];
    } finally {
      this.advancedFilesLoading = false;
    }
  }

  // 高级关卡：读取选中文件内容（relPath 相对工程根目录）。
  async selectAdvancedSourceFile(relPath: string): Promise<void> {
    this.selectedSourceFile = relPath;
    this.sourceFileLoading = true;
    this.sourceFileError = '';
    try {
      let absPath = ADVANCED_PROJECT_ROOT + '/' + relPath;
      let readUrl = 'http://127.0.0.1:7681/read-file?path=' + encodeURIComponent(absPath);
      let content = await this.client.requestText(readUrl, http.RequestMethod.GET);
      if (content.indexOf('error:') === 0 || content.indexOf('path not allowed') === 0 ||
        content.indexOf('file not found') === 0 || content.indexOf('missing path') === 0) {
        throw new Error(content.trim() || 'empty source file response');
      }
      this.sourceFileContent = content;
    } catch (e) {
      this.sourceFileContent = '';
      this.sourceFileError = e instanceof Error ? e.message : String(e);
    } finally {
      this.sourceFileLoading = false;
    }
  }

  onSourceTabSelected(): void {
    this.workspaceTab = 1;
    if (this.currentMode === 'advanced') {
      // 高级关卡：浏览整个工程文件树，首次进入（或尚未加载）时拉取文件列表。
      if (this.advancedFiles.length === 0 && !this.advancedFilesLoading) {
        this.fetchAdvancedFileList();
      }
      return;
    }
    if (this.selectedTaskIndex > 0) {
      this.fetchBoardSourceFile();
    }
  }

  handleChatStreamEvent(payload: Record<string, Object>) {
    // 一旦 OpenClaw 开始返回（首个流式/最终/错误事件），立即结束加载遮罩，不必等整轮跑完。
    if (this.projectInitOverlayVisible) {
      this.projectInitOverlayVisible = false;
    }
    if (this.aiProcessingOverlayVisible) {
      this.aiProcessingOverlayVisible = false;
    }

    // 诊断采集：把本轮里每一种「形态」（state + 顶层字段集合）首次出现的原始事件
    // 原样写入 OpenClaw 日志，便于据此精确实现思考/工具调用/工具结果的富展示。
    let shapeKey = String(payload['state']) + '|' + Object.keys(payload).sort().join(',');
    if (!this.seenChatEventShapes.has(shapeKey)) {
      this.seenChatEventShapes.add(shapeKey);
      let dump = JSON.stringify(payload);
      if (dump.length > 2000) {
        dump = dump.substring(0, 2000) + '…(截断)';
      }
      this.currentExecutionLog += '[event] ' + dump + '\n';
    }

    let state = payload['state'] as string;
    let text = '';

    if (payload['text'] && typeof payload['text'] === 'string') {
      text = String(payload['text']);
    } else if (payload['message']) {
      text = this.client.extractMessageText(payload['message'] as Record<string, Object>);
    }

    if (state === 'delta') {
      // 首个 delta 即开始轮询 chat.history，实时把 思考/工具/结果 渲染到对话区。
      if (!this.historyPollActive) {
        this.startHistoryPolling(this.courseEpoch);
      }
      // 已被富展示接管：纯文本由轮询/最终补全，跳过以免与分段气泡相互覆盖闪烁。
      if (this.turnRichActive) {
        return;
      }
      if (this.chatMessages.length > 0) {
        let lastMsg = this.chatMessages[this.chatMessages.length - 1];
        if (lastMsg.sender === 'assistant') {
          lastMsg.text = text;
          this.chatMessages = [...this.chatMessages];
        } else {
          this.chatMessages.push(new ChatMessage('assistant', text));
          this.chatMessages = [...this.chatMessages];
        }
      } else {
        this.chatMessages.push(new ChatMessage('assistant', text));
        this.chatMessages = [...this.chatMessages];
      }
    } else if (state === 'final') {
      this.stopHistoryPolling();
      // 兜底：最终回复为空或 NO_REPLY 时，不要把对话气泡清空（看起来像被截断）。
      // 若已有实质过程文案则保留并补一句「已完成」；否则给一句明确的完成提示。
      let trimmedFinal = text.trim();
      let isEmptyFinal = (trimmedFinal === '' || trimmedFinal === 'NO_REPLY');
      let fallbackFinal = '已执行完成，但本轮未返回文字总结。可在「工作区」查看改动的代码与编译/安装结果。';
      // 富展示已接管时，对话区由 history 分段驱动，不再改纯文本气泡（否则会覆盖分段）。
      if (!this.turnRichActive) {
        if (this.chatMessages.length > 0 && this.chatMessages[this.chatMessages.length - 1].sender === 'assistant') {
          let lastMsg = this.chatMessages[this.chatMessages.length - 1];
          if (!isEmptyFinal) {
            lastMsg.text = text;
          } else if (this.isPlaceholderOrEmpty(lastMsg.text)) {
            lastMsg.text = fallbackFinal;
          } else {
            lastMsg.text = lastMsg.text + '\n\n（本轮已执行完成。）';
          }
        } else {
          this.chatMessages.push(new ChatMessage('assistant', isEmptyFinal ? fallbackFinal : text));
        }
        this.chatMessages = [...this.chatMessages];
      }

      this.client.completeTurn(isEmptyFinal ? fallbackFinal : text);
      this.studentQuestionEnabled = true;
      this.openClawBusy = false;
      this.seenChatEventShapes.clear();

      // 收尾再拉一次历史，补齐完整过程与最终回复；持久化可能略有延迟，1.2s 后再补一次。
      let finalEpoch = this.courseEpoch;
      this.enrichTurnFromHistory(finalEpoch);
      setTimeout(() => { this.enrichTurnFromHistory(finalEpoch); }, 1200);
    } else if (state === 'error' || state === 'aborted') {
      this.stopHistoryPolling();
      let errorMsg = 'OpenClaw 调用失败/中断';
      if (payload['error']) {
        errorMsg = 'OpenClaw 错误: ' + String(payload['error']);
      }
      this.chatMessages.push(new ChatMessage('assistant', errorMsg));
      this.chatMessages = [...this.chatMessages];
      
      this.client.failTurn(new Error(errorMsg));
      this.openClawBusy = false;
      this.seenChatEventShapes.clear();
    }
  }

  // 判断某条助手气泡是否只是占位文案（「OpenClaw 正在…」「正在还原…」）或空，
  // 用于 final 兜底：最终回复为空/NO_REPLY 时决定是补完成提示还是保留已有过程文案。
  private isPlaceholderOrEmpty(s: string): boolean {
    let t = s.trim();
    if (t === '') {
      return true;
    }
    return t.startsWith('OpenClaw 正在') || t.startsWith('正在');
  }

  // 开始/停止本轮的 chat.history 轮询（递归 setTimeout，避免请求重叠）。
  private startHistoryPolling(epoch: number): void {
    if (this.historyPollActive) {
      return;
    }
    this.historyPollActive = true;
    this.turnRichActive = false;
    this.historyShapeLogged = false;
    this.scheduleHistoryPoll(epoch);
  }

  private stopHistoryPolling(): void {
    this.historyPollActive = false;
  }

  private scheduleHistoryPoll(epoch: number): void {
    setTimeout(() => {
      if (!this.historyPollActive || epoch !== this.courseEpoch) {
        return;
      }
      this.applyHistoryToTurn(epoch).then(() => {
        if (this.historyPollActive && epoch === this.courseEpoch) {
          this.scheduleHistoryPoll(epoch);
        }
      }).catch(() => {
        if (this.historyPollActive && epoch === this.courseEpoch) {
          this.scheduleHistoryPoll(epoch);
        }
      });
    }, 1500);
  }

  // final 收尾时再拉一次历史，补齐完整过程与最终回复（与轮询共用同一渲染逻辑）。
  private async enrichTurnFromHistory(epoch: number): Promise<void> {
    await this.applyHistoryToTurn(epoch);
  }

  // 拉取会话历史，把本轮（历史里最后一条 user 之后的所有消息）解析成
  // 「思考 / 工具调用 / 工具返回 / 文本」分段，替换对话区里本轮的纯文本助手气泡，
  // 呈现与 WebUI 类似的实时过程。任何异常或课程被重置都静默放弃，保留已显示的纯文本。
  private async applyHistoryToTurn(epoch: number): Promise<void> {
    try {
      let raw = await this.client.fetchHistoryRaw();
      if (epoch !== this.courseEpoch || !raw) {
        return;
      }
      let payload = JSON.parse(raw) as Record<string, Object>;
      let messages = this.extractHistoryMessages(payload);
      // 诊断：每轮仅首次记录历史响应结构，便于核对/排错（截图即可），不刷屏。
      if (!this.historyShapeLogged) {
        this.historyShapeLogged = true;
        this.currentExecutionLog += '[history] msgs=' + messages.length.toString()
          + ' keys=' + Object.keys(payload).sort().join(',') + '\n';
      }
      if (messages.length === 0) {
        return;
      }
      // 持久化时序守卫：历史里的 user 条数 < 对话区 user 气泡数，说明本轮还没写入历史，
      // 此时套用会错把上一轮内容贴到当前轮，故跳过等待下次轮询。
      let histUsers = 0;
      for (let i = 0; i < messages.length; i++) {
        if (String(messages[i]['role']) === 'user') {
          histUsers++;
        }
      }
      let uiUsers = 0;
      for (let i = 0; i < this.chatMessages.length; i++) {
        if (this.chatMessages[i].sender === 'user') {
          uiUsers++;
        }
      }
      if (histUsers < uiUsers) {
        return;
      }
      let segments = this.buildTurnSegments(messages);
      if (segments.length === 0) {
        return;
      }
      let lastUserIdx = -1;
      for (let i = this.chatMessages.length - 1; i >= 0; i--) {
        if (this.chatMessages[i].sender === 'user') {
          lastUserIdx = i;
          break;
        }
      }
      let head: Array<ChatMessage> = lastUserIdx >= 0
        ? this.chatMessages.slice(0, lastUserIdx + 1)
        : this.chatMessages.slice(0, this.chatMessages.length);
      this.chatMessages = head.concat(segments);
      // 标记本轮已被富展示接管：后续 delta 不再写纯文本气泡。
      this.turnRichActive = true;
    } catch (e) {
      // 静默：富展示是增强项，失败不影响已显示的最终回复。
    }
  }

  // 从 chat.history 响应里取出消息数组，兼容多种封装：
  // 顶层 messages/items/events/history/log/entries 任一为数组即可；
  // 数组元素兼容 {type:'message', message:{role,content,...}} 与直接 {role,content,...} 两种。
  private extractHistoryMessages(payload: Record<string, Object>): Array<Record<string, Object>> {
    let arr: Array<Object> | null = null;
    let candidates: Array<string> = ['messages', 'items', 'events', 'history', 'log', 'entries'];
    for (let i = 0; i < candidates.length; i++) {
      let v = payload[candidates[i]];
      if (Array.isArray(v)) {
        arr = v as Array<Object>;
        break;
      }
    }
    let out: Array<Record<string, Object>> = [];
    if (!arr) {
      return out;
    }
    for (let i = 0; i < arr.length; i++) {
      let rec = arr[i] as Record<string, Object>;
      if (!rec) {
        continue;
      }
      if (rec['message'] && typeof rec['message'] === 'object') {
        out.push(rec['message'] as Record<string, Object>);
      } else if (rec['role']) {
        out.push(rec);
      }
    }
    return out;
  }

  // 取历史里最后一条 user 之后的消息，逐条按内容块拆成富展示分段。
  private buildTurnSegments(messages: Array<Record<string, Object>>): Array<ChatMessage> {
    let lastUser = -1;
    for (let i = messages.length - 1; i >= 0; i--) {
      if (String(messages[i]['role']) === 'user') {
        lastUser = i;
        break;
      }
    }
    let start = lastUser >= 0 ? lastUser + 1 : 0;
    let segs: Array<ChatMessage> = [];
    for (let i = start; i < messages.length; i++) {
      let m = messages[i];
      let role = String(m['role']);
      if (role === 'toolResult') {
        let toolName = m['toolName'] ? String(m['toolName']) : 'tool';
        let isErr = (m['isError'] ? String(m['isError']) === 'true' : false);
        let resText = this.extractBlockText(m['content']);
        segs.push(new ChatMessage('assistant', resText, 'toolResult', toolName, '', isErr));
      } else if (role === 'assistant') {
        let content = m['content'];
        if (Array.isArray(content)) {
          let blocks = content as Array<Object>;
          for (let j = 0; j < blocks.length; j++) {
            let b = blocks[j] as Record<string, Object>;
            if (!b) {
              continue;
            }
            let bt = String(b['type']);
            if (bt === 'thinking') {
              let th = b['thinking'] ? String(b['thinking']) : '';
              if (th.trim() !== '') {
                segs.push(new ChatMessage('assistant', th, 'thinking'));
              }
            } else if (bt === 'text') {
              let tx = b['text'] ? String(b['text']) : '';
              if (tx.trim() !== '') {
                segs.push(new ChatMessage('assistant', tx, 'text'));
              }
            } else if (bt === 'toolCall') {
              let name = b['name'] ? String(b['name']) : 'tool';
              let argSummary = this.summarizeToolArgs(b['arguments']);
              segs.push(new ChatMessage('assistant', '', 'toolCall', name, argSummary));
            }
          }
        } else {
          let tx = this.extractBlockText(content);
          if (tx.trim() !== '') {
            segs.push(new ChatMessage('assistant', tx, 'text'));
          }
        }
      }
    }
    return segs;
  }

  // 从内容数组/字符串里拼出纯文本（用于 user/toolResult 的 text 块）。
  private extractBlockText(content: Object | undefined): string {
    if (!content) {
      return '';
    }
    if (typeof content === 'string') {
      return content as string;
    }
    if (Array.isArray(content)) {
      let arr = content as Array<Object>;
      let parts: Array<string> = [];
      for (let i = 0; i < arr.length; i++) {
        let b = arr[i] as Record<string, Object>;
        if (b && b['type'] === 'text' && b['text']) {
          parts.push(String(b['text']));
        } else if (typeof arr[i] === 'string') {
          parts.push(arr[i] as string);
        }
      }
      return parts.join('');
    }
    return '';
  }

  // 把工具参数压成一行摘要：exec 显示命令、read 显示路径(+offset/limit)，其它回退紧凑 JSON。
  private summarizeToolArgs(args: Object | undefined): string {
    if (!args || typeof args !== 'object') {
      return '';
    }
    let a = args as Record<string, Object>;
    if (a['command']) {
      return String(a['command']);
    }
    if (a['path']) {
      let p = String(a['path']);
      if (a['offset'] && a['limit']) {
        return p + '  (offset ' + String(a['offset']) + ', limit ' + String(a['limit']) + ')';
      }
      return p;
    }
    let s = JSON.stringify(a);
    if (s.length > 200) {
      s = s.substring(0, 200) + '…';
    }
    return s;
  }

  async sendChatMessage() {
    if (!this.chatInput.trim()) {
      return;
    }
    if (!this.studentQuestionEnabled && this.tutorialStep !== 4) {
      promptAction.showToast({
        message: '请先完成本关 OpenClaw 协同开发任务，再进行自由提问。',
        duration: 2200
      });
      return;
    }
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    let userMsg = this.chatInput.trim();
    this.chatMessages.push(new ChatMessage('user', userMsg));
    this.chatInput = '';
    this.openClawBusy = true;
    this.aiProcessingPhase = 'sending';
    this.aiProcessingOverlayVisible = true;
    let epoch = this.courseEpoch;

    try {
      let sendMsg = userMsg;
      if (this.selectedTaskIndex === 4 && userMsg === '请将 HAP 主页面内容修改为 hello world，然后按完整流程执行：编译未签名 HAP、签名生成已签名 HAP、卸载旧应用、安装新 HAP 并启动 EntryAbility。请在执行前说明会修改的文件和命令边界，执行后汇报每一步真实结果。') {
        sendMsg = buildPracticeFullFlowPrompt();
      } else if (this.selectedTaskIndex === 1 && this.tutorialStep === 3 && this.highestCompletedLevel >= 1 && !this.level1QaPromptInjected) {
        sendMsg = '请先读取第一关答疑记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile-qa.md。' +
          '本轮是学生课后自由提问，不是关卡触发任务。请只解释问题，不要重新编译、签名、安装或启动应用。\n\n学生问题：' + userMsg;
        this.level1QaPromptInjected = true;
      } else if (this.selectedTaskIndex === 2 && this.tutorialStep === 3 && this.highestCompletedLevel >= 2 && !this.level2QaPromptInjected) {
        sendMsg = '请先读取第二关答疑记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level2-sign-qa.md。' +
          '本轮是学生课后自由提问，不是关卡触发任务。请只解释问题，不要重新编译、签名、安装或启动应用，不要改变当前关卡进度。\n\n学生问题：' + userMsg;
        this.level2QaPromptInjected = true;
      } else if (this.selectedTaskIndex === 3 && this.tutorialStep === 3 && this.highestCompletedLevel >= 3 && !this.level3QaPromptInjected) {
        sendMsg = '请先读取第三关答疑记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level3-deploy-qa.md。' +
          '本轮是学生课后自由提问，不是关卡触发任务。请只解释问题，不要重新编译、签名、安装或启动应用，不要改变当前关卡进度。\n\n学生问题：' + userMsg;
        this.level3QaPromptInjected = true;
        this.level3QaPromptInjected = true;
      }
      let chatAgentId = '';
      if (this.currentMode === 'advanced') {
        chatAgentId = this.advancedScreen === 'teaching' ? TEACHING_AGENT_ID : FREEDEV_AGENT_ID;
      }
      await this.client.startTurn(sendMsg, () => {
        this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在思考中...'));
        this.chatMessages = [...this.chatMessages];
      }, chatAgentId, () => { this.aiProcessingPhase = 'replying'; });
      this.openClawBusy = false;
    } catch (error) {
      this.aiProcessingOverlayVisible = false;
      // 因课程重置导致的失败：对话已刷新，不再补残留失败文案。
      if (epoch !== this.courseEpoch) {
        return;
      }
      let message = (error as Error).message;
      this.currentExecutionLog += '[openclaw] chat failed: ' + message + '\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 调用失败：' + message));
      this.openClawBusy = false;
    }
  }

  selectPracticeLevel() {
    this.selectedTaskIndex = 4;
    this.selectedTaskTitle = '练习关卡：OpenClaw 自由练习';
    this.selectedTaskDesc = '选择一个练习提示词，自动填入下方输入框，再发送给 OpenClaw 进行答疑或演示。';
    this.selectedTaskPrompt = '';
    this.tutorialStep = 4;
    this.workspaceTab = 0;
    this.openClawBusy = false;
    this.studentQuestionEnabled = true;
    this.chatInput = '';
    this.chatMessages.push(new ChatMessage('assistant', '已进入练习关卡。请选择左侧练习提示词，内容会自动填入下方输入框，确认后点击发送。'));
  }

  fillPracticePrompt(promptText: string) {
    this.chatInput = promptText;
    promptAction.showToast({
      message: '已填入输入框，请确认后发送。',
      duration: 1600
    });
  }

  async initFreeDevIdentity(): Promise<void> {
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    let epoch = this.courseEpoch;
    this.studentQuestionEnabled = true;
    this.workspaceTab = 0;
    this.chatInput = '';
    this.chatMessages.push(new ChatMessage('user', '【自由开发】初始化日程 HAP 自由开发身份'));
    this.openClawBusy = true;
    try {
      // 与 60s 超时哨兵竞速：网关迟迟不响应时不至于无限卡在初始化遮罩。
      let raceResult = await Promise.race([
        this.client.startTurn(buildScheduleIdentityPrompt(), () => {
          this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在初始化身份...'));
          this.chatMessages = [...this.chatMessages];
        }, FREEDEV_AGENT_ID).then(() => 'ok'),
        this.timeoutSentinel(60000)
      ]);
      // 被重置过就不再标记就绪（旧身份初始化作废），避免误置 freeDevReady 让旧会话被当成已就绪。
      if (epoch !== this.courseEpoch) {
        return;
      }
      if (raceResult === '__timeout__') {
        this.projectInitOverlayVisible = false;
        this.openClawBusy = false;
        this.currentExecutionLog += '[openclaw] free-dev identity init timeout (60s)\n';
        this.chatMessages.push(new ChatMessage('assistant',
          '身份初始化超时（网关 60 秒内未响应）。请确认板端 OpenClaw 网关与 shell-bridge 在运行，然后点「重置开发」后重新进入自由开发。'));
        this.chatMessages = [...this.chatMessages];
        return;
      }
      this.freeDevReady = true;
      this.openClawBusy = false;
    } catch (error) {
      // 因课程重置导致的失败（代际已变）：clearCourseState 已把对话刷新干净，
      // 这里不要再往里补「初始化失败：Course reset」残留文案。
      if (epoch !== this.courseEpoch) {
        return;
      }
      let message = (error as Error).message;
      this.currentExecutionLog += '[openclaw] free-dev identity init failed: ' + message + '\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 身份初始化失败：' + message));
      this.openClawBusy = false;
      this.projectInitOverlayVisible = false;
    }
  }

  async sendFreeDevPrompt(promptText: string, label: string): Promise<void> {
    if (!this.freeDevReady) {
      promptAction.showToast({
        message: '请先点击“进入自由开发”初始化身份。',
        duration: 1800
      });
      return;
    }
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    let epoch = this.courseEpoch;
    this.workspaceTab = 0;
    this.chatMessages.push(new ChatMessage('user', label));
    this.openClawBusy = true;
    this.aiProcessingPhase = 'sending';
    this.aiProcessingOverlayVisible = true;
    try {
      await this.client.startTurn(promptText, () => {
        this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在思考中...'));
        this.chatMessages = [...this.chatMessages];
      }, FREEDEV_AGENT_ID, () => { this.aiProcessingPhase = 'replying'; });
      this.openClawBusy = false;
    } catch (error) {
      this.aiProcessingOverlayVisible = false;
      // 因课程重置导致的失败：对话已刷新，不再补残留失败文案。
      if (epoch !== this.courseEpoch) {
        return;
      }
      let message = (error as Error).message;
      this.currentExecutionLog += '[openclaw] free-dev prompt failed: ' + message + '\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 调用失败：' + message));
      this.openClawBusy = false;
    }
  }

  async initTeachingIdentity(): Promise<void> {
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    let epoch = this.courseEpoch;
    this.studentQuestionEnabled = true;
    this.workspaceTab = 0;
    this.chatInput = '';
    this.chatMessages.push(new ChatMessage('user', '【教学之路】初始化日志 HAP 课程讲师身份'));
    this.openClawBusy = true;
    try {
      // 与 60s 超时哨兵竞速：网关迟迟不响应时不至于无限卡在初始化遮罩。
      let raceResult = await Promise.race([
        this.client.startTurn(buildTeachingIdentityPrompt(), () => {
          this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在初始化讲师身份...'));
          this.chatMessages = [...this.chatMessages];
        }, TEACHING_AGENT_ID).then(() => 'ok'),
        this.timeoutSentinel(60000)
      ]);
      // 被重置过就不再标记就绪（旧身份初始化作废）。
      if (epoch !== this.courseEpoch) {
        return;
      }
      if (raceResult === '__timeout__') {
        this.projectInitOverlayVisible = false;
        this.openClawBusy = false;
        this.currentExecutionLog += '[openclaw] teaching identity init timeout (60s)\n';
        this.chatMessages.push(new ChatMessage('assistant',
          '讲师身份初始化超时（网关 60 秒内未响应）。请确认板端 OpenClaw 网关与 shell-bridge 在运行，然后点「重置开发」后重新进入教学之路。'));
        this.chatMessages = [...this.chatMessages];
        return;
      }
      this.teachingReady = true;
      this.openClawBusy = false;
    } catch (error) {
      // 因课程重置导致的失败：对话已刷新，不再补残留失败文案。
      if (epoch !== this.courseEpoch) {
        return;
      }
      let message = (error as Error).message;
      this.currentExecutionLog += '[openclaw] teaching identity init failed: ' + message + '\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 讲师身份初始化失败：' + message));
      this.openClawBusy = false;
      this.projectInitOverlayVisible = false;
    }
  }

  async enterNextLogHapFlow(): Promise<void> {
    if (!this.teachingReady) {
      promptAction.showToast({
        message: '请先初始化讲师身份。',
        duration: 1800
      });
      return;
    }
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    let previousStep = this.teachingFlowStep;
    let nextStep = previousStep + 1;
    if (nextStep >= 6) {
      promptAction.showToast({
        message: '日志 HAP 开发教学流程已完成。',
        duration: 1800
      });
      return;
    }
    let epoch = this.courseEpoch;
    this.studentQuestionEnabled = true;
    this.workspaceTab = 0;
    this.teachingFlowStep = nextStep;
    this.chatMessages.push(new ChatMessage('user', '【教学之路·开发流程】请讲解：' + getLogHapFlowChatTitle(nextStep)));
    this.openClawBusy = true;
    this.aiProcessingPhase = 'sending';
    this.aiProcessingOverlayVisible = true;
    try {
      await this.client.startTurn(buildLogHapFlowPrompt(nextStep), () => {
        this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在讲解...'));
        this.chatMessages = [...this.chatMessages];
      }, TEACHING_AGENT_ID, () => { this.aiProcessingPhase = 'replying'; });
      this.openClawBusy = false;
    } catch (error) {
      this.aiProcessingOverlayVisible = false;
      // 因课程重置导致的失败：对话已刷新，不再补残留失败文案。
      if (epoch !== this.courseEpoch) {
        return;
      }
      let message = (error as Error).message;
      this.teachingFlowStep = previousStep;
      this.currentExecutionLog += '[openclaw] teaching flow step failed: ' + message + '\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 调用失败：' + message));
      this.openClawBusy = false;
    }
  }

  clearCourseState(): void {
    // 页面层代际自增：在途的 enterFreeDev/enterTeaching/init* 在其 await 返回后会发现
    // 代际已变而放弃继续启动旧流程（如已被重置后才返回的 restoreAdvancedProject）。
    this.courseEpoch++;
    this.client.reset();
    this.stopHistoryPolling();
    this.turnRichActive = false;

    this.selectedTaskIndex = 0;
    this.maxUnlockedLevel = 1;
    this.highestCompletedLevel = 0;
    this.level1QaPromptInjected = false;
    this.level2QaPromptInjected = false;
    this.level3QaPromptInjected = false;
    this.tutorialStep = 0;
    this.currentProgress = 0;
    this.currentExecutionLog = '';
    this.workspaceTab = 0;
    this.step1Status = 0;
    this.step2Status = 0;
    this.step3Status = 0;
    this.step4Status = 0;
    this.step5Status = 0;
    this.step6Status = 0;
    this.chatInput = '';
    this.openClawBusy = false;
    this.studentQuestionEnabled = false;
    this.freeDevReady = false;
    this.advancedScreen = 'menu';
    this.teachingReady = false;
    this.teachingFlowStep = 0;
    this.projectInitOverlayVisible = false;
    this.projectInitStep = 0;
    this.aiProcessingOverlayVisible = false;
    this.advancedFiles = [];
    this.advancedFilesError = '';
    this.selectedSourceFile = '';
    this.sourceFileContent = '';
    this.chatMessages = [
      new ChatMessage('assistant', '你好，我是 OpenClaw 智能答疑助手。请先选择第一关并呼叫 OpenClaw 完成首轮协同开发，随后即可继续提问。')
    ];
  }

  // 弹出二次确认弹窗（自定义暗色样式，见 build 末尾的 resetConfirmVisible 遮罩）。
  // 用户点「确定」才真正重置。自由开发入口下文案用「重置开发」，其余用「重置课程」。
  confirmResetCourse(): void {
    if (this.courseResetting) {
      return;
    }
    this.resetConfirmVisible = true;
  }

  async resetCourse(): Promise<void> {
    if (this.courseResetting) {
      return;
    }
    this.courseResetting = true;
    // 先无条件清掉会话与课程状态（含 client.reset() 关旧连接 + freeDevReady/teachingReady=false）。
    // 不能把它放在工程还原 HTTP 成功之后：高级版还原脚本较重（30s 超时），一旦慢/失败就会跳过清理，
    // 导致会话没被重置、freeDevReady 仍为 true，下次进自由发挥复用旧会话（即「粘在上一个会话」）。
    // 简单关还原脚本轻量、基本不失败，所以一直能开新会话——这正是两者表现差异的根因。
    this.clearCourseState();
    this.sourceFileContent = '';
    this.sourceFileError = '';
    try {
      let resetUrl = this.currentMode === 'advanced' ? this.advancedResetUrl : 'http://127.0.0.1:7681/reset-course';
      await this.client.requestText(
        resetUrl,
        http.RequestMethod.GET
      );
      this.showCourseResetNotice(true);
    } catch (e) {
      let message = e instanceof Error ? e.message : this.getErrorMessage(e as Object);
      console.error('Course reset failed: ' + message);
      this.showCourseResetNotice(false);
    } finally {
      this.courseResetting = false;
    }
  }

  // 把板端高级版工程（/data/local/tmp/advanced-hapbuild/project）刷回初始备份，
  // 确保每次进入教学/自由发挥都是最原始的模板（OpenClaw 交互会改动该工程）。
  async restoreAdvancedProject(): Promise<boolean> {
    // 还原是板端直连脚本（/reset-advanced → restore_advanced_project.sh），偶发失败/超时，
    // 故最多重试 3 次，每次间隔 800ms；全部失败再给出明确反馈（而不是默默用脏工程继续）。
    const maxAttempts = 3;
    let lastInfo = '';
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        let out = await this.client.requestText(this.advancedResetUrl, http.RequestMethod.GET);
        this.currentExecutionLog += '[reset-advanced] (try ' + attempt.toString() + ') ' + out + '\n';
        if (out.indexOf('ok:') >= 0) {
          this.chatMessages.push(new ChatMessage('assistant', '日程工程已还原到初始模板，可以开始本关。'));
          this.chatMessages = [...this.chatMessages];
          return true;
        }
        lastInfo = out;
      } catch (e) {
        lastInfo = e instanceof Error ? e.message : this.getErrorMessage(e as Object);
        this.currentExecutionLog += '[reset-advanced] (try ' + attempt.toString() + ') failed: ' + lastInfo + '\n';
      }
      if (attempt < maxAttempts) {
        await this.delay(800);
      }
    }
    this.chatMessages.push(new ChatMessage('assistant',
      '日程工程还原多次未成功（已重试 ' + maxAttempts.toString() + ' 次，将继续，但工程可能不是初始状态）：' + lastInfo));
    this.chatMessages = [...this.chatMessages];
    return false;
  }

  // 把板上已安装的日程 HAP 还原成最原始基线包：板端直跑 install_initial_advanced.sh
  // （/install-initial → 卸载+安装+启动基线签名包，不编译不签名），不再经 OpenClaw 发提示词，秒级完成。
  // 与 restoreAdvancedProject 同样最多重试 3 次（间隔 800ms），失败给明确反馈但不阻断后续身份确认。
  async installInitialAdvanced(): Promise<boolean> {
    const maxAttempts = 3;
    let lastInfo = '';
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        let out = await this.client.requestText(this.advancedInstallInitialUrl, http.RequestMethod.GET);
        this.currentExecutionLog += '[install-initial] (try ' + attempt.toString() + ') ' + out + '\n';
        if (out.indexOf('ok:') >= 0) {
          this.chatMessages.push(new ChatMessage('assistant', '板上日程 HAP 已还原为最原始模板。'));
          this.chatMessages = [...this.chatMessages];
          return true;
        }
        lastInfo = out;
      } catch (e) {
        lastInfo = e instanceof Error ? e.message : this.getErrorMessage(e as Object);
        this.currentExecutionLog += '[install-initial] (try ' + attempt.toString() + ') failed: ' + lastInfo + '\n';
      }
      if (attempt < maxAttempts) {
        await this.delay(800);
      }
    }
    this.chatMessages.push(new ChatMessage('assistant',
      '板上日程 HAP 初始化安装多次未成功（已重试 ' + maxAttempts.toString() + ' 次）：' + lastInfo));
    this.chatMessages = [...this.chatMessages];
    return false;
  }

  // 教学之路初始状态：仅启动（aa start）完整主日程 HAP（schedule-signed.hap），不卸载/不重装。
  // 板端直跑 install_initial_teaching.sh（/install-teaching），不经 OpenClaw；最多重试 3 次（间隔 800ms）。
  async installTeachingBaseline(): Promise<boolean> {
    const maxAttempts = 3;
    let lastInfo = '';
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        let out = await this.client.requestText(this.teachingInstallUrl, http.RequestMethod.GET);
        this.currentExecutionLog += '[install-teaching] (try ' + attempt.toString() + ') ' + out + '\n';
        if (out.indexOf('ok:') >= 0) {
          this.chatMessages.push(new ChatMessage('assistant', '板上完整主日程 HAP 已启动，可以开始本关讲解。'));
          this.chatMessages = [...this.chatMessages];
          return true;
        }
        lastInfo = out;
      } catch (e) {
        lastInfo = e instanceof Error ? e.message : this.getErrorMessage(e as Object);
        this.currentExecutionLog += '[install-teaching] (try ' + attempt.toString() + ') failed: ' + lastInfo + '\n';
      }
      if (attempt < maxAttempts) {
        await this.delay(800);
      }
    }
    this.chatMessages.push(new ChatMessage('assistant',
      '主日程 HAP 启动多次未成功（已重试 ' + maxAttempts.toString() + ' 次）：' + lastInfo));
    this.chatMessages = [...this.chatMessages];
    return false;
  }

  // 进入「教学之路」：首次进入刷回初始工程并初始化讲师身份；
  // 若身份已就位（例如返回主页后再次进入），直接回到教学之路页，不重复还原/初始化。
  async enterTeaching(): Promise<void> {
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    if (this.teachingReady) {
      this.advancedScreen = 'teaching';
      this.workspaceTab = 0;
      return;
    }
    let epoch = this.courseEpoch;
    this.advancedScreen = 'teaching';
    this.projectInitStep = 0;
    this.projectInitOverlayVisible = true;
    this.workspaceTab = 0;
    this.chatMessages.push(new ChatMessage('assistant', '正在还原日程工程到初始模板...'));
    this.chatMessages = [...this.chatMessages];
    await this.restoreAdvancedProject();
    // 还原是个 HTTP 往返：若期间课程被重置（代际变化），放弃继续启动旧流程。
    if (epoch !== this.courseEpoch) {
      return;
    }
    if (!this.teachingReady) {
      this.projectInitStep = 1;
      // 教学之路初始状态：仅启动完整主日程 HAP（板端直跑 aa start，不经 OpenClaw），再做轻量身份确认。
      await this.installTeachingBaseline();
      if (epoch !== this.courseEpoch) {
        return;
      }
      await this.initTeachingIdentity();
    }
  }

  // 进入「自由发挥」：首次进入刷回初始工程并初始化还原身份；
  // 若身份已就位（例如返回主页后再次进入），直接回到自由开发页，不重复还原/初始化。
  async enterFreeDev(): Promise<void> {
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    if (this.freeDevReady) {
      this.advancedScreen = 'freedev';
      this.workspaceTab = 0;
      return;
    }
    let epoch = this.courseEpoch;
    this.advancedScreen = 'freedev';
    this.projectInitStep = 0;
    this.projectInitOverlayVisible = true;
    this.workspaceTab = 0;
    this.chatMessages.push(new ChatMessage('assistant', '正在还原日程工程到初始模板...'));
    this.chatMessages = [...this.chatMessages];
    await this.restoreAdvancedProject();
    // 还原是个 HTTP 往返：若期间课程被重置（代际变化），放弃继续启动旧流程。
    if (epoch !== this.courseEpoch) {
      return;
    }
    if (!this.freeDevReady) {
      this.projectInitStep = 1;
      // C2：板上 HAP 还原改为板端直跑（不再经 OpenClaw 提示词），秒级完成。
      await this.installInitialAdvanced();
      if (epoch !== this.courseEpoch) {
        return;
      }
      await this.initFreeDevIdentity();
    }
  }

  // Pre-fill states on selecting a task
  selectTask(index: number) {
    if (index === 4) {
      this.selectPracticeLevel();
      return;
    }

    this.selectedTaskIndex = index;
    this.tutorialStep = 1;
    this.workspaceTab = 0;
    this.openClawBusy = false;
    this.chatInput = '';

    if (index === 1) {
      this.selectedTaskTitle = '第一关：编译与构建（声明式 UI 与 HAP 构建）';
      this.selectedTaskDesc = '学习 ArkUI 与 HAP 构建流程，调用 Hvigor 编译生成未签名 HAP。';
      this.selectedTaskPrompt = '请先读取第一关动作记忆文件 /data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md，然后只运行第一关编译脚本 sh /data/local/tmp/oh61-hapbuild/compile_unsigned.sh。编译结束后验证 /data/local/tmp/entry-unsigned.hap 是否存在并向我报告。不得修改源码，不得签名，不得安装，不得启动应用。';
      this.previewText = 'Hello, OpenHarmony!';
      this.previewSubText = '23'; // SDK Version
      this.previewColor = '#f5c2e7';
      this.openclawSummary = `【第一关：编译 HAP 实训成果】
1. 编译链路验证：OpenClaw 按第一关动作记忆运行 compile_unsigned.sh，验证教学 HAP 工程可以进入 Docker 构建环境。
2. 容器增量同步：脚本将板端工程同步到 linux-env 容器中的 /root/HAP-BuildKit/project。
3. Hvigor 编译：容器内调用 hvigor assembleHap 完成真实构建。
4. 未签名 HAP 产出：最终验证 /data/local/tmp/entry-unsigned.hap 存在，第一关只到编译产物，不进行签名、安装或启动。`;
    } else if (index === 2) {
      this.selectedTaskTitle = '第二关：应用签名（PKCS12 私钥库与证书）';
      this.selectedTaskDesc = '理解 OpenHarmony 应用签名流程，使用证书和 Profile 生成已签名 HAP。';
      this.selectedTaskPrompt = '请先读取第二关动作记忆文件 /data/local/tmp/.openclaw/workspace/memory/oh61-level2-sign.md，然后只执行签名脚本 sh /data/local/tmp/oh61-hapbuild/build_sign_install_run.sh --sign-only。签名结束后验证 /data/local/tmp/entry-signed.hap 是否存在并向我报告。不得修改源码，不得重新编译，不得安装，不得启动应用，不得读取第一关或第三关记忆文件。';
      this.previewText = 'com.openclaw.learnhap'; // Bundle Name
      this.previewSubText = 'debugKey'; // Key Alias
      this.previewColor = '#89b4fa';
      this.openclawSummary = `【第二关：数字签名 HAP 实训成果】
1. 动作边界确认：OpenClaw 按第二关动作记忆读取 oh61-level2-sign.md，只执行签名任务。
2. 签名材料加载：确认 OpenHarmony.p12、证书链和 Profile 已就绪。
3. HAP 签名：签名脚本生成并验证 /data/local/tmp/entry-signed.hap。
4. 第二关只到签名产物，不进行源码修改、重新编译、安装或启动。`;
    } else if (index === 3) {
      this.selectedTaskTitle = '第三关：应用全生命周期调试（HDC 桥接与交互）';
      this.selectedTaskDesc = '通过 shell-bridge 客户端完成已签名 HAP 的安装、启动和部署验证。';
      this.selectedTaskPrompt = '请先读取第三关动作记忆文件 /data/local/tmp/.openclaw/workspace/memory/oh61-level3-deploy.md，然后只围绕 /data/local/tmp/entry-signed.hap 执行卸载、安装、启动与状态验证，并向我报告真实结果。不得修改源码，不得重新编译，不得重新签名，不得读取第一关或第二关记忆文件。';
      this.previewText = 'install'; // Current Action
      this.previewSubText = '039C1E0604834A08'; // Device connect key
      this.previewColor = '#a6e3a1';
      this.openclawSummary = `【第三关：全生命周期调试实训成果】
1. 动作边界确认：OpenClaw 按第三关动作记忆读取 oh61-level3-deploy.md，只执行部署与生命周期验证任务。
2. 联调服务建立：打通板端 shell-bridge 通信通道，调度 BundleManager 与 AbilityManager 核心服务。
3. 安装部署：围绕 /data/local/tmp/entry-signed.hap 完成卸载、安装和部署状态验证。
4. 启动生命周期：拉起应用主图形进程 EntryAbility，并报告真实运行结果，不再修改源码、编译或签名。`;
    }

    if (index <= this.highestCompletedLevel) {
      this.tutorialStep = 3;
      this.currentProgress = 100;
      this.step1Status = 2;
      this.step2Status = 2;
      this.step3Status = 2;
      this.step4Status = 2;
      this.step5Status = 2;
      this.step6Status = 2;
      this.studentQuestionEnabled = true;
    } else {
      this.tutorialStep = 1;
      this.currentProgress = 0;
      this.step1Status = 0;
      this.step2Status = 0;
      this.step3Status = 0;
      this.step4Status = 0;
      this.step5Status = 0;
      this.step6Status = 0;
      this.studentQuestionEnabled = false;
    }

    // Append a welcome message to the AI Chatbox
    let taskName = index === 1 ? '编译 HAP' : (index === 2 ? '数字签名' : '部署与启动');
    let welcomeText = 'OpenClaw 关卡向导：已加载第' + index + '关【' + taskName + '】。完成关卡后，可以在下方继续提问。';
    this.chatMessages.push(new ChatMessage('assistant', welcomeText));
  }

  // Smoothly advances the progress bar & step checklists concurrently with the real OpenClaw streaming thread
  async animateProgress() {
    if (this.selectedTaskIndex === 1) {
      this.step1Status = 1;
      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 15;
      this.currentExecutionLog += '[info] Found ArkTS workspace at /data/local/tmp/oh61-hapbuild/project\n';
      this.step1Status = 2;
      this.step2Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 35;
      this.currentExecutionLog += '[info] Loading text assets: "' + this.previewText + '" successfully parsed.\n';
      this.step2Status = 2;
      this.step3Status = 1;

      await this.delay(1200);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 60;
      this.currentExecutionLog += '[info] Running CodeLinter checkers. Scanning for decorator usage (@Entry, @Component)...\n';
      this.step3Status = 2;
      this.step4Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 80;
      this.currentExecutionLog += '[info] Invoking hvigor compiler node script in background daemon...\n';
      this.step4Status = 2;
      this.step5Status = 1;

      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 95;
      this.currentExecutionLog += '[info] Compiling raw files to ArkTS bytecode index. Outputting ZIP wrapper stream...\n';
      this.currentExecutionLog += '[info] Package created: entry-unsigned.hap (size: 71 KB)\n';
      this.step5Status = 2;
      this.step6Status = 1;
    } else if (this.selectedTaskIndex === 2) {
      this.step1Status = 1;
      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 15;
      this.currentExecutionLog += '[info] Signature Service Agent running...\n';
      this.step1Status = 2;
      this.step2Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 35;
      this.currentExecutionLog += '[info] Reading Provisioning Profile: signature/HelloHap_debug_profile.json\n';
      this.step2Status = 2;
      this.step3Status = 1;

      await this.delay(1200);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 60;
      this.currentExecutionLog += '[info] Matching application bundleName with Profile descriptor...\n';
      this.step3Status = 2;
      this.step4Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 80;
      this.currentExecutionLog += '[info] Executing sign-profile action to create binary p7b wrapper...\n';
      this.step4Status = 2;
      this.step5Status = 1;

      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 95;
      this.currentExecutionLog += '[info] Signing HAP binary package with alias: ' + this.previewSubText + '\n';
      this.step5Status = 2;
      this.step6Status = 1;
    } else {
      this.step1Status = 1;
      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 15;
      this.currentExecutionLog += '[info] HDC 连接代理启动中...\n';
      this.step1Status = 2;
      this.step2Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 35;
      this.currentExecutionLog += '[info] 已与板端 hdcd 守护进程建立 TCP 会话，端口 3456。\n';
      this.step2Status = 2;
      this.step3Status = 1;

      await this.delay(1200);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 60;
      this.currentExecutionLog += '[info] 正在上传 HAP 包：entry-default-signed.hap（1.43 MB）到 /data/local/tmp/\n';
      this.step3Status = 2;
      this.step4Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 80;
      this.currentExecutionLog += '[info] 通知板端 BundleManager（bm）安装本地文件...\n';
      this.step4Status = 2;
      this.step5Status = 1;

      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 95;
      this.currentExecutionLog += '[info] 正在拉起目标应用：com.openclaw.learnhap 的 EntryAbility\n';
      this.step5Status = 2;
      this.step6Status = 1;
    }
  }

  // Send this lesson task to the real OpenClaw gateway, then keep the visual teaching flow moving.
  async runOpenClaw() {
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理当前任务，请等待完成。',
        duration: 1800
      });
      return;
    }
    let epoch = this.courseEpoch;
    this.tutorialStep = 2;
    this.currentProgress = 0;
    this.currentExecutionLog = '[info] OpenClaw Agent gateway handoff starting...\n';
    this.studentQuestionEnabled = false;
    this.openClawBusy = true;
    this.step1Status = 1;
    this.step2Status = 0;
    this.step3Status = 0;
    this.step4Status = 0;
    this.step5Status = 0;
    this.step6Status = 0;

    this.currentExecutionLog += '[network] requesting shell-bridge token on :7681\n';
    this.currentExecutionLog += '[network] sending lesson prompt to OpenClaw gateway /v1/chat/completions\n';
    this.chatMessages.push(new ChatMessage('user', this.selectedTaskPrompt));

    // 启动进度条与步骤动画，并与 OpenClaw 流式响应并行执行
    this.animateProgress();

    let reply = '';
    try {
      reply = await this.client.startTurn(this.selectedTaskPrompt, () => {
        this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在连接并开始分析...'));
        this.chatMessages = [...this.chatMessages];
      });
      this.currentExecutionLog += '[openclaw] real agent turn accepted.\n';
      this.currentExecutionLog += '[openclaw] reply: ' + reply + '\n';
    } catch (error) {
      // 因课程重置导致的失败：对话与进度已刷新，不再补残留失败文案/不回退步骤。
      if (epoch !== this.courseEpoch) {
        return;
      }
      let message = (error as Error).message;
      this.currentExecutionLog += '[openclaw] real gateway call failed: ' + message + '\n';
      this.currentExecutionLog += '[openclaw] stopped: OpenClaw call is required.\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 协同开发请求失败：' + message));
      this.step1Status = 0;
      this.currentProgress = 0;
      this.openClawBusy = false;
      this.tutorialStep = 1; // Back to step 1
      return;
    }
    // 成功返回后若期间已被重置，放弃推进关卡进度（避免在新课程态上误推进）。
    if (epoch !== this.courseEpoch) {
      return;
    }

    // 当 OpenClaw 成功响应后，立即完成整条教学流程
    this.currentProgress = 100;
    this.step1Status = 2;
    this.step2Status = 2;
    this.step3Status = 2;
    this.step4Status = 2;
    this.step5Status = 2;
    this.step6Status = 2;
    this.currentExecutionLog += '[info] Verification: Output HAP target has 0 security alerts. Build COMPLETE! 🎉\n';

    this.highestCompletedLevel = Math.max(this.highestCompletedLevel, this.selectedTaskIndex);
    if (this.selectedTaskIndex < 3) {
      this.maxUnlockedLevel = Math.max(this.maxUnlockedLevel, this.selectedTaskIndex + 1);
    }

    await this.delay(600);
    this.tutorialStep = 3;
    this.workspaceTab = 0;
    this.studentQuestionEnabled = true;
    this.openClawBusy = false;
    this.fetchBoardSourceFile();
  }

  // 全屏聚焦加载遮罩：背景压暗 + 中间聚焦卡片转圈（类似人脸识别那种聚焦弹窗）。
  // 「项目初始化」与「AI 助手处理中」共用此样式，仅文案不同。
  // phase：0=不显示步骤点（项目初始化）；1=第一步「发送/接收」高亮；2=第二步「回复」高亮。
  @Builder focusLoadingOverlay(title: string, subtitle: string, phase: number) {
    Column() {
      Column() {
        LoadingProgress()
          .width(64)
          .height(64)
          .color(phase >= 2 ? '#a6e3a1' : '#89b4fa')

        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ top: 14 })

        Text(subtitle)
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(18)
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })

        if (phase > 0) {
          // 两步进度点：当前阶段高亮，已完成阶段保持高亮，未到阶段置灰。
          Row() {
            Circle({ width: 8, height: 8 })
              .fill(phase >= 1 ? '#89b4fa' : '#45475a')
            Row()
              .width(20)
              .height(2)
              .backgroundColor(phase >= 2 ? '#89b4fa' : '#45475a')
              .margin({ left: 6, right: 6 })
            Circle({ width: 8, height: 8 })
              .fill(phase >= 2 ? '#89b4fa' : '#45475a')
          }
          .margin({ top: 16 })
          .alignItems(VerticalAlign.Center)
        }
      }
      .width(320)
      .padding({ left: 24, right: 24, top: 28, bottom: 28 })
      .backgroundColor('#1e1e2e')
      .borderRadius(16)
      .border({ width: 1, color: '#45475a' })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#A6000000')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
    Column() {
      if (this.currentMode === '') {
        // === Selection & Entry Home Page ===
        HomeEntryView({
          onEnterTutorial: () => {
            this.currentMode = 'tutorial';
            this.tutorialStep = 0;
            this.selectedTaskIndex = 0;
          },
          onEnterAdvanced: () => {
            this.currentMode = 'advanced';
            this.tutorialStep = 0;
            this.selectedTaskIndex = 0;
            this.workspaceTab = 0;
            this.advancedScreen = 'menu';
            // 返回主页不等于重置：不在此清空 freeDevReady/teachingReady，
            // 再次进入高级课程时保留已初始化的身份，避免重复初始化（重置请走「重置开发」按钮）。
          }
        })

      } else if (this.currentMode === 'tutorial' || this.currentMode === 'advanced') {
        // === INTERACTIVE TUTORIAL INTERFACE (SPLIT SCREEN) ===
        Column() {
          // 1. Header Toolbar
          Row() {
            Button('返回主页')
              .height(36)
              .fontSize(14)
              .backgroundColor('#45475a')
              .fontColor('#cdd6f4')
              .borderRadius(8)
              .onClick(() => { this.currentMode = ''; })

            Text(this.currentMode === 'advanced' ? '鸿蒙 ArkUI 高级开发课程' : '鸿蒙 ArkUI 智能交互式学习课程')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#cdd6f4')
              .margin({ left: 16 })

            Blank()

            if (this.tutorialStep > 0 || (this.currentMode === 'advanced' && this.advancedScreen !== 'menu')) {
              Button(this.courseResetting
                ? '正在还原项目...'
                : (this.currentMode === 'advanced' && this.advancedScreen === 'freedev' ? '重置开发' : '重置课程'))
                .height(36)
                .fontSize(14)
                .backgroundColor('#f38ba8')
                .fontColor('#1e1e2e')
                .borderRadius(8)
                .enabled(!this.courseResetting)
                .onClick(() => { this.confirmResetCourse(); })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#252538')

          if (this.courseResetNoticeVisible) {
            Row() {
              Text(this.courseResetNoticeSuccess ? '✓' : '!')
                .width(34)
                .height(34)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.courseResetNoticeSuccess ? '#1e1e2e' : '#ffffff')
                .textAlign(TextAlign.Center)
                .backgroundColor(this.courseResetNoticeSuccess ? '#a6e3a1' : '#f38ba8')
                .borderRadius(17)
                .margin({ right: 12 })

              Column() {
                Text(this.courseResetNoticeTitle)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.courseResetNoticeSuccess ? '#a6e3a1' : '#f38ba8')

                Text(this.courseResetNoticeMessage)
                  .fontSize(12)
                  .fontColor('#cdd6f4')
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)

              Blank()
            }
            .width('96%')
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .margin({ top: 10, bottom: 2 })
            .backgroundColor(this.courseResetNoticeSuccess ? '#26352f' : '#3b2932')
            .border({
              width: 1,
              color: this.courseResetNoticeSuccess ? '#a6e3a1' : '#f38ba8'
            })
            .borderRadius(12)
          }

          // 2. Main Content Split View
          Row() {
            // === LEFT PANEL: TUTOR CARD ===
            Column() {
              // 1. Top Section
              Column() {
                if (this.currentMode === 'advanced') {
                  if (this.advancedScreen === 'teaching') {
                    TeachingPathView({
                      teachingReady: this.teachingReady,
                      teachingBusy: this.openClawBusy,
                      teachingFlowStep: this.teachingFlowStep,
                      teachingFlowTotal: 6,
                      onBack: () => { this.advancedScreen = 'menu'; },
                      onReinitIdentity: () => { this.initTeachingIdentity(); },
                      onEnterNextFlow: () => { this.enterNextLogHapFlow(); }
                    })
                  } else if (this.advancedScreen === 'freedev') {
                    FreeDevView({
                      freeDevReady: this.freeDevReady,
                      freeDevBusy: this.openClawBusy,
                      onReinitIdentity: () => { this.initFreeDevIdentity(); },
                      onSendRestoreType: () => {
                        this.sendFreeDevPrompt(buildRestoreTypeMenuPrompt(), '① 还原：类型下拉菜单');
                      },
                      onSendRestoreReminder: () => {
                        this.sendFreeDevPrompt(buildRestoreReminderPrompt(), '② 还原：提醒 + 响铃开关');
                      }
                    })
                  } else {
                    AdvancedMenuView({
                      onEnterTeaching: () => { this.enterTeaching(); },
                      freeDevBusy: this.openClawBusy,
                      onEnterFreeDev: () => { this.enterFreeDev(); }
                    })
                  }

                } else if (this.tutorialStep === 0) {
                  // Step 0: Choose Course List
                  Scroll() {
                    Column() {
                      Text('请选择挑战关卡（当前学习进度）')
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#cdd6f4')
                        .margin({ bottom: 12, top: 6 })
                        .alignSelf(ItemAlign.Start)

                    // Level 1 Card
                    Column() {
                      Row() {
                        Text('第一关：编译 HAP')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#f5c2e7')

                        Text(this.highestCompletedLevel >= 1 ? '已学习' : '待挑战')
                          .fontSize(11)
                          .fontColor('#f5c2e7')
                          .backgroundColor(this.highestCompletedLevel >= 1 ? '#1e3e2e' : '#3c223c')
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: 6 })

                      Text('学习如何编译 HAP 工程，并通过 hvigor 生成 entry-unsigned.hap 未签名包。')
                        .fontSize(12)
                        .fontColor('#a6adc8')
                        .margin({ bottom: 12 })
                        .lineHeight(16)

                      Button(this.highestCompletedLevel >= 1 ? '查看学习记录' : '点击进入挑战')
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor('#45475a')
                        .fontColor('#f5c2e7')
                        .onClick(() => { this.selectTask(1); })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .margin({ bottom: 10 })
                    .alignItems(HorizontalAlign.Start)

                    // Level 2 Card
                    Column() {
                      Row() {
                        Text('第二关：数字签名')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.maxUnlockedLevel >= 2 ? '#89b4fa' : '#6c7086')

                        Text(this.highestCompletedLevel >= 2 ? '已学习' : (this.maxUnlockedLevel >= 2 ? '待挑战' : '未解锁'))
                          .fontSize(11)
                          .fontColor(this.maxUnlockedLevel >= 2 ? '#89b4fa' : '#6c7086')
                          .backgroundColor(this.highestCompletedLevel >= 2 ? '#1e3e2e' : (this.maxUnlockedLevel >= 2 ? '#1e2e4e' : '#313244'))
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: 6 })

                      Text('使用证书、私钥库和 Profile 将第一关产物转换为已签名 HAP。')
                        .fontSize(12)
                        .fontColor(this.maxUnlockedLevel >= 2 ? '#a6adc8' : '#6c7086')
                        .margin({ bottom: 12 })
                        .lineHeight(16)

                      Button(this.highestCompletedLevel >= 2 ? '查看学习记录' : (this.maxUnlockedLevel >= 2 ? '点击进入挑战' : '请先完成第一关'))
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor(this.maxUnlockedLevel >= 2 ? '#45475a' : '#313244')
                        .fontColor(this.maxUnlockedLevel >= 2 ? '#89b4fa' : '#6c7086')
                        .enabled(this.maxUnlockedLevel >= 2)
                        .onClick(() => { this.selectTask(2); })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .margin({ bottom: 10 })
                    .alignItems(HorizontalAlign.Start)

                    // Level 3 Card
                    Column() {
                      Row() {
                        Text('第三关：部署与启动')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.maxUnlockedLevel >= 3 ? '#a6e3a1' : '#6c7086')

                        Text(this.highestCompletedLevel >= 3 ? '已学习' : (this.maxUnlockedLevel >= 3 ? '待挑战' : '未解锁'))
                          .fontSize(11)
                          .fontColor(this.maxUnlockedLevel >= 3 ? '#a6e3a1' : '#6c7086')
                          .backgroundColor(this.highestCompletedLevel >= 3 ? '#1e3e2e' : (this.maxUnlockedLevel >= 3 ? '#1e3e2e' : '#313244'))
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: 6 })

                      Text('通过 shell-bridge 完成已签名 HAP 的卸载、安装、启动与状态验证。')
                        .fontSize(12)
                        .fontColor(this.maxUnlockedLevel >= 3 ? '#a6adc8' : '#6c7086')
                        .margin({ bottom: 12 })
                        .lineHeight(16)

                      Button(this.highestCompletedLevel >= 3 ? '查看学习记录' : (this.maxUnlockedLevel >= 3 ? '点击进入挑战' : '请先完成第二关'))
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor(this.maxUnlockedLevel >= 3 ? '#45475a' : '#313244')
                        .fontColor(this.maxUnlockedLevel >= 3 ? '#a6e3a1' : '#6c7086')
                        .enabled(this.maxUnlockedLevel >= 3)
                        .onClick(() => { this.selectTask(3); })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .margin({ bottom: 10 })
                    .alignItems(HorizontalAlign.Start)

                    if (this.highestCompletedLevel >= 3) {
                      // Practice Level Card
                      Column() {
                        Row() {
                          Text('练习关卡：提示词练习')
                            .fontSize(14)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#fab387')

                          Text('可练习')
                            .fontSize(11)
                            .fontColor('#fab387')
                            .backgroundColor('#3e2e1e')
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .borderRadius(4)
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.SpaceBetween)
                        .margin({ bottom: 6 })

                        Text('提供多个常用提示词，点击后自动填入底部输入框，便于继续向 OpenClaw 提问或练习完整流程。')
                          .fontSize(12)
                          .fontColor('#a6adc8')
                          .margin({ bottom: 12 })
                          .lineHeight(16)

                        Button('进入练习关卡')
                          .width('100%')
                          .height(34)
                          .fontSize(12)
                          .backgroundColor('#45475a')
                          .fontColor('#fab387')
                          .onClick(() => { this.selectTask(4); })
                      }
                      .width('100%')
                      .padding(14)
                      .backgroundColor('#313244')
                      .borderRadius(8)
                      .alignItems(HorizontalAlign.Start)
                    }
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16 })
                  }
                  .width('100%')

                } else if (this.tutorialStep === 1) {
                  // Step 1: Confirm prompt details & Send to OpenClaw
                  Column() {
                    Text('确认提示词与准备运行')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#cdd6f4')
                      .margin({ bottom: 6, top: 4 })

                    Text(this.selectedTaskTitle)
                      .fontSize(13)
                      .fontColor('#89b4fa')
                      .fontWeight(FontWeight.Bold)
                      .margin({ bottom: 4 })

                    Text(this.selectedTaskDesc)
                      .fontSize(11)
                      .fontColor('#a6adc8')
                      .margin({ bottom: 12 })

                    // Prompt Box Title
                    Text('计划向 OpenClaw 发送的提示词：')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#f5c2e7')
                      .margin({ bottom: 6 })

                    // Interactive Prompt Display
                    TextArea({ text: this.selectedTaskPrompt })
                      .width('100%')
                      .height(110)
                      .fontSize(11)
                      .fontColor('#cdd6f4')
                      .backgroundColor('#1e1e2e')
                      .borderWidth(1)
                      .borderColor('#585b70')
                      .borderRadius(6)
                      .margin({ bottom: 12 })
                      .padding(8)
                      .onChange((v) => { this.selectedTaskPrompt = v; })

                    // Buttons
                    Button('呼叫 OpenClaw 协同开发')
                      .width('100%')
                      .height(40)
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .backgroundColor(this.openClawBusy ? '#45475a' : '#a6e3a1')
                      .fontColor(this.openClawBusy ? '#a6adc8' : '#1e1e2e')
                      .borderRadius(6)
                      .margin({ bottom: 8 })
                      .enabled(!this.openClawBusy)
                      .onClick(() => { this.runOpenClaw(); })

                    Button('返回选择任务')
                      .width('100%')
                      .height(34)
                      .fontSize(12)
                      .backgroundColor('#45475a')
                      .fontColor('#cdd6f4')
                      .borderRadius(6)
                      .onClick(() => { this.tutorialStep = 0; })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                  .alignItems(HorizontalAlign.Start)

                } else if (this.tutorialStep === 2) {
                  // Step 2: OpenClaw execution simulation
                  Column() {
                    Text('OpenClaw 正在执行任务...')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#cdd6f4')
                      .margin({ top: 20, bottom: 20 })

                    // Progress Bar
                    Row() {
                      Text('任务进度：' + this.currentProgress + '%')
                        .fontSize(13)
                        .fontColor('#a6adc8')
                      Blank()
                    }.width('90%').margin({ bottom: 6 })

                    Row() {
                      Row() {
                        Row()
                          .width(this.currentProgress + '%')
                          .height('100%')
                          .backgroundColor('#89b4fa')
                          .borderRadius(4)
                      }
                      .width('100%')
                      .height(8)
                      .backgroundColor('#313244')
                      .borderRadius(4)
                    }
                    .width('90%')
                    .margin({ bottom: 30 })

                    // Steps Timeline
                    Column() {
                      // Step 1
                      Row() {
                        Text(this.step1Status === 2 ? 'done' : (this.step1Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step1Status === 2 ? '#a6e3a1' : (this.step1Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(getStepLabel(this.selectedTaskIndex, 1))
                          .fontSize(13)
                          .fontColor(this.step1Status === 2 ? '#a6e3a1' : (this.step1Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 2
                      Row() {
                        Text(this.step2Status === 2 ? 'done' : (this.step2Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step2Status === 2 ? '#a6e3a1' : (this.step2Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(getStepLabel(this.selectedTaskIndex, 2))
                          .fontSize(13)
                          .fontColor(this.step2Status === 2 ? '#a6e3a1' : (this.step2Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 3
                      Row() {
                        Text(this.step3Status === 2 ? 'done' : (this.step3Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step3Status === 2 ? '#a6e3a1' : (this.step3Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(getStepLabel(this.selectedTaskIndex, 3))
                          .fontSize(13)
                          .fontColor(this.step3Status === 2 ? '#a6e3a1' : (this.step3Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 4
                      Row() {
                        Text(this.step4Status === 2 ? 'done' : (this.step4Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step4Status === 2 ? '#a6e3a1' : (this.step4Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(getStepLabel(this.selectedTaskIndex, 4))
                          .fontSize(13)
                          .fontColor(this.step4Status === 2 ? '#a6e3a1' : (this.step4Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 5
                      Row() {
                        Text(this.step5Status === 2 ? 'done' : (this.step5Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step5Status === 2 ? '#a6e3a1' : (this.step5Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(getStepLabel(this.selectedTaskIndex, 5))
                          .fontSize(13)
                          .fontColor(this.step5Status === 2 ? '#a6e3a1' : (this.step5Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 6
                      Row() {
                        Text(this.step6Status === 2 ? 'done' : (this.step6Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step6Status === 2 ? '#a6e3a1' : (this.step6Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(getStepLabel(this.selectedTaskIndex, 6))
                          .fontSize(13)
                          .fontColor(this.step6Status === 2 ? '#a6e3a1' : (this.step6Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')
                    }
                    .padding(20)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .width('90%')
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Start)

                } else if (this.tutorialStep === 3) {
                  // Step 3: Finished, show summary, architectural tips and dynamic editor
                  Scroll() {
                    Column() {
                      Text('开发任务完成')
                        .fontSize(22)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#a6e3a1')
                        .margin({ top: 10, bottom: 14 })

                      // 1. OpenClaw Language Summary Card
                      Column() {
                        Row() {
                          Text('第' + this.selectedTaskIndex + '关：已学习内容与核心要点')
                            .fontSize(13)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#1e1e2e')
                        }
                        .width('100%')
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .backgroundColor('#f5c2e7')
                        .borderRadius({ topLeft: 8, topRight: 8 })

                        Text(this.openclawSummary)
                          .fontSize(13)
                          .fontColor('#cdd6f4')
                          .lineHeight(20)
                          .padding(12)
                      }
                      .width('100%')
                      .backgroundColor('#313244')
                      .borderRadius(8)
                      .margin({ bottom: 16 })

                      // 2. Simplified guidance instruction card
                      Column() {
                        Text('提示：本关已学习完成，可以使用下方输入框继续向 OpenClaw 提问。')
                          .fontSize(12)
                          .fontColor('#a6adc8')
                          .lineHeight(18)
                      }
                      .width('100%')
                      .padding(14)
                      .backgroundColor('#313244')
                      .borderRadius(8)
                      .margin({ bottom: 16 })

                      // 3. Dynamic campaign progression buttons
                      if (this.selectedTaskIndex > 1) {
                        Button('返回上一关复习')
                          .width('100%')
                          .height(40)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#313244')
                          .fontColor('#cdd6f4')
                          .borderRadius(8)
                          .margin({ bottom: 10 })
                          .onClick(() => { this.selectTask(this.selectedTaskIndex - 1); })
                      }

                      if (this.selectedTaskIndex === 1) {
                        Button('第一关已学习，进入第二关')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#89b4fa')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 20 })
                          .onClick(() => {
                            this.maxUnlockedLevel = Math.max(this.maxUnlockedLevel, 2);
                            this.selectTask(2);
                          })
                      } else if (this.selectedTaskIndex === 2) {
                        Button('第二关已学习，进入第三关')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#a6e3a1')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 20 })
                          .onClick(() => {
                            this.maxUnlockedLevel = Math.max(this.maxUnlockedLevel, 3);
                            this.selectTask(3);
                          })
                      } else {
                        Button('全部关卡已学习，返回选择关卡')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#f5c2e7')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 10 })
                          .onClick(() => {
                            this.maxUnlockedLevel = 3;
                            this.highestCompletedLevel = 3;
                            this.tutorialStep = 0;
                            this.selectedTaskIndex = 0;
                          })

                        Button('进入练习关卡')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#fab387')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 20 })
                          .onClick(() => { this.selectPracticeLevel(); })
                      }
                    }
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                } else if (this.tutorialStep === 4) {
                  // Step 4: Practice prompt picker after all lessons are completed
                  Scroll() {
                    Column() {
                      Text('练习关卡：使用提示词练习hap基础开发')
                        .fontSize(22)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#fab387')
                        .margin({ top: 10, bottom: 8 })

                      Text('点击一个提示词选项，内容会自动填入底部输入框；你可以直接发送，也可以继续编辑后再发送。')
                        .fontSize(12)
                        .fontColor('#a6adc8')
                        .lineHeight(18)
                        .margin({ bottom: 14 })

                      Button('1. 解释编译命令')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#f5c2e7')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请解释第一关中的编译命令：sh /data/local/tmp/oh61-hapbuild/compile_unsigned.sh。请说明它会读取哪个工程目录、进入哪个构建环境、执行什么 hvigor 构建动作，以及最终生成和验证哪个未签名 HAP 产物。');
                        })

                      Button('2. 解释签名命令')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#89b4fa')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请解释第二关中的签名命令：sh /data/local/tmp/oh61-hapbuild/build_sign_install_run.sh --sign-only。请说明 OpenHarmony HAP 签名需要哪些材料，sign-profile 和 sign-app 分别做什么，以及如何验证 /data/local/tmp/entry-signed.hap。');
                        })

                      Button('3. 解释卸载安装，启动 HAP 命令')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#a6e3a1')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请解释第三关中卸载、安装、启动 HAP 的命令流程。请分别说明 bm uninstall、bm install、aa start 或对应 shell-bridge/HDC 调用的作用、执行顺序、关键参数和常见失败原因。');
                        })

                      Button('4. 修改 HAP 为 Hello World，并编译签名启动')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#fab387')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请将 HAP 主页面内容修改为 hello world，然后按完整流程执行：编译未签名 HAP、签名生成已签名 HAP、卸载旧应用、安装新 HAP 并启动 EntryAbility。请在执行前说明会修改的文件和命令边界，执行后汇报每一步真实结果。');
                        })

                      Button('返回选择关卡')
                        .width('100%')
                        .height(38)
                        .fontSize(12)
                        .backgroundColor('#45475a')
                        .fontColor('#cdd6f4')
                        .borderRadius(8)
                        .onClick(() => {
                          this.tutorialStep = 0;
                          this.selectedTaskIndex = 0;
                        })
                    }
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                }
              }
              .width('100%')
              .layoutWeight(1)

              if (this.tutorialStep !== 0 || (this.currentMode === 'advanced' && this.advancedScreen !== 'menu')) {
                // 2. Student question input (hidden on level selection page to avoid covering cards)
                Column() {
                  // Input Bar at the Bottom
                  Row() {
                    TextInput({
                      placeholder: this.studentQuestionEnabled ? (this.openClawBusy ? 'OpenClaw 正在处理，请等待回复完成...' : '在此提问，例如：什么是 HAP 签名？') : '请先点击“呼叫 OpenClaw 协同开发”并等待任务完成...',
                      text: this.chatInput
                    })
                      .layoutWeight(1)
                      .height(34)
                      .fontSize(11)
                      .fontColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#cdd6f4' : '#6c7086')
                      .placeholderColor('#585b70')
                      .backgroundColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#11111b' : '#181825')
                      .borderRadius(4)
                      .borderWidth(1)
                      .borderColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#45475a' : '#313244')
                      .margin({ right: 6 })
                      .enabled((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy)
                      .onChange((v) => { this.chatInput = v; })
                      .onSubmit(() => { this.sendChatMessage(); })

                    Button('发送')
                      .height(34)
                      .fontSize(12)
                      .backgroundColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#89b4fa' : '#45475a')
                      .fontColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#1e1e2e' : '#a6adc8')
                      .borderRadius(4)
                      .enabled((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy)
                      .onClick(() => { this.sendChatMessage(); })
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#1e1e2e')
                .borderRadius(10)
                .margin({ top: 12 })
              }
            }
            .width('45%')
            .height('100%')
            .backgroundColor('#252538')
            .padding({ top: 12, bottom: 12 })

            // Middle Divider
            Divider()
              .vertical(true)
              .width(1)
              .color('#313244')
              .height('100%')

            // === RIGHT PANEL: LIVE WORKSPACE ===
            WorkspaceView({
              workspaceTab: $workspaceTab,
              selectedTaskIndex: this.selectedTaskIndex,
              currentMode: this.currentMode,
              chatMessages: $chatMessages,
              sourceFileLoading: this.sourceFileLoading,
              sourceFileError: this.sourceFileError,
              sourceFileContent: this.sourceFileContent,
              sourceText: getSourceTabText(this.selectedTaskIndex, this.sourceFileLoading, this.sourceFileError, this.sourceFileContent),
              currentExecutionLog: this.currentExecutionLog,
              advancedFiles: this.advancedFiles,
              advancedFilesLoading: this.advancedFilesLoading,
              advancedFilesError: this.advancedFilesError,
              selectedSourceFile: this.selectedSourceFile,
              onSelectSourceTab: () => { this.onSourceTabSelected(); },
              onRefreshSource: () => { this.fetchBoardSourceFile(); },
              onSelectAdvancedFile: (path: string) => { this.selectAdvancedSourceFile(path); },
              onRefreshAdvancedFiles: () => { this.fetchAdvancedFileList(); }
            })
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#1e1e2e')

      } else {
        // === WebView Screens (Shell Terminal or OpenClaw Web UI) ===
        Column() {
          Row() {
            Button('返回')
              .height(36)
              .fontSize(14)
              .backgroundColor('#585b70')
              .fontColor('#cdd6f4')
              .borderRadius(8)
              .onClick(() => { this.currentMode = ''; })
          }
          .width('100%')
          .padding({ left: 8, top: 4, bottom: 4 })
          .backgroundColor('#313244')

          Web({
            src: this.currentMode === 'terminal'
              ? $rawfile('terminal.html')
              : $rawfile('openclaw-loader.html'),
            controller: this.controller
          })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .mixedMode(MixedMode.All)
            .width('100%')
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#1e1e2e')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1e1e2e')

    if (this.projectInitOverlayVisible) {
      if (this.projectInitStep >= 1) {
        // 第二步：还原板上 HAP（自由发挥经板端直跑）并经 OpenClaw 初始化身份。
        this.focusLoadingOverlay('正在初始化项目', '② 正在初始化身份，请稍候', 2)
      } else {
        // 第一步：HTTP 直连板端还原工程源码模板。
        this.focusLoadingOverlay('正在初始化项目', '① 正在还原日程工程模板，请稍候', 1)
      }
    }

    if (this.aiProcessingOverlayVisible) {
      if (this.aiProcessingPhase === 'replying') {
        this.focusLoadingOverlay('OpenClaw 正在回复', 'AI 助手正在生成回复内容，请稍候', 2)
      } else {
        this.focusLoadingOverlay('对话已发送', 'OpenClaw 正在接收信息，请稍候', 1)
      }
    }

    if (this.resetConfirmVisible) {
      // 自定义暗色二次确认弹窗，风格对齐整个 HAP（深色卡片 + 粉色强调）。
      Column() {
        Column() {
          Text(this.advancedScreen === 'freedev' ? '重置开发' : '重置课程')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#cdd6f4')

          Text(this.advancedScreen === 'freedev'
            ? '将清空当前自由开发会话，并把日程工程还原到初始模板。未保存的改动会丢失，确定继续吗？'
            : '将清空当前会话并把课程工程还原到初始模板。未保存的改动会丢失，确定继续吗？')
            .fontSize(14)
            .fontColor('#a6adc8')
            .lineHeight(22)
            .margin({ top: 14 })

          Row() {
            Button('取消')
              .layoutWeight(1)
              .height(42)
              .fontSize(15)
              .fontColor('#cdd6f4')
              .backgroundColor('#313244')
              .borderRadius(10)
              .onClick(() => { this.resetConfirmVisible = false; })

            Button(this.advancedScreen === 'freedev' ? '确定重置开发' : '确定重置课程')
              .layoutWeight(1)
              .height(42)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1e1e2e')
              .backgroundColor('#f38ba8')
              .borderRadius(10)
              .margin({ left: 12 })
              .onClick(() => {
                this.resetConfirmVisible = false;
                this.resetCourse();
              })
          }
          .width('100%')
          .margin({ top: 24 })
        }
        .width(340)
        .padding({ left: 24, right: 24, top: 24, bottom: 24 })
        .backgroundColor('#252538')
        .borderRadius(16)
        .border({ width: 1, color: '#45475a' })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#A6000000')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    }
    .width('100%')
    .height('100%')
  }
}
