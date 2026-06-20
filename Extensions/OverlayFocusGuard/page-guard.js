(() => {
  const toggleEventName = "overlay-focus-guard:set-enabled";
  const component = "page-guard";

  const state = {
    enabled: false,
    installed: false,
    dispatchingRecoveryEvent: false
  };

  function log(event, fields = {}) {
    console.info("[OverlayFocusGuard]", { component, event, ...fields });
  }

  function warn(event, fields = {}) {
    console.warn("[OverlayFocusGuard]", { component, event, ...fields });
  }

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
    } catch (_) {
      warn("patch-getter-failed", { propertyName });
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
    } catch (_) {
      warn("patch-method-failed", { methodName });
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
    log("installed");
  }

  function setEnabled(enabled) {
    const nextEnabled = Boolean(enabled);
    const previousEnabled = state.enabled;
    state.enabled = nextEnabled;

    if (nextEnabled) {
      dispatchVisibleFocusState();
    }

    if (previousEnabled !== nextEnabled) {
      log("enabled-changed", { enabled: nextEnabled });
    }
  }

  window.addEventListener(toggleEventName, (event) => {
    setEnabled(event.detail?.enabled === true);
  });

  install();
})();
