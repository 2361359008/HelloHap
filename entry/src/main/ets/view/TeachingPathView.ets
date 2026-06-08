// 教学之路视图
// 高级版「教学之路」开发流程：日志项目初始化与后续流程解读。
// 应用内分步讲解卡片 + 一个「让 OpenClaw 详解」按钮（点击后由父组件调用 openclaw）。
// 首步先以已经设计好的日志 HAP 为入口，按流程介绍后续开发步骤。

@Component
export struct TeachingPathView {
  // 返回高级版菜单
  onBack: () => void = () => {};
  // 让 OpenClaw 详解开发流程
  onExplainWithOpenClaw: () => void = () => {};
  // 重新初始化讲师身份
  onReinitIdentity: () => void = () => {};
  // 讲师身份是否已初始化（决定详解按钮是否可点）
  @Prop teachingReady: boolean = false;
  // openclaw 是否正在处理（处理中禁用按钮）
  @Prop teachingBusy: boolean = false;

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

          Text('教学之路')
            .fontSize(13)
            .fontColor('#6c7086')
            .margin({ left: 10 })
        }
        .width('100%')
        .margin({ top: 6, bottom: 12 })
        .justifyContent(FlexAlign.Start)

        Text('开发流程：日志 HAP 教学导览')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('本流程目标：从已经完成视觉设计的日志 HAP 开始，按开发顺序理解工程初始化、页面搭建、日志数据、交互与构建部署。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(18)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        this.InfoCard('① 初始化日志项目',
          '欢迎来到日志 HAP 的开发教学流程。你可以看到目前日志 HAP 已经设计好的样子，接下来我将深度介绍该 HAP 的开发流程。第一步先建立工程视角：它由 AppScope、entry、resources、signing 与构建脚本共同组成。')

        this.InfoCard('② 应用身份与资源',
          'AppScope/app.json5：bundleName（包名）、versionCode、versionName、label（应用名引用）。\nAppScope/resources/base/element/string.json：app_name（应用显示名）。这一步确定日志 HAP 的应用身份、名称与基础资源。')

        this.InfoCard('③ 模块入口配置',
          'entry/src/main/module.json5：配置 abilities（应用能力入口）与 requestPermissions（申请的系统权限）。日志 HAP 的页面启动入口、路由能力和必要权限都从这里开始对齐。')

        this.InfoCard('④ 页面结构搭建',
          'entryability/EntryAbility.ets：应用入口 Ability（一般不动）。\npages/Index.ets：日志 HAP 的主页面，负责展示列表、输入区、状态提示等核心 UI。\nresources/base/profile/main_pages.json：路由页面清单，新增页面要在这里登记。')

        this.InfoCard('⑤ 日志功能实现',
          '围绕日志条目的新增、展示、筛选和状态反馈梳理 ArkTS 状态变量、事件处理与组件布局。这里开始从"看见设计好的样子"过渡到"理解它是怎么被写出来的"。')

        this.InfoCard('⑥ 构建签名与部署',
          'signing/、build-profile.json5、hvigor 脚手架和安装启动脚本负责把日志 HAP 打包成可运行应用。后续流程会继续讲清楚编译、签名、安装和启动的边界。')

        if (this.teachingReady) {
          Text('讲师身份已就位，可点击下方让 OpenClaw 按流程讲解日志 HAP。')
            .fontSize(11)
            .fontColor('#a6e3a1')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        } else {
          Text(this.teachingBusy ? '正在初始化讲师身份...' : '讲师身份未就位，请重新初始化后再讲解。')
            .fontSize(11)
            .fontColor('#f9e2af')
            .margin({ top: 2, bottom: 8 })
            .alignSelf(ItemAlign.Start)
        }

        Button(this.teachingBusy ? 'OpenClaw 正在处理...' : '让 OpenClaw 详解开发流程')
          .width('100%')
          .height(36)
          .fontSize(12)
          .backgroundColor('#11305a')
          .fontColor('#89b4fa')
          .enabled(this.teachingReady && !this.teachingBusy)
          .opacity((this.teachingReady && !this.teachingBusy) ? 1 : 0.5)
          .margin({ top: 2, bottom: 8 })
          .onClick(() => { this.onExplainWithOpenClaw(); })

        if (!this.teachingReady) {
          Button('重新初始化讲师身份')
            .width('100%')
            .height(34)
            .fontSize(12)
            .backgroundColor('#45475a')
            .fontColor('#cdd6f4')
            .enabled(!this.teachingBusy)
            .opacity(this.teachingBusy ? 0.5 : 1)
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
