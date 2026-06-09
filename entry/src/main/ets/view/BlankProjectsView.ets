// 随心自由开发 · 工程列表视图（A 方案）
// 进入「随心自由开发」先到这里：列出已有空白工程副本卡片（点「继续开发」继续），
// 以及一个「＋ 新建空白工程」按钮：点击直接进新对话，用第一句话描述开发目标，
// 由 AI 校验后自动创建工程副本（不再先输工程名）。
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
  // 删除某个已有工程副本（二次确认后）
  onDelete: (name: string) => void = () => {};
  // 一键清空所有工程副本（强确认后）
  onClearAll: () => void = () => {};

  // 删除单个工程的二次确认弹窗。
  private confirmDelete(name: string): void {
    AlertDialog.show({
      title: '删除工程',
      message: '确定删除工程「' + name + '」吗？\n该工程的代码副本和对话记录都会被删除，且无法恢复。其它工程与模板不受影响。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        fontColor: '#f38ba8',
        value: '删除',
        action: () => { this.onDelete(name); }
      }
    });
  }

  // 一键清空所有工程的强确认弹窗。
  private confirmClearAll(): void {
    AlertDialog.show({
      title: '清空所有随心工程',
      message: '确定清空全部 ' + this.blankProjects.length.toString() + ' 个随心工程吗？\n所有代码副本和对话记录都会被删除，且无法恢复！只读模板不受影响。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        fontColor: '#f38ba8',
        value: '全部清空',
        action: () => { this.onClearAll(); }
      }
    });
  }

  @Builder
  ProjectCard(project: BlankProjectInfo) {
    Column() {
      Row() {
        // 标题优先显示 HAP 名字（AI 起的），其次开发目标（会话首句），最后回退工程名。
        Text(project.label.length > 0 ? project.label : (project.goal.length > 0 ? project.goal : project.name))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#a6e3a1')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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

      // 已有 HAP 名字时，把开发目标作为第二行说明，便于回忆这工程要做什么。
      if (project.label.length > 0 && project.goal.length > 0) {
        Text(project.goal)
          .fontSize(11)
          .fontColor('#cdd6f4')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 2 })
          .alignSelf(ItemAlign.Start)
      }

      // 工程名（blank-时间戳）作为副标题，便于区分不同副本。
      if (project.label.length > 0 || project.goal.length > 0) {
        Text(project.name)
          .fontSize(11)
          .fontColor('#9399b2')
          .margin({ bottom: 2 })
          .alignSelf(ItemAlign.Start)
      }

      Text(project.path)
        .fontSize(11)
        .fontColor('#a6adc8')
        .lineHeight(15)
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Button('继续开发')
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .backgroundColor('#45475a')
          .fontColor('#a6e3a1')
          .enabled(!this.blankBusy)
          .opacity(this.blankBusy ? 0.5 : 1)
          .onClick(() => { this.onContinue(project.name); })

        Button('删除')
          .width(64)
          .height(34)
          .fontSize(12)
          .backgroundColor('#3b2932')
          .fontColor('#f38ba8')
          .margin({ left: 8 })
          .enabled(!this.blankBusy)
          .opacity(this.blankBusy ? 0.5 : 1)
          .onClick(() => { this.confirmDelete(project.name); })
      }
      .width('100%')
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

        // 新建空白工程：直接进新对话，用第一句话描述目标，AI 校验后自动创建。
        Column() {
          Text('＋ 新建空白工程')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#89b4fa')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          Text('点下方按钮直接进入对话，第一句话告诉我你想做的 HAP（例：做一个待办清单 HAP），我会校验后自动创建工程并按目标开发。')
            .fontSize(11)
            .fontColor('#a6adc8')
            .lineHeight(15)
            .margin({ bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Button(this.blankBusy ? '处理中...' : '新建空白工程并描述目标')
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

          if (this.blankProjects.length > 0) {
            Button('清空所有')
              .height(28)
              .fontSize(11)
              .backgroundColor('#3b2932')
              .fontColor('#f38ba8')
              .borderRadius(6)
              .margin({ right: 8 })
              .enabled(!this.blankBusy && !this.blankListLoading)
              .opacity((!this.blankBusy && !this.blankListLoading) ? 1 : 0.5)
              .onClick(() => { this.confirmClearAll(); })
          }

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
