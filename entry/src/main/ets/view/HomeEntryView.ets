// 主页入口视图
// 从 pages/Index.ets 抽取：应用首页的标题、基础版/高级版入口与设备状态指示条。
// 通过回调把模式切换交回页面处理。

@Component
export struct HomeEntryView {
  onEnterTutorial: () => void = () => {};
  onEnterAdvanced: () => void = () => {};

  build() {
    Column() {
      // Title Section
      Text('OpenClaw 智能开发向导')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cdd6f4')
        .margin({ top: 80, bottom: 10 })

      Text('专为 OpenHarmony ArkUI 打造的 AI 协同学习平台')
        .fontSize(14)
        .fontColor('#a6adc8')
        .margin({ bottom: 60 })

      // 1. Interactive Tutorial Mode - Simple (Beginner Edition)
      Button('交互式学习（基础版）')
        .width('70%')
        .height(56)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#f5c2e7') // Pink
        .fontColor('#1e1e2e')
        .borderRadius(12)
        .margin({ bottom: 20 })
        .onClick(() => { this.onEnterTutorial(); })

      // 2. Interactive Tutorial Mode - Advanced (Pro Edition)
      Button('交互式学习（高级版）')
        .width('70%')
        .height(56)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#fab387') // Peach
        .fontColor('#1e1e2e')
        .borderRadius(12)
        .margin({ bottom: 20 })
        .onClick(() => { this.onEnterAdvanced(); })

      // Device status indicator bar
      Row() {
        Row() {
          Circle({ width: 8, height: 8 }).fill('#a6e3a1').margin({ right: 6 })
          Text('Shell-Bridge：在线 (7681)').fontSize(12).fontColor('#a6adc8')
        }.margin({ right: 20 })

        Row() {
          Circle({ width: 8, height: 8 }).fill('#a6e3a1').margin({ right: 6 })
          Text('OpenClaw Gateway：运行中 (18800)').fontSize(12).fontColor('#a6adc8')
        }
      }
      .margin({ top: 50 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#1e1e2e')
  }
}
