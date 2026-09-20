"""The rocket, defined analytically in its own axis coordinates.

u runs along the hull from tail to nose and v across it; `raster` turns that
into cells. `size` is the hull thickness in cells and every other length
derives from it, so the rocket rescales by changing that one number.
"""

from raster import EMPTY, HULL, NOSE, FIN, GLASS, FLAME, CORE, flame_at, ogive

# Parts the hull is separated from by a black band.
BODY = {HULL: 0, NOSE: 1, FIN: 2, FLAME: 3, CORE: 3, GLASS: 4}


class Rocket:
    """Cone, cylinder, swept fins, exhaust plume."""
    group = BODY

    def __init__(self, size=11):
        h = self.h = size
        self.half = h / 2.0
        self.hull_len = 2.06 * h
        self.nose_len = 1.11 * h
        self.flame_len = 0.89 * h
        self.fin_reach = 1.33 * h / 2.0
        self.nose_u1 = self.hull_len + self.nose_len
        self.fin_u0 = 0.06 * self.hull_len
        self.fin_u1 = self.fin_u0 + 0.72 * h
        self.port_u = 0.72 * self.hull_len
        self.port_r = max(2.0, h / 4.0)

    @property
    def u_range(self):
        return (-self.flame_len, self.nose_u1)

    @property
    def v_max(self):
        return self.half + self.fin_reach

    def region(self, u, v, frame):
        av = abs(v)
        f = flame_at(u, v, frame, 0.0, self.half, self.flame_len)
        if f:
            return f
        if 0 <= u <= self.hull_len and av <= self.half:
            if abs(u - self.port_u) + av <= self.port_r:
                return GLASS
            return HULL
        if self.hull_len <= u <= self.nose_u1 and av <= self.half * ogive(
                (u - self.hull_len) / self.nose_len, 1.0):
            return NOSE
        if self.fin_u0 <= u <= self.fin_u1:
            t = (self.fin_u1 - u) / (self.fin_u1 - self.fin_u0)
            if self.half <= av <= self.half + self.fin_reach * t:
                return FIN
        return EMPTY
