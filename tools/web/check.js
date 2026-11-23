// Plan 0009, R16: open the web build in Chromium (Playwright), wait for the
// first frame of the world, and keep a screenshot, the times, the memory, and
// the console errors. Usage: node tools/web/check.js URL OUT_FOLDER
const { chromium } = require('playwright');
const { execSync } = require('child_process');
const fs = require('fs');
const [url, out] = [process.argv[2], process.argv[3]];
fs.mkdirSync(out, { recursive: true });
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
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-precise-memory-info'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [], log = [];
  page.on('console', m => { log.push(`${m.type()}: ${m.text()}`); if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(String(e)));
  page.on('crash', () => errors.push('the page crashed (memory: ' + JSON.stringify(rssByType()) + ')'));
  browser.on('disconnected', () => errors.push('the browser closed'));
  const t0 = Date.now();
  const result = { url, errors };
  try {
    await page.goto(url, { waitUntil: 'load', timeout: 600000 });
    result.loadMs = Date.now() - t0;
    // The signal of the game (R16), or for a build before R16 the hidden status box of the loader.
    await page.waitForFunction(() => (window.vungTau && window.vungTau.firstFrameMs >= 0) ||
        (document.getElementById('status') && getComputedStyle(document.getElementById('status')).visibility === 'hidden'),
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
})();
