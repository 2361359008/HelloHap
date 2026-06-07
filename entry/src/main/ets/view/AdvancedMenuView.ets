// 高级版菜单视图
// 从 pages/Index.ets 抽取：高级版左侧的"教学之路 / 自由开发"两个入口卡片。
// 两个入口点击后各自进入独立子界面（教学之路 / 自由开发视图）。

@Component
export struct AdvancedMenuView {
  // 点击「进入教学之路」：进入教学子界面
  onEnterTeaching: () => void = () => {};
  // 点击「进入自由开发」：进入自由开发子界面
  onEnterFreeDev: () => void = () => {};
  // openclaw 是否正在处理（处理中禁用入口按钮）
  @Prop freeDevBusy: boolean = false;

  build() {
    Column() {
      Text('请选择高级开发模式')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#cdd6f4')
        .margin({ bottom: 12, top: 6 })
        .alignSelf(ItemAlign.Start)

      Column() {
        Text('教学之路')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fab387')
          .margin({ bottom: 6 })

        Text('按照进阶课程路线学习 ArkUI 项目设计与开发。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .margin({ bottom: 12 })

        Button('进入教学之路')
          .width('100%')
          .height(34)
          .fontSize(12)
          .backgroundColor('#45475a')
          .fontColor('#fab387')
          .onClick(() => { this.onEnterTeaching(); })
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#313244')
      .borderRadius(8)
      .margin({ bottom: 10 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text('自由开发')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#89b4fa')
          .margin({ bottom: 6 })

        Text('进入日程 HAP 还原任务：初始化 openclaw 身份后，选择提示词驱动 OpenClaw 协同开发。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .margin({ bottom: 12 })
          .lineHeight(16)

        Button('进入自由开发')
          .width('100%')
          .height(34)
          .fontSize(12)
          .backgroundColor('#45475a')
          .fontColor('#89b4fa')
          .enabled(!this.freeDevBusy)
          .opacity(this.freeDevBusy ? 0.5 : 1)
          .onClick(() => { this.onEnterFreeDev(); })
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#313244')
      .borderRadius(8)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}
