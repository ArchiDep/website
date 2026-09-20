"""The coffee mug, animated: rising steam and a shifting reflection.

The mug is decoded from the hand-pixelated layer rather than redrawn - it is
already on the grid and already contains both the steam wisp and the reflection
on the coffee's surface. Animating it means moving those cells, not drawing new
art.

The steam sways as a wave travelling up the wisp, which is how steam reads in a
few frames without tweening. Only the rows clear of the mug's rim move; below
it the wisp is tangled with the rim's own cells and shifting them would tear
the mug.
"""

import math
import pixgrid as P

EMPTY, BLACK, MUG, COFFEE, STEAM, SHINE = ".", "#", "W", "K", "c", "t"

SYMBOL = {
    (0, 0, 0, 0): EMPTY,
    (0, 0, 0, 255): BLACK,
    (255, 255, 255, 255): MUG,
    (105, 68, 56, 255): COFFEE,
    (247, 218, 168, 255): STEAM,
    (221, 161, 110, 255): SHINE,
}

RIM_Y = 6              # first row where the wisp meets the mug; below it, static

# Steam drifts and the reflection shimmers far more slowly than the exhaust
# flickers, so each of their poses is held for several frames rather than being
# given its own frame rate. Holding also keeps the motion stepped rather than
# smooth, which is the look we want.
STEAM_POSES, STEAM_HOLD = 3, 4     # a full sway every 12 frames
SHINE_POSES, SHINE_HOLD = 4, 6     # a full shimmer every 24
SHINE_DX = [0, 1, 0, -1]           # never more than a cell

STEAM_PERIOD = STEAM_POSES * STEAM_HOLD
SHINE_PERIOD = SHINE_POSES * SHINE_HOLD


def base():
    _, _, g = P.to_grid(f"{P.SRC}/coffee.png")
    return [[SYMBOL[c] for c in row] for row in g]


def sway(y, pose):
    """Horizontal offset of the wisp at row y, as a wave travelling upward.

    The amplitude grows toward the top, where the steam is furthest from the
    cup and freest to drift, and falls to zero at the lowest free row so the
    wisp stays joined to the cup. The wavelength is long enough that
    neighbouring rows never shift apart by more than a cell, which is what
    keeps the wisp from breaking into pieces.
    """
    anchor = RIM_Y - 1
    amp = 1.15 * (anchor - y) / anchor
    phase = 2 * math.pi * (pose / STEAM_POSES) + y * (2 * math.pi / 9.0)
    return round(amp * math.sin(phase))


def frame(i):
    g = base()
    h, w = len(g), len(g[0])
    out = [row[:] for row in g]

    # Steam: shift each free row of the wisp sideways.
    for y in range(RIM_Y):
        dx = sway(y, (i // STEAM_HOLD) % STEAM_POSES)
        out[y] = [EMPTY] * w
        for x in range(w):
            if g[y][x] == STEAM and 0 <= x + dx < w:
                out[y][x + dx] = STEAM

    # Reflection: lift it off the surface, then lay it back down shifted.
    dx = SHINE_DX[(i // SHINE_HOLD) % SHINE_POSES]
    shine = [(x, y) for y in range(h) for x in range(w) if g[y][x] == SHINE]
    for x, y in shine:
        out[y][x] = COFFEE
    for x, y in shine:
        nx = x + dx
        if 0 <= nx < w and out[y][nx] == COFFEE:
            out[y][nx] = SHINE
    return out


def frames(n):
    return [frame(i) for i in range(n)]
