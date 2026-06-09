// 多元开发菜单视图
// 高级关卡「多元开发」入口的子页：列出多个可自由开发的 HAP 工程卡片，
// 点击任一卡片进入对应工程的「自由开发」工作区。

import { MultiDevProject, MULTIDEV_PROJECTS } from '../model/MultiDevContent';

@Component
export struct MultiDevMenuView {
  // 点击某个工程卡片：进入该工程的自由开发工作区
  onSelectProject: (id: string) => void = () => {};
  // openclaw 是否正在处理（处理中禁用入口按钮）
  @Prop multiDevBusy: boolean = false;

  @Builder
  ProjectCard(project: MultiDevProject) {
    Column() {
      Text(project.title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(project.accent)
        .margin({ bottom: 6 })
        .alignSelf(ItemAlign.Start)

      Text(project.subtitle)
        .fontSize(12)
        .fontColor('#a6adc8')
        .lineHeight(16)
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Button('进入' + project.title)
        .width('100%')
        .height(34)
        .fontSize(12)
        .backgroundColor('#45475a')
        .fontColor(project.accent)
        .enabled(!this.multiDevBusy)
        .opacity(this.multiDevBusy ? 0.5 : 1)
        .onClick(() => { this.onSelectProject(project.id); })
    }
    .width('48%')
    .padding(14)
    .backgroundColor('#313244')
    .borderRadius(8)
    .margin({ bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column() {
        Text('多元开发')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 6, top: 6 })
          .alignSelf(ItemAlign.Start)

        Text('选择一个 HAP 工程，进入后加载该工程的初始模板并装到板上，然后和 AI 助手一起自由开发。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(16)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(MULTIDEV_PROJECTS, (project: MultiDevProject) => {
            this.ProjectCard(project)
          }, (project: MultiDevProject) => project.id)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .layoutWeight(1)
  }
}
