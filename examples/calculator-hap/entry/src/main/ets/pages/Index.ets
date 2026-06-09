@Entry
@Component
struct Index {
  @State display: string = '0'
  @State expression: string = ''
  @State pendingOperator: string = ''
  @State accumulator: number = 0
  @State waitingForOperand: boolean = false
  @State error: boolean = false
  @State lastOperator: string = ''
  @State lastOperand: number = 0
  @State compactMode: boolean = false

  private keySize(): number {
    return this.compactMode ? 48 : 72
  }

  private keyGap(): number {
    return this.compactMode ? 6 : 12
  }

  private keyFontSize(label: string): number {
    if (this.compactMode) {
      return label.length > 1 ? 18 : 22
    }
    return label.length > 1 ? 24 : 30
  }

  private parseDisplay(): number {
    let value: number = Number(this.display)
    return Number.isFinite(value) ? value : 0
  }

  private formatNumber(value: number): string {
    if (!Number.isFinite(value)) {
      return 'Error'
    }
    let rounded: number = Math.round(value * 10000000000) / 10000000000
    let text: string = rounded.toString()
    if (text.length > 14) {
      text = rounded.toExponential(7)
    }
    return text
  }

  private clearAll(): void {
    this.display = '0'
    this.expression = ''
    this.pendingOperator = ''
    this.accumulator = 0
    this.waitingForOperand = false
    this.error = false
    this.lastOperator = ''
    this.lastOperand = 0
  }

  private inputDigit(digit: string): void {
    if (this.error) {
      this.clearAll()
    }
    if (this.waitingForOperand || this.display === '0') {
      this.display = digit
      this.waitingForOperand = false
    } else if (this.display.length < 14) {
      this.display += digit
    }
  }

  private inputDoubleZero(): void {
    if (this.waitingForOperand || this.error) {
      this.inputDigit('0')
      return
    }
    if (this.display !== '0' && this.display.length < 13) {
      this.display += '00'
    }
  }

  private inputDecimal(): void {
    if (this.error) {
      this.clearAll()
    }
    if (this.waitingForOperand) {
      this.display = '0.'
      this.waitingForOperand = false
    } else if (this.display.indexOf('.') < 0 && this.display.length < 14) {
      this.display += '.'
    }
  }

  private backspace(): void {
    if (this.error) {
      this.clearAll()
      return
    }
    if (this.waitingForOperand) {
      return
    }
    if (this.display.length <= 1 ||
      (this.display.length === 2 && this.display.startsWith('-'))) {
      this.display = '0'
    } else {
      this.display = this.display.substring(0, this.display.length - 1)
    }
  }

  private percentage(): void {
    if (this.error) {
      return
    }
    let value: number = this.parseDisplay() / 100
    this.display = this.formatNumber(value)
  }

  private calculate(left: number, right: number, operator: string): number {
    if (operator === '+') {
      return left + right
    }
    if (operator === '−') {
      return left - right
    }
    if (operator === '×') {
      return left * right
    }
    if (operator === '÷') {
      return right === 0 ? Number.NaN : left / right
    }
    return right
  }

  private chooseOperator(operator: string): void {
    if (this.error) {
      return
    }
    let input: number = this.parseDisplay()
    if (this.pendingOperator.length > 0 && !this.waitingForOperand) {
      let result: number = this.calculate(this.accumulator, input, this.pendingOperator)
      this.display = this.formatNumber(result)
      if (this.display === 'Error') {
        this.error = true
        this.expression = 'Cannot divide by zero'
        return
      }
      this.accumulator = result
    } else if (this.pendingOperator.length === 0) {
      this.accumulator = input
    }
    this.pendingOperator = operator
    this.expression = this.formatNumber(this.accumulator) + ' ' + operator
    this.waitingForOperand = true
    this.lastOperator = ''
  }

  private equals(): void {
    if (this.error) {
      return
    }
    let operator: string = this.pendingOperator
    let operand: number = this.parseDisplay()
    if (operator.length === 0 && this.lastOperator.length > 0) {
      operator = this.lastOperator
      operand = this.lastOperand
      this.accumulator = this.parseDisplay()
    }
    if (operator.length === 0) {
      return
    }
    if (this.waitingForOperand) {
      operand = this.accumulator
    }
    let leftText: string = this.formatNumber(this.accumulator)
    let result: number = this.calculate(this.accumulator, operand, operator)
    this.display = this.formatNumber(result)
    if (this.display === 'Error') {
      this.error = true
      this.expression = 'Cannot divide by zero'
      this.pendingOperator = ''
      return
    }
    this.expression = leftText + ' ' + operator + ' ' + this.formatNumber(operand) + ' ='
    this.accumulator = result
    this.lastOperator = operator
    this.lastOperand = operand
    this.pendingOperator = ''
    this.waitingForOperand = true
  }

  @Builder
  private calculatorKey(label: string, background: string, foreground: string, action: () => void) {
    Text(label)
      .width(this.keySize())
      .height(this.keySize())
      .borderRadius(this.keySize() / 2)
      .backgroundColor(background)
      .fontColor(foreground)
      .fontSize(this.keyFontSize(label))
      .fontWeight(FontWeight.Medium)
      .textAlign(TextAlign.Center)
      .shadow({
        radius: this.compactMode ? 4 : 8,
        color: '#22000000',
        offsetX: 0,
        offsetY: this.compactMode ? 1 : 3
      })
      .onClick(action)
  }

  @Builder
  private keyRow(labels: string[], backgrounds: string[], foregrounds: string[]) {
    Row({ space: this.keyGap() }) {
      ForEach(labels, (label: string, index: number) => {
        this.calculatorKey(label, backgrounds[index], foregrounds[index], () => {
          this.handleKey(label)
        })
      }, (label: string) => label)
    }
    .justifyContent(FlexAlign.Center)
  }

  private handleKey(label: string): void {
    if (label >= '0' && label <= '9') {
      this.inputDigit(label)
    } else if (label === '00') {
      this.inputDoubleZero()
    } else if (label === '.') {
      this.inputDecimal()
    } else if (label === 'AC') {
      this.clearAll()
    } else if (label === '⌫') {
      this.backspace()
    } else if (label === '%') {
      this.percentage()
    } else if (label === '=') {
      this.equals()
    } else {
      this.chooseOperator(label)
    }
  }

  build() {
    Column() {
      Row() {
        Text('Calculator')
          .fontSize(this.compactMode ? 15 : 18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#27282B')
        Blank()
        Text('⋮')
          .fontSize(this.compactMode ? 24 : 30)
          .fontColor('#27282B')
      }
      .width('100%')
      .height(this.compactMode ? 38 : 54)
      .padding({
        left: this.compactMode ? 18 : 28,
        right: this.compactMode ? 18 : 28,
        top: this.compactMode ? 6 : 22
      })

      Blank()

      Column() {
        Text(this.expression)
          .width('100%')
          .height(this.compactMode ? 20 : 30)
          .fontSize(this.compactMode ? 14 : 18)
          .fontColor(this.error ? '#D84315' : '#777A80')
          .textAlign(TextAlign.End)
          .maxLines(1)

        Text(this.display)
          .width('100%')
          .height(this.compactMode ? 46 : 78)
          .fontSize(this.compactMode
            ? (this.display.length > 10 ? 30 : 40)
            : (this.display.length > 10 ? 46 : 62))
          .fontWeight(FontWeight.Lighter)
          .fontColor('#17181A')
          .textAlign(TextAlign.End)
          .maxLines(1)
      }
      .width('100%')
      .height(this.compactMode ? 68 : 112)
      .padding({
        left: this.compactMode ? 18 : 28,
        right: this.compactMode ? 18 : 28,
        bottom: this.compactMode ? 2 : 4
      })

      Column({ space: this.keyGap() }) {
        this.keyRow(
          ['AC', '%', '⌫', '÷'],
          ['#F1F2F4', '#F1F2F4', '#F1F2F4', '#E6E8EB'],
          ['#161719', '#161719', '#161719', '#161719']
        )
        this.keyRow(
          ['7', '8', '9', '×'],
          ['#F7F8F9', '#F7F8F9', '#F7F8F9', '#E6E8EB'],
          ['#161719', '#161719', '#161719', '#161719']
        )
        this.keyRow(
          ['4', '5', '6', '−'],
          ['#F7F8F9', '#F7F8F9', '#F7F8F9', '#E6E8EB'],
          ['#161719', '#161719', '#161719', '#161719']
        )
        this.keyRow(
          ['1', '2', '3', '+'],
          ['#F7F8F9', '#F7F8F9', '#F7F8F9', '#E6E8EB'],
          ['#161719', '#161719', '#161719', '#161719']
        )
        this.keyRow(
          ['00', '0', '.', '='],
          ['#F7F8F9', '#F7F8F9', '#F7F8F9', '#FF8A22'],
          ['#161719', '#161719', '#161719', '#FFFFFF']
        )
      }
      .width('100%')
      .padding({ bottom: this.compactMode ? 6 : 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ECEDEF')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      let height: number = Number(newArea.height)
      this.compactMode = height > 0 && height < 600
    })
  }
}
