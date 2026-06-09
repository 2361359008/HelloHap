@Entry
@Component
struct Index {
  @State grid: number[][] = []
  @State revealed: boolean[][] = []
  @State flags: boolean[][] = []
  @State status: number = 0
  @State flagCount: number = 0
  @State elapsed: number = 0
  @State face: string = '😊'

  private timerId: number = 0
  private readonly ROWS: number = 10
  private readonly COLS: number = 10
  private readonly MINES: number = 15

  aboutToAppear(): void {
    this.resetGame()
  }

  private resetGame(): void {
    if (this.timerId > 0) {
      clearInterval(this.timerId)
      this.timerId = 0
    }
    let g: number[][] = []
    let r: boolean[][] = []
    let f: boolean[][] = []
    for (let i = 0; i < this.ROWS; i++) {
      let grow: number[] = []
      let rrow: boolean[] = []
      let frow: boolean[] = []
      for (let j = 0; j < this.COLS; j++) {
        grow.push(0)
        rrow.push(false)
        frow.push(false)
      }
      g.push(grow)
      r.push(rrow)
      f.push(frow)
    }
    this.grid = g
    this.revealed = r
    this.flags = f
    this.status = 0
    this.flagCount = 0
    this.elapsed = 0
    this.face = '😊'
  }

  private plantMines(sr: number, sc: number): void {
    let placed: number = 0
    let tries: number = 0
    while (placed < this.MINES && tries < 1000) {
      tries++
      let r: number = Math.floor(Math.random() * this.ROWS)
      let c: number = Math.floor(Math.random() * this.COLS)
      if (Math.abs(r - sr) <= 1 && Math.abs(c - sc) <= 1) continue
      if (this.grid[r][c] === 9) continue
      this.grid[r][c] = 9
      placed++
    }
    for (let r: number = 0; r < this.ROWS; r++) {
      for (let c: number = 0; c < this.COLS; c++) {
        if (this.grid[r][c] === 9) continue
        let n: number = 0
        for (let dr: number = -1; dr <= 1; dr++) {
          for (let dc: number = -1; dc <= 1; dc++) {
            let nr: number = r + dr
            let nc: number = c + dc
            if (nr >= 0 && nr < this.ROWS && nc >= 0 && nc < this.COLS && this.grid[nr][nc] === 9) {
              n++
            }
          }
        }
        this.grid[r][c] = n
      }
    }
    this.grid = [...this.grid]
  }

  private doFlood(sr: number, sc: number): void {
    let stack: number[] = [sr * this.COLS + sc]
    while (stack.length > 0) {
      let idx: number = stack.pop() as number
      let r: number = Math.floor(idx / this.COLS)
      let c: number = idx % this.COLS
      if (r < 0 || r >= this.ROWS || c < 0 || c >= this.COLS) continue
      if (this.revealed[r][c] || this.flags[r][c]) continue
      this.revealed[r][c] = true
      if (this.grid[r][c] === 0) {
        for (let dr: number = -1; dr <= 1; dr++) {
          for (let dc: number = -1; dc <= 1; dc++) {
            if (dr === 0 && dc === 0) continue
            stack.push((r + dr) * this.COLS + (c + dc))
          }
        }
      }
    }
  }

  private showMines(cr: number, cc: number): void {
    for (let r: number = 0; r < this.ROWS; r++) {
      for (let c: number = 0; c < this.COLS; c++) {
        if (this.grid[r][c] === 9) {
          this.revealed[r][c] = true
        }
      }
    }
    this.revealed[cr][cc] = true
    this.revealed = [...this.revealed]
  }

  private checkWin(): boolean {
    let cnt: number = 0
    for (let r: number = 0; r < this.ROWS; r++) {
      for (let c: number = 0; c < this.COLS; c++) {
        if (this.revealed[r][c]) cnt++
      }
    }
    return cnt === this.ROWS * this.COLS - this.MINES
  }

  private onTap(r: number, c: number): void {
    if (this.status !== 0) return
    if (this.revealed[r][c] || this.flags[r][c]) return

    if (this.timerId === 0) {
      this.plantMines(r, c)
      this.timerId = setInterval(() => {
        this.elapsed++
      }, 1000)
    }

    if (this.grid[r][c] === 9) {
      this.status = 2
      this.face = '😵'
      if (this.timerId > 0) {
        clearInterval(this.timerId)
        this.timerId = 0
      }
      this.showMines(r, c)
      return
    }

    this.doFlood(r, c)
    this.revealed = [...this.revealed]

    if (this.checkWin()) {
      this.status = 1
      this.face = '😎'
      if (this.timerId > 0) {
        clearInterval(this.timerId)
        this.timerId = 0
      }
    }
  }

  private onFlag(r: number, c: number): void {
    if (this.status !== 0) return
    if (this.revealed[r][c]) return

    this.flags[r][c] = !this.flags[r][c]
    if (this.flags[r][c]) {
      this.flagCount++
    } else {
      this.flagCount--
    }
    this.flags = [...this.flags]
  }

  private numColor(n: number): string {
    if (n === 1) return '#1976D2'
    if (n === 2) return '#388E3C'
    if (n === 3) return '#D32F2F'
    if (n === 4) return '#7B1FA2'
    if (n === 5) return '#FF6F00'
    if (n === 6) return '#00897B'
    if (n === 7) return '#37474F'
    if (n === 8) return '#616161'
    return '#161616'
  }

  private cellBg(r: number, c: number): string {
    let v: number = this.grid[r][c]
    let rev: boolean = this.revealed[r][c]
    let flg: boolean = this.flags[r][c]
    if (!rev && !flg) return '#D8DADD'
    if (flg) return '#FFE0B2'
    if (rev && v === 9 && this.status === 2) return '#FF5252'
    if (rev && v === 9) return '#F5F5F5'
    if (rev) return '#F5F5F5'
    return '#D8DADD'
  }

  private cellText(r: number, c: number): string {
    let v: number = this.grid[r][c]
    let rev: boolean = this.revealed[r][c]
    let flg: boolean = this.flags[r][c]
    if (flg && !rev) return '🚩'
    if (!rev) return ''
    if (v === 9) return '💣'
    if (v > 0) return '' + v
    return ''
  }

  private cellFg(r: number, c: number): string {
    let v: number = this.grid[r][c]
    if (v > 0 && v <= 8) return this.numColor(v)
    return '#161616'
  }

  build() {
    Stack() {
      Column() {
        Text('💣 扫雷')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#161616')
          .margin({ top: 32, bottom: 16 })

        Row() {
          Text('💣 ' + (this.MINES - this.flagCount))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#161616')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Text(this.face)
            .fontSize(32)
            .onClick(() => {
              this.resetGame()
            })

          Text('⏱ ' + this.elapsed)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#161616')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(56)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .margin({ left: 20, right: 20, bottom: 16 })

        Column() {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (r: number) => {
            Row() {
              ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (c: number) => {
                Text(this.cellText(r, c))
                  .width(34)
                  .height(34)
                  .fontSize(this.cellText(r, c).length > 1 ? 14 : 16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.cellFg(r, c))
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.cellBg(r, c))
                  .borderRadius(4)
                  .margin(1)
                  .onClick(() => {
                    this.onTap(r, c)
                  })
                  .gesture(
                    LongPressGesture()
                      .onAction(() => {
                        this.onFlag(r, c)
                      })
                  )
              }, (c: number) => 'c' + c.toString())
            }
          }, (r: number) => 'r' + r.toString())
        }
        .padding(3)
        .backgroundColor('#C8CACD')
        .borderRadius(12)
        .margin({ left: 20, right: 20 })

        Text('点击揭开 · 长按插旗')
          .fontSize(13)
          .fontColor('#92969D')
          .margin({ top: 16 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F1F2F4')

      if (this.status !== 0) {
        Column() {
          Text(this.status === 1 ? '🎉 胜利！' : '💥 踩雷了！')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Text(this.status === 1
            ? '用时 ' + this.elapsed.toString() + ' 秒'
            : '坚持了 ' + this.elapsed.toString() + ' 秒')
            .fontSize(16)
            .fontColor('#E0E0E0')
            .margin({ top: 8 })

          Text('重新开始')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#1677FF')
            .borderRadius(12)
            .padding({ left: 32, right: 32, top: 12, bottom: 12 })
            .margin({ top: 24 })
            .onClick(() => {
              this.resetGame()
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
