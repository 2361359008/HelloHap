const fs = require('fs');

const path = 'D:/DevEcoProjects/HelloHap/entry/src/main/ets/pages/Index.ets';
const lines = fs.readFileSync(path, 'utf8').split(/\r?\n/);

lines[1468] = "                      Text('开发任务完成')";
lines[1477] = "                          Text('第' + this.selectedTaskIndex + '关：已学习内容与核心要点')";
lines[1501] = "                        Text('提示：本关已学习完成，可以使用下方输入框继续向 OpenClaw 提问。')";
lines[1515] = "                        Button('返回上一关复习')";
lines[1528] = "                        Button('第一关已学习，进入第二关')";
lines[1542] = "                        Button('第二关已学习，进入第三关')";
lines[1556] = "                        Button('全部关卡已学习，返回选择关卡')";
lines[1587] = "                    placeholder: this.studentQuestionEnabled ? (this.openClawBusy ? 'OpenClaw 正在处理，请等待回复完成...' : '在此提问，例如：什么是 HAP 签名？') : '请先点击“呼叫 OpenClaw 协同开发”并等待任务完成...',";

fs.writeFileSync(path, lines.join('\n'), 'utf8');
