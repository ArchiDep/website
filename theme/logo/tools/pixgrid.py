"""Reading and writing the logo's pixel grids.

The source layers in `../src` are stored at one file pixel per drawn pixel, so
the grid is unambiguous: nothing has to be inferred, and no rescaling can put a
drawn pixel half in one cell and half in another. They were originally painted
with a 5x5 brush, which `cell` still allows for, and reading verifies that every
cell is a single flat colour so a broken grid fails loudly rather than silently
averaging.

PNG writing is done here rather than with a library so the generator needs
nothing installed: nearest-neighbour upscaling of flat colour is a handful of
lines, and an image library would be the only dependency in the whole pipeline.
"""

import os
import struct
import subprocess
import zlib

SRC = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "src"))


def read_rgba(path):
    out = subprocess.run(["magick", path, "-depth", "8", "rgba:-"],
                         capture_output=True, check=True).stdout
    w, h = subprocess.run(["magick", "identify", "-format", "%w %h", path],
                          capture_output=True, check=True).stdout.decode().split()
    w, h = int(w), int(h)
    assert len(out) == w * h * 4, (len(out), w * h * 4)
    return w, h, out


def to_grid(path, cell=1):
    """Decode to a grid of RGBA tuples, one per drawn pixel."""
    w, h, data = read_rgba(path)
    assert w % cell == 0 and h % cell == 0, f"{path}: {w}x{h} is not a whole grid"
    grid = []
    for gy in range(h // cell):
        row = []
        for gx in range(w // cell):
            colour = None
            for dy in range(cell):
                for dx in range(cell):
                    i = ((gy * cell + dy) * w + gx * cell + dx) * 4
                    px = tuple(data[i:i + 4])
                    if px[3] == 0:
                        px = (0, 0, 0, 0)
                    if colour is None:
                        colour = px
                    elif px != colour:
                        raise AssertionError(
                            f"{path}: cell ({gx},{gy}) is not one flat colour")
            row.append(colour)
        grid.append(row)
    return len(grid[0]), len(grid), grid


def write_png(path, grid, scale=1):
    """Write RGBA, nearest-neighbour upscaled, with no image library."""
    rows, cols = len(grid), len(grid[0])
    raw = bytearray()
    for y in range(rows):
        for _ in range(scale):
            raw.append(0)                     # filter type 0
            for x in range(cols):
                raw.extend(bytes(grid[y][x]) * scale)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", cols * scale, rows * scale,
                                      8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
