// 自由开发视图
// 高级版「自由开发」专属子界面：日程 HAP 还原任务。
// 进入后初始化 openclaw 还原（知时）身份，身份就位后用两个还原提示词驱动 OpenClaw 协同开发。
// 与「教学之路」视图结构一致：返回 + 标题 + 任务说明卡片 + 身份状态 + 还原提示词按钮。

@Component
export struct FreeDevView {
  // 返回高级版菜单
  onBack: () => void = () => {};
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
        Row() {
          Button('‹ 返回')
            .fontSize(12)
            .height(30)
            .backgroundColor('#45475a')
            .fontColor('#cdd6f4')
            .onClick(() => { this.onBack(); })

          Text('自由开发')
            .fontSize(13)
            .fontColor('#6c7086')
            .margin({ left: 10 })
        }
        .width('100%')
        .margin({ top: 6, bottom: 12 })
        .justifyContent(FlexAlign.Start)

        Text('日程 HAP 还原任务')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('任务目标：把分身 schedulehap-lite 按完整版 schedulehap 的设计逐步还原。进入即把工程刷回初始模板，身份就位后选择下方提示词驱动 OpenClaw 协同开发。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(18)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        this.InfoCard('改动边界',
          '全部 UI 与逻辑都在 entry/src/main/ets/pages/Index.ets，99% 的改动只动这一个文件。绝对别碰 build-profile.json5、hvigor*、oh-package.json5、package.json、signing/、EntryAbility.ets。')

        this.InfoCard('待还原的三处差异（都在 Index.ets）',
          '① 「类型」行：分身是静态展示 → 还原 = 补回下拉菜单。\n② 「重复」行：分身是静态展示 → 还原 = 补回下拉菜单。\n③ 「提醒」下拉 +「响铃提醒」开关：分身整段删除 → 还原 = 整段加回。')

        if (this.freeDevReady) {
          Text('还原身份已就位，选择下方提示词发送给 OpenClaw。')
            .fontSize(11)
            .fontColor('#a6e3a1')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else {
          Text(this.freeDevBusy ? '正在初始化还原身份...' : '还原身份未就位，请重新初始化后再发送提示词。')
            .fontSize(11)
            .fontColor('#f9e2af')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        }

        Button('① 还原：类型下拉菜单')
          .width('100%')
          .height(36)
          .fontSize(12)
          .backgroundColor('#11305a')
          .fontColor('#89b4fa')
          .enabled(this.freeDevReady && !this.freeDevBusy)
          .opacity((this.freeDevReady && !this.freeDevBusy) ? 1 : 0.5)
          .margin({ top: 2, bottom: 8 })
          .onClick(() => { this.onSendRestoreType(); })

        Button('② 还原：提醒 + 响铃开关')
          .width('100%')
          .height(36)
          .fontSize(12)
          .backgroundColor('#11305a')
          .fontColor('#89b4fa')
          .enabled(this.freeDevReady && !this.freeDevBusy)
          .opacity((this.freeDevReady && !this.freeDevBusy) ? 1 : 0.5)
          .margin({ bottom: 8 })
          .onClick(() => { this.onSendRestoreReminder(); })

        if (!this.freeDevReady) {
          Button(this.freeDevBusy ? 'OpenClaw 正在处理...' : '重新初始化还原身份')
            .width('100%')
            .height(34)
            .fontSize(12)
            .backgroundColor('#45475a')
            .fontColor('#cdd6f4')
            .enabled(!this.freeDevBusy)
            .opacity(this.freeDevBusy ? 0.5 : 1)
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
