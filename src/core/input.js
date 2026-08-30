/** Tastatur-Input mit Edge-Detection (gedrueckt / gerade gedrueckt). */

export function createInput(target = window) {
  const down = new Set();
  const pressed = new Set();
  const consumed = new Set();
  let enabled = true;

  const onKeyDown = (e) => {
    if (!enabled) return;
    if (e.repeat) return;
    // Scrollen / Browser-Shortcuts im Spiel unterdruecken.
    if (BLOCKED.has(e.code)) e.preventDefault();
    down.add(e.code);
    pressed.add(e.code);
  };
  const onKeyUp = (e) => {
    down.delete(e.code);
  };
  const onBlur = () => {
    // Nur gehaltene Tasten vergessen. Frisch gedrückte NICHT verwerfen:
    // Beim Wechsel vom Briefing ins Spiel verliert der Button den Fokus, und
    // das Blur-Event würde sonst genau den ersten Tastendruck schlucken.
    down.clear();
  };

  target.addEventListener('keydown', onKeyDown);
  target.addEventListener('keyup', onKeyUp);
  target.addEventListener('blur', onBlur);

  return {
    isDown: (code) => down.has(code),
    /** true genau einmal pro physischem Tastendruck. */
    justPressed(code) {
      if (pressed.has(code) && !consumed.has(code)) {
        consumed.add(code);
        return true;
      }
      return false;
    },
    anyDown: (codes) => codes.some((c) => down.has(c)),
    /** Am Ende jedes Frames aufrufen. */
    endFrame() {
      pressed.clear();
      consumed.clear();
    },
    setEnabled(v) {
      enabled = v;
      if (!v) { down.clear(); pressed.clear(); }
    },
    destroy() {
      target.removeEventListener('keydown', onKeyDown);
      target.removeEventListener('keyup', onKeyUp);
      target.removeEventListener('blur', onBlur);
    }
  };
}

const BLOCKED = new Set([
  'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space',
  'Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit7', 'Digit8', 'Digit9', 'Digit0'
]);
