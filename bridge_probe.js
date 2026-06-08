// 临时排查脚本：直接打板端 shell-bridge 的 /read-file 与 /list-files，打印状态码与返回长度。
// 用法：node bridge_probe.js
var http = require('http');

function hit(path, label, cb) {
  var url = 'http://127.0.0.1:7681' + path;
  http.get(url, function (r) {
    var d = '';
    r.on('data', function (c) { d += c; });
    r.on('end', function () {
      console.log('=== ' + label + ' ===');
      console.log('URL    : ' + url);
      console.log('STATUS : ' + r.statusCode);
      console.log('LENGTH : ' + d.length);
      console.log('HEAD   : ' + JSON.stringify(d.slice(0, 160)));
      console.log('');
      if (cb) cb();
    });
  }).on('error', function (e) {
    console.log('=== ' + label + ' (ERROR) ===');
    console.log('URL  : ' + url);
    console.log('ERR  : ' + e.message);
    console.log('');
    if (cb) cb();
  });
}

var root = '/data/local/tmp/advanced-hapbuild/project';
var idx = root + '/entry/src/main/ets/pages/Index.ets';

hit('/list-files?path=' + encodeURIComponent(root), 'list-files (advanced root)', function () {
  hit('/read-file?path=' + encodeURIComponent(idx), 'read-file (advanced Index.ets)', function () {
    hit('/read-file?path=' + encodeURIComponent('/data/local/tmp/oh61-hapbuild/project/entry/src/main/ets/pages/Index.ets'), 'read-file (basic Index.ets for comparison)', null);
  });
});
