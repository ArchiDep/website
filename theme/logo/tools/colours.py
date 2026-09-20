"""PICO-8 colour assignments for the logo.

The whole logo is converted, not just the rocket: a PICO-8 rocket against the
laptop's original greys and blues reads as half-finished, because those greys
belong to no particular palette.
"""

from raster import EMPTY, OUTLINE, HULL, NOSE, FIN, GLASS, FLAME, CORE


def _rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# The PICO-8 palette, by its usual indices.
P8 = {i: _rgb(c) for i, c in enumerate([
    "000000", "1D2B53", "7E2553", "008751", "AB5236", "5F574F", "C2C3C7",
    "FFF1E8", "FF004D", "FFA300", "FFEC27", "00E436", "29ADFF", "83769C",
    "FF77A8", "FFCCAA"])}

BLACK, WHITE, RED, ORANGE, YELLOW, BLUE = P8[0], P8[7], P8[8], P8[9], P8[10], P8[12]
GREY, DARKGREY, BROWN, PEACH = P8[6], P8[5], P8[4], P8[15]

ROCKET = {
    EMPTY: (0, 0, 0, 0),
    OUTLINE: BLACK,
    HULL: WHITE,
    NOSE: RED,
    FIN: RED,
    GLASS: BLUE,
    FLAME: ORANGE,
    CORE: YELLOW,
}

# The laptop layer's own colours, mapped into the palette. The screen's two
# blues must stay distinguishable, so the lighter one gets its own value rather
# than collapsing onto PICO-8's blue.
LAPTOP_MAP = {
    (0, 0, 0, 255): BLACK,
    (205, 205, 205, 255): GREY,
    (95, 95, 95, 255): DARKGREY,
    (117, 174, 203, 255): BLUE,
    (136, 186, 209, 255): _rgb("83DDFF"),
}

# The mug, by the symbols `coffee` decodes it into. The reflection on the
# surface needs its own value: mapping it and the coffee both onto PICO-8's
# brown erases it, which is what the hand-drawn layer's tan streak is for.
MUG_MAP = {
    ".": (0, 0, 0, 0),
    "#": BLACK,
    "W": WHITE,
    "K": BROWN,
    "c": PEACH,        # steam
    "t": ORANGE,       # reflection on the coffee
}


def convert(grid):
    return [[LAPTOP_MAP.get(c, c) for c in row] for row in grid]


def paint_mug(grid):
    return [[MUG_MAP[c] for c in row] for row in grid]
