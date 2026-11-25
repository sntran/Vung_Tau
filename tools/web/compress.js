// Plan 0031, D4: the Brotli copy of each large file of the web build
// (FILE.br), which the Worker gives with "Content-Encoding: br" to a browser
// that takes it. Usage: node tools/web/compress.js FILE...
const fs = require('fs');
const zlib = require('zlib');
for (const file of process.argv.slice(2)) {
  const data = fs.readFileSync(file);
  const t0 = Date.now();
  const out = zlib.brotliCompressSync(data, {
    params: {
      [zlib.constants.BROTLI_PARAM_QUALITY]: 9,
      [zlib.constants.BROTLI_PARAM_LGWIN]: 24,
      [zlib.constants.BROTLI_PARAM_SIZE_HINT]: data.length,
    },
  });
  fs.writeFileSync(`${file}.br`, out);
  console.log(`${file}: ${(data.length / 1e6).toFixed(1)} MB, Brotli ${(out.length / 1e6).toFixed(1)} MB (${((Date.now() - t0) / 1000).toFixed(0)} s)`);
}
