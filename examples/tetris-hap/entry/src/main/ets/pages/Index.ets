@Entry
@Component
struct Index {
  private readonly W: number = 10
  private readonly H: number = 20
  private readonly PIECES: number[][][][] = [
    [[[0,1],[0,2],[0,3],[0,4]],[[1,0],[2,0],[3,0],[4,0]]],
    [[[0,0],[0,1],[1,0],[1,1]]],
    [[[0,0],[1,0],[1,1],[1,2]],[[0,0],[1,0],[2,0],[2,-1]],[[0,0],[0,1],[0,2],[1,2]],[[0,1],[1,1],[2,1],[2,0]]],
    [[[0,0],[1,0],[2,0],[2,1]],[[0,0],[0,1],[0,2],[1,0]],[[0,0],[0,1],[1,1],[2,1]],[[0,2],[1,0],[1,1],[1,2]]],
    [[[0,1],[0,2],[1,0],[1,1]],[[0,0],[1,0],[1,1],[2,1]]],
    [[[0,0],[0,1],[1,1],[1,2]],[[0,1],[1,0],[1,1],[2,0]]],
    [[[0,0],[0,1],[1,0],[2,0]],[[0,0],[1,0],[1,1],[1,2]],[[0,1],[1,1],[2,0],[2,1]],[[0,0],[0,1],[0,2],[1,2]]]
  ]
  private readonly COLORS: string[] = ['', '#00E5FF', '#FFEB3B', '#AA00FF', '#00E676', '#FF1744', '#2979FF', '#FF9100']

  @State board: number[] = []
  @State piece: number[][] = []
  @State px: number = 0
  @State py: number = 0
  @State pType: number = 0
  @State pRot: number = 0
  @State score: number = 0
  @State level: number = 1
  @State lines: number = 0
  @State status: number = 0
  @State nextType: number = 0
  @State preview: number[] = []

  private timerId: number = -1
  private rotId: number = -1
  private dropId: number = -1

  aboutToAppear(): void { this.newGame() }
  aboutToDisappear(): void { this.killTimers() }

  private killTimers(): void {
    if (this.timerId > 0) { clearInterval(this.timerId); this.timerId = -1 }
    if (this.rotId > 0) { clearInterval(this.rotId); this.rotId = -1 }
    if (this.dropId > 0) { clearInterval(this.dropId); this.dropId = -1 }
  }

  private rot(p: number[][]): number[][] {
    let r: number[][] = []
    for (let i = 0; i < p.length; i++) r.push([-p[i][1], p[i][0]])
    return r
  }

  private hit(p: number[][], x: number, y: number): boolean {
    for (let i = 0; i < p.length; i++) {
      let bx = x + p[i][1], by = y + p[i][0]
      if (bx < 0 || bx >= this.W || by >= this.H) return true
      if (by >= 0 && this.board[by * this.W + bx] !== 0) return true
    }
    return false
  }

  private spawn(): void {
    this.pType = this.nextType
    this.pRot = 0
    this.piece = this.PIECES[this.pType][0]
    this.px = 3; this.py = -1
    if (this.hit(this.piece, this.px, this.py)) {
      this.status = 2; this.killTimers()
    }
    this.nextType = Math.floor(Math.random() * 7)
    this.showPreview()
  }

  private showPreview(): void {
    let p = this.PIECES[this.nextType][0]
    let g: number[] = []
    for (let i = 0; i < 16; i++) g.push(0)
    for (let i = 0; i < p.length; i++) {
      let pr = p[i][0], pc = p[i][1]
      if (pr >= 0 && pr < 4 && pc >= 0 && pc < 4) g[pr * 4 + pc] = this.nextType + 1
    }
    this.preview = g
  }

  private lock(): void {
    for (let i = 0; i < this.piece.length; i++) {
      let bx = this.px + this.piece[i][1], by = this.py + this.piece[i][0]
      if (by >= 0 && by < this.H) this.board[by * this.W + bx] = this.pType + 1
    }
    this.board = [...this.board]
    let cleared = 0
    let nb: number[][] = []
    for (let r = 0; r < this.H; r++) {
      let full = true
      for (let c = 0; c < this.W; c++) if (this.board[r * this.W + c] === 0) { full = false; break }
      if (!full) { let row: number[] = []; for (let c = 0; c < this.W; c++) row.push(this.board[r * this.W + c]); nb.push(row) }
      else cleared++
    }
    for (let i = 0; i < cleared; i++) { let row: number[] = []; for (let j = 0; j < this.W; j++) row.push(0); nb.unshift(row) }
    if (cleared > 0) {
      this.board = []; for (let r = 0; r < this.H; r++) for (let c = 0; c < this.W; c++) this.board.push(nb[r][c])
      this.board = [...this.board]
      this.lines += cleared
      this.score += [0, 100, 300, 500, 800][cleared] * this.level
      let nl = Math.floor(this.lines / 10) + 1
      if (nl > this.level) { this.level = nl; this.startLoop() }
    }
    this.spawn()
  }

  private startLoop(): void {
    if (this.timerId > 0) clearInterval(this.timerId)
    this.timerId = setInterval(() => this.tick(), Math.max(100, 500 - (this.level - 1) * 50))
  }

  private tick(): void {
    if (this.status !== 0) return
    if (!this.hit(this.piece, this.px, this.py + 1)) { this.py++; this.piece = [...this.piece] }
    else this.lock()
  }

  private moveL(): void { if (this.status === 0 && !this.hit(this.piece, this.px - 1, this.py)) { this.px--; this.piece = [...this.piece] } }
  private moveR(): void { if (this.status === 0 && !this.hit(this.piece, this.px + 1, this.py)) { this.px++; this.piece = [...this.piece] } }
  private softDrop(): void { if (this.status === 0 && !this.hit(this.piece, this.px, this.py + 1)) { this.py++; this.score++; this.piece = [...this.piece] } }

  private doRotate(): void {
    if (this.status !== 0) return
    let nr = (this.pRot + 1) % this.PIECES[this.pType].length
    let np = this.PIECES[this.pType][nr]
    if (!this.hit(np, this.px, this.py)) { this.piece = np; this.pRot = nr }
    else if (!this.hit(np, this.px + 1, this.py)) { this.px++; this.piece = np; this.pRot = nr }
    else if (!this.hit(np, this.px - 1, this.py)) { this.px--; this.piece = np; this.pRot = nr }
  }

  private hardDrop(): void {
    if (this.status !== 0) return
    while (!this.hit(this.piece, this.px, this.py + 1)) { this.py++; this.score += 2 }
    this.lock(); this.piece = [...this.piece]
  }

  private startRotate(): void { this.doRotate(); if (this.rotId > 0) clearInterval(this.rotId); this.rotId = setInterval(() => this.doRotate(), 180) }
  private stopRotate(): void { if (this.rotId > 0) { clearInterval(this.rotId); this.rotId = -1 } }
  private startDrop(): void { this.softDrop(); if (this.dropId > 0) clearInterval(this.dropId); this.dropId = setInterval(() => this.softDrop(), 60) }
  private stopDrop(): void { if (this.dropId > 0) { clearInterval(this.dropId); this.dropId = -1 } }

  private cellColor(r: number, c: number): string {
    let idx = r * this.W + c
    for (let i = 0; i < this.piece.length; i++) {
      if (this.py + this.piece[i][0] === r && this.px + this.piece[i][1] === c) return this.COLORS[this.pType + 1]
    }
    let v = this.board[idx]
    return v > 0 ? this.COLORS[v] : '#1A1A1A'
  }

  private newGame(): void {
    this.killTimers()
    this.board = []; for (let i = 0; i < this.W * this.H; i++) this.board.push(0)
    this.score = 0; this.level = 1; this.lines = 0; this.status = 0
    this.nextType = Math.floor(Math.random() * 7)
    this.spawn(); this.startLoop()
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('🧱 俄罗斯方块').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Blank()
          Text('Lv.' + this.level).fontSize(15).fontColor('#888')
        }.width('100%').padding({ left: 16, right: 16, top: 32, bottom: 8 })

        Row() {
          Column() {
            Text('SCORE').fontSize(10).fontColor('#666')
            Text('' + this.score).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFF')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Column() {
            Text('NEXT').fontSize(10).fontColor('#666').margin({ bottom: 2 })
            Row() {
              ForEach([0, 1, 2, 3], (pr: number) => {
                Column() {
                  ForEach([0, 1, 2, 3], (pc: number) => {
                    Text('').width(10).height(10).borderRadius(1).margin(0.5)
                      .backgroundColor(this.preview[pr * 4 + pc] > 0 ? this.COLORS[this.preview[pr * 4 + pc]] : '#111')
                  }, (pc: number) => 'p' + pc)
                }
              }, (pr: number) => 'r' + pr)
            }
          }.alignItems(HorizontalAlign.Center)
          Column() {
            Text('LINES').fontSize(10).fontColor('#666')
            Text('' + this.lines).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFF')
          }.layoutWeight(1).alignItems(HorizontalAlign.End)
        }.width('100%').padding({ left: 16, right: 16, bottom: 8 })

        Column() {
          ForEach([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19], (r: number) => {
            Row() {
              ForEach([0,1,2,3,4,5,6,7,8,9], (c: number) => {
                Text('').width(14).height(14).borderRadius(2).margin(0.5).backgroundColor(this.cellColor(r, c))
              }, (c: number) => 'c' + c)
            }
          }, (r: number) => 'r' + r)
        }.padding(3).backgroundColor('#333').borderRadius(6)

        Blank()

        Row() {
          Text('◀').fontSize(22).fontColor('#FFF').width(60).height(44).textAlign(TextAlign.Center)
            .backgroundColor('#333').borderRadius(10).onClick(() => this.moveL())
          Blank()
          Text('↻').fontSize(22).fontColor('#FFF').width(60).height(44).textAlign(TextAlign.Center)
            .backgroundColor('#333').borderRadius(10)
            .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) this.startRotate(); else this.stopRotate() })
          Blank()
          Text('▼').fontSize(22).fontColor('#FFF').width(60).height(44).textAlign(TextAlign.Center)
            .backgroundColor('#333').borderRadius(10)
            .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) this.startDrop(); else this.stopDrop() })
          Blank()
          Text('▶').fontSize(22).fontColor('#FFF').width(60).height(44).textAlign(TextAlign.Center)
            .backgroundColor('#333').borderRadius(10).onClick(() => this.moveR())
          Blank()
          Text('⏬').fontSize(16).fontColor('#FFF').width(60).height(44).textAlign(TextAlign.Center)
            .backgroundColor('#E53935').borderRadius(10).onClick(() => this.hardDrop())
        }.width('100%').padding({ left: 12, right: 12, bottom: 24 })
      }.width('100%').height('100%').backgroundColor('#0D0D0D')

      if (this.status === 2) {
        Column() {
          Text('💥 Game Over').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#FFF')
          Text('得分: ' + this.score).fontSize(18).fontColor('#CCC').margin({ top: 8 })
          Text('重新开始').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFF')
            .backgroundColor('#1677FF').borderRadius(12).padding({ left: 32, right: 32, top: 12, bottom: 12 }).margin({ top: 24 })
            .onClick(() => this.newGame())
        }.width('100%').height('100%').backgroundColor('#CC000000').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
