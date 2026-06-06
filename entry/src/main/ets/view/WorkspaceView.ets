// 右侧工作区视图
// 从 pages/Index.ets 抽取：右侧"OpenClaw 对话 / 源码文件 / OpenClaw 日志"三个标签页。
// 状态通过 @Link/@Prop 与页面双向/单向绑定，源码文本与刷新动作由页面提供。

import { ChatMessage } from '../model/OpenClawTypes';

@Component
export struct WorkspaceView {
  @Link workspaceTab: number;
  @Prop selectedTaskIndex: number;
  @Link chatMessages: Array<ChatMessage>;
  @Prop sourceFileLoading: boolean;
  @Prop sourceFileError: string;
  @Prop sourceText: string;
  @Prop currentExecutionLog: string;
  onSelectSourceTab: () => void = () => {};
  onRefreshSource: () => void = () => {};

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
                if (this.selectedTaskIndex === 0) {
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
