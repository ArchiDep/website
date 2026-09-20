"""Assembling the logo and its parts: laptop, rocket in its screen, mug in front.

The three moving parts run on different cycle lengths - the exhaust every 4
frames, the steam every 12, the reflection every 24 - so they never visibly
lock-step. Each loop is the lowest common multiple of the parts it contains,
which is why the mug alone and the whole logo both loop in 24 frames while the
rocket alone loops in 4.

The parts are emitted separately as well as composed because the site uses them
separately: the whole logo heads the course home page, the rocket sits in the
header, and the mug sits in the sidebar footer.
"""

import math

import coffee
import colours
import pixgrid as P
import raster
from rocket import Rocket

LAPTOP_AT = (2, 16)            # in cells, as in the original composite
COFFEE_AT = (4, 40)
SCREEN = (19, 4, 54, 30)       # x, y, w, h of the screen within the laptop
CANVAS = (98, 76)

ROCKET_SIZE = 11               # hull thickness in cells; see rocket.Rocket
FRAME_MS = 150                 # duration of one frame

MUG_CYCLE = math.lcm(coffee.STEAM_PERIOD, coffee.SHINE_PERIOD)
LOGO_CYCLE = math.lcm(raster.FRAMES, MUG_CYCLE)


def _paste(dst, src, at):
    ox, oy = at
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c[3]:
                dst[oy + y][ox + x] = c


def laptop():
    _, _, g = P.to_grid(f"{P.SRC}/laptop.png")
    return colours.convert(g)


def rockets():
    return [[[colours.ROCKET[c] for c in row] for row in s]
            for s in raster.sprites(Rocket(ROCKET_SIZE))]


def mugs():
    return [colours.paint_mug(coffee.frame(i)) for i in range(MUG_CYCLE)]


def composite():
    lap, rocket = laptop(), rockets()
    sx, sy, sw, sh = SCREEN
    ox = LAPTOP_AT[0] + sx + (sw - len(rocket[0][0])) // 2
    oy = LAPTOP_AT[1] + sy + (sh - len(rocket[0])) // 2
    out = []
    for i in range(LOGO_CYCLE):
        w, h = CANVAS
        g = [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]
        _paste(g, lap, LAPTOP_AT)
        _paste(g, rocket[i % raster.FRAMES], (ox, oy))
        _paste(g, colours.paint_mug(coffee.frame(i)), COFFEE_AT)
        out.append(g)
    return out


def crop(grids):
    """Trim every frame to one common box, so they stay registered."""
    h, w = len(grids[0]), len(grids[0][0])
    rows = [y for y in range(h) if any(g[y][x][3] for g in grids for x in range(w))]
    cols = [x for x in range(w) if any(g[y][x][3] for g in grids for y in range(h))]
    return [[[g[y][x] for x in range(cols[0], cols[-1] + 1)]
             for y in range(rows[0], rows[-1] + 1)] for g in grids]


PARTS = {
    "logo": lambda: crop(composite()),
    "rocket": lambda: crop(rockets()),
    "coffee": lambda: crop(mugs()),
    "laptop": lambda: [laptop()],
}


if __name__ == "__main__":
    for name, build in PARTS.items():
        fr = build()
        print("%-7s %2d frame(s)  %d x %d cells  %.1fs"
              % (name, len(fr), len(fr[0][0]), len(fr[0]),
                 len(fr) * FRAME_MS / 1000))
