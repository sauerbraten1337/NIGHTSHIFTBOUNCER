/** Minimaler Event-Bus zur Entkopplung von Systemen, UI und Audio. */

export function createBus() {
  const handlers = new Map();

  return {
    on(type, fn) {
      if (!handlers.has(type)) handlers.set(type, new Set());
      handlers.get(type).add(fn);
      return () => this.off(type, fn);
    },
    off(type, fn) {
      handlers.get(type)?.delete(fn);
    },
    emit(type, payload) {
      const set = handlers.get(type);
      if (set) for (const fn of [...set]) fn(payload);
      const any = handlers.get('*');
      if (any) for (const fn of [...any]) fn({ type, payload });
    },
    clear() {
      handlers.clear();
    }
  };
}
