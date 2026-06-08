// 右侧工作区视图
// 从 pages/Index.ets 抽取：右侧"OpenClaw 对话 / 源码文件 / OpenClaw 日志"三个标签页。
// 状态通过 @Link/@Prop 与页面双向/单向绑定，源码文本与刷新动作由页面提供。

import { ChatMessage } from '../model/OpenClawTypes';

@Component
export struct WorkspaceView {
  @Link workspaceTab: number;
  @Prop selectedTaskIndex: number;
  @Prop currentMode: string;
  @Link chatMessages: Array<ChatMessage>;
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
  onSelectSourceTab: () => void = () => {};
  onRefreshSource: () => void = () => {};
  onSelectAdvancedFile: (path: string) => void = () => {};
  onRefreshAdvancedFiles: () => void = () => {};

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
      return '// 选择左侧文件查看内容';
    }
    return this.sourceFileContent ? this.sourceFileContent : '// （空文件）';
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

            Scroll() {
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
            // 高级关卡：浏览整个工程的文件树（左侧文件列表 + 右侧文件内容）。
            Column() {
              Row() {
                Text(this.selectedSourceFile ? this.selectedSourceFile : '日程工程文件浏览（advanced-hapbuild/project）')
                  .fontSize(11)
                  .fontColor('#585b70')
                  .fontFamily('monospace')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text((this.advancedFilesLoading || this.sourceFileLoading) ? '读取中...' : '刷新')
                  .fontSize(11)
                  .fontColor((this.advancedFilesLoading || this.sourceFileLoading) ? '#585b70' : '#89b4fa')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor('#313244')
                  .borderRadius(4)
                  .onClick(() => {
                    if (!this.advancedFilesLoading && !this.sourceFileLoading) {
                      this.onRefreshAdvancedFiles();
                    }
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 6 })

              Row() {
                // 左侧：工程文件列表
                Scroll() {
                  Column() {
                    if (this.advancedFilesError) {
                      Text('文件列表读取失败\n' + this.advancedFilesError + '\n请确认 shell-bridge (:7681) 已部署 /list-files 接口')
                        .fontSize(11)
                        .fontColor('#f38ba8')
                        .fontFamily('monospace')
                        .lineHeight(16)
                        .padding(10)
                    } else if (this.advancedFiles.length === 0) {
                      Text(this.advancedFilesLoading ? '正在加载文件列表...' : '暂无文件')
                        .fontSize(11)
                        .fontColor('#585b70')
                        .padding(10)
                    } else {
                      ForEach(this.advancedFiles, (file: string) => {
                        Text(file)
                          .fontSize(11)
                          .fontColor(file === this.selectedSourceFile ? '#89b4fa' : '#a6adc8')
                          .fontFamily('monospace')
                          .width('100%')
                          .padding({ left: 10, right: 8, top: 7, bottom: 7 })
                          .backgroundColor(file === this.selectedSourceFile ? '#313244' : 'transparent')
                          .onClick(() => { this.onSelectAdvancedFile(file); })
                      })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .width('100%')
                }
                .width('42%')
                .height('100%')
                .backgroundColor('#181825')

                Divider()
                  .vertical(true)
                  .width(1)
                  .color('#313244')
                  .height('100%')

                // 右侧：选中文件内容
                Scroll() {
                  Column() {
                    Text(this.advancedSourceDisplay())
                      .fontSize(12)
                      .fontColor(this.sourceFileError ? '#f38ba8' : '#a6e3a1')
                      .fontFamily('monospace')
                      .lineHeight(17)
                      .padding(12)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .width('100%')
                }
                .layoutWeight(1)
                .height('100%')
              }
              .width('100%')
              .layoutWeight(1)
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
