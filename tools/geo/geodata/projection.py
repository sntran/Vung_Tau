"""The projection of plan 0005, D4.

Map coordinates are meters in UTM zone 48N (EPSG:32648) from the game origin:
x is east and y is north. Game coordinates are X east, Y up, and Z south
(game -Z is north). So game X = map x, and game Z = -map y.
"""

import numpy as np
from pyproj import Transformer


class Projection:
    def __init__(self, origin_e: float, origin_n: float, epsg: int = 32648):
        self.epsg = epsg
        self.origin_e = origin_e
        self.origin_n = origin_n
        self._forward = Transformer.from_crs(4326, epsg, always_xy=True)
        self._inverse = Transformer.from_crs(epsg, 4326, always_xy=True)

    @classmethod
    def at(cls, lon: float, lat: float, round_m: float, epsg: int = 32648) -> "Projection":
        """Makes a projection with the origin at the point, rounded to round_m meters."""
        e, n = Transformer.from_crs(4326, epsg, always_xy=True).transform(lon, lat)
        return cls(round(e / round_m) * round_m, round(n / round_m) * round_m, epsg)

    def to_utm(self, lon, lat):
        return self._forward.transform(lon, lat)

    def to_map(self, lon, lat):
        """Degrees to map meters (x east, y north) from the origin."""
        e, n = self._forward.transform(lon, lat)
        return np.asarray(e) - self.origin_e, np.asarray(n) - self.origin_n

    def map_to_lonlat(self, x, y):
        return self._inverse.transform(np.asarray(x) + self.origin_e, np.asarray(y) + self.origin_n)

    def to_game(self, lon, lat):
        """Degrees to game (X, Z)."""
        x, y = self.to_map(lon, lat)
        return x, -y

    def game_to_lonlat(self, x, z):
        return self.map_to_lonlat(x, -np.asarray(z))

    def origin_lonlat(self) -> tuple[float, float]:
        lon, lat = self._inverse.transform(self.origin_e, self.origin_n)
        return float(lon), float(lat)


def map_to_game(coords) -> list[list[float]]:
    """Map (x, y) points to game [X, Z] points, rounded to 1 cm."""
    return [[round(float(x), 2), round(-float(y), 2)] for x, y in coords]
