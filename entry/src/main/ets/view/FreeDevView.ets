// 自由开发视图
// 高级版「自由开发」专属子界面：日程 HAP 自由开发任务。
// 进入后初始化 openclaw 协同（知时）身份，身份就位后用两个提示词驱动 OpenClaw 协同开发。
// 结构：标题 + 任务说明卡片 + 身份状态 + 提示词按钮。（返回主页由顶部工具栏统一处理）

@Component
export struct FreeDevView {
  // 重新初始化还原身份
  onReinitIdentity: () => void = () => {};
  // 发送提示词①：还原「类型」下拉菜单
  onSendRestoreType: () => void = () => {};
  // 发送提示词②：还原「提醒」下拉与「响铃提醒」开关
  onSendRestoreReminder: () => void = () => {};
  // 还原身份是否已初始化（决定提示词按钮是否可点）
  @Prop freeDevReady: boolean = false;
  // openclaw 是否正在处理（处理中禁用按钮）
  @Prop freeDevBusy: boolean = false;

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
        Text('日程 HAP 自由开发任务')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('欢迎来到自由开发日程 HAP 界面，你应该已经看到初始化好的 HAP 项目，请尽情发挥你的想象，和 AI 助手一起开发你想要设计出来的日程 HAP。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(18)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        this.InfoCard('改动边界',
          '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，99% 的改动只动这一个文件。绝对别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signing/、EntryAbility.ets。')

        if (this.freeDevReady) {
          Text('自由开发身份已就位，选择下方提示词发送给 OpenClaw。')
            .fontSize(11)
            .fontColor('#a6e3a1')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else if (this.freeDevBusy) {
          Text('正在初始化自由开发身份...')
            .fontSize(11)
            .fontColor('#f9e2af')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else {
          Text('自由开发身份未就位，请重新初始化后再发送提示词。')
            .fontSize(11)
            .fontColor('#f9e2af')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        }

        Button('① 自由开发：类型下拉菜单')
          .width('100%')
          .height(42)
          .fontSize(13)
          .backgroundColor('#313244')
          .fontColor('#89b4fa')
          .borderRadius(8)
          .enabled(this.freeDevReady && !this.freeDevBusy)
          .opacity((this.freeDevReady && !this.freeDevBusy) ? 1 : 0.5)
          .margin({ bottom: 10 })
          .onClick(() => { this.onSendRestoreType(); })

        Button('② 自由开发：提醒 + 响铃开关')
          .width('100%')
          .height(42)
          .fontSize(13)
          .backgroundColor('#313244')
          .fontColor('#a6e3a1')
          .borderRadius(8)
          .enabled(this.freeDevReady && !this.freeDevBusy)
          .opacity((this.freeDevReady && !this.freeDevBusy) ? 1 : 0.5)
          .margin({ bottom: 10 })
          .onClick(() => { this.onSendRestoreReminder(); })

        if (!this.freeDevReady) {
          Button(this.freeDevBusy ? 'OpenClaw 正在处理...' : '重新初始化自由开发身份')
            .width('100%')
            .height(38)
            .fontSize(12)
            .backgroundColor('#45475a')
            .fontColor('#cdd6f4')
            .borderRadius(8)
            .enabled(!this.freeDevBusy)
            .opacity(this.freeDevBusy ? 0.5 : 1)
            .margin({ bottom: 10 })
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
