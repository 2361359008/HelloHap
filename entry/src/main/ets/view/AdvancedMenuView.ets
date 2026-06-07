// 高级版菜单视图
// 从 pages/Index.ets 抽取：高级版左侧的"教学之路 / 自由开发"两个入口卡片。
// 「自由开发」点击后初始化 openclaw 身份会话，并展示两个还原提示词按钮。

import { promptAction } from '@kit.ArkUI';

@Component
export struct AdvancedMenuView {
  // 点击「进入自由开发」：初始化 openclaw 身份会话
  onEnterFreeDev: () => void = () => {};
  // 发送提示词①：还原「类型」下拉菜单
  onSendRestoreType: () => void = () => {};
  // 发送提示词②：还原「提醒」下拉与「响铃提醒」开关
  onSendRestoreReminder: () => void = () => {};
  // 身份是否已初始化（决定是否展示两个提示词按钮）
  @Prop freeDevReady: boolean = false;
  // openclaw 是否正在处理（处理中禁用按钮）
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
          .onClick(() => {
            promptAction.showToast({
              message: '教学之路正在开发中。',
              duration: 1800
            });
          })
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

        Button(this.freeDevReady ? '重新初始化身份' : '进入自由开发')
          .width('100%')
          .height(34)
          .fontSize(12)
          .backgroundColor('#45475a')
          .fontColor('#89b4fa')
          .enabled(!this.freeDevBusy)
          .opacity(this.freeDevBusy ? 0.5 : 1)
          .onClick(() => { this.onEnterFreeDev(); })

        if (this.freeDevReady) {
          Text('身份已就位，选择提示词发送给 OpenClaw：')
            .fontSize(11)
            .fontColor('#a6e3a1')
            .margin({ top: 12, bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Button('① 还原：类型下拉菜单')
            .width('100%')
            .height(34)
            .fontSize(12)
            .backgroundColor('#11305a')
            .fontColor('#89b4fa')
            .enabled(!this.freeDevBusy)
            .opacity(this.freeDevBusy ? 0.5 : 1)
            .margin({ bottom: 8 })
            .onClick(() => { this.onSendRestoreType(); })

          Button('② 还原：提醒 + 响铃开关')
            .width('100%')
            .height(34)
            .fontSize(12)
            .backgroundColor('#11305a')
            .fontColor('#89b4fa')
            .enabled(!this.freeDevBusy)
            .opacity(this.freeDevBusy ? 0.5 : 1)
            .onClick(() => { this.onSendRestoreReminder(); })
        }
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
