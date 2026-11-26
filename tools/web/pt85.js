// Plan 0031, PT-85 web_load: after each deploy, open the page at
// ?start=bai_truoc&ride and at ?start=hem in Chromium with an empty cache and
// a network of 50 Mbit/s (--mbps=). Wait for the first frame of the world,
// push the joystick with a real touch, and check that the scooter (or the
// player) moves. Keep a screenshot of the loading screen, of the first frame,
// and of the first move, with the times, the bytes, and the memory. On the
// scooter, ride 300 m along Quang Trung with the stick and check that no
// model of the showcase waits for its files at the end ("waiting", step 2).
// A script error or an engine error in the console is a failure. With
// --targets (after step 2 of plan 0031), a time or a size over its target of
// D10 is a failure. Usage: node tools/web/check.js URL OUT --pt85
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
// The joystick: its rest place is the middle of its zone (Main.STICK_ZONE,
// 340 × 260 at the bottom left of the base view of 1280 × 720), its radius
// Joystick.RADIUS (80).
const STICK = { x: 170, y: 720 - 130, radius: 80 };
// The road of the ride: Quang Trung to the south from the start of Bãi Trước.
const QUANG_TRUNG_SOUTH = 1558591261;
const RIDE_M = 300;

function quangTrung() {
  const data = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/geo/build/roads.json'), 'utf8'));
  const roads = data.roads || data;
  const road = roads.find((r) => Number(r.id) === QUANG_TRUNG_SOUTH);
  return road ? road.points.map((p) => ({ x: p[0], z: p[2] })) : [];
}

async function touch(cdp, type, x, y) {
  await cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
}

async function state(page) {
  return page.evaluate(() => (window.vungTau && window.vungTau.state) ? window.vungTau.state : null).catch(() => null);
}

// Rides the route with the stick: the knob to the point 12 m ahead on the
// route (the turn of the handlebars under 0.8, so no tight turn), and up for
// the speed. Returns the meters ridden.
async function rideAlong(page, cdp, route, meters, limitS) {
  let ridden = 0;
  let last = await state(page);
  const t0 = Date.now();
  await touch(cdp, 'touchStart', STICK.x, STICK.y);
  while (ridden < meters && Date.now() - t0 < limitS * 1000) {
    const now = await state(page);
    if (now && last) ridden += Math.hypot(now.x - last.x, now.z - last.z);
    last = now || last;
    let steer = 0;
    if (now && route.length > 1) {
      let best = 0;
      for (let i = 0; i < route.length; i++) {
        if (Math.hypot(route[i].x - now.x, route[i].z - now.z) < Math.hypot(route[best].x - now.x, route[best].z - now.z)) best = i;
      }
      let target = route[Math.min(best + 1, route.length - 1)];
      for (let i = best; i < route.length; i++) {
        target = route[i];
        if (Math.hypot(route[i].x - now.x, route[i].z - now.z) > 12) break;
      }
      const heading = now.heading * Math.PI / 180;
      const front = { x: -Math.sin(heading), z: -Math.cos(heading) };
      const right = { x: -front.z, z: front.x };
      const to = { x: target.x - now.x, z: target.z - now.z };
      const alpha = Math.atan2(to.x * right.x + to.z * right.z, to.x * front.x + to.z * front.z);
      steer = Math.max(-0.75, Math.min(0.75, alpha * 2.0));
    }
    const up = Math.sqrt(Math.max(0, 1 - steer * steer));
    await touch(cdp, 'touchMove', STICK.x + steer * STICK.radius, STICK.y - up * STICK.radius);
    await page.waitForTimeout(150);
  }
  await touch(cdp, 'touchEnd', 0, 0);
  return ridden;
}

async function openPage(base, query, label, ctx) {
  const { out, options, ARGS, WASM_HOOK, memoryOf } = ctx;
  const mbps = Number(options.mbps || 50);
  const browser = await chromium.launch({ args: ARGS });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, hasTouch: true });
  await context.addInitScript(WASM_HOOK);
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 20, downloadThroughput: mbps * 1e6 / 8, uploadThroughput: 10e6 / 8 });
  let bytes = 0;
  cdp.on('Network.loadingFinished', (e) => { bytes += e.encodedDataLength; });
  const errors = [], log = [];
  page.on('console', (m) => {
    log.push(`${m.type()}: ${m.text()}`);
    if (/SCRIPT ERROR|^ERROR:|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
  });
  page.on('pageerror', (e) => errors.push(String(e).slice(0, 300)));
  page.on('crash', () => errors.push('the page crashed'));
  const r = { label, url: base + query, mbps, errors, checks: [] };
  const t0 = Date.now();
  const expect = (ok, text) => { r.checks.push({ ok: Boolean(ok), text }); if (!ok) console.log(`FAIL ${label}: ${text}`); };
  try {
    await page.goto(base + query, { waitUntil: 'commit', timeout: 600000 });
    await page.waitForTimeout(3000);
    await page.screenshot({ path: `${out}/${label}_1_loading.png`, timeout: 120000 }).catch(() => {});
    await page.waitForFunction(() => window.vungTau && window.vungTau.firstFrameMs >= 0, null, { timeout: 1800000, polling: 250 });
    r.firstFrameS = (Date.now() - t0) / 1000;
    r.bytesBeforeFirstFrameMB = Math.round(bytes / 1e5) / 10;
    r.memoryAtFirstFrame = await memoryOf(page);
    await page.screenshot({ path: `${out}/${label}_2_first_frame.png`, timeout: 120000 }).catch(() => {});
    await page.waitForFunction(() => window.vungTau.canMoveMs >= 0, null, { timeout: 1800000, polling: 250 });
    r.canMoveS = (Date.now() - t0) / 1000;
    // The first move: a real touch on the joystick, up.
    // The stick up until the scooter (or the player) moves 1 m, for 30 s at
    // most: SwiftShader of the workspace can give few frames a second, and
    // the test counts the time of the page, not of the game.
    const before = await state(page);
    let after = before;
    const moveStart = Date.now();
    await touch(cdp, 'touchStart', STICK.x, STICK.y);
    while (Date.now() - moveStart < 30000) {
      await touch(cdp, 'touchMove', STICK.x, STICK.y - STICK.radius);
      await page.waitForTimeout(150);
      after = await state(page) || after;
      if (before && after && Math.hypot(after.x - before.x, after.z - before.z) > 1.0) break;
    }
    r.firstMoveS = (Date.now() - moveStart) / 1000;
    const framesAt = after && before ? (after.frames - before.frames) / Math.max(r.firstMoveS, 0.1) : null;
    r.framesPerSecond = framesAt === null ? null : Math.round(framesAt * 10) / 10;
    await page.screenshot({ path: `${out}/${label}_3_first_move.png`, timeout: 120000 }).catch(() => {});
    await touch(cdp, 'touchEnd', 0, 0);
    const moved = before && after ? Math.hypot(after.x - before.x, after.z - before.z) : 0;
    r.firstMoveM = Math.round(moved * 100) / 100;
    expect(moved > 0.5, `a touch on the joystick moves the ${after && after.riding ? 'scooter' : 'player'}: ${r.firstMoveM} m`);
    // R11: the line of the times shows at the top after the first move (a build of a branch).
    r.timesLine = await page.evaluate(() => window.vungTau.timesLine || '').catch(() => '');
    r.parts = await page.evaluate(() => window.vungTau.marks || {}).catch(() => ({}));
    expect(r.timesLine !== '', `the line of the times shows after the first move: "${r.timesLine}"`);
    await page.screenshot({ path: `${out}/${label}_3b_times_line.png`, timeout: 120000 }).catch(() => {});
    if (after && after.riding) {
      // At 0.4 frames a second (SwiftShader of the workspace), 300 m take about 20 minutes.
      const ridden = await rideAlong(page, cdp, quangTrung(), RIDE_M, 1500);
      r.riddenM = Math.round(ridden);
      await page.waitForTimeout(1000);
      await page.screenshot({ path: `${out}/${label}_4_after_${RIDE_M}m.png`, timeout: 120000 }).catch(() => {});
      expect(ridden >= RIDE_M, `the scooter rides ${RIDE_M} m along Quang Trung: ${r.riddenM} m`);
      const waiting = await page.evaluate(() => window.vungTau.waiting).catch(() => undefined);
      r.waitingModels = waiting === undefined ? 'no signal (before step 2)' : waiting;
      if (waiting !== undefined) expect(waiting === 0, `no model of the showcase waits for its files at the end: ${waiting}`);
    }
    r.memoryEnd = await memoryOf(page);
  } catch (e) {
    r.failure = String(e).slice(0, 300);
    expect(false, r.failure);
    await page.screenshot({ path: `${out}/${label}_failure.png` }).catch(() => {});
  }
  r.bytesAllMB = Math.round(bytes / 1e5) / 10;
  expect(r.errors.length === 0, `no script error or engine error in the console: ${r.errors.slice(0, 3).join(' | ')}`);
  if (options.targets) {
    const T = ctx.TARGETS;
    expect(r.bytesBeforeFirstFrameMB <= T.bytesMB, `at most ${T.bytesMB} MB before the first frame: ${r.bytesBeforeFirstFrameMB} MB`);
    expect(r.firstFrameS <= T.firstFrameS, `the first frame at most ${T.firstFrameS} s: ${r.firstFrameS} s`);
    expect(r.canMoveS <= T.canMoveS, `the player can move at most ${T.canMoveS} s: ${r.canMoveS} s`);
    expect(r.memoryAtFirstFrame && r.memoryAtFirstFrame.pageMB <= T.memoryMB, `the page at most ${T.memoryMB} MB at the first frame`);
  }
  fs.writeFileSync(`${out}/${label}_console.log`, log.join('\n'));
  await browser.close();
  return r;
}

async function run(ctx) {
  const base = ctx.url.replace(/[?#].*$/, '');
  const results = [];
  for (const [query, label] of [['?start=bai_truoc&ride', 'bai_truoc_ride'], ['?start=hem', 'hem']]) {
    const r = await openPage(base, query, label, ctx);
    results.push(r);
    console.log(JSON.stringify(r, null, 2));
  }
  fs.writeFileSync(`${ctx.out}/pt85.json`, JSON.stringify(results, null, 2));
  const failed = results.flatMap((r) => r.checks.filter((c) => !c.ok));
  console.log(failed.length ? `PT-85 FAIL (${failed.length})` : 'PT-85 PASS');
  return failed.length ? 1 : 0;
}

module.exports = { run };
