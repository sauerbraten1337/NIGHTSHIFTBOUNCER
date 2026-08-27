/** Fixed-Timestep Game-Loop mit variablem Rendering. */

export function createLoop({ update, render, step = 1 / 60, maxFrameTime = 0.25 }) {
  let running = false;
  let last = 0;
  let acc = 0;
  let rafId = 0;
  let elapsed = 0;

  function frame(now) {
    if (!running) return;
    const dt = Math.min(maxFrameTime, (now - last) / 1000 || 0);
    last = now;
    acc += dt;
    let guard = 0;
    while (acc >= step && guard < 8) {
      update(step, elapsed);
      elapsed += step;
      acc -= step;
      guard++;
    }
    if (guard >= 8) acc = 0; // Spirale vermeiden
    render(dt, elapsed);
    rafId = requestAnimationFrame(frame);
  }

  return {
    start() {
      if (running) return;
      running = true;
      last = performance.now();
      acc = 0;
      rafId = requestAnimationFrame(frame);
    },
    stop() {
      running = false;
      cancelAnimationFrame(rafId);
    },
    get running() {
      return running;
    },
    get elapsed() {
      return elapsed;
    }
  };
}
