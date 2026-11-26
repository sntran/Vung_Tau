// Plan 0009, R16, and plan 0031, R1: open the web build in Chromium
// (Playwright) and measure it.
//
//   node tools/web/check.js URL OUT
//       As a computer (1280 × 720, no limits): the first frame of the world,
//       screenshots, the times, the memory, and the console errors.
//   node tools/web/check.js URL OUT --measure [--md=docs/web/load.md --step=NAME]
//       Plan 0031, D3: as a phone (720 × 1280 and 2400 × 1080, a touch screen,
//       the processor four times slower), with a limit on the network of
//       25 Mbit/s and of 100 Mbit/s, with an empty cache and then with the
//       cache. For each: the bytes over the network before the first frame,
//       the time to the first frame of the world, the time until the player
//       can move, and the memory (the heap of the engine, the JavaScript heap,
//       and all of the page). --sizes=, --mbps=, and --cpu= change the set.
//   node tools/web/check.js URL OUT --pt85 [--mbps=50] [--targets]
//       Plan 0031, PT-85: see tools/web/pt85.js.
//   node tools/web/check.js URL OUT --r15 [--mbps=100 --md=docs/web/load.md --step=NAME]
//       Plan 0031, R15: two visits with a disk cache of 50 MB; the second
//       visit gets no pack over the network.
//   node tools/web/check.js URL OUT --loading
//       Plan 0031, R6: screenshots of the loading screen at three sizes.
//   node tools/web/check.js URL OUT --packtest
//       Plan 0031, D5: the page with ?packtest downloads a second pack while
//       the game runs and loads a scene from it (scripts/web/pack_test.gd).
//
// URL is the page with its parameters (for example ...?start=bai_truoc&ride).
const { chromium } = require('playwright');
const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const positional = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const options = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith('--'))
  .map((a) => { const [k, v] = a.slice(2).split('='); return [k, v === undefined ? true : v]; }));
const [url, out] = positional;
fs.mkdirSync(out, { recursive: true });

const ARGS = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-precise-memory-info'];
// A phone of the reference of plan 0031 (Q1, Q3): Chrome on Android. A generic agent string.
const PHONE_AGENT = 'Mozilla/5.0 (Linux; Android 15; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
// D10: the targets, at 25 Mbit/s.
const TARGETS = { bytesMB: 40, firstFrameS: 20, canMoveS: 40, canMoveCachedS: 15, memoryMB: 700 };

// The memory (resident) of the processes of Chromium, by type, in MB.
function rssByType() {
  const lines = execSync('ps -eo rss,args').toString().split('\n');
  const sum = {};
  for (const l of lines) {
    if (!/chrom/i.test(l)) continue;
    const m = l.trim().match(/^(\d+)\s+(.*)$/); if (!m) continue;
    const t = (m[2].match(/--type=([a-z-]+)/) || [, 'browser'])[1];
    sum[t] = (sum[t] || 0) + Number(m[1]) / 1024;
  }
  for (const k in sum) sum[k] = Math.round(sum[k]);
  return sum;
}

// Before the page: keep each WebAssembly.Memory of the engine, for its heap.
const WASM_HOOK = `(() => {
  const memories = [];
  const keep = (imports, result) => {
    try {
      const instance = result.instance || result;
      for (const value of Object.values(instance.exports || {})) if (value instanceof WebAssembly.Memory) memories.push(value);
      for (const group of Object.values(imports || {})) for (const value of Object.values(group || {})) if (value instanceof WebAssembly.Memory) memories.push(value);
    } catch (e) {}
    return result;
  };
  const instantiate = WebAssembly.instantiate;
  WebAssembly.instantiate = function (source, imports) { return instantiate.apply(this, arguments).then((r) => keep(imports, r)); };
  const streaming = WebAssembly.instantiateStreaming;
  if (streaming) WebAssembly.instantiateStreaming = function (source, imports) { return streaming.apply(this, arguments).then((r) => keep(imports, r)); };
  window.__wasmHeapMB = () => memories.length ? Math.round(Math.max(...memories.map((m) => m.buffer.byteLength)) / 1048576) : null;
})();`;

// Plan 0031, D11: the parts of the start from the marks of the page
// (tools/web/page.js), in s, as LoadTimes.parts() gives them in the game.
async function startParts(page) {
  return page.evaluate(() => {
    const m = (window.vungTau && window.vungTau.marks) || {};
    const r = {};
    const s = (v) => Math.round(v / 100) / 10;
    if (m.downloadEnd >= 0) r.downloadS = s(m.downloadEnd);
    if (m.compileEnd >= 0 && m.compileStart >= 0) r.compileS = s(m.compileEnd - m.compileStart);
    if (m.engine >= 0) r.engineS = s(m.engine - Math.max(m.downloadEnd || 0, m.compileEnd || 0));
    if (m.firstFrame >= 0 && m.engine >= 0) r.worldS = s(m.firstFrame - m.engine);
    if (m.canMove >= 0 && m.firstFrame >= 0) r.moveS = s(m.canMove - m.firstFrame);
    return r;
  }).catch(() => ({}));
}

async function memoryOf(page) {
  const rss = rssByType();
  return {
    engineHeapMB: await page.evaluate(() => window.__wasmHeapMB ? window.__wasmHeapMB() : null).catch(() => null),
    jsHeapMB: await page.evaluate(() => performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null).catch(() => null),
    pageMB: (rss.renderer || 0) + (rss['gpu-process'] || 0),
    rssMB: rss,
  };
}

// One opening of the page: the times from the start of the navigation, the
// bytes over the network before the first frame, and the memory.
async function openOnce(context, cdp, label, shots) {
  const page = context.pages()[0] || await context.newPage();
  const errors = [], log = [];
  // A file that the network cuts stops the load of the engine: stop the wait
  // at once, not after its time limit (openings() then tries again).
  let cut;
  const networkCut = new Promise((_, reject) => { cut = reject; });
  networkCut.catch(() => {});
  page.on('console', (m) => {
    log.push(`${m.type()}: ${m.text()}`);
    if (m.type() === 'error') errors.push(m.text());
    if (/ERR_CONNECTION_RESET|ERR_CONNECTION_CLOSED|ERR_HTTP2|TypeError: network error|ERR_NETWORK_CHANGED/.test(m.text())) cut(new Error('NETWORK CUT: ' + m.text()));
  });
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('crash', () => errors.push('the page crashed (memory: ' + JSON.stringify(rssByType()) + ')'));
  let bytes = 0, requests = 0, fromCache = 0, packBytes = 0;
  // Plan 0031, R15: the bytes of the packs over the network (index.pck, p/HASH.pck, and the other packs).
  const urls = {};
  const onResponse = (e) => { urls[e.requestId] = e.response.url; };
  const onFinished = (e) => {
    bytes += e.encodedDataLength; requests += 1;
    if (/\.pck(\.br)?(\?|$)/.test((urls[e.requestId] || '').split('#')[0])) packBytes += e.encodedDataLength;
  };
  const onServed = () => { fromCache += 1; };
  cdp.on('Network.responseReceived', onResponse);
  cdp.on('Network.loadingFinished', onFinished);
  cdp.on('Network.requestServedFromCache', onServed);
  const result = { label, errors };
  const t0 = Date.now();
  try {
    await page.goto(url, { waitUntil: 'commit', timeout: 600000 });
    if (shots) setTimeout(() => page.screenshot({ path: `${out}/${label}_loading.png` }).catch(() => {}), 5000);
    await Promise.race([networkCut,
      page.waitForFunction(() => window.vungTau && window.vungTau.firstFrameMs >= 0, null, { timeout: 1800000, polling: 250 })]);
    result.firstFrameS = (Date.now() - t0) / 1000;
    result.bytesBeforeFirstFrameMB = Math.round(bytes / 1e5) / 10;
    result.requestsBeforeFirstFrame = requests;
    result.fromCache = fromCache;
    result.memoryAtFirstFrame = await memoryOf(page);
    // A slow frame of SwiftShader can take more than 30 s: a screenshot is not a measure.
    if (shots) await page.screenshot({ path: `${out}/${label}_first_frame.png`, timeout: 120000 }).catch(() => {});
    await page.waitForFunction(() => window.vungTau.canMoveMs >= 0, null, { timeout: 1800000, polling: 250 });
    result.canMoveS = (Date.now() - t0) / 1000;
    result.memoryCanMove = await memoryOf(page);
    result.parts = await startParts(page);
    // D13, D16: the memory of the page when each pack is there (bai_truoc is
    // in the area of the pack people), 300 s at most; the memory before the
    // packs is the memory when the player can move.
    const wanted = await page.evaluate(() => Object.keys((window.vungTauBuild || {}).packs || {}).filter((k) => k !== 'index')).catch(() => []);
    if (!wanted.length) wanted.push('people');
    result.packs = {};
    const tPacks = Date.now();
    while (Date.now() - tPacks < 300000 && Object.keys(result.packs).length < wanted.length) {
      const there = await page.evaluate(() => Object.keys((window.vungTau && window.vungTau.packs) || {})).catch(() => []);
      for (const id of there) {
        if (wanted.includes(id) && !result.packs[id]) result.packs[id] = { s: (Date.now() - t0) / 1000, memory: await memoryOf(page) };
      }
      await page.waitForTimeout(1000);
    }
    // D16: the game ends the measure of the longest frame of a pack when its
    // upgrades are done, or 60 s after the pack is there (70 s at most here).
    await page.waitForFunction((ids) => ids.every((id) => !window.vungTau.packs[id] || window.vungTau.packs[id].upgradesMs !== undefined),
      Object.keys(result.packs), { timeout: 70000, polling: 1000 }).catch(() => {});
    const times = await page.evaluate(() => window.vungTau.packs || {}).catch(() => ({}));
    for (const id in result.packs) result.packs[id].times = times[id] || {};
    if (result.packs.people) {
      result.peopleS = result.packs.people.s;
      result.memoryPeople = result.packs.people.memory;
    }
    if (shots) await page.screenshot({ path: `${out}/${label}_can_move.png`, timeout: 120000 }).catch(() => {});
  } catch (e) {
    result.failure = String(e).slice(0, 300);
    await page.screenshot({ path: `${out}/${label}_failure.png` }).catch(() => {});
  }
  result.bytesAllMB = Math.round(bytes / 1e5) / 10;
  result.packsOverNetworkMB = Math.round(packBytes / 1e5) / 10;
  cdp.off('Network.responseReceived', onResponse);
  cdp.off('Network.loadingFinished', onFinished);
  cdp.off('Network.requestServedFromCache', onServed);
  fs.writeFileSync(`${out}/${label}_console.log`, log.join('\n'));
  return result;
}

async function phoneContext(size, mbps, cpu, extraArgs = [], profileDir = null) {
  const [width, height] = size.split('x').map(Number);
  const profile = profileDir || fs.mkdtempSync(path.join(os.tmpdir(), 'vt-profile-'));
  const context = await chromium.launchPersistentContext(profile, {
    args: ARGS.concat(extraArgs), viewport: { width, height }, isMobile: true, hasTouch: true, deviceScaleFactor: 1, userAgent: PHONE_AGENT,
  });
  await context.addInitScript(WASM_HOOK);
  const page = context.pages()[0] || await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false, latency: 40, downloadThroughput: mbps * 1e6 / 8, uploadThroughput: Math.min(mbps, 10) * 1e6 / 8,
  });
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
  return { context, cdp, profile };
}

async function measure() {
  const sizes = String(options.sizes || '720x1280,2400x1080').split(',');
  const networks = String(options.mbps || '25,100').split(',').map(Number);
  const cpu = Number(options.cpu || 4);
  const rows = [];
  for (const size of sizes) {
    for (const mbps of networks) {
      // A cut of the network is not a measure of the build: one more try,
      // with a new profile (an empty cache again). The row says so.
      for (let attempt = 1; attempt <= 2; attempt++) {
        const { context, cdp, profile } = await phoneContext(size, mbps, cpu);
        const pair = [];
        for (const cache of ['empty', 'cache']) {
          const label = `${size}_${mbps}mbps_${cache}`;
          const r = await openOnce(context, cdp, label, cache === 'empty');
          Object.assign(r, { size, mbps, cache, cpu, attempt });
          pair.push(r);
          console.log(JSON.stringify(r));
          if (r.failure) break;
        }
        await context.close();
        fs.rmSync(profile, { recursive: true, force: true });
        const wasCut = pair.some((r) => /NETWORK CUT/.test(r.failure || ''));
        if (!wasCut || attempt === 2) { rows.push(...pair); break; }
      }
    }
  }
  fs.writeFileSync(`${out}/measure.json`, JSON.stringify({ url, rows }, null, 2));
  if (options.md) writeMarkdown(String(options.md), String(options.step || 'A measure'), rows);
}

// Plan 0031, R6: the loading screen of D7 at 1280 × 720, 2400 × 1080, and
// 720 × 1280 (a phone at 25 Mbit/s): a screenshot while the pack downloads and
// one while the engine starts and builds the street.
async function loadingShots() {
  const sizes = String(options.sizes || '1280x720,2400x1080,720x1280').split(',');
  const result = { url, sizes: {} };
  for (const size of sizes) {
    const { context, profile } = await phoneContext(size, Number(options.mbps || 25), Number(options.cpu || 4));
    const page = context.pages()[0];
    const r = result.sizes[size] = {};
    try {
      // ?loadingshot: the page waits 5 s before the start of the engine (a screenshot needs a frame).
      await page.goto(url + (url.includes('?') ? '&' : '?') + 'loadingshot', { waitUntil: 'commit', timeout: 600000 });
      await page.waitForFunction(() => window.vungTau && window.vungTau.loadingState && window.vungTau.loadingState().part > 0.1,
        null, { timeout: 600000, polling: 250 });
      r.download = await page.evaluate(() => window.vungTau.loadingState());
      await page.screenshot({ path: `${out}/loading_${size}_download.png` });
      await page.waitForFunction(() => window.vungTau.loadingState().stage === 'world', null, { timeout: 900000, polling: 250 });
      r.world = await page.evaluate(() => window.vungTau.loadingState());
      await page.screenshot({ path: `${out}/loading_${size}_world.png`, timeout: 120000 }).catch((e) => { r.worldShot = String(e).slice(0, 120); });
      await page.waitForFunction(() => window.vungTau.firstFrameMs >= 0, null, { timeout: 1800000, polling: 500 });
      r.hiddenAtFirstFrame = await page.evaluate(() => !document.getElementById('vt-loading'));
    } catch (e) { r.failure = String(e).slice(0, 300); }
    console.log(size, JSON.stringify(r));
    await context.close();
    fs.rmSync(profile, { recursive: true, force: true });
  }
  fs.writeFileSync(`${out}/loading.json`, JSON.stringify(result, null, 2));
  return Object.values(result.sizes).every((r) => !r.failure && r.hiddenAtFirstFrame) ? 0 : 1;
}

// Plan 0031, R15: two visits with a disk cache of 50 MB (smaller than the
// start pack); the second visit gets no pack over the network (D15: the page
// keeps the packs in its Cache Storage). Each visit waits for the pack people.
async function cacheCheck() {
  const size = String(options.sizes || '720x1280'), mbps = Number(options.mbps || 100), cpu = Number(options.cpu || 4);
  // Each visit is a new browser on the same profile (its disk cache and its
  // Cache Storage), as a next visit on a phone: no memory of the browser
  // from the visit before.
  const rows = [];
  let profile = null;
  for (const visit of ['first', 'second']) {
    const browser = await phoneContext(size, mbps, cpu, ['--disk-cache-size=52428800'], profile);
    profile = browser.profile;
    // The Chromium of the workspace keeps the start pack (91 MB) also in a disk
    // cache of 50 MB. A phone does not (report 0031, D-0031-04): the second
    // visit has no HTTP cache. The Cache Storage of the page (D15) stays.
    if (visit === 'second') await browser.cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
    const r = await openOnce(browser.context, browser.cdp, `r15_${visit}`, false);
    Object.assign(r, { visit, size, mbps });
    rows.push(r);
    console.log(JSON.stringify(r));
    await browser.context.close();
    if (r.failure) break;
  }
  fs.rmSync(profile, { recursive: true, force: true });
  const second = rows[1] || {};
  const pass = !second.failure && second.peopleS !== undefined && second.packsOverNetworkMB === 0;
  fs.writeFileSync(`${out}/r15.json`, JSON.stringify({ url, pass, rows }, null, 2));
  if (options.md) {
    const date = new Date().toISOString().slice(0, 10);
    const lines = ['', `## ${options.step || 'R15'} (${date})`, '',
      `R15: \`${url}\`, ${size.replace('x', ' × ')}, ${mbps} Mbit/s, a disk cache of 50 MB, two visits (each a new browser on the same profile; the second with no HTTP cache, as a phone). ${pass ? 'Pass' : '**Fail**'}: the second visit gets ${second.packsOverNetworkMB} MB of packs over the network.`, '',
      '| Visit | Packs over the network | All over the network | First frame | Can move | The pack people there |',
      '|---|---|---|---|---|---|'];
    for (const r of rows) {
      lines.push(`| ${r.visit} | ${r.packsOverNetworkMB} MB | ${r.bytesAllMB} MB | ${cell(r.firstFrameS !== undefined ? Math.round(r.firstFrameS) : undefined, ' s')} | ` +
        `${cell(r.canMoveS !== undefined ? Math.round(r.canMoveS) : undefined, ' s')} | ${r.peopleS !== undefined ? Math.round(r.peopleS) + ' s' : 'no'} |` +
        (r.failure ? ` ${r.failure.split('\n')[0].replace(/\|/g, '/').slice(0, 120)}` : ''));
    }
    fs.appendFileSync(String(options.md), lines.join('\n') + '\n');
  }
  return pass ? 0 : 1;
}

function peopleCell(r) {
  return packCell(r, 'people');
}

// The time when the pack is there, the page and the heap of the engine then,
// and the longest frame from its request until its upgrades are done (D16).
function packCell(r, id) {
  const p = (r.packs || {})[id];
  if (!p && id === 'people' && r.peopleS !== undefined) {
    const m = r.memoryPeople || {};
    return `${Math.round(r.peopleS)} s, ${m.pageMB} MB, ${m.engineHeapMB} MB`;
  }
  if (!p) return '—';
  const m = p.memory || {};
  const t = p.times || {};
  const left = t.upgradesLeft ? ` (${t.upgradesLeft} upgrades wait after ${Math.round((t.upgradesMs || 0) / 1000)} s)` : '';
  const longest = t.longestFrameMs !== undefined ? `, longest frame ${t.longestFrameMs} ms${left}` : '';
  return `${Math.round(p.s)} s, ${m.pageMB} MB, ${m.engineHeapMB} MB${longest}`;
}

function partsCell(p) {
  if (!p || p.downloadS === undefined) return '—';
  const v = (x) => (x === undefined ? '—' : `${x}`);
  return `${v(p.downloadS)} / ${v(p.compileS)} / ${v(p.engineS)} / ${v(p.worldS)} / ${v(p.moveS)} s`;
}

function cell(value, unit, target) {
  if (value === undefined || value === null) return '—';
  const text = `${value}${unit}`;
  return target !== undefined && value > target ? `**${text}**` : text;
}

// Adds a section with one row for each opening to the file (R1).
function writeMarkdown(file, step, rows) {
  const date = new Date().toISOString().slice(0, 10);
  const lines = [
    '', `## ${step} (${date})`, '',
    `\`${url}\`, the processor ${rows[0] ? rows[0].cpu : 4} times slower. A value in bold is over its target of D10 (at 25 Mbit/s).`, '',
    '| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | Page when the player can move | The pack models there: time, page, heap of the engine | The people there: time, page, heap of the engine |',
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|',
  ];
  for (const r of rows) {
    const at25 = r.mbps <= 25;
    const m = r.memoryAtFirstFrame || {};
    const move = r.cache === 'cache' ? TARGETS.canMoveCachedS : TARGETS.canMoveS;
    lines.push(`| ${r.size.replace('x', ' × ')} | ${r.mbps} Mbit/s | ${r.cache === 'empty' ? 'empty' : 'with the cache'}${r.attempt > 1 ? ' (second try: the network cut the first)' : ''} | ` +
      `${cell(r.bytesBeforeFirstFrameMB, ' MB', at25 && r.cache === 'empty' ? TARGETS.bytesMB : undefined)} | ` +
      `${cell(r.firstFrameS !== undefined ? Math.round(r.firstFrameS) : undefined, ' s', at25 ? TARGETS.firstFrameS : undefined)} | ` +
      `${cell(r.canMoveS !== undefined ? Math.round(r.canMoveS) : undefined, ' s', at25 ? move : undefined)} | ` +
      `${cell(m.engineHeapMB, ' MB')} | ${cell(m.jsHeapMB, ' MB')} | ${cell(m.pageMB, ' MB', TARGETS.memoryMB)} | ${partsCell(r.parts)} | ${cell((r.memoryCanMove || {}).pageMB, ' MB')} | ${packCell(r, 'models')} | ${peopleCell(r)} |` +
      (r.failure ? ` ${r.failure.split('\n')[0].replace(/\|/g, '/').slice(0, 120)}` : ''));
  }
  const errors = [...new Set(rows.flatMap((r) => r.errors || []))].filter((e) => !/Occlusion culling is disabled|_print_warning/.test(e));
  if (errors.length) lines.push('', 'Errors in the console: ' + errors.slice(0, 5).map((e) => `\`${e.slice(0, 160)}\``).join('; '));
  fs.appendFileSync(file, lines.join('\n') + '\n');
}

// The legacy check (plan 0009, R16): as a computer, no limits.
async function check() {
  const browser = await chromium.launch({ args: ARGS });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [], log = [];
  page.on('console', (m) => { log.push(`${m.type()}: ${m.text()}`); if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('crash', () => errors.push('the page crashed (memory: ' + JSON.stringify(rssByType()) + ')'));
  browser.on('disconnected', () => errors.push('the browser closed'));
  const t0 = Date.now();
  const result = { url, errors };
  try {
    await page.goto(url, { waitUntil: 'load', timeout: 600000 });
    result.loadMs = Date.now() - t0;
    await page.waitForFunction(() => (window.vungTau && window.vungTau.firstFrameMs >= 0) ||
        !document.getElementById('status') || getComputedStyle(document.getElementById('status')).visibility === 'hidden',
        null, { timeout: 1200000, polling: 500 });
    result.firstFrameMs = Date.now() - t0;
    result.signal = await page.evaluate(() => window.vungTau ? 'game' : 'loader (a build before R16)');
    result.world = await page.evaluate(() => window.vungTau ? window.vungTau.world : null);
    if (!result.world) await page.waitForTimeout(5000);
    await page.screenshot({ path: `${out}/first_frame.png` });
    result.memoryAtFirstFrame = { rssMB: rssByType(), jsHeapMB: await page.evaluate(() => performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null) };
    try {
      if (result.world) {
        await page.waitForFunction(() => window.vungTau.settledMs >= 0, null, { timeout: 900000, polling: 1000 });
        result.settledMs = Date.now() - t0;
      } else {
        await page.waitForTimeout(40000);
        result.settled = 'no signal: 40 s after the first frame';
      }
    } catch (e) { result.settled = 'not in 15 minutes'; }
    await page.waitForTimeout(3000);
    await page.screenshot({ path: `${out}/settled.png` });
    result.memorySettled = { rssMB: rssByType(), jsHeapMB: await page.evaluate(() => performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : null) };
  } catch (e) {
    result.failure = String(e).slice(0, 400);
    await page.screenshot({ path: `${out}/failure.png` }).catch(() => {});
  }
  fs.writeFileSync(`${out}/console.log`, log.join('\n'));
  fs.writeFileSync(`${out}/result.json`, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
  await browser.close();
}

// Plan 0031, D5: the test of a second pack, as a computer with no limits.
async function packTest() {
  const browser = await chromium.launch({ args: ARGS });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await context.addInitScript(WASM_HOOK);
  const page = await context.newPage();
  const log = [], errors = [];
  page.on('console', (m) => { log.push(`${m.type()}: ${m.text()}`); if (/SCRIPT ERROR|^ERROR:/.test(m.text())) errors.push(m.text()); });
  const target = url + (url.includes('?') ? '&' : '?') + 'packtest';
  const t0 = Date.now();
  const result = { url: target, errors };
  try {
    await page.goto(target, { waitUntil: 'commit', timeout: 600000 });
    await page.waitForFunction(() => window.vungTau && window.vungTau.packTest && window.vungTau.packTest.done, null, { timeout: 1800000, polling: 500 });
    result.packTest = await page.evaluate(() => window.vungTau.packTest);
    result.seconds = (Date.now() - t0) / 1000;
    result.memory = await memoryOf(page);
    result.userAgent = await page.evaluate(() => navigator.userAgent);
  } catch (e) { result.failure = String(e).slice(0, 300); }
  await page.screenshot({ path: `${out}/packtest.png` }).catch(() => {});
  fs.writeFileSync(`${out}/packtest_console.log`, log.join('\n'));
  fs.writeFileSync(`${out}/packtest.json`, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
  await browser.close();
  const t = result.packTest || {};
  return t.works && errors.length === 0 ? 0 : 1;
}

const pt85 = require('./pt85.js');
(async () => {
  if (options.measure) await measure();
  else if (options.pt85) process.exitCode = await pt85.run({ url, out, options, ARGS, WASM_HOOK, TARGETS, memoryOf, rssByType });
  else if (options.packtest) process.exitCode = await packTest();
  else if (options.r15) process.exitCode = await cacheCheck();
  else if (options.loading) process.exitCode = await loadingShots();
  else await check();
})();
