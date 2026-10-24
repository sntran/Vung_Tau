"""The sea level from tide constituents (plan 0003, D12, R8f).

This is the same calculation as pyTMD with the FES nodal corrections, for
the constituents of EOT20. The game has the same code in
scripts/geo/tide.gd. tide.py makes sure that this code agrees with pyTMD.

The sea level is the sum of f · A · cos(G + u − g) for each constituent:
  A, g  the amplitude and the phase lag from the tide model,
  G     the astronomical argument from the Doodson numbers,
  f, u  the nodal corrections (Schureman, "Manual of harmonic analysis and
        prediction of tides", 1958).
"""

import numpy as np

MJD_UNIX = 40587.0
MJD_J2000 = 51544.5
CENTURY = 36525.0

# The nodal correction of each constituent of EOT20.
NODAL = {
    "2n2": "m2", "j1": "j1", "k1": "k1", "k2": "k2", "m2": "m2", "m4": "m4", "mf": "mf", "mm": "mm",
    "n2": "m2", "o1": "o1", "p1": "none", "q1": "o1", "s1": "none", "s2": "none", "sa": "none",
    "ssa": "none", "t2": "none",
}


def _poly(coefficients, t):
    return sum(c * t ** i for i, c in enumerate(coefficients))


def mean_longitudes(mjd):
    """S, H, P, N, Ps in degrees (Meeus, the ASTRO5 terms in pyTMD)."""
    t = (np.asarray(mjd, dtype=float) - MJD_J2000) / CENTURY
    moon = np.array([218.3164477, 481267.88123421, -1.5786e-3, 1.855835e-6, -1.53388e-8])
    elongation = np.array([297.8501921, 445267.1114034, -1.8819e-3, 1.83195e-6, -8.8445e-9])
    s = _poly(moon, t)
    h = _poly(moon - elongation, t)
    p = _poly([83.3532465, 4069.0137287, -1.032e-2, -1.249172e-5], t)
    n = _poly([125.04452, -1934.136261, 2.0708e-3, 2.22222e-6], t)
    ps = 282.94 + 1.7192 * t
    return tuple(np.mod(x, 360.0) for x in (s, h, p, n, ps))


def schureman(n_deg):
    """I, ξ, ν, ν′, ν″ in radians from N (Schureman, pages 156, 45, and 46)."""
    n = np.radians(n_deg)
    i = np.arccos(0.913694997 - 0.035692561 * np.cos(n))
    at1 = np.arctan(1.01883 * np.tan(n / 2.0))
    at2 = np.arctan(0.64412 * np.tan(n / 2.0))
    xi = -at1 - at2 + n
    xi = np.arctan2(np.sin(xi), np.cos(xi))
    nu = at1 - at2
    nu_p = np.arctan(np.sin(2.0 * i) * np.sin(nu) / (np.sin(2.0 * i) * np.cos(nu) + 0.3347))
    nu_s = 0.5 * np.arctan(np.sin(i) ** 2 * np.sin(2.0 * nu) / (np.sin(i) ** 2 * np.cos(2.0 * nu) + 0.0727))
    return i, xi, nu, nu_p, nu_s


def nodal(kind: str, i, xi, nu, nu_p, nu_s):
    """The factor f and the angle u (radians) of one kind of nodal correction."""
    if kind == "m2":
        return np.cos(i / 2.0) ** 4 / 0.9154, 2.0 * xi - 2.0 * nu
    if kind == "m4":
        f, u = nodal("m2", i, xi, nu, nu_p, nu_s)
        return f * f, 2.0 * u
    if kind == "o1":
        return np.sin(i) * np.cos(i / 2.0) ** 2 / 0.38, 2.0 * xi - nu
    if kind == "k1":
        return np.sqrt(0.8965 * np.sin(2.0 * i) ** 2 + 0.6001 * np.sin(2.0 * i) * np.cos(nu) + 0.1006), -nu_p
    if kind == "k2":
        return np.sqrt(19.0444 * np.sin(i) ** 4 + 2.7702 * np.sin(i) ** 2 * np.cos(2.0 * nu) + 0.0981), -2.0 * nu_s
    if kind == "j1":
        return np.sin(2.0 * i) / 0.7214, -nu
    if kind == "mf":
        return np.sin(i) ** 2 / 0.1578, -2.0 * xi
    if kind == "mm":
        return (2.0 / 3.0 - np.sin(i) ** 2) / 0.5021, 0.0 * xi
    return 1.0 + 0.0 * xi, 0.0 * xi


def level(tide: dict, point: str, unix_seconds) -> np.ndarray:
    """The sea level in meters above mean sea level at the times (seconds since 1970, UTC)."""
    mjd = np.asarray(unix_seconds, dtype=float) / 86400.0 + MJD_UNIX
    s, h, p, n, ps = mean_longitudes(mjd + tide["tt_minus_ut1_s"] / 86400.0)
    hour = 24.0 * np.mod(mjd, 1.0)
    tau = 15.0 * hour - s + h
    args = np.stack([tau, s, h, p, n, ps, 90.0 + 0.0 * tau], axis=-1)
    i, xi, nu, nu_p, nu_s = schureman(n)
    total = np.zeros_like(mjd)
    constants = tide["points"][point]["constituents"]
    for c in tide["constituents"]:
        name = c["name"]
        g = np.radians(args @ np.array(c["doodson"], dtype=float))
        f, u = nodal(c["nodal"], i, xi, nu, nu_p, nu_s)
        amplitude = constants[name]["amplitude"]
        phase = np.radians(constants[name]["phase"])
        total = total + f * amplitude * np.cos(g + u - phase)
    return total
