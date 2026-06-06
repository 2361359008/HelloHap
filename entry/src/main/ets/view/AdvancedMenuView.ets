// 高级版菜单视图
// 从 pages/Index.ets 抽取：高级版左侧的"教学之路 / 自由开发"两个入口卡片。
// 具体功能暂未开发，点击仅提示。

import { promptAction } from '@kit.ArkUI';

@Component
export struct AdvancedMenuView {
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

        Text('进入开放式开发空间，自主规划和实现 HAP 项目。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .margin({ bottom: 12 })

        Button('进入自由开发')
          .width('100%')
          .height(34)
          .fontSize(12)
          .backgroundColor('#45475a')
          .fontColor('#89b4fa')
          .onClick(() => {
            promptAction.showToast({
              message: '自由开发正在开发中。',
              duration: 1800
            });
          })
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
