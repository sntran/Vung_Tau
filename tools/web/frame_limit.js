// Plan 0031, R18 (changed 2026-11-27): the longest frame while a pack loads is
// at most the median frame of the same run plus OVER_MEDIAN_MS. The game counts
// the frames after "can move" (window.vungTau.frames: count, medianMs,
// longestMs). check.js --measure and PT-85 use this rule; the Python test
// tools/web/tests/test_frame_limit.py checks it.
'use strict';

const OVER_MEDIAN_MS = 250;

// The limit of a run (ms), or null when the run has no frames after "can move".
function packFrameLimitMs(frames) {
  if (!frames || !frames.count) return null;
  return Math.round((frames.medianMs + OVER_MEDIAN_MS) * 10) / 10;
}

// The packs of a row of the measure whose longest frame is over the limit, in words.
function packFrameFailures(r) {
  const packs = Object.entries(r.packs || {}).filter(([, p]) => (p.times || {}).longestFrameMs !== undefined);
  if (!packs.length) return [];
  const limit = packFrameLimitMs(r.frames);
  if (limit === null) return [`${r.label}: no median frame of the run`];
  return packs.filter(([, p]) => p.times.longestFrameMs > limit)
    .map(([id, p]) => `${r.label}: the pack ${id}, a frame of ${p.times.longestFrameMs} ms (the median frame ${Math.round(r.frames.medianMs)} ms, the limit ${Math.round(limit)} ms)`);
}

module.exports = { OVER_MEDIAN_MS, packFrameLimitMs, packFrameFailures };
