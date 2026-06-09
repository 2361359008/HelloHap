// 随心自由开发 · 工程列表视图（A 方案）
// 进入「随心自由开发」先到这里：列出已有空白工程副本卡片（点「继续开发」继续），
// 以及一个「＋ 新建空白工程」（输入名字后从只读模板复制出新副本再进入）。
// 模板只读、旧工程全部保留、绝不清空开发记录。
// 返回上一级（多元开发列表）由顶部工具栏统一处理。

import { BlankProjectInfo } from '../model/MultiDevContent';

@Component
export struct BlankProjectsView {
  // 已有工程副本列表
  @Prop blankProjects: BlankProjectInfo[] = [];
  // 列表加载中
  @Prop blankListLoading: boolean = false;
  // 列表加载错误（空=无错）
  @Prop blankListError: string = '';
  // 新建工程名输入
  @Link blankNewName: string;
  // openclaw / 板端是否正在处理（处理中禁用按钮）
  @Prop blankBusy: boolean = false;
  // 刷新列表
  onRefresh: () => void = () => {};
  // 继续开发某个已有工程
  onContinue: (name: string) => void = () => {};
  // 新建一个空白工程
  onCreate: () => void = () => {};

  @Builder
  ProjectCard(project: BlankProjectInfo) {
    Column() {
      Row() {
        Text(project.name)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#a6e3a1')
          .layoutWeight(1)
          .alignSelf(ItemAlign.Start)

        if (project.isCurrent) {
          Text('当前')
            .fontSize(10)
            .fontColor('#a6e3a1')
            .backgroundColor('#1e3e2e')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
        }
      }
      .width('100%')
      .margin({ bottom: 6 })

      Text(project.path)
        .fontSize(11)
        .fontColor('#a6adc8')
        .lineHeight(15)
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Button('继续开发')
        .width('100%')
        .height(34)
        .fontSize(12)
        .backgroundColor('#45475a')
        .fontColor('#a6e3a1')
        .enabled(!this.blankBusy)
        .opacity(this.blankBusy ? 0.5 : 1)
        .onClick(() => { this.onContinue(project.name); })
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
        Text('随心自由开发')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 6, top: 6 })
          .alignSelf(ItemAlign.Start)

        Text('每个空白工程相互独立、永久保留。点「继续开发」回到已有工程，或新建一个全新的空白工程。模板只读，不会被污染。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(16)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        // 新建空白工程
        Column() {
          Text('＋ 新建空白工程')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#89b4fa')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '工程名（字母/数字/-_，留空则用时间戳）', text: this.blankNewName })
            .width('100%')
            .height(36)
            .fontSize(12)
            .backgroundColor('#1e1e2e')
            .fontColor('#cdd6f4')
            .borderRadius(6)
            .margin({ bottom: 10 })
            .enabled(!this.blankBusy)
            .onChange((value: string) => { this.blankNewName = value; })

          Button(this.blankBusy ? '处理中...' : '从模板新建并进入')
            .width('100%')
            .height(36)
            .fontSize(12)
            .backgroundColor('#45475a')
            .fontColor('#89b4fa')
            .borderRadius(6)
            .enabled(!this.blankBusy)
            .opacity(this.blankBusy ? 0.5 : 1)
            .onClick(() => { this.onCreate(); })
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#313244')
        .borderRadius(8)
        .margin({ bottom: 14 })
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text('已有工程')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#cdd6f4')
            .layoutWeight(1)
            .alignSelf(ItemAlign.Start)

          Button('刷新')
            .height(28)
            .fontSize(11)
            .backgroundColor('#45475a')
            .fontColor('#cdd6f4')
            .borderRadius(6)
            .enabled(!this.blankBusy && !this.blankListLoading)
            .opacity((!this.blankBusy && !this.blankListLoading) ? 1 : 0.5)
            .onClick(() => { this.onRefresh(); })
        }
        .width('100%')
        .margin({ bottom: 8 })

        if (this.blankListLoading) {
          Text('正在加载工程列表...')
            .fontSize(12)
            .fontColor('#f9e2af')
            .margin({ top: 4, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else if (this.blankListError.length > 0) {
          Text('加载失败：' + this.blankListError)
            .fontSize(12)
            .fontColor('#f38ba8')
            .margin({ top: 4, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else if (this.blankProjects.length === 0) {
          Text('还没有任何空白工程，点上方「新建空白工程」开始。')
            .fontSize(12)
            .fontColor('#a6adc8')
            .margin({ top: 4, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else {
          ForEach(this.blankProjects, (project: BlankProjectInfo) => {
            this.ProjectCard(project)
          }, (project: BlankProjectInfo) => project.name)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .layoutWeight(1)
  }
}
