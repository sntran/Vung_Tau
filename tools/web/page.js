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
    var end = vt.marks.packEnd !== undefined ? vt.marks.packEnd : -1;
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

  // Plan 0031, D15: the page gets the packs and keeps them. Each pack is in parts
  // of at most 50 MB over the network, named by the hash of their content
  // (p/HASH.pck, R7): the page takes a part from the Cache Storage of the
  // browser, or else downloads it and keeps it there. A part that no pack of
  // this build uses goes from the cache (the packs of older builds).
  var CACHE = 'vung-tau-packs';
  vt.packState = vt.packState || {};

  function build() { return window.vungTauBuild || {}; }

  // The bytes of a part, from the cache or the network; "progress(n)" gets the new bytes.
  function getPart(cache, part, progress) {
    var url = new URL(part.url, window.location.href).href;
    var fromCache = cache ? cache.match(url) : Promise.resolve(undefined);
    return fromCache.then(function (cached) {
      if (cached) {
        return cached.arrayBuffer().then(function (b) { progress(b.byteLength, true); return b; });
      }
      return fetch(url).then(function (response) {
        if (!response.ok) throw new Error('the part ' + part.url + ': HTTP ' + response.status);
        var reader = response.body.getReader();
        var chunks = [], length = 0;
        function pump() {
          return reader.read().then(function (r) {
            if (r.done) return;
            chunks.push(r.value); length += r.value.byteLength; progress(r.value.byteLength, false);
            return pump();
          });
        }
        return pump().then(function () {
          var bytes = new Uint8Array(length), at = 0;
          chunks.forEach(function (c) { bytes.set(c, at); at += c.byteLength; });
          var keep = cache ? cache.put(url, new Response(bytes)).catch(function () {}) : Promise.resolve();
          return keep.then(function () { return bytes.buffer; });
        });
      });
    });
  }

  // The bytes of a pack of this build (its parts one after another).
  vt.getPack = function (id, progress) {
    var pack = (build().packs || {})[id];
    if (!pack) return Promise.reject(new Error('no pack ' + id));
    var state = vt.packState[id] = { state: 'loading', bytes: 0, size: pack.size, fromCache: 0, startMs: performance.now() };
    var open = ('caches' in window) ? caches.open(CACHE).catch(function () { return null; }) : Promise.resolve(null);
    return open.then(function (cache) {
      var out = new Uint8Array(pack.size), at = 0;
      var chain = Promise.resolve();
      pack.parts.forEach(function (part) {
        chain = chain.then(function () {
          return getPart(cache, part, function (n, cached) {
            state.bytes += n;
            if (cached) state.fromCache += n;
            if (progress) progress(state.bytes, pack.size);
          }).then(function (b) { out.set(new Uint8Array(b), at); at += b.byteLength; });
        });
      });
      return chain.then(function () {
        state.state = 'done';
        state.ms = performance.now() - state.startMs;
        return out.buffer;
      });
    });
  };

  // The packs of older builds go from the cache.
  vt.pruneCache = function () {
    if (!('caches' in window)) return Promise.resolve();
    var used = {};
    Object.values(build().packs || {}).forEach(function (pack) {
      pack.parts.forEach(function (part) { used[new URL(part.url, window.location.href).href] = true; });
    });
    return caches.open(CACHE).then(function (cache) {
      return cache.keys().then(function (keys) {
        return Promise.all(keys.filter(function (r) { return !used[r.url]; }).map(function (r) { return cache.delete(r); }));
      });
    }).catch(function () {});
  };

  // A pack for the game (WebPacks): its file in the file system of the engine
  // (not user://), then window.vungTau.packState[ID] = {state: 'done', path}.
  vt.loadPack = function (id) {
    if (vt.packState[id] && vt.packState[id].state !== 'error') return;
    vt.getPack(id).then(function (buffer) {
      var path = '/tmp/packs/' + id + '.pck';
      vt.engine.copyToFS(path, buffer);
      vt.packState[id].path = path;
      vt.packState[id].state = 'done';
    }).catch(function (e) {
      vt.packState[id] = { state: 'error', error: String(e) };
    });
  };

  // The start of the game (the page of Godot calls it for engine.startGame()):
  // the start pack comes from the page, and the engine gets it as a buffer.
  vt.startGame = function (engine, override) {
    vt.engine = engine;
    if (!(build().packs || {}).index) return engine.startGame(override);
    var onProgress = override && override.onProgress;
    var exe = engine.config.executable;
    engine.config.update(override || {});
    engine.config.args = ['--main-pack', 'index.pck'].concat(engine.config.args);
    return Promise.all([
      engine.init(exe),
      vt.getPack('index', function (done, total) { if (onProgress) onProgress(done, total); }).then(function (buffer) {
        vt.mark('packEnd');
        return engine.preloadFile(buffer, 'index.pck');
      }),
    ]).then(function () {
      vt.pruneCache();
      return engine.start();
    });
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
