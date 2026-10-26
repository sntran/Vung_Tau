"""The heights of the intertidal zone from satellite images and the tide
(plan 0005, R8g), with the pixel method of DEA Intertidal (Geoscience
Australia): each image shows each pixel wet or dry, the tide model gives the
sea level at the time of the image, and the height of the pixel is the sea
level where it changes from dry to wet."""

import numpy as np

# A pixel is intertidal when this many of its clear images, or more, are wet
# above its height, and this many, or more, are dry below it (report 0005, D-0005-06: a share of the
# images stopped the data at about -1.55 m, because few images have the sea
# lower).
MIN_WET = 5
MIN_DRY = 5
# A pixel gets no value when more than this part of its clear images
# disagrees with its height (wet above it or dry below it).
MAX_ERROR = 0.2
# The values of an observation.
UNCLEAR, DRY, WET = -1, 0, 1


def elevations(tides: np.ndarray, observations: np.ndarray, min_wet: int = MIN_WET, min_dry: int = MIN_DRY,
               max_error: float = MAX_ERROR) -> tuple[np.ndarray, np.ndarray]:
    """The height of each pixel.

    tides is the sea level (m) at the time of each image, shape (N,).
    observations is UNCLEAR, DRY, or WET for each image and pixel, shape (N, ...).
    Returns the heights (NaN where the pixel has no value) and the number of
    clear images of each pixel.

    A pixel at the height e is wet when the sea is above e. For each height
    between two sorted sea levels, the errors are the wet images with a lower
    sea level and the dry images with a higher sea level. The height with the
    fewest errors is the middle between the two sea levels (when some heights
    have the same fewest errors, the middle one of them).
    """
    order = np.argsort(tides)
    levels = np.asarray(tides, dtype=np.float64)[order]
    obs = observations[order]
    shape = obs.shape[1:]
    obs = obs.reshape(len(levels), -1)
    wet = (obs == WET).astype(np.int32)
    dry = (obs == DRY).astype(np.int32)
    clear = wet.sum(axis=0) + dry.sum(axis=0)
    # errors[k] for a height between levels[k - 1] and levels[k]: the wet
    # images below (index < k) and the dry images above (index >= k).
    wet_below = np.vstack([np.zeros((1, wet.shape[1]), np.int32), np.cumsum(wet, axis=0)])
    dry_below = np.vstack([np.zeros((1, dry.shape[1]), np.int32), np.cumsum(dry, axis=0)])
    errors = wet_below + (dry_below[-1] - dry_below)
    # When some places have the same fewest errors, take the middle one.
    fewest = errors == errors.min(axis=0)
    first = np.argmax(fewest, axis=0)
    last = len(levels) - np.argmax(fewest[::-1], axis=0)
    best = (first + last) // 2
    # The middle between the sea levels around the best place.
    padded = np.concatenate([[levels[0]], levels, [levels[-1]]])
    height = (padded[best] + padded[best + 1]) / 2.0
    columns = np.arange(errors.shape[1])
    error_share = errors[best, columns] / np.maximum(clear, 1)
    # Only the images that agree with the height count: the dry images below it
    # and the wet images above it. A few wrong images (a boat, a wave) do not
    # give a value to a pixel that is always wet or always dry.
    dry_below_height = dry_below[best, columns]
    wet_above_height = wet_below[-1] - wet_below[best, columns]
    valid = (wet_above_height >= min_wet) & (dry_below_height >= min_dry) & (error_share <= max_error)
    height = np.where(valid, height, np.nan).astype(np.float32)
    return height.reshape(shape), clear.reshape(shape)


def water_index(green: np.ndarray, nir: np.ndarray) -> np.ndarray:
    """The normalized difference water index (NDWI) from the green and the near-infrared bands."""
    g = green.astype(np.float32)
    n = nir.astype(np.float32)
    return (g - n) / np.maximum(g + n, 1.0)


# The scene classes of Sentinel-2 L2A that are not clear: no data, saturated,
# cloud shadow, cloud (medium and high probability), and thin cirrus.
NOT_CLEAR = (0, 1, 3, 8, 9, 10)


def observe(green: np.ndarray, nir: np.ndarray, scl: np.ndarray) -> np.ndarray:
    """WET, DRY, or UNCLEAR for each pixel of one image. scl has the size of green."""
    result = np.where(water_index(green, nir) > 0.0, WET, DRY).astype(np.int8)
    result[np.isin(scl, NOT_CLEAR) | (green == 0)] = UNCLEAR
    return result
