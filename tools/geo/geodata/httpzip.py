"""A file of a ZIP archive on a web server, read with HTTP range requests
(plan 0009, R5b): the tile of DeltaDTM is 5 MB in a file of 17 GB, and only
the directory of the archive and the tile are downloaded."""

from __future__ import annotations

import io
import time
import urllib.request
import zipfile
from pathlib import Path


class RangeFile(io.RawIOBase):
    """A file on a web server that answers range requests, as a file that can seek."""

    def __init__(self, url: str, user_agent: str, tries: int = 5):
        self.url, self.headers, self.tries, self.pos = url, {"User-Agent": user_agent}, tries, 0
        with self._open(0, 0) as answer:
            self.size = int(answer.headers["Content-Range"].split("/")[1])

    def _open(self, start: int, end: int):
        request = urllib.request.Request(self.url, headers=self.headers | {"Range": f"bytes={start}-{end}"})
        return urllib.request.urlopen(request, timeout=300)

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = 0) -> int:
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
        return self.pos

    def readinto(self, buffer) -> int:
        if self.pos >= self.size or len(buffer) == 0:
            return 0
        end = min(self.pos + len(buffer), self.size) - 1
        for attempt in range(self.tries):
            try:
                with self._open(self.pos, end) as answer:
                    data = answer.read()
                break
            except OSError:
                if attempt == self.tries - 1:
                    raise
                time.sleep(2 * (attempt + 1))
        buffer[:len(data)] = data
        self.pos += len(data)
        return len(data)


def extract(url: str, name: str, path: Path, user_agent: str) -> int:
    """Writes the file of the archive whose name ends with name to path. Returns its size."""
    archive = zipfile.ZipFile(io.BufferedReader(RangeFile(url, user_agent), buffer_size=1 << 20))
    found = [i for i in archive.infolist() if i.filename.endswith(name)]
    if len(found) != 1:
        raise FileNotFoundError(f"{name}: {len(found)} files of the archive have this name")
    with archive.open(found[0]) as source, open(path, "wb") as out:
        while block := source.read(1 << 22):
            out.write(block)
    return found[0].file_size
