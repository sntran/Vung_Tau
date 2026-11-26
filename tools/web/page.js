// Plan 0031, D11: the times of the parts of the start of the web build.
// tools/web/deploy.sh puts this script in index.html before the script of
// Godot. It marks (performance.now(), ms) the compile of the WebAssembly, and
// the game marks the start of the engine, the first frame, and the moment
// when the player can move (window.vungTau.mark(NAME)). The end of the download
// of the pack and of the WebAssembly comes from the timing of the resources.
// window.vungTau.times() gives the line of the game (scripts/web/load_times.gd);
// window.vungTau.marks gives the parts (tools/web/check.js writes them).
(function () {
  var vt = window.vungTau = window.vungTau || {};
  vt.marks = vt.marks || {};
  var memories = [];

  // The end of the download of the pack and the WebAssembly (the latest of the two).
  function downloadEnd() {
    var end = -1;
    performance.getEntriesByType('resource').forEach(function (e) {
      if (/index\.(pck|wasm)$/.test(e.name.split('?')[0])) end = Math.max(end, e.responseEnd);
    });
    return end;
  }

  // The bytes over the network (as they come: compressed; 0 from a cache).
  function bytes() {
    var n = 0;
    var nav = performance.getEntriesByType('navigation')[0];
    if (nav) n += nav.transferSize || 0;
    performance.getEntriesByType('resource').forEach(function (e) { n += e.transferSize || 0; });
    return n;
  }

  vt.mark = function (name) {
    if (name in vt.marks) return;
    vt.marks[name] = performance.now();
    if (name === 'firstFrame') {
      vt.marks.downloadEnd = downloadEnd();
      vt.bytesAtFirstFrame = bytes();
    }
  };

  function keep(imports, result) {
    try {
      var instance = result.instance || result;
      Object.values(instance.exports || {}).forEach(function (v) { if (v instanceof WebAssembly.Memory) memories.push(v); });
      Object.values(imports || {}).forEach(function (group) {
        Object.values(group || {}).forEach(function (v) { if (v instanceof WebAssembly.Memory) memories.push(v); });
      });
    } catch (e) { /* no memory to keep */ }
    return result;
  }
  var instantiate = WebAssembly.instantiate;
  WebAssembly.instantiate = function (source, imports) {
    vt.mark('compileStart');
    return instantiate.apply(this, arguments).then(function (r) { vt.mark('compileEnd'); return keep(imports, r); });
  };
  var streaming = WebAssembly.instantiateStreaming;
  if (streaming) {
    WebAssembly.instantiateStreaming = function (source, imports) {
      vt.mark('compileStart');
      return streaming.apply(this, arguments).then(function (r) { vt.mark('compileEnd'); return keep(imports, r); });
    };
  }

  // The heap of the engine (MB), or null.
  vt.heapMB = function () {
    if (!memories.length) return null;
    return Math.round(Math.max.apply(null, memories.map(function (m) { return m.buffer.byteLength; })) / 1048576);
  };

  // The times of the line (LoadTimes.line()): s from the start of the page.
  vt.times = function () {
    var m = vt.marks, t = {};
    if ('firstFrame' in m) t.firstFrameS = m.firstFrame / 1000;
    if ('canMove' in m) t.canMoveS = m.canMove / 1000;
    if (vt.bytesAtFirstFrame !== undefined) t.bytesMB = vt.bytesAtFirstFrame / 1e6;
    var heap = vt.heapMB();
    if (performance.memory && heap !== null) t.pageMB = heap + Math.round(performance.memory.usedJSHeapSize / 1048576);
    return t;
  };
})();
