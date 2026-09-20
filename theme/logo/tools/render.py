"""Render the logo, its parts and the icons into `course/favicons`.

They are written straight into the directory the course build publishes from, so
there is one copy of each file rather than a rendered set here and a published
set there.

Scales are whole numbers of pixels per drawn pixel, not fixed pixel sizes. The
logo is 93 drawn pixels wide, so a fixed 512 would be 5.5 pixels per drawn
pixel: every asset made that way has to either blur or make some pixels wider
than others, and the unevenness crawls once the image animates. Whole-number
scales cost almost nothing to keep - lossless WebP run-length-encodes flat
colour, so scaling up only lengthens the runs.

The icons are the exception. Their sizes are fixed by what browsers ask for and
none is a whole multiple of the artwork, so they are resampled down from a large
render and are soft as a result. Drawing them at their own sizes would be
better; the generated rocket cannot do it, because its outline is one cell thick
whatever the size and at icon sizes the black eats the hull.
"""

import os
import subprocess
import sys

import logo
import pixgrid as P

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "course", "favicons"))

# Which scales of each part to write, chosen from the size it is shown at and
# the device pixel ratios worth serving. The whole logo heads the course home
# page at 186 CSS pixels, which is 2x, and the idle laptop heads the dashboard's
# login page at the same size; the rocket and the cup are shown small.
# Everything written here is published, so unused scales are not rendered.
SCALES = {"logo": (2, 4, 6), "desk": (2, 4, 6), "rocket": (1, 2, 3),
          "coffee": (1, 2, 3)}

# Only the logo and the cup animate. The rocket is shown small, in the header
# and the sidebar, where the exhaust would be a distraction rather than a
# detail, so it is written as a still.
STILL_ONLY = {"rocket"}

# Sizes browsers ask for, and the part each icon set is drawn from.
ICON_SIZES = [16, 32, 48, 96, 180, 192]
ICON_SETS = {"archidep-rocket": "rocket", "archidep": "logo"}
ICO_SIZES = [16, 32, 48]


def _encode(frames, scale, stem):
    tmp = os.path.join(OUT, ".frames")
    paths = []
    for i, g in enumerate(frames):
        p = f"{tmp}/{stem}-{i:02d}.png"
        P.write_png(p, g, scale=scale)
        paths.append(p)
    anim = f"{OUT}/{stem}.webp"
    subprocess.run(["magick", "-dispose", "background",
                    "-delay", str(round(logo.FRAME_MS / 10)), "-loop", "0",
                    *paths, "-define", "webp:lossless=true", anim], check=True)
    for p in paths:
        os.remove(p)
    os.rmdir(tmp)
    return anim


def parts():
    rows = []
    for name, scales in SCALES.items():
        frames = logo.PARTS[name]()
        for scale in scales:
            stem = f"archidep-{name}-{scale}x"
            still = f"{OUT}/{stem}.png"
            P.write_png(still, frames[0], scale=scale)
            animated = len(frames) > 1 and name not in STILL_ONLY
            size = os.path.getsize(_encode(frames, scale, stem)) if animated \
                else os.path.getsize(still)
            rows.append((stem, len(frames[0][0]) * scale, len(frames[0]) * scale,
                         os.path.getsize(still), size if animated else 0))
    return rows


def icons():
    """Square icons, resampled down from the largest render of each part.

    These are the only files here an image library writes, and it stamps each
    one with the time it was written unless stripped of everything that is not
    the picture. Left in, that stamp makes every icon a changed file on every
    run whether or not a pixel moved, which buries a real change in a dozen
    spurious ones.
    """
    rows = []
    for prefix, part in ICON_SETS.items():
        source = f"{OUT}/archidep-{part}-{max(SCALES[part])}x.png"
        for size in ICON_SIZES:
            path = f"{OUT}/{prefix}-{size}.png"
            subprocess.run(
                ["magick", source,
                 # fit inside the square, then centre it on a transparent one
                 "-resize", f"{size}x{size}",
                 "-background", "none", "-gravity", "center",
                 "-extent", f"{size}x{size}", "-strip", path], check=True)
            rows.append((os.path.basename(path), size, size,
                         os.path.getsize(path), 0))
    ico = os.path.normpath(os.path.join(OUT, "..", "favicon.ico"))
    subprocess.run(["magick",
                    *[f"{OUT}/archidep-rocket-{s}.png" for s in ICO_SIZES],
                    ico], check=True)
    rows.append(("favicon.ico", 0, 0, os.path.getsize(ico), 0))
    return rows


def _delays(path):
    return [int(t) for t in subprocess.run(
        ["magick", "identify", "-format", "%T ", path],
        capture_output=True, check=True).stdout.split()]


def _same(path, want, scale):
    w, h, buf = P.read_rgba(path)
    for y in range(0, h, scale):
        for x in range(0, w, scale):
            k = (y * w + x) * 4
            got, exp = tuple(buf[k:k + 4]), want[y // scale][x // scale]
            if (got[3] != 0) if exp[3] == 0 else (got != exp):
                return False
    return True


def _check(name, scale, frames):
    """Which source frame each kept frame stands for, then compare."""
    path = f"{OUT}/archidep-{name}-{scale}x.webp"
    delays = _delays(path)
    starts, at = [], 0
    for d in delays:
        starts.append(at * 10 // logo.FRAME_MS)
        at += d
    bad = []
    if at * 10 != len(frames) * logo.FRAME_MS:
        bad.append(f"{name} {scale}x total duration")
    tmp = os.path.join(OUT, ".verify")
    os.makedirs(tmp, exist_ok=True)
    subprocess.run(["magick", path, "-coalesce", f"{tmp}/f-%02d.png"], check=True)
    for j in range(len(delays)):
        if not _same(f"{tmp}/f-{j:02d}.png", frames[starts[j]], scale):
            bad.append(f"{name} {scale}x frame {j}")
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    return bad


def verify():
    """Every animation must decode back to the frames it was built from.

    The encoder collapses runs of identical frames into one with a longer
    delay, and because the parts change on cycles that interleave unevenly
    those delays are not all equal. So which source frame a kept frame stands
    for has to be found by accumulating the delays, not by assuming each kept
    frame covers the same span.
    """
    bad = []
    for name, scales in SCALES.items():
        frames = logo.PARTS[name]()
        if len(frames) == 1 or name in STILL_ONLY:
            continue
        for scale in scales:
            bad += _check(name, scale, frames)
    return bad


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for stem, w, h, still, anim in parts() + icons():
        print("%-26s %4dx%-4d  %5.1f KB%s"
              % (stem, w, h, still / 1024,
                 "  anim %5.1f KB" % (anim / 1024) if anim else ""))
    if "--verify" in sys.argv:
        bad = verify()
        print("\n" + ("every animation round-trips exactly" if not bad
                      else "MISMATCH: " + ", ".join(bad)))
