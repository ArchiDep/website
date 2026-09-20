"""Turning a rocket defined in axis coordinates into cells on the grid.

A style describes its rocket analytically - u runs along the hull from tail to
nose, v across it - and this module classifies each grid cell by where its
centre falls. That single quantisation is the whole trick. Authoring a rocket
upright and then rotating the bitmap quantises twice, once into the upright
sprite and again into the rotated one, and the two stair-step patterns beat
against each other into ragged edges. Classifying cells against the true shape
gives edges that step in a regular period instead.

Black is added last, derived from the filled shape, so the outline cannot tear
open: the silhouette gets an outline, and cells of the body are eroded into a
band wherever they touch a part the style says to separate them from.
"""

import math

EMPTY, OUTLINE = ".", "#"
HULL, NOSE, FIN, GLASS, FLAME, CORE = "h", "n", "f", "g", "x", "y"

FRAMES = 4
FLAME_SCALE = [1.0, 0.62, 0.84, 0.45]      # per-frame exhaust length


def flame_at(u, v, frame, engine_u, half, length):
    """The exhaust, as a plume tapering away from the engine at engine_u."""
    span = length * FLAME_SCALE[frame % FRAMES]
    if not (engine_u - span <= u <= engine_u):
        return None
    t = (engine_u - u) / span                      # 0 at the engine, 1 at the tip
    outer = (half - 0.5) * (1 - t)
    if abs(v) > outer:
        return None
    core = (half - 0.5) * 0.55 * (1 - t * 2.1)
    return CORE if core > 0.3 and abs(v) <= core else FLAME


def ogive(t, sharpness=0.65):
    """Nose profile: 1 at the base (t=0), 0 at the tip (t=1)."""
    return max(0.0, (1.0 - t)) ** sharpness


def fill(style, frame, angle):
    th = math.radians(angle)
    ct, st = math.cos(th), math.sin(th)
    u0, u1 = style.u_range
    vm = style.v_max
    pts = [(u * ct + v * st, -u * st + v * ct)
           for u in (u0 - 2, u1 + 2) for v in (-vm - 2, vm + 2)]
    x0 = math.floor(min(p[0] for p in pts))
    y0 = math.floor(min(p[1] for p in pts))
    w = math.ceil(max(p[0] for p in pts)) - x0 + 1
    h = math.ceil(max(p[1] for p in pts)) - y0 + 1
    out = []
    for Y in range(h):
        row = []
        for X in range(w):
            gx, gy = X + x0, Y + y0
            row.append(style.region(gx * ct - gy * st, gx * st + gy * ct, frame))
        out.append(row)
    return out


def add_black(g, group):
    """Erode separations between parts, then outline the silhouette."""
    h, w = len(g), len(g[0])
    nb = ((1, 0), (-1, 0), (0, 1), (0, -1))

    def at(x, y):
        return g[y][x] if 0 <= x < w and 0 <= y < h else EMPTY

    eroded = [row[:] for row in g]
    for y in range(h):
        for x in range(w):
            me = g[y][x]
            if me in (EMPTY, OUTLINE):
                continue
            if group.get(me, -1) != group.get(HULL, -99):
                continue          # only the body erodes, so parts keep their size
            for dx, dy in nb:
                other = at(x + dx, y + dy)
                if other != EMPTY and group.get(other, -1) != group.get(me, -2):
                    eroded[y][x] = OUTLINE
                    break

    out = [row[:] for row in eroded]
    for y in range(h):
        for x in range(w):
            if eroded[y][x] == EMPTY and any(
                    0 <= x + dx < w and 0 <= y + dy < h
                    and eroded[y + dy][x + dx] != EMPTY for dx, dy in nb):
                out[y][x] = OUTLINE
    return out


def sprites(style, angle=26.565):
    """All frames of a style, trimmed to one common box so they overlay."""
    fr = [add_black(fill(style, f, angle), style.group) for f in range(FRAMES)]
    h, w = len(fr[0]), len(fr[0][0])
    rows = [y for y in range(h) if any(g[y][x] != EMPTY for g in fr for x in range(w))]
    cols = [x for x in range(w) if any(g[y][x] != EMPTY for g in fr for y in range(h))]
    return [[[g[y][x] for x in range(cols[0], cols[-1] + 1)]
             for y in range(rows[0], rows[-1] + 1)] for g in fr]
