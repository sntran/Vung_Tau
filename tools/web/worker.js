// Plan 0009, R16, and plan 0031, D4: the web build on Cloudflare. The page and its small files
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

// Plan 0031, D15 and R7: a part of a pack (p/HASH.pck in the bucket). The name
// changes with the content, so the cache time is one year; the Brotli copy goes
// to a browser that takes it.
async function packPart(request, env, name) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405 });
  }
  const key = `p/${name}`;
  const headers = new Headers();
  headers.set("Content-Type", "application/octet-stream");
  headers.set("Cache-Control", "public, max-age=31536000, immutable");
  headers.set("Vary", "Accept-Encoding");
  if ((request.headers.get("Accept-Encoding") || "").includes("br")) {
    const encoded = await env.BUILDS.get(`${key}.br`);
    if (encoded !== null) {
      headers.set("Content-Encoding", "br");
      headers.set("Content-Length", String(encoded.size));
      headers.set("ETag", `"${name}-br"`);
      return new Response(request.method === "HEAD" ? null : encoded.body, { headers, encodeBody: "manual" });
    }
  }
  const object = await env.BUILDS.get(key);
  if (object === null) {
    return new Response("Not found", { status: 404 });
  }
  headers.set("Content-Length", String(object.size));
  headers.set("ETag", `"${name}"`);
  return new Response(request.method === "HEAD" ? null : object.body, { headers });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    // Plan 0031, D15 and R7: a part of a pack, named by the hash of its content.
    const part = url.pathname.match(/^\/p\/([0-9a-f]{16,64}\.pck)$/);
    if (part) {
      return packPart(request, env, part[1]);
    }
    const match = url.pathname.match(/^\/b\/([0-9a-f]{7,40})\/([A-Za-z0-9._-]+)$/);
    if (!match) {
      return env.ASSETS.fetch(request);
    }
    const [, build, name] = match;
    // Plan 0031, D5: the other packs of the build (the test pack, the packs of the areas).
    if (!(name in R2_FILES) && /^[a-z0-9_]+\.pck$/.test(name)) {
      R2_FILES[name] = "application/octet-stream";
    }
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
    headers.set("Vary", "Accept-Encoding");
    // Plan 0031, D4: the Brotli copy (NAME.br) to a browser that takes it.
    // "manual": the body is already encoded, and Cloudflare sends it as it is.
    if ((request.headers.get("Accept-Encoding") || "").includes("br")) {
      const encoded = await env.BUILDS.get(`${key}.br`);
      if (encoded !== null) {
        headers.set("Content-Encoding", "br");
        headers.set("Content-Length", String(encoded.size));
        headers.set("ETag", `"${build}-${name}-br"`);
        return new Response(request.method === "HEAD" ? null : encoded.body, { headers, encodeBody: "manual" });
      }
    }
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
