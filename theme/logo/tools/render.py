"""Render every part of the logo at every scale into `../rendered`.

Scales are whole numbers of pixels per drawn pixel, not fixed pixel sizes. The
logo is 93 drawn pixels wide, so a fixed 512 would be 5.5 pixels per drawn
pixel: every asset made that way has to either blur or make some pixels wider
than others, and the unevenness crawls once the image animates. Whole-number
scales cost nothing to keep - lossless WebP run-length-encodes flat colour, so
scaling up only lengthens the runs and every scale lands within a kilobyte of
the others.

Each animated part is written twice: the animation, and the first frame as a
still. The still is what `prefers-reduced-motion` is served, so those visitors
never download the animation at all, and it is also what shows anywhere the
animation cannot play, such as print and PDF export.
"""

import os
import subprocess
import sys

import logo
import pixgrid as P

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "rendered"))
SCALES = range(1, 7)


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


def render():
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for name, build in logo.PARTS.items():
        frames = build()
        for scale in SCALES:
            stem = f"archidep-{name}-{scale}x"
            still = f"{OUT}/{stem}.png"
            P.write_png(still, frames[0], scale=scale)
            size = os.path.getsize(still)
            anim = None
            if len(frames) > 1:
                anim = _encode(frames, scale, stem)
                size = os.path.getsize(anim)
            rows.append((name, scale,
                         len(frames[0][0]) * scale, len(frames[0]) * scale,
                         os.path.getsize(still), size if anim else 0))
    return rows


def _same(path, want, scale):
    """Does a decoded frame match the grid it was built from?"""
    w, h, buf = P.read_rgba(path)
    for y in range(0, h, scale):
        for x in range(0, w, scale):
            k = (y * w + x) * 4
            got, exp = tuple(buf[k:k + 4]), want[y // scale][x // scale]
            if (got[3] != 0) if exp[3] == 0 else (got != exp):
                return False
    return True


def _delays(path):
    return [int(t) for t in subprocess.run(
        ["magick", "identify", "-format", "%T ", path],
        capture_output=True, check=True).stdout.split()]


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
    for name, build in logo.PARTS.items():
        frames = build()
        if len(frames) == 1:
            continue
        for scale in SCALES:
            bad += _check(name, scale, frames)
    return bad


if __name__ == "__main__":
    for name, scale, w, h, still, anim in render():
        print("%-7s %dx  %4dx%-4d  still %5.1f KB%s"
              % (name, scale, w, h, still / 1024,
                 "  anim %5.1f KB" % (anim / 1024) if anim else ""))
    if "--verify" in sys.argv:
        bad = verify()
        print("\n" + ("every animation round-trips exactly" if not bad
                      else "MISMATCH: " + ", ".join(bad)))
