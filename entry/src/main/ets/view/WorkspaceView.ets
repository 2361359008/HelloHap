// 右侧工作区视图
// 从 pages/Index.ets 抽取：右侧"OpenClaw 对话 / 源码文件 / OpenClaw 日志"三个标签页。
// 状态通过 @Link/@Prop 与页面双向/单向绑定，源码文本与刷新动作由页面提供。

import { ChatMessage } from '../model/OpenClawTypes';

// 工程文件树节点（由扁平的相对路径列表构建而成）。
class FileLeaf {
  name: string = '';
  relPath: string = '';
  constructor(name: string, relPath: string) {
    this.name = name;
    this.relPath = relPath;
  }
}

class FileTreeNode {
  name: string = '';
  relPath: string = '';
  children: FileTreeNode[] = [];
  files: FileLeaf[] = [];
  findChild(name: string): FileTreeNode | undefined {
    for (let i = 0; i < this.children.length; i++) {
      if (this.children[i].name === name) {
        return this.children[i];
      }
    }
    return undefined;
  }
}

// 目录树展开后的一行（目录或文件），供弹窗树形选择器渲染。
class FileTreeRow {
  name: string = '';
  relPath: string = '';
  isDir: boolean = false;
  depth: number = 0;
  expanded: boolean = false;
  constructor(name: string, relPath: string, isDir: boolean, depth: number, expanded: boolean) {
    this.name = name;
    this.relPath = relPath;
    this.isDir = isDir;
    this.depth = depth;
    this.expanded = expanded;
  }
}

function compareByName(a: string, b: string): number {
  return a < b ? -1 : (a > b ? 1 : 0);
}

@Component
export struct WorkspaceView {
  @Link workspaceTab: number;
  @Prop selectedTaskIndex: number;
  @Prop currentMode: string;
  @Link @Watch('onChatMessagesChanged') chatMessages: Array<ChatMessage>;
  @Prop sourceFileLoading: boolean;
  @Prop sourceFileError: string;
  @Prop sourceText: string;
  @Prop sourceFileContent: string;
  @Prop currentExecutionLog: string;
  // 高级关卡源码区：整个工程的文件树与选中状态。
  @Prop advancedFiles: string[];
  @Prop advancedFilesLoading: boolean;
  @Prop advancedFilesError: string;
  @Prop selectedSourceFile: string;
  // OpenClaw 是否正在处理（驱动顶部「AI 助手正在处理…」左右动画与忙态展示）。
  @Prop @Watch('onOpenClawBusyChange') openClawBusy: boolean;
  onSelectSourceTab: () => void = () => {};
  onRefreshSource: () => void = () => {};
  onSelectAdvancedFile: (path: string) => void = () => {};
  onRefreshAdvancedFiles: () => void = () => {};
  // 文件树弹窗的显隐与已展开目录（相对路径）。
  @State showFileTree: boolean = false;
  @State expandedDirs: string[] = [];
  // 顶部「AI 助手正在处理…」左右往返动画的水平位移量（px）。
  @State busyShift: number = 0;
  // 对话区滚动控制器：新消息/流式更新到达时自动滚到底部，跟随最新对话。
  private chatScroller: Scroller = new Scroller();

  // chatMessages 变化（新消息或流式更新）时，延迟到布局完成后把对话区滚到底部。
  onChatMessagesChanged(): void {
    setTimeout(() => { this.chatScroller.scrollEdge(Edge.Bottom); }, 60);
  }

  aboutToAppear(): void {
    if (this.openClawBusy) {
      this.startBusyAnim();
    }
  }

  // openClawBusy 变化时驱动顶部提示左右往返：忙时无限交替平移，空闲时复位。
  onOpenClawBusyChange(): void {
    if (this.openClawBusy) {
      this.startBusyAnim();
    } else {
      animateTo({ duration: 0 }, () => { this.busyShift = 0; });
    }
  }

  private startBusyAnim(): void {
    this.busyShift = 0;
    animateTo({ duration: 760, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.busyShift = 40;
    });
  }

  // 高级关卡源码区右侧内容文本（根据加载/错误/选中状态计算）。
  private advancedSourceDisplay(): string {
    if (this.sourceFileLoading) {
      return '// 正在从板端读取文件...';
    }
    if (this.sourceFileError) {
      return '// 板端文件读取失败\n// ' + this.sourceFileError +
        '\n// 请确认 shell-bridge (:7681) 已部署 /read-file 接口后重试';
    }
    if (!this.selectedSourceFile) {
      return '// 点上方「选择文件」从工程目录树里选一个文件查看内容';
    }
    return this.sourceFileContent ? this.sourceFileContent : '// （该文件为空或无文本内容）';
  }

  // 由扁平相对路径列表构建目录树。
  private buildFileTree(files: string[]): FileTreeNode {
    let root = new FileTreeNode();
    for (let i = 0; i < files.length; i++) {
      let parts = files[i].split('/');
      let node = root;
      let acc = '';
      for (let j = 0; j < parts.length; j++) {
        let part = parts[j];
        acc = acc.length > 0 ? acc + '/' + part : part;
        if (j === parts.length - 1) {
          node.files.push(new FileLeaf(part, acc));
        } else {
          let child = node.findChild(part);
          if (child === undefined) {
            child = new FileTreeNode();
            child.name = part;
            child.relPath = acc;
            node.children.push(child);
          }
          node = child;
        }
      }
    }
    return root;
  }

  // 按「目录在前、各自字母序」深度优先展开成可见行；仅展开 expandedDirs 中的目录。
  private flattenNode(node: FileTreeNode, depth: number, out: FileTreeRow[]): void {
    let kids = node.children.slice();
    kids.sort((a: FileTreeNode, b: FileTreeNode) => compareByName(a.name, b.name));
    for (let i = 0; i < kids.length; i++) {
      let dir = kids[i];
      let isExp = this.expandedDirs.indexOf(dir.relPath) >= 0;
      out.push(new FileTreeRow(dir.name, dir.relPath, true, depth, isExp));
      if (isExp) {
        this.flattenNode(dir, depth + 1, out);
      }
    }
    let leaves = node.files.slice();
    leaves.sort((a: FileLeaf, b: FileLeaf) => compareByName(a.name, b.name));
    for (let i = 0; i < leaves.length; i++) {
      out.push(new FileTreeRow(leaves[i].name, leaves[i].relPath, false, depth, false));
    }
  }

  private buildVisibleRows(): FileTreeRow[] {
    let root = this.buildFileTree(this.advancedFiles);
    let out: FileTreeRow[] = [];
    this.flattenNode(root, 0, out);
    return out;
  }

  private toggleDir(relPath: string): void {
    let idx = this.expandedDirs.indexOf(relPath);
    if (idx >= 0) {
      let next = this.expandedDirs.slice();
      next.splice(idx, 1);
      this.expandedDirs = next;
    } else {
      this.expandedDirs = this.expandedDirs.concat([relPath]);
    }
  }

  // 打开文件树弹窗；首次打开时自动展开到当前选中文件的各级父目录。
  private openFileTree(): void {
    if (this.expandedDirs.length === 0 && this.selectedSourceFile.length > 0) {
      let parts = this.selectedSourceFile.split('/');
      let acc = '';
      let seed: string[] = [];
      for (let i = 0; i < parts.length - 1; i++) {
        acc = acc.length > 0 ? acc + '/' + parts[i] : parts[i];
        seed.push(acc);
      }
      this.expandedDirs = seed;
    }
    this.showFileTree = true;
  }

  build() {
    Column() {
      // 1. Workspace Tab Bar
      Row() {
        // Tab 0 button: OpenClaw Chat
        Row() {
          Text('OpenClaw 对话')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.workspaceTab === 0 ? '#89b4fa' : '#a6adc8')
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor(this.workspaceTab === 0 ? '#313244' : 'transparent')
        .borderRadius({ topLeft: 6, topRight: 6 })
        .onClick(() => { this.workspaceTab = 0; })

        // Tab 1 button: Source Code
        Row() {
          Text('源码文件 (Source)')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.workspaceTab === 1 ? '#89b4fa' : '#a6adc8')
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor(this.workspaceTab === 1 ? '#313244' : 'transparent')
        .borderRadius({ topLeft: 6, topRight: 6 })
        .onClick(() => { this.onSelectSourceTab(); })

        // Tab 2 button: OpenClaw Logs
        Row() {
          Text('OpenClaw 日志')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.workspaceTab === 2 ? '#89b4fa' : '#a6adc8')
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor(this.workspaceTab === 2 ? '#313244' : 'transparent')
        .borderRadius({ topLeft: 6, topRight: 6 })
        .onClick(() => { this.workspaceTab = 2; })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6 })
      .backgroundColor('#1e1e2e')

      // 2. Tab Workspace Content Area
      Column() {
        if (this.workspaceTab === 0) {
          // === TAB 0: OPENCLAW CHAT WORKSPACE ===
          Column() {
            Row() {
              Text('OpenClaw')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#cdd6f4')
              Text('main')
                .fontSize(11)
                .fontColor('#a6adc8')
                .margin({ left: 8 })
              Text('聊天')
                .fontSize(11)
                .fontColor('#f38ba8')
                .fontWeight(FontWeight.Bold)
                .margin({ left: 8 })
              if (this.openClawBusy) {
                // 处理中：转圈 + 左右往返移动的「AI 助手正在处理…」
                Row() {
                  LoadingProgress()
                    .width(14).height(14).color('#f9e2af')
                  Text('AI 助手正在处理…')
                    .fontSize(11).fontColor('#f9e2af').fontWeight(FontWeight.Bold)
                    .margin({ left: 6 })
                    .translate({ x: this.busyShift })
                }
                .margin({ left: 12 })
                .alignItems(VerticalAlign.Center)
              }
              Blank()
              Text('qwen3.7-max')
                .fontSize(11)
                .fontColor('#a6adc8')
                .backgroundColor('#313244')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .borderRadius(6)
              Text('HTTP')
                .fontSize(10)
                .fontColor('#1e1e2e')
                .fontWeight(FontWeight.Bold)
                .backgroundColor('#a6e3a1')
                .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                .borderRadius(6)
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 14, bottom: 12 })
            .backgroundColor('#181825')
            .borderWidth({ bottom: 1 })
            .borderColor('#313244')

            Scroll(this.chatScroller) {
              Column() {
                if (this.selectedTaskIndex === 0 && this.currentMode !== 'advanced') {
                  Column() {
                    Text('选择左侧关卡后，这里会显示本应用内置的 OpenClaw 主对话区。')
                      .fontSize(15)
                      .fontColor('#cdd6f4')
                      .fontWeight(FontWeight.Bold)
                      .textAlign(TextAlign.Center)
                      .margin({ bottom: 8 })
                    Text('它只连接 OpenClaw 后端接口，不再嵌入 Web UI 页面。')
                      .fontSize(12)
                      .fontColor('#a6adc8')
                      .textAlign(TextAlign.Center)
                  }
                  .width('100%')
                  .layoutWeight(1)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                } else {
                  ForEach(this.chatMessages, (msg: ChatMessage) => {
                    if (msg.kind === 'thinking') {
                      // OpenClaw 思考过程：暗色斜体块，点按展开/收起。
                      Column() {
                        Row() {
                          Text('💭 思考过程')
                            .fontSize(11).fontWeight(FontWeight.Bold).fontColor('#9399b2')
                          Text(msg.collapsed ? '展开' : '收起')
                            .fontSize(10).fontColor('#6c7086').margin({ left: 8 })
                        }
                        .width('100%').justifyContent(FlexAlign.Start).margin({ bottom: 4 })
                        Text(msg.text)
                          .fontSize(12).fontColor('#9399b2').fontStyle(FontStyle.Italic).lineHeight(18)
                          .maxLines(msg.collapsed ? 3 : 100000)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                          .copyOption(CopyOptions.LocalDevice)
                          .width('100%')
                      }
                      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .backgroundColor('#1e1e2e').borderRadius(8)
                      .border({ width: { left: 3 }, color: '#585b70' })
                      .margin({ bottom: 10 })
                      .onClick(() => { msg.collapsed = !msg.collapsed; this.chatMessages = [...this.chatMessages]; })
                    } else if (msg.kind === 'toolCall') {
                      // OpenClaw 调用工具：工具名 + 参数摘要（read 的路径 / exec 的命令）。
                      Column() {
                        Row() {
                          Text('🔧 调用工具')
                            .fontSize(11).fontWeight(FontWeight.Bold).fontColor('#f9e2af')
                          Text(msg.toolName)
                            .fontSize(11).fontWeight(FontWeight.Bold).fontColor('#fab387')
                            .fontFamily('monospace').margin({ left: 6 })
                        }
                        .width('100%').justifyContent(FlexAlign.Start).margin({ bottom: msg.toolArgs.length > 0 ? 4 : 0 })
                        if (msg.toolArgs.length > 0) {
                          Text(msg.toolArgs)
                            .fontSize(11).fontColor('#cdd6f4').fontFamily('monospace').lineHeight(16)
                            .maxLines(msg.collapsed ? 3 : 100000)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                            .copyOption(CopyOptions.LocalDevice)
                            .width('100%')
                        }
                      }
                      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .backgroundColor('#1e1e2e').borderRadius(8)
                      .border({ width: { left: 3 }, color: '#f9e2af' })
                      .margin({ bottom: 10 })
                      .onClick(() => { msg.collapsed = !msg.collapsed; this.chatMessages = [...this.chatMessages]; })
                    } else if (msg.kind === 'toolResult') {
                      // 工具返回结果：等宽，默认折叠，出错标红，点按展开/收起。
                      Column() {
                        Row() {
                          Text(msg.isError ? '⚠ 工具返回（错误）' : '📄 工具返回')
                            .fontSize(11).fontWeight(FontWeight.Bold)
                            .fontColor(msg.isError ? '#f38ba8' : '#a6e3a1')
                          Text(msg.toolName)
                            .fontSize(10).fontColor('#6c7086').fontFamily('monospace').margin({ left: 6 })
                          Text(msg.collapsed ? '展开' : '收起')
                            .fontSize(10).fontColor('#6c7086').margin({ left: 8 })
                        }
                        .width('100%').justifyContent(FlexAlign.Start).margin({ bottom: 4 })
                        Text(msg.text)
                          .fontSize(11).fontColor('#bac2de').fontFamily('monospace').lineHeight(16)
                          .maxLines(msg.collapsed ? 8 : 100000)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                          .copyOption(CopyOptions.LocalDevice)
                          .width('100%')
                      }
                      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 })
                      .backgroundColor('#181825').borderRadius(8)
                      .border({ width: { left: 3 }, color: msg.isError ? '#f38ba8' : '#a6e3a1' })
                      .margin({ bottom: 10 })
                      .onClick(() => { msg.collapsed = !msg.collapsed; this.chatMessages = [...this.chatMessages]; })
                    } else {
                      Column() {
                        Row() {
                          Text(msg.sender === 'user' ? 'You' : 'OpenClaw')
                            .fontSize(11)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(msg.sender === 'user' ? '#f5c2e7' : '#a6e3a1')
                          Text(msg.sender === 'user' ? '学生输入' : 'Assistant')
                            .fontSize(9)
                            .fontColor('#6c7086')
                            .margin({ left: 6 })
                        }
                        .width('100%')
                        .justifyContent(msg.sender === 'user' ? FlexAlign.End : FlexAlign.Start)
                        .margin({ bottom: 4 })

                        Row() {
                          Text(msg.text)
                            .fontSize(13)
                            .fontColor(msg.sender === 'user' ? '#1e1e2e' : '#cdd6f4')
                            .lineHeight(19)
                            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                            .copyOption(CopyOptions.LocalDevice)
                        }
                        .padding({ left: 14, right: 14, top: 11, bottom: 11 })
                        .backgroundColor(msg.sender === 'user' ? '#f5c2e7' : '#313244')
                        .borderRadius(10)
                        .alignSelf(msg.sender === 'user' ? ItemAlign.End : ItemAlign.Start)
                        .width(msg.sender === 'user' ? '72%' : '82%')
                        .margin({ bottom: 16 })
                      }
                      .width('100%')
                      .alignItems(msg.sender === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
                    }
                  })
                }
              }
              .width('100%')
              .padding({ left: 22, right: 22, top: 20, bottom: 20 })
            }
            .layoutWeight(1)
            .backgroundColor('#11111b')

          }
          .width('100%')
          .height('100%')
          .backgroundColor('#11111b')

        } else if (this.workspaceTab === 1) {
          // === TAB 1: BOARD SOURCE FILE ===
          if (this.currentMode === 'advanced') {
            // 高级关卡：内容区占满整宽；文件目录改为点「选择文件」弹出的可展开目录树（编辑器风格）。
            Stack({ alignContent: Alignment.TopStart }) {
              // 基础层：顶部工具条 + 全宽文件内容
              Column() {
                Row() {
                  Text('选择文件')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#89b4fa')
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor('#313244')
                    .borderRadius(6)
                    .onClick(() => { this.openFileTree(); })
                  Text(this.selectedSourceFile ? this.selectedSourceFile : '（未选择文件）')
                    .fontSize(11)
                    .fontColor('#a6adc8')
                    .fontFamily('monospace')
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ left: 10 })
                  Text((this.advancedFilesLoading || this.sourceFileLoading) ? '读取中...' : '刷新')
                    .fontSize(11)
                    .fontColor((this.advancedFilesLoading || this.sourceFileLoading) ? '#585b70' : '#89b4fa')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('#313244')
                    .borderRadius(4)
                    .margin({ left: 8 })
                    .onClick(() => {
                      if (!this.advancedFilesLoading && !this.sourceFileLoading) {
                        this.onRefreshAdvancedFiles();
                      }
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 8 })
                .backgroundColor('#181825')

                Scroll() {
                  Column() {
                    Text(this.advancedSourceDisplay())
                      .fontSize(12)
                      .fontColor(this.sourceFileError ? '#f38ba8' : '#a6e3a1')
                      .fontFamily('monospace')
                      .lineHeight(17)
                      .padding(14)
                      .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                      .copyOption(CopyOptions.LocalDevice)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .width('100%')
                }
                .layoutWeight(1)
                .width('100%')
              }
              .width('100%')
              .height('100%')

              // 弹出层：可展开的工程目录树
              if (this.showFileTree) {
                Stack() {
                  // 半透明遮罩，点击空白处关闭
                  Column()
                    .width('100%')
                    .height('100%')
                    .backgroundColor('#8C000000')
                    .onClick(() => { this.showFileTree = false; })

                  // 居中的树形选择面板
                  Column() {
                    Row() {
                      Text('工程文件')
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#cdd6f4')
                      Blank()
                      Text(this.advancedFilesLoading ? '加载中' : '刷新')
                        .fontSize(11)
                        .fontColor(this.advancedFilesLoading ? '#585b70' : '#89b4fa')
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor('#313244')
                        .borderRadius(4)
                        .onClick(() => {
                          if (!this.advancedFilesLoading && !this.sourceFileLoading) {
                            this.onRefreshAdvancedFiles();
                          }
                        })
                      Text('✕')
                        .fontSize(15)
                        .fontColor('#a6adc8')
                        .margin({ left: 14 })
                        .onClick(() => { this.showFileTree = false; })
                    }
                    .width('100%')
                    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                    .backgroundColor('#181825')

                    Scroll() {
                      Column() {
                        if (this.advancedFilesError) {
                          Text('文件列表读取失败\n' + this.advancedFilesError +
                            '\n请确认 shell-bridge (:7681) 已部署 /list-files 接口')
                            .fontSize(11)
                            .fontColor('#f38ba8')
                            .fontFamily('monospace')
                            .lineHeight(16)
                            .padding(12)
                        } else if (this.advancedFiles.length === 0) {
                          Text(this.advancedFilesLoading ? '正在加载文件列表...' : '暂无文件')
                            .fontSize(11)
                            .fontColor('#585b70')
                            .padding(12)
                        } else {
                          ForEach(this.buildVisibleRows(), (row: FileTreeRow) => {
                            Row() {
                              Text(row.isDir ? (row.expanded ? '▾' : '▸') : '')
                                .fontSize(11)
                                .fontColor('#89b4fa')
                                .width(16)
                                .textAlign(TextAlign.Center)
                              Text(row.name)
                                .fontSize(12)
                                .fontFamily('monospace')
                                .fontWeight(row.isDir ? FontWeight.Bold : FontWeight.Normal)
                                .fontColor(!row.isDir && row.relPath === this.selectedSourceFile
                                  ? '#89b4fa' : (row.isDir ? '#cdd6f4' : '#a6adc8'))
                                .layoutWeight(1)
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                            }
                            .width('100%')
                            .padding({ left: 8 + row.depth * 16, right: 8, top: 7, bottom: 7 })
                            .backgroundColor(!row.isDir && row.relPath === this.selectedSourceFile
                              ? '#313244' : 'transparent')
                            .onClick(() => {
                              if (row.isDir) {
                                this.toggleDir(row.relPath);
                              } else {
                                this.onSelectAdvancedFile(row.relPath);
                                this.showFileTree = false;
                              }
                            })
                          }, (row: FileTreeRow) => row.relPath + (row.isDir ? '/d' : '/f'))
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .width('100%')
                    }
                    .layoutWeight(1)
                    .width('100%')
                    .backgroundColor('#11111b')
                  }
                  .width('80%')
                  .height('82%')
                  .borderRadius(10)
                  .clip(true)
                  .border({ width: 1, color: '#313244' })
                }
                .width('100%')
                .height('100%')
              }
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#11111b')

          } else {
            Column() {
              Row() {
                Text('/data/local/tmp/oh61-hapbuild/project/entry/src/main/ets/pages/Index.ets')
                  .fontSize(11)
                  .fontColor('#585b70')
                  .fontFamily('monospace')
                  .layoutWeight(1)
                if (this.selectedTaskIndex > 0) {
                  Text(this.sourceFileLoading ? '读取中...' : '刷新')
                    .fontSize(11)
                    .fontColor(this.sourceFileLoading ? '#585b70' : '#89b4fa')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('#313244')
                    .borderRadius(4)
                    .onClick(() => {
                      if (!this.sourceFileLoading) {
                        this.onRefreshSource();
                      }
                    })
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 6 })

              Scroll() {
                Column() {
                  Text(this.sourceText)
                    .fontSize(13)
                    .fontColor(this.sourceFileError ? '#f38ba8' : '#a6e3a1')
                    .fontFamily('monospace')
                    .lineHeight(18)
                    .padding(16)
                    .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                    .copyOption(CopyOptions.LocalDevice)
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
              }
              .layoutWeight(1)
              .width('100%')
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#11111b')
          }

        } else if (this.workspaceTab === 2) {
          // === TAB 2: OPENCLAW AGENT LOGS ===
          Scroll() {
            Column() {
              if (!this.currentExecutionLog) {
                Text('> Console idle. Ready to boot OpenClaw.')
                  .fontSize(13)
                  .fontColor('#585b70')
                  .fontFamily('monospace')
                  .padding(16)
              } else {
                Text(this.currentExecutionLog)
                  .fontSize(12)
                  .fontColor('#cdd6f4')
                  .fontFamily('monospace')
                  .lineHeight(16)
                  .padding(16)
                  .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                  .copyOption(CopyOptions.LocalDevice)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#11111b')
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#252538')
    }
    .width('55%')
    .height('100%')
    .backgroundColor('#1e1e2e')
  }
}
