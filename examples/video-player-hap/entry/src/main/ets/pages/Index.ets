// 视频播放器 · 自由开发首页
// 一个最小可用的视频播放器：用 ArkUI Video 组件播放网络/本地视频，带播放/暂停/停止与 URL 加载。
// 约定：UI 与逻辑都写在本文件里；尽量只改这一个文件即可在板上看到效果。
// 想扩展：播放列表、进度条拖动、倍速、全屏、本地文件选择、字幕等，都可以从这里和 AI 一起加。

@Entry
@Component
struct Index {
  // 默认示例视频（公共测试片源）。换成你自己的网络地址或本地 rawfile 即可。
  @State videoSrc: string = 'https://media.w3.org/2010/05/sintel/trailer.mp4';
  @State urlInput: string = 'https://media.w3.org/2010/05/sintel/trailer.mp4';
  @State isPlaying: boolean = false;
  @State statusText: string = '准备就绪';
  @State currentTime: number = 0;
  @State durationTime: number = 0;

  private controller: VideoController = new VideoController();

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
        .autoPlay(false)
        .controls(true)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#000000')
        .onStart(() => {
          this.isPlaying = true;
          this.statusText = '播放中';
        })
        .onPause(() => {
          this.isPlaying = false;
          this.statusText = '已暂停';
        })
        .onFinish(() => {
          this.isPlaying = false;
          this.statusText = '播放结束';
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
