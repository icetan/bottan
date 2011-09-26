var reCache = {}
,match = 
exports.match = function (str, handlers, res, fn) {
  if (typeof res === 'function') {
    fn = res;
    res = reCache; 
  }
  for (var i in handlers) {
    if (!res[i]) res[i] = new RegExp(i, 'i');
    var m = res[i].exec(str);
    if (m) {
      fn(handlers[i], m.splice(1));
    }
  }
}
