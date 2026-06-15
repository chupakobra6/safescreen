(() => {
  const toggleEventName = "overlay-focus-guard:set-enabled";

  const state = {
    enabled: false,
    installed: false,
    dispatchingRecoveryEvent: false,
    restorers: []
  };

  function findPropertyDescriptor(object, propertyName) {
    let current = object;
    while (current) {
      const descriptor = Object.getOwnPropertyDescriptor(current, propertyName);
      if (descriptor) {
        return { owner: current, descriptor };
      }
      current = Object.getPrototypeOf(current);
    }
    return null;
  }

  function addRestorer(callback) {
    state.restorers.push(callback);
  }

  function patchGetter(prototype, propertyName, value) {
    const original = findPropertyDescriptor(prototype, propertyName);
    if (!original || original.descriptor.configurable === false) {
      return;
    }

    try {
      Object.defineProperty(original.owner, propertyName, {
        configurable: true,
        enumerable: original.descriptor.enumerable,
        get() {
          return state.enabled ? value : original.descriptor.get?.call(this);
        }
      });
      addRestorer(() => Object.defineProperty(original.owner, propertyName, original.descriptor));
    } catch (_) {
      // Some pages harden descriptors. Leave them unchanged instead of failing the page.
    }
  }

  function patchMethod(prototype, methodName, replacement) {
    const original = findPropertyDescriptor(prototype, methodName);
    if (!original || original.descriptor.configurable === false || typeof original.descriptor.value !== "function") {
      return;
    }

    try {
      Object.defineProperty(original.owner, methodName, {
        configurable: true,
        enumerable: original.descriptor.enumerable,
        writable: true,
        value(...args) {
          if (state.enabled) {
            return replacement.call(this, ...args);
          }
          return original.descriptor.value.apply(this, args);
        }
      });
      addRestorer(() => Object.defineProperty(original.owner, methodName, original.descriptor));
    } catch (_) {
      // Leave native behavior if this page does not allow patching.
    }
  }

  function addGuardedEventBlocker(target, eventName) {
    const handler = (event) => {
      if (!state.enabled || state.dispatchingRecoveryEvent) {
        return;
      }

      event.stopImmediatePropagation();
    };

    target.addEventListener(eventName, handler, true);
    addRestorer(() => target.removeEventListener(eventName, handler, true));
  }

  function dispatchVisibleFocusState() {
    state.dispatchingRecoveryEvent = true;
    try {
      window.dispatchEvent(new Event("focus"));
    } catch (_) {}

    try {
      document.dispatchEvent(new Event("visibilitychange"));
    } catch (_) {}
    state.dispatchingRecoveryEvent = false;
  }

  function install() {
    if (state.installed) {
      return;
    }

    patchGetter(Document.prototype, "hidden", false);
    patchGetter(Document.prototype, "visibilityState", "visible");
    patchGetter(Document.prototype, "webkitHidden", false);
    patchGetter(Document.prototype, "webkitVisibilityState", "visible");
    patchMethod(Document.prototype, "hasFocus", () => true);

    for (const eventName of ["blur", "visibilitychange", "webkitvisibilitychange", "pagehide", "freeze"]) {
      addGuardedEventBlocker(window, eventName);
      addGuardedEventBlocker(document, eventName);
    }

    state.installed = true;
  }

  function uninstall() {
    while (state.restorers.length > 0) {
      const restore = state.restorers.pop();
      try {
        restore();
      } catch (_) {}
    }
    state.installed = false;
  }

  function setEnabled(enabled) {
    const nextEnabled = Boolean(enabled);
    if (nextEnabled) {
      install();
    }

    state.enabled = nextEnabled;

    if (nextEnabled) {
      dispatchVisibleFocusState();
    } else {
      uninstall();
    }
  }

  window.addEventListener(toggleEventName, (event) => {
    setEnabled(event.detail?.enabled === true);
  });
})();
