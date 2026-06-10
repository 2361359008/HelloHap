// 主页入口视图
// 从 pages/Index.ets 抽取：应用首页的标题、基础版/高级版入口与设备状态指示条。
// 通过回调把模式切换交回页面处理。

@Component
export struct HomeEntryView {
  onEnterTutorial: () => void = () => {};
  onEnterAdvanced: () => void = () => {};
  // 进入多元开发（多个可自由开发的 HAP 工程）。openclaw 处理中禁用。
  onEnterMultiDev: () => void = () => {};
  @Prop multiDevBusy: boolean = false;

  build() {
    Column() {
      // Title Section
      Text('开源鸿蒙hap的ai助手导学和自由开发')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cdd6f4')
        .margin({ top: 80, bottom: 10 })

      Text('为OpenHarmony Hap打造的AI助手协同学习平台')
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

      // 3. 多元开发：多个可自由开发的 HAP 工程（日程/扫雷/视频/计算器/俄罗斯方块/随心）
      Button('多元开发')
        .width('70%')
        .height(56)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#89b4fa') // Blue
        .fontColor('#1e1e2e')
        .borderRadius(12)
        .margin({ bottom: 20 })
        .enabled(!this.multiDevBusy)
        .opacity(this.multiDevBusy ? 0.5 : 1)
        .onClick(() => { this.onEnterMultiDev(); })

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
