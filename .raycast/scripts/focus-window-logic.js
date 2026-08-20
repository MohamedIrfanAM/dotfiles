#!/usr/bin/env osascript -l JavaScript
// focus-window-logic.js
// Usage: osascript -l JavaScript focus-window-logic.js <left|right|up|down>
//
// Geometry-only directional window focus. Looks at every on-screen,
// non-minimized window across all visible apps, scores them relative
// to the currently focused window's center point, and raises/activates
// the best match in the requested direction.
//
// Perf notes: the biggest cost in this kind of script is round-trips to
// System Events, not JS execution. Every property read (position, size,
// minimized...) is its own Accessibility Apple Event. So this version:
//   1. Filters processes/windows server-side with whose() instead of
//      pulling everything and checking in JS.
//   2. Reads each window's geometry in one bulk properties() call
//      instead of 3 separate calls (position, size, minimized).
//   3. Skips background-only processes entirely (whose({visible:true})).

function run(argv) {
  const direction = (argv[0] || '').toLowerCase();
  const VALID = ['left', 'right', 'up', 'down'];
  if (!VALID.includes(direction)) {
    return 'Usage: focus-window-logic.js <left|right|up|down>';
  }

  const DEADZONE = 10; // px - ignore near-zero deltas so we don't "focus" the current window

  const SE = Application('System Events');
  SE.includeStandardAdditions = true;

  // Only regular, visible app processes (skips menu-bar-only agents,
  // background daemons, etc.) - filtered server-side, not in JS.
  let procs;
  try {
    procs = SE.applicationProcesses.whose({ visible: true })();
  } catch (e) {
    procs = SE.applicationProcesses();
  }

  // --- Current focused window's geometry ---
  let current = null;
  let frontProc = null;
  try {
    const fp = SE.applicationProcesses.whose({ frontmost: true })();
    frontProc = fp.length ? fp[0] : null;
  } catch (e) {}

  if (frontProc) {
    try {
      let w;
      try {
        const focusedWins = frontProc.windows.whose({ focused: true })();
        w = focusedWins.length ? focusedWins[0] : frontProc.windows[0];
      } catch (e) {
        w = frontProc.windows[0];
      }
      const props = w.properties();
      const pos = props.position, size = props.size;
      current = { cx: pos[0] + size[0] / 2, cy: pos[1] + size[1] / 2 };
    } catch (e) {}
  }

  if (!current) return 'Could not determine the current focused window.';

  // --- Candidate windows: non-minimized, across visible processes ---
  let candidates = [];
  for (const proc of procs) {
    let wins;
    try {
      wins = proc.windows.whose({ minimized: false })();
    } catch (e) {
      try { wins = proc.windows(); } catch (e2) { continue; }
    }
    if (!wins.length) continue;

    let procName;
    try { procName = proc.name(); } catch (e) { procName = 'unknown'; }

    for (const w of wins) {
      try {
        const props = w.properties();
        if (props.minimized) continue; // belt-and-suspenders if whose() filter wasn't supported
        const pos = props.position, size = props.size;
        if (!pos || !size || size[0] === 0 || size[1] === 0) continue;

        candidates.push({
          proc: proc,
          procName: procName,
          win: w,
          cx: pos[0] + size[0] / 2,
          cy: pos[1] + size[1] / 2
        });
      } catch (e) { continue; }
    }
  }

  if (candidates.length === 0) return 'No candidate windows found.';

  // --- Score candidates ---
  let best = null;
  let bestScore = Infinity;

  for (const cand of candidates) {
    const dx = cand.cx - current.cx;
    const dy = cand.cy - current.cy;
    if (Math.abs(dx) < DEADZONE && Math.abs(dy) < DEADZONE) continue; // effectively the same window

    let primary, secondary, valid;
    if (direction === 'left') { primary = -dx; secondary = dy; valid = dx < -DEADZONE; }
    else if (direction === 'right') { primary = dx; secondary = dy; valid = dx > DEADZONE; }
    else if (direction === 'up') { primary = -dy; secondary = dx; valid = dy < -DEADZONE; }
    else /* down */ { primary = dy; secondary = dx; valid = dy > DEADZONE; }

    if (!valid) continue;

    // Penalize misalignment on the perpendicular axis more than distance
    // on the primary axis, so directly-across windows win over diagonal ones.
    const score = primary + Math.abs(secondary) * 2;
    if (score < bestScore) {
      bestScore = score;
      best = cand;
    }
  }

  if (!best) return 'No window found in that direction.';

  try {
    best.proc.frontmost = true;
    try { best.win.attributes.byName('AXMain').setTo(true); } catch (e) {}
    try { best.win.actions.byName('AXRaise').perform(); } catch (e) {}
  } catch (e) {
    return 'Found a window but could not focus it: ' + e;
  }

  return 'Focused: ' + best.procName;
}
