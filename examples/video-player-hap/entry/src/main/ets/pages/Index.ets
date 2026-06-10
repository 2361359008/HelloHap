// 视频播放器 · 自由开发首页
// 一个最小可用的视频播放器：用 ArkUI Video 组件播放网络/本地视频，带播放/暂停/停止与 URL 加载。
// 约定：UI 与逻辑都写在本文件里；尽量只改这一个文件即可在板上看到效果。
// 想扩展：播放列表、进度条拖动、倍速、全屏、本地文件选择、字幕等，都可以从这里和 AI 一起加。

@Entry
@Component
struct Index {
  // 默认播放工程内置视频（entry/src/main/resources/rawfile/ai-mini-pc-fast-intro-typewriter.mp4）。
  // src 同时支持 Resource（内置 rawfile）与 string（http/https 网络地址）。
  @State videoSrc: Resource | string = $rawfile('ai-mini-pc-fast-intro-typewriter.mp4');
  @State urlInput: string = '';
  @State isPlaying: boolean = false;
  @State statusText: string = '启动中，准备自动全屏播放...';
  @State currentTime: number = 0;
  @State durationTime: number = 0;

  private controller: VideoController = new VideoController();
  // 启动自动全屏只做一次：首次开始播放时请求全屏，之后手动播放不再强制全屏。
  private autoFullscreenDone: boolean = false;

  // 秒数格式化为 mm:ss。
  formatTime(seconds: number): string {
    let s: number = Math.floor(seconds);
    let m: number = Math.floor(s / 60);
    let r: number = s % 60;
    let mm: string = m < 10 ? '0' + m.toString() : m.toString();
    let rr: string = r < 10 ? '0' + r.toString() : r.toString();
    return mm + ':' + rr;
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('视频播放器')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#1F2430')
      .alignItems(VerticalAlign.Center)

      // 视频播放区
      Video({
        src: this.videoSrc,
        controller: this.controller
      })
        .width('100%')
        .height(240)
        .autoPlay(true)
        .loop(false)
        .controls(true)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#000000')
        .onStart(() => {
          this.isPlaying = true;
          this.statusText = '播放中';
          // 启动即自动全屏播放一次：首次开始播放时请求全屏，仅触发一次。
          if (!this.autoFullscreenDone) {
            this.autoFullscreenDone = true;
            this.controller.requestFullscreen(true);
          }
        })
        .onPause(() => {
          this.isPlaying = false;
          this.statusText = '已暂停';
        })
        .onFinish(() => {
          this.isPlaying = false;
          this.statusText = '播放结束';
          // 自动播放一次结束后退出全屏，回到普通播放器界面。
          this.controller.exitFullscreen();
        })
        .onPrepared((event) => {
          if (event) {
            this.durationTime = event.duration;
          }
          this.statusText = '已就绪';
        })
        .onUpdate((event) => {
          if (event) {
            this.currentTime = event.time;
          }
        })
        .onError(() => {
          this.isPlaying = false;
          this.statusText = '播放出错（检查网络或视频地址）';
        })

      // 进度时间
      Text(this.formatTime(this.currentTime) + ' / ' + this.formatTime(this.durationTime))
        .fontSize(13)
        .fontColor('#A7B0C0')
        .margin({ top: 10 })

      // 状态
      Text(this.statusText)
        .fontSize(13)
        .fontColor('#FAB387')
        .margin({ top: 4 })

      // 控制按钮
      Row() {
        Button(this.isPlaying ? '暂停' : '播放')
          .width(90)
          .height(40)
          .fontSize(15)
          .backgroundColor('#1677FF')
          .onClick(() => {
            if (this.isPlaying) {
              this.controller.pause();
            } else {
              this.controller.start();
            }
          })

        Button('停止')
          .width(90)
          .height(40)
          .fontSize(15)
          .backgroundColor('#45475A')
          .margin({ left: 16 })
          .onClick(() => {
            this.controller.stop();
            this.isPlaying = false;
            this.currentTime = 0;
            this.statusText = '已停止';
          })

        Button('内置视频')
          .width(96)
          .height(40)
          .fontSize(14)
          .backgroundColor('#FAB387')
          .fontColor('#11151C')
          .margin({ left: 16 })
          .onClick(() => {
            this.videoSrc = $rawfile('ai-mini-pc-fast-intro-typewriter.mp4');
            this.currentTime = 0;
            this.durationTime = 0;
            this.statusText = '已加载内置视频';
          })
      }
      .margin({ top: 16 })

      // URL 加载
      Row() {
        TextInput({ text: this.urlInput, placeholder: '输入视频地址（http/https）' })
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor('#11151C')
          .fontColor('#E6E9EF')
          .placeholderColor('#6C7486')
          .onChange((value: string) => {
            this.urlInput = value;
          })

        Button('加载')
          .width(72)
          .height(40)
          .fontSize(14)
          .backgroundColor('#A6E3A1')
          .fontColor('#11151C')
          .margin({ left: 10 })
          .onClick(() => {
            if (this.urlInput.length === 0) {
              return;
            }
            this.videoSrc = this.urlInput;
            this.currentTime = 0;
            this.durationTime = 0;
            this.statusText = '正在加载新视频...';
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#11151C')
    .alignItems(HorizontalAlign.Center)
  }
}
