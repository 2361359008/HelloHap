// 自由开发视图（多元开发各工程通用）
// 高级关卡「多元开发」里某个工程的自由开发工作区：进入后初始化该工程绑定的 openclaw
// 身份，身份就位后既可直接对话，也可点该工程的预设提示词（若有）驱动 OpenClaw 协同开发。
// 结构：标题 + 欢迎语 + 改动边界卡片 + 身份状态 + 预设提示词按钮（数据驱动）。
// 返回上一级（多元开发列表）由顶部工具栏统一处理。

import { MultiDevProject, MultiDevPrompt, getMultiDevProject } from '../model/MultiDevContent';

@Component
export struct FreeDevView {
  // 当前工程 id（决定标题/欢迎语/边界/预设提示词）
  @Prop projectId: string = 'schedule';
  // 重新初始化身份
  onReinitIdentity: () => void = () => {};
  // 点击第 index 个预设提示词
  onSendPreset: (index: number) => void = () => {};
  // 身份是否已初始化（决定提示词按钮是否可点）
  @Prop freeDevReady: boolean = false;
  // openclaw 是否正在处理（处理中禁用按钮）
  @Prop freeDevBusy: boolean = false;

  @Builder
  InfoCard(title: string, body: string, accent: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent)
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
        Text(getMultiDevProject(this.projectId).title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text(getMultiDevProject(this.projectId).welcome)
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(18)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        this.InfoCard('改动边界', getMultiDevProject(this.projectId).boundary,
          getMultiDevProject(this.projectId).accent)

        if (this.freeDevReady) {
          Text('身份已就位，可直接对话；也可点下方提示词发送给 OpenClaw。')
            .fontSize(11)
            .fontColor('#a6e3a1')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else if (this.freeDevBusy) {
          Text('正在初始化开发身份...')
            .fontSize(11)
            .fontColor('#f9e2af')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else {
          Text('开发身份未就位，请重新初始化后再开始。')
            .fontSize(11)
            .fontColor('#f9e2af')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        }

        ForEach(getMultiDevProject(this.projectId).presets, (preset: MultiDevPrompt, index: number) => {
          Button(preset.label)
            .width('100%')
            .height(42)
            .fontSize(13)
            .backgroundColor('#313244')
            .fontColor(preset.accent)
            .borderRadius(8)
            .enabled(this.freeDevReady && !this.freeDevBusy)
            .opacity((this.freeDevReady && !this.freeDevBusy) ? 1 : 0.5)
            .margin({ bottom: 10 })
            .onClick(() => { this.onSendPreset(index); })
        }, (preset: MultiDevPrompt, index: number) => preset.label + index.toString())

        if (!this.freeDevReady) {
          Button(this.freeDevBusy ? 'OpenClaw 正在处理...' : '重新初始化开发身份')
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
