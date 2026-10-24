"""Download the MakeHuman asset packs in tools/people/packs.json (plan 0006, R11).

Usage: python3 fetch_packs.py OUT_DIR

Writes OUT_DIR/NAME.zip for each pack, OUT_DIR/packs.lock.json with the license,
the source, and the SHA-256 of each file, and OUT_DIR/failed.txt with the packs
that did not download. The downloads run at the same time, each with a time limit.
"""

import concurrent.futures
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse

ALLOWED = {"CC0", "CC-BY"}
CONFIG = pathlib.Path(__file__).with_name("packs.json")


def fetch(url: str, dest: pathlib.Path, seconds: int) -> bool:
    cmd = ["curl", "-fsSL", "--retry", "2", "--connect-timeout", "30",
           "--max-time", str(seconds), "-o", str(dest), url]
    return subprocess.run(cmd).returncode == 0


def one(name: str, lic: str, page_tpl: str, out: pathlib.Path):
    page = page_tpl.format(name=name)
    html_file = out / f"{name}.html"
    if not fetch(page, html_file, 120):
        return name, None, f"the page {page} did not download"
    html = html_file.read_text("utf-8", "replace")
    html_file.unlink()
    links = [urllib.parse.urljoin(page, h)
             for h in re.findall(r"""href=["']([^"']+\.zip)["']""", html)]
    if not links:
        return name, None, f"the page {page} has no zip link"
    dest = out / f"{name}.zip"
    for url in links:
        if fetch(url, dest, 1500):
            data = dest.read_bytes()
            return name, {"license": lic, "page": page, "source": url,
                          "sha256": hashlib.sha256(data).hexdigest(),
                          "bytes": len(data)}, None
        print(f"{name}: {url} failed", flush=True)
    return name, None, "all links failed: " + " ".join(links)


def main() -> int:
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    cfg = json.loads(CONFIG.read_text("utf-8"))
    for name, lic in cfg["packs"].items():
        if lic not in ALLOWED:
            print(f"{name}: the license {lic} is not permitted", flush=True)
            return 1
    lock, failed = {}, []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        jobs = [pool.submit(one, n, l, cfg["page"], out) for n, l in cfg["packs"].items()]
        for job in concurrent.futures.as_completed(jobs):
            name, entry, error = job.result()
            if entry:
                lock[name] = entry
                print(f"{name}: {entry['bytes']} bytes from {entry['source']}", flush=True)
            else:
                failed.append(name)
                print(f"{name}: {error}", flush=True)
    (out / "packs.lock.json").write_text(json.dumps(dict(sorted(lock.items())), indent=2))
    (out / "failed.txt").write_text("\n".join(sorted(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
