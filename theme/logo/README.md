# Logo

The ArchiDep logo: a rocket launching off a laptop screen, next to a cup of
coffee. It is 8-bit pixel art, hand-drawn on a strict grid, and it animates —
the exhaust burns, the steam drifts, and the light on the coffee shifts.

Both halves of the project use it, which is why it lives with the theme rather
than with either one: the whole logo heads the course home page, the rocket
sits in the header, the cup sits in the sidebar footer, and the laptop with
nothing launching off it heads the dashboard's login page.

## What is here

- `src/`: the hand-drawn source, one file pixel per drawn pixel. `laptop.png`
  (93×58) and `coffee.png` (27×31) are drawn by hand and are the only
  irreplaceable files in this directory. `rocket.png` (42×75) is the original
  upright rocket, kept because the rocket in the logo is built from its
  proportions rather than from the drawing itself.
- `tools/`: the generator, in dependency-free Python. It needs only a Python 3
  interpreter and ImageMagick.

What it produces is written straight into
[`course/favicons`](../../course/favicons), the directory the course build
publishes from, and committed there, so there is one copy of each file and no
build step needs Python or ImageMagick.

## The grid

Every drawn pixel is one cell. The source files store one cell per file pixel,
so nothing has to be inferred and no rescaling can put a drawn pixel half in one
cell and half in another. Reading a layer verifies that each cell is a single
flat colour, so a broken grid fails loudly instead of silently averaging.

The rocket is the exception: it is not drawn but [generated](tools/rocket.py)
from a description of its shape, because it is slanted. Rotating pixel art tears
it — the drawing is already on a grid, and rotating the bitmap lands it on a
second one, so the two stair-step patterns fight and the edges come out ragged.
Describing the rocket in its own axis coordinates and asking each cell which
part it falls in quantises once instead of twice, and the edges step in a
regular period.

## Colours

The palette is [PICO-8][pico8]'s, applied to the whole logo rather than to the
rocket alone: a PICO-8 rocket against the laptop's original greys reads as
half-converted, because those greys belong to no particular palette. The mapping
is in [`tools/colours.py`](tools/colours.py).

## The animation

Three things move, on cycles of different lengths so they never visibly
lock-step:

- the **exhaust** flickers, a new shape every frame;
- the **steam** drifts, each pose held four frames;
- the **reflection** on the coffee shifts by a single cell, each pose held six.

At 150 ms a frame that is 0.6 s, 1.8 s and 3.6 s respectively, and the whole
logo loops in 24 frames. Poses are held rather than given their own frame rate
so the motion stays stepped — smooth tweening would fight the 8-bit style, and
steam that drifted as fast as flame flickers would look frantic.

Each animation is accompanied by its first frame as a still. That still is what
`prefers-reduced-motion` visitors are served, so they never download the
animation at all, and it is what appears anywhere the animation cannot play,
such as print and PDF export.

## The idle laptop

The login page shows the same laptop and cup with no rocket, because nothing has
been launched yet. An idle machine needs something on its screen, so the screen
becomes the moving part in the exhaust's place: bands of colour sliding
diagonally across it, a screen saver.

The glare is not painted over. It is the room reflected in the glass rather than
part of the picture on the screen, so it stays where the hand drew it and
lightens whatever an effect has put behind it, which is what keeps the screen
reading as glass. Its blue is the one the hand drew rather than a computed one,
so the phase the bars pass through matches the logo's screen exactly. The effect
is in [`tools/screen.py`](tools/screen.py).

Its loop has to close against the cup's. The two are composed into one animation
whose length is the lowest common multiple of both, so an effect whose period
shares no factor with the cup's 24 frames makes that multiple enormous;
eight-cell bars in three colours come back to where they started after 24 frames
as well.

## Sizes

Assets are rendered at whole numbers of pixels per drawn pixel rather than at
fixed pixel sizes — the whole logo and the idle laptop at 2×, 4× and 6×, the
rocket and the cup at 1×, 2× and 3×, each chosen from the size it is shown at
and the device pixel ratios worth serving. A fixed size that is not a whole
multiple of the artwork forces every pixel to be either blurred or unevenly
widened, and once the image animates that unevenness crawls. The logo is 93
drawn pixels wide, so a 512-pixel-wide asset would be 5.5 pixels per drawn
pixel.

Displayed sizes should be whole multiples too. 93 drawn pixels at 2× is 186 CSS
pixels; serving 4× and 6× alongside lets displays at device pixel ratios of 2
and 3 land on whole numbers as well. Device pixel ratios that are themselves
fractional, such as 1.5, cannot be made exact by any choice of asset.

Keeping every scale costs almost nothing. Lossless WebP run-length-encodes flat
colour, so scaling up only lengthens the runs: every scale of the whole logo
lands between 3 and 5 KB, and the 6× is smaller than the 3×.

The icons browsers ask for are the exception. None of 16, 32, 48, 96, 180 or 192
is a whole multiple of the artwork, so they are resampled down from the largest
render and are soft at the smallest sizes. Drawing them at their own sizes would
be better, and the generated rocket cannot do it: its outline is one cell thick
whatever the size, so below about 23 cells across the black eats the hull.

## Regenerating

```bash
cd theme/logo/tools && python3 render.py --verify
```

This rewrites every logo, part and icon in `course/favicons`, and `favicon.ico`
beside it. `--verify` decodes each animation back and checks it against the
frames it was built from, cell by cell; it is worth running, because the encoder
collapses runs of identical frames into one with a longer delay and the result
should still be exactly what was intended.

A file added or dropped here has to be added to or dropped from the list of
files a build publishes, in
[`ArchiDep.CourseSite.Build`](../../app/lib/archidep/course_site/build.ex).

To change the artwork, edit a file in `src/` at one pixel per drawn pixel and
regenerate. To change the rocket's shape or size, or the timing, see
[`tools/rocket.py`](tools/rocket.py) and [`tools/logo.py`](tools/logo.py).

## Attribution

The palette is from [PICO-8][pico8] by Lexaloffle Games.

[pico8]: https://www.lexaloffle.com/pico-8.php
