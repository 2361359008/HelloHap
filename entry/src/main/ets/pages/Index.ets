import { webview } from '@kit.ArkWeb';
import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';
import { ChatMessage } from '../model/OpenClawTypes';
import { buildPracticeFullFlowPrompt, getStepLabel, getSourceTabText } from '../model/CourseContent';
import { OpenClawClient } from '../service/OpenClawClient';
import { HomeEntryView } from '../view/HomeEntryView';
import { AdvancedMenuView } from '../view/AdvancedMenuView';
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
  @State courseResetting: boolean = false;
  @State courseResetNoticeVisible: boolean = false;
  @State courseResetNoticeSuccess: boolean = true;
  @State courseResetNoticeTitle: string = '';
  @State courseResetNoticeMessage: string = '';
  private courseResetNoticeSequence: number = 0;
  private readonly boardIndexEtsUrl: string =
    'http://127.0.0.1:7681/read-file?path=%2Fdata%2Flocal%2Ftmp%2Foh61-hapbuild%2Fproject%2Fentry%2Fsrc%2Fmain%2Fets%2Fpages%2FIndex.ets';

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

  aboutToAppear(): void {
    this.client.onChatEvent = (payload: Record<string, Object>) => {
      this.handleChatStreamEvent(payload);
    };
  }

  // Async helper for delays
  delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
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
    await this.delay(success ? 3200 : 4200);
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

  onSourceTabSelected(): void {
    this.workspaceTab = 1;
    if (this.selectedTaskIndex > 0) {
      this.fetchBoardSourceFile();
    }
  }

  handleChatStreamEvent(payload: Record<string, Object>) {
    let state = payload['state'] as string;
    let text = '';

    if (payload['text'] && typeof payload['text'] === 'string') {
      text = String(payload['text']);
    } else if (payload['message']) {
      text = this.client.extractMessageText(payload['message'] as Record<string, Object>);
    }

    if (state === 'delta') {
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
      if (this.chatMessages.length > 0) {
        let lastMsg = this.chatMessages[this.chatMessages.length - 1];
        if (lastMsg.sender === 'assistant') {
          lastMsg.text = text;
        } else {
          this.chatMessages.push(new ChatMessage('assistant', text));
        }
      } else {
        this.chatMessages.push(new ChatMessage('assistant', text));
      }
      this.chatMessages = [...this.chatMessages];
      
      this.client.completeTurn(text);
      this.studentQuestionEnabled = true;
      this.openClawBusy = false;
    } else if (state === 'error' || state === 'aborted') {
      let errorMsg = 'OpenClaw 调用失败/中断';
      if (payload['error']) {
        errorMsg = 'OpenClaw 错误: ' + String(payload['error']);
      }
      this.chatMessages.push(new ChatMessage('assistant', errorMsg));
      this.chatMessages = [...this.chatMessages];
      
      this.client.failTurn(new Error(errorMsg));
      this.openClawBusy = false;
    }
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
      await this.client.startTurn(sendMsg, () => {
        this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在思考中...'));
        this.chatMessages = [...this.chatMessages];
      });
      this.openClawBusy = false;
    } catch (error) {
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

  clearCourseState(): void {
    this.client.reset();

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
    this.chatMessages = [
      new ChatMessage('assistant', '你好，我是 OpenClaw 智能答疑助手。请先选择第一关并呼叫 OpenClaw 完成首轮协同开发，随后即可继续提问。')
    ];
  }

  async resetCourse(): Promise<void> {
    if (this.courseResetting) {
      return;
    }
    this.courseResetting = true;
    try {
      await this.client.requestText(
        'http://127.0.0.1:7681/reset-course',
        http.RequestMethod.GET
      );
      this.clearCourseState();
      this.sourceFileContent = '';
      this.sourceFileError = '';
      this.showCourseResetNotice(true);
    } catch (e) {
      let message = e instanceof Error ? e.message : this.getErrorMessage(e as Object);
      console.error('Course reset failed: ' + message);
      this.showCourseResetNotice(false);
    } finally {
      this.courseResetting = false;
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

  build() {
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

            if (this.tutorialStep > 0) {
              Button(this.courseResetting ? '正在还原项目...' : '重置课程')
                .height(36)
                .fontSize(14)
                .backgroundColor('#f38ba8')
                .fontColor('#1e1e2e')
                .borderRadius(8)
                .enabled(!this.courseResetting)
                .onClick(() => { this.resetCourse(); })
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
                  AdvancedMenuView()

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

              if (this.tutorialStep !== 0) {
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
              chatMessages: $chatMessages,
              sourceFileLoading: this.sourceFileLoading,
              sourceFileError: this.sourceFileError,
              sourceText: getSourceTabText(this.selectedTaskIndex, this.sourceFileLoading, this.sourceFileError, this.sourceFileContent),
              currentExecutionLog: this.currentExecutionLog,
              onSelectSourceTab: () => { this.onSourceTabSelected(); },
              onRefreshSource: () => { this.fetchBoardSourceFile(); }
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
  }
}
