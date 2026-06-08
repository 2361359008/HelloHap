// 教学之路视图
// 高级版「教学之路」第一关：日程项目文件准备解读。
// 应用内分步讲解卡片 + 一个「让 OpenClaw 详解」按钮（点击后由父组件调用 openclaw）。
// 本关只讲创建日程 HAP 需要准备哪些文件及其作用，不涉及页面组件的设计代码。

@Component
export struct TeachingPathView {
  // 返回高级版菜单
  onBack: () => void = () => {};
  // 让 OpenClaw 详解文件准备
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

        Text('第一关：日程项目文件准备解读')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#cdd6f4')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('本关目标：看懂创建一个日程 HAP 需要准备哪些文件、各自作用。先不涉及日程页面里组件的设计代码。')
          .fontSize(12)
          .fontColor('#a6adc8')
          .lineHeight(18)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        this.InfoCard('① 工程结构总览',
          '一个 HAP 工程的标准目录：AppScope（应用级身份与资源）、entry（唯一的 HAP 模块，放页面与逻辑）、signing（签名材料）、构建脚本与脚手架。先建立"一个工程通常只有一个 entry 模块"的整体印象。')

        this.InfoCard('② 应用身份',
          'AppScope/app.json5：bundleName（包名）、versionCode、versionName、label（图标名）。\nAppScope/resources/base/element/string.json：app_name（应用显示名，被 app.json5 的 label 引用）。这两处决定"这个应用是谁、叫什么"。')

        this.InfoCard('③ 模块与权限',
          'entry/src/main/module.json5：配置 abilities（应用能力入口）与 requestPermissions（申请的系统权限，例如要联网就在这里加网络权限）。')

        this.InfoCard('④ 入口与页面',
          'entryability/EntryAbility.ets：应用入口 Ability（一般不动）。\npages/Index.ets：首页页面（后续关卡才在这里写日程界面）。\nresources/base/profile/main_pages.json：路由页面清单，新增页面要在这里登记。\nresources/base/element/string.json：模块字符串（module_desc / EntryAbility_desc / EntryAbility_label）。')

        this.InfoCard('⑤ 签名材料与构建脚本',
          'signing/：p12 / pem / profile 等签名材料，用于把 HAP 打包成可安装包（注意别提交真实密钥）。\n工程级 build-profile.json5 与 hvigor 脚手架负责构建流程，一般不动。')

        this.InfoCard('⑥ 哪些文件不要随意改',
          'build-profile.json5、hvigor*、oh-package.json5、package.json、signing/ 内容、EntryAbility.ets——改这些容易破坏编译/签名。除非明确需要，否则别碰。')

        if (this.teachingReady) {
          Text('讲师身份已就位，可点击下方让 OpenClaw 讲解文件准备。')
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

        Button(this.teachingBusy ? 'OpenClaw 正在处理...' : '让 OpenClaw 详解文件准备')
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
