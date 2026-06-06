// 课程文案与代码生成
// 从 pages/Index.ets 抽取的纯函数：根据关卡与界面输入生成提示词、步骤标签、
// 源码展示文本及示例代码。这些函数不依赖组件状态，仅通过入参计算返回值。

export function buildOpenClawPrompt(
  selectedTaskIndex: number,
  selectedTaskTitle: string,
  selectedTaskPrompt: string,
  previewText: string,
  previewSubText: string
): string {
  let taskName = selectedTaskIndex === 1 ? '第一关：编译 HAP' :
    (selectedTaskIndex === 2 ? '第二关：签名 HAP' : '第三关：部署与生命周期调试');

  let prompt = `你是在此 OpenHarmony 开发板上运行的 OpenClaw AI 协同开发助手。请为 HAP 教学应用启动一轮真实的协同开发任务。
当前任务：${taskName}
选择标题：${selectedTaskTitle}
学员自定义提示词：
${selectedTaskPrompt}

当前 UI 交互输入：
- 预览文本 / 行为目标 (previewText): ${previewText}
- 预览子文本 / SDK版本 (previewSubText): ${previewSubText}

`;

  if (selectedTaskIndex === 1) {
    prompt += `第一关动作边界（必须严格执行）：
1. 必须先读取动作记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md
2. 只允许运行编译脚本：sh /data/local/tmp/oh61-hapbuild/compile_unsigned.sh
3. 编译后只允许验证产物：ls -lh /data/local/tmp/entry-unsigned.hap
4. 不得修改源码，不得签名，不得安装，不得启动应用，不得读取第二关或第三关记忆文件。

`;
  } else if (selectedTaskIndex === 2) {
    prompt += `第二关动作边界（必须严格执行）：
1. 必须先读取动作记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level2-sign.md
2. 只允许运行签名动作：sh /data/local/tmp/oh61-hapbuild/build_sign_install_run.sh --sign-only
3. 签名后只允许验证产物：ls -lh /data/local/tmp/entry-signed.hap
4. 不得修改源码，不得重新编译，不得安装，不得启动应用，不得读取第一关或第三关记忆文件。

`;
  } else if (selectedTaskIndex === 3) {
    prompt += `第三关动作边界（必须严格执行）：
1. 必须先读取动作记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level3-deploy.md
2. 只允许围绕 /data/local/tmp/entry-signed.hap 执行卸载、安装、启动与状态验证。
3. 只允许使用第三关记忆指定的 shell-bridge 客户端或部署脚本完成本关动作。
4. 不得修改源码，不得重新编译，不得重新签名，不得读取第一关或第二关记忆文件，不得提前扩展额外调试任务。

`;
  }

  prompt += `HAP 工程目录配置信息：
- 主机同步目录：/data/local/tmp/oh61-hapbuild/project
- Docker 内编译目录：/root/HAP-BuildKit/project
- 主页面路径：entry/src/main/ets/pages/Index.ets

请严格按当前关卡动作记忆执行，不要跨关卡推进，不要补做下一关。任务完成后，用精炼中文汇报真实执行结果和产物状态。`;

  return prompt;
}

export function buildPracticeFullFlowPrompt(): string {
  return '执行以下命令并等待完成：\n\n' +
    'sh /data/local/tmp/oh61-hapbuild/practice_fullflow.sh\n\n' +
    '要求：\n' +
    '1. 只执行这一条命令。\n' +
    '2. 不要执行任何额外命令。\n' +
    '3. 等待命令执行完毕。\n' +
    '4. 命令成功则只回复：练习关卡执行成功。\n' +
    '5. 命令失败则只回复：练习关卡执行失败，并附上脚本原始输出。';
}

export function getStepLabel(selectedTaskIndex: number, stepNum: number): string {
  if (selectedTaskIndex === 1) {
    if (stepNum === 1) return '分析项目工程结构与资源依赖';
    if (stepNum === 2) return '加载资源文件并生成索引表';
    if (stepNum === 3) return '执行静态检查（CodeLinter）';
    if (stepNum === 4) return '执行 hvigorw assembleHap 编译';
    if (stepNum === 5) return '打包生成未签名包 unsigned.hap';
    return '验证 HAP 构建产物完整性';
  } else if (selectedTaskIndex === 2) {
    if (stepNum === 1) return '载入本地 .p12 私钥库';
    if (stepNum === 2) return '解析 Profile 描述证书 json';
    if (stepNum === 3) return '校验绑定包名（BundleName）匹配';
    if (stepNum === 4) return '调用 sign-profile 签发 debug.p7b';
    if (stepNum === 5) return '执行 hap-sign-tool 签署 app.hap';
    return '生成并验证已签名包 signed.hap';
  } else {
    if (stepNum === 1) return '轮询检测本地物理 HDC 目标';
    if (stepNum === 2) return '开启调试桥套接字数据通道';
    if (stepNum === 3) return '验证已签名 HAP 产物';
    if (stepNum === 4) return '调用安装客户端执行 bm install';
    if (stepNum === 5) return '调用 aa 工具拉起 EntryAbility';
    return '返回板端生命周期运行状态';
  }
}

export function getSourceTabText(
  selectedTaskIndex: number,
  sourceFileLoading: boolean,
  sourceFileError: string,
  sourceFileContent: string
): string {
  if (selectedTaskIndex === 0) {
    return '// 等待加载源码...';
  }
  if (sourceFileLoading) {
    return '// 正在从板端读取源码文件...\n// /data/local/tmp/oh61-hapbuild/project/entry/src/main/ets/pages/Index.ets';
  }
  if (sourceFileError) {
    return '// 板端源码读取失败\n' +
      '// ' + sourceFileError + '\n' +
      '// 请确认 shell-bridge (:7681) 已部署 /read-file 接口后重试';
  }
  if (sourceFileContent) {
    return sourceFileContent;
  }
  return '// 尚未加载板端源码，请切换到本页或点击刷新';
}

export function getGeneratedCode(
  selectedTaskIndex: number,
  chatInput: string,
  previewText: string,
  previewSubText: string
): string {
  if (selectedTaskIndex === 4) {
    return `# [练习关卡：练习提示词]\n` +
           `# 选择左侧提示词后，会自动填入底部输入框。\n` +
           `# 当前输入框内容：\n` +
           `${chatInput}`;
  }

  if (selectedTaskIndex === 1) {
    return `// [编译工作区：D:\\DevEcoProjects\\HelloHap\\AppScope\\app.json5]\n` +
           `{\n` +
           `  "app": {\n` +
           `    "bundleName": "com.openclaw.learnhap",\n` +
           `    "vendor": "example",\n` +
           `    "versionCode": 1000000,\n` +
           `    "versionName": "1.0.0"\n` +
           `  }\n` +
           `}\n\n` +
           `// [主编页面：entry/src/main/ets/pages/Index.ets]\n` +
           `@Entry\n` +
           `@Component\n` +
           `struct IndexPage {\n` +
           `  build() {\n` +
           `    Column() {\n` +
           `      Text("${previewText}")\n` +
           `        .fontSize(36)\n` +
           `        .fontWeight(FontWeight.Bold)\n` +
           `        .fontColor("#cdd6f4")\n` +
           `    }\n` +
           `    .width('100%')\n` +
           `    .height('100%')\n` +
           `    .justifyContent(FlexAlign.Center)\n` +
           `    .backgroundColor('#1e1e2e')\n` +
           `  }\n` +
           `}\n\n` +
           `// === HVIGOR 构建命令 ===\n` +
           `node "D:\\DevEcoStudio\\tools\\hvigor\\bin\\hvigorw.js" --mode module -p product=default assembleHap --analyze=normal`;
  } else if (selectedTaskIndex === 2) {
    return `# 步骤一：使用私钥签名应用证书描述 Profile (.p7b)\n` +
           `& "D:\\DevEcoStudio\\DevEco Studio\\jbr\\bin\\java.exe" -jar "D:\\OpenHarmony\\18\\toolchains\\lib\\hap-sign-tool.jar" sign-profile \`\n` +
           `  -keyAlias "openharmony application ca" \`\n` +
           `  -keyPwd 123456 \`\n` +
           `  -mode localSign \`\n` +
           `  -signAlg SHA256withECDSA \`\n` +
           `  -keystoreFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmony.p12" \`\n` +
           `  -keystorePwd 123456 \`\n` +
           `  -profileCertFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmonyCA.pem" \`\n` +
           `  -inFile "D:\\DevEcoProjects\\HelloHap\\signature\\HelloHap_debug_profile.json" \`\n` +
           `  -outFile "D:\\DevEcoProjects\\HelloHap\\signature\\HelloHap_debug.p7b"\n\n` +
           `# 步骤二：使用开发者私钥对编译出的未签名 HAP 进行正式签名\n` +
           `& "D:\\DevEcoStudio\\DevEco Studio\\jbr\\bin\\java.exe" -jar "D:\\OpenHarmony\\18\\toolchains\\lib\\hap-sign-tool.jar" sign-app \`\n` +
           `  -keyAlias "${previewSubText}" \`\n` +
           `  -signAlg SHA256withECDSA \`\n` +
           `  -mode localSign \`\n` +
           `  -appCertFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmonyAppChain.pem" \`\n` +
           `  -profileFile "D:\\DevEcoProjects\\HelloHap\\signature\\HelloHap_debug.p7b" \`\n` +
           `  -inFile "D:\\DevEcoProjects\\HelloHap\\entry\\build\\default\\outputs\\default\\entry-default-unsigned.hap" \`\n` +
           `  -keystoreFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmony.p12" \`\n` +
           `  -outFile "D:\\DevEcoProjects\\HelloHap\\entry\\build\\default\\outputs\\default\\entry-default-signed.hap" \`\n` +
           `  -keyPwd 123456 \`\n` +
           `  -keystorePwd 123456 \`\n` +
           `  -signCode 1`;
  } else if (selectedTaskIndex === 3) {
    if (previewText === 'install') {
      return `# [HDC 动作：将 HAP 传输并覆盖安装到物理开发板]\n` +
             `hdc ${previewSubText ? '-t ' + previewSubText : ''} install -r "D:\\DevEcoProjects\\HelloHap\\entry\\build\\default\\outputs\\default\\entry-default-signed.hap"`;
    } else if (previewText === 'start') {
      return `# [HDC 动作：使用底层 aa 工具启动应用 EntryAbility]\n` +
             `hdc ${previewSubText ? '-t ' + previewSubText : ''} shell "aa start -a EntryAbility -b com.openclaw.learnhap"`;
    } else {
      return `# [HDC 动作：一键彻底卸载目标包名的沙箱与应用程序]\n` +
             `hdc ${previewSubText ? '-t ' + previewSubText : ''} uninstall "com.openclaw.learnhap"`;
    }
  }
  return '';
}
