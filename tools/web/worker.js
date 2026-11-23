// Plan 0009, R16: the web build on Cloudflare. The page and its small files
// are static assets of this Worker. The page asks for b/BUILD/index.pck and
// b/BUILD/index.wasm (BUILD: the commit of the build), and the Worker gives
// them from the R2 bucket (builds/BUILD/...), with their MIME types and a long
// cache time: the name of each build is new, so a cached file never goes old.
const R2_FILES = {
  "index.pck": "application/octet-stream",
  "index.wasm": "application/wasm",
};

// A file larger than one upload of wrangler (300 MiB) is in parts:
// NAME.part0, NAME.part1, ... The Worker gives the parts as one file.
async function partsOf(env, key) {
  const listed = await env.BUILDS.list({ prefix: `${key}.part` });
  return listed.objects
    .map((object) => ({ key: object.key, size: object.size, index: Number(object.key.slice(key.length + 5)) }))
    .sort((a, b) => a.index - b.index);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/b\/([0-9a-f]{7,40})\/([A-Za-z0-9._-]+)$/);
    if (!match) {
      return env.ASSETS.fetch(request);
    }
    const [, build, name] = match;
    if (!(name in R2_FILES)) {
      // A small file of the build (an audio worklet): a static asset.
      return env.ASSETS.fetch(new Request(new URL(`/${name}`, url), request));
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", { status: 405 });
    }
    const key = `builds/${build}/${name}`;
    const headers = new Headers();
    headers.set("Content-Type", R2_FILES[name]);
    headers.set("Cache-Control", "public, max-age=31536000, immutable");
    const object = await env.BUILDS.get(key);
    if (object !== null) {
      headers.set("Content-Length", String(object.size));
      headers.set("ETag", object.httpEtag);
      return new Response(request.method === "HEAD" ? null : object.body, { headers });
    }
    const parts = await partsOf(env, key);
    if (parts.length === 0) {
      return new Response("Not found", { status: 404 });
    }
    const length = parts.reduce((sum, part) => sum + part.size, 0);
    headers.set("Content-Length", String(length));
    headers.set("ETag", `"${build}-${name}"`);
    if (request.method === "HEAD") {
      return new Response(null, { headers });
    }
    const { readable, writable } = new FixedLengthStream(length);
    ctx.waitUntil((async () => {
      for (const part of parts) {
        const object = await env.BUILDS.get(part.key);
        await object.body.pipeTo(writable, { preventClose: true });
      }
      await writable.close();
    })());
    return new Response(readable, { headers });
  },
};
