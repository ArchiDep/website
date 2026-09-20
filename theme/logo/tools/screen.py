"""What the laptop shows when nothing is launching off it.

The logo's laptop has a rocket on its screen. A laptop drawn without one needs
something there, and a screen saver is what an idle machine shows — so the
screen becomes the moving part, in place of the exhaust.

The effect draws only the picture on the screen. The glare is not part of that
picture: it is the room reflected in the glass, so it stays where the hand drew
it and lightens whatever is behind it instead of being painted over. That is
what keeps the screen reading as glass rather than as a coloured rectangle.

The effect loops in a whole number of frames, because the mug beside it loops in
24 and the two are composed into one animation whose length is the lowest common
multiple of both. A period sharing no factor with 24 makes that multiple
enormous: eight-cell bars in three colours come back to where they started after
24 frames, so the pair loops in 24 as well.
"""

import colours

W, H = 54, 30                  # the screen, in cells


class Bars:
    """Bands of colour sliding diagonally across the screen.

    They run the other way from the glare so that they cross it rather than
    lining up with it, which is what shows that one is on the glass and the
    other behind it. They advance a cell a frame, slowly enough to read as an
    idle machine rather than as something happening.
    """

    def __init__(self, palette, width=8):
        self.palette, self.width = palette, width
        self.period = width * len(palette)

    def content(self, i):
        n = len(self.palette)
        return [[self.palette[((x + y + i) // self.width) % n] for x in range(W)]
                for y in range(H)]


BARS = Bars([colours.NAVY, colours.INDIGO, colours.BLUE])
