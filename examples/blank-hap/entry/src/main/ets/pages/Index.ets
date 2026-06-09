// 随心自由开发 · 空白工程首页
// 这是一个完全空白的起点：只有一行欢迎语。请从这里开始，和 AI 助手一起把你想要的应用搭出来。
// 约定：UI 与逻辑都写在本文件里；尽量只改这一个文件即可在板上看到效果。

@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('随心自由开发')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1677FF')
        .margin({ bottom: 12 })

      Text('这是一个完全空白的 HAP 工程，从这里开始自由发挥。')
        .fontSize(14)
        .fontColor('#666666')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F7F9FC')
  }
}
