// 教学之路视图
// 高级版「教学之路」开发流程：日志项目初始化与后续流程解读。
// 应用内每次只展示一个流程卡片 + 一个「进入下一流程」按钮（点击后由父组件调用 openclaw）。
// 首步先以已经设计好的日志 HAP 为入口，按流程介绍后续开发步骤。

@Component
export struct TeachingPathView {
  // 返回高级版菜单
  onBack: () => void = () => {};
  // 进入下一流程并让 OpenClaw 讲解
  onEnterNextFlow: () => void = () => {};
  // 重新初始化讲师身份
  onReinitIdentity: () => void = () => {};
  // 讲师身份是否已初始化（决定详解按钮是否可点）
  @Prop teachingReady: boolean = false;
  // openclaw 是否正在处理（处理中禁用按钮）
  @Prop teachingBusy: boolean = false;
  // 当前展示的流程步骤，从 0 开始
  @Prop teachingFlowStep: number = 0;
  // 流程总数
  @Prop teachingFlowTotal: number = 6;
  // 当前卡片标题和正文由父页面状态直接传入，确保切换流程时卡片同步刷新。
  @Prop teachingFlowTitle: string = '① 初始化日志项目';
  @Prop teachingFlowBody: string = '';

  @Builder
  InfoCard(title: string, body: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#89b4fa')
        .margin({ bottom: 6 })
        .alignSelf(ItemAlign.Start)

      Text(body)
        .fontSize(12)
        .fontColor('#a6adc8')
        .lineHeight(18)
        .alignSelf(ItemAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#313244')
    .borderRadius(8)
    .margin({ bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button('‹ 返回')
            .fontSize(12)
            .height(30)
            .backgroundColor('#45475a')
            .fontColor('#cdd6f4')
            .onClick(() => { this.onBack(); })

          Text('教学之路')
            .fontSize(13)
            .fontColor('#6c7086')
            .margin({ left: 10 })
        }
        .width('100%')
        .margin({ top: 6, bottom: 12 })
        .justifyContent(FlexAlign.Start)

        Text('开发流程：日志 HAP 教学导览')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('本流程目标：按步骤理解日志 HAP 的开发过程。当前只展示一个流程，点击下方按钮后进入下一流程并触发 OpenClaw 讲解。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(18)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        this.InfoCard(this.teachingFlowTitle, this.teachingFlowBody)

        if (this.teachingReady) {
          Text(this.teachingFlowStep < this.teachingFlowTotal - 1 ? '讲师身份已就位，可点击下方进入下一流程。' : '日志 HAP 开发教学流程已到最后一步。')
            .fontSize(11)
            .fontColor('#a6e3a1')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else {
          Text(this.teachingBusy ? '正在初始化讲师身份...' : '讲师身份未就位，请重新初始化后再讲解。')
            .fontSize(11)
            .fontColor('#f9e2af')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        }

        if (this.teachingFlowStep < this.teachingFlowTotal - 1) {
          Button(this.teachingBusy ? 'OpenClaw 正在处理...' : '进入下一流程')
            .width('100%')
            .height(36)
            .fontSize(12)
            .backgroundColor('#11305a')
            .fontColor('#89b4fa')
            .enabled(this.teachingReady && !this.teachingBusy)
            .opacity((this.teachingReady && !this.teachingBusy) ? 1 : 0.5)
            .margin({ top: 2, bottom: 8 })
            .onClick(() => { this.onEnterNextFlow(); })
        }

        if (!this.teachingReady) {
          Button('重新初始化讲师身份')
            .width('100%')
            .height(34)
            .fontSize(12)
            .backgroundColor('#45475a')
            .fontColor('#cdd6f4')
            .enabled(!this.teachingBusy)
            .opacity(this.teachingBusy ? 0.5 : 1)
            .margin({ bottom: 8 })
            .onClick(() => { this.onReinitIdentity(); })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .layoutWeight(1)
  }
}
