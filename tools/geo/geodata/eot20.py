"""Downloads the ocean tide files of EOT20 (plan 0004, D12).

The EOT20 file on SEANOE is a zip file (2.3 GB) with two zip files in it:
the ocean tides and the load tides. The game needs only the ocean tides, so
this module downloads only that part, with an HTTP range request, and
unpacks the 17 constituent files.
"""

import struct
import urllib.request
import zipfile
import zlib
from pathlib import Path

URL = "https://www.seanoe.org/data/00683/79489/data/85762.zip"
LICENSE = "CC BY 4.0. Hart-Davis, M. G. et al. (2021): EOT20 - A global Empirical Ocean Tide model from multi-mission satellite altimetry. SEANOE. https://doi.org/10.17882/79489"
USER_AGENT = "VungTau-game-geodata/1.0 (https://github.com/sntran/Vung_Tau)"
INNER = "ocean_tides.zip"


def _get(start: int, end: int) -> bytes:
    request = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{end}", "User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read()


def _size() -> int:
    request = urllib.request.Request(URL, method="HEAD", headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return int(response.headers["Content-Length"])


def _inner_entry() -> tuple[int, int, int]:
    """The offset of the local header, the compressed size, and the method of the inner zip."""
    size = _size()
    tail = _get(max(0, size - 65536), size - 1)
    end = tail.rfind(b"PK\x05\x06")
    cd_size, cd_offset = struct.unpack("<II", tail[end + 12:end + 20])
    directory = _get(cd_offset, cd_offset + cd_size - 1)
    pos = 0
    while directory[pos:pos + 4] == b"PK\x01\x02":
        method = struct.unpack("<H", directory[pos + 10:pos + 12])[0]
        compressed = struct.unpack("<I", directory[pos + 20:pos + 24])[0]
        name_len, extra_len, comment_len = struct.unpack("<HHH", directory[pos + 28:pos + 34])
        offset = struct.unpack("<I", directory[pos + 42:pos + 46])[0]
        name = directory[pos + 46:pos + 46 + name_len].decode()
        if name == INNER:
            return offset, compressed, method
        pos += 46 + name_len + extra_len + comment_len
    raise RuntimeError(f"{INNER} is not in {URL}")


def download(folder: Path) -> Path:
    """Puts the files in folder/EOT20/ocean_tides/ (the layout of pyTMD). Returns that folder."""
    target = folder / "EOT20" / "ocean_tides"
    if target.exists() and len(list(target.glob("*_ocean_eot20.nc"))) == 17:
        return target
    target.mkdir(parents=True, exist_ok=True)
    offset, compressed, method = _inner_entry()
    header = _get(offset, offset + 29)
    name_len, extra_len = struct.unpack("<HH", header[26:30])
    start = offset + 30 + name_len + extra_len
    inner_path = folder / INNER
    inflater = zlib.decompressobj(-15) if method == 8 else None
    block = 64 << 20
    with open(inner_path, "wb") as out:
        for pos in range(start, start + compressed, block):
            data = _get(pos, min(pos + block, start + compressed) - 1)
            out.write(inflater.decompress(data) if inflater else data)
        if inflater:
            out.write(inflater.flush())
    with zipfile.ZipFile(inner_path) as inner:
        for info in inner.infolist():
            if info.filename.endswith("_ocean_eot20.nc") and not Path(info.filename).name.startswith("._"):
                info.filename = Path(info.filename).name
                inner.extract(info, target)
    inner_path.unlink()
    return target
