using System.ComponentModel;
using System.Globalization;
using System.Runtime.InteropServices;

namespace OverlayBrowser.Windows;

internal sealed class HotKeyController : IDisposable
{
    private const uint VkLeftShift = 0xA0;
    private const uint VkRightShift = 0xA1;
    private const uint VkLeftControl = 0xA2;
    private const uint VkRightControl = 0xA3;
    private const uint VkLeftAlt = 0xA4;
    private const uint VkRightAlt = 0xA5;
    private const uint VkLeftWindows = 0x5B;
    private const uint VkRightWindows = 0x5C;

    private readonly Action<ModifierHotKeySide> _onPressed;
    private readonly ModifierHotKeyState _state = new();
    private readonly NativeMethods.LowLevelKeyboardProc _callback;
    private nint _hook;

    internal HotKeyController(Action<ModifierHotKeySide> onPressed)
    {
        _onPressed = onPressed;
        _callback = HandleKeyboardEvent;
    }

    internal void Register()
    {
        if (_hook != nint.Zero)
        {
            return;
        }

        nint module = NativeMethods.GetModuleHandle(null);
        _hook = NativeMethods.SetWindowsHookEx(
            NativeMethods.WhKeyboardLl,
            _callback,
            module,
            0);

        if (_hook == nint.Zero)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Unable to install the global keyboard hook.");
        }

        AppLog.Info("hotkey", "hook-installed");
    }

    public void Dispose()
    {
        if (_hook == nint.Zero)
        {
            return;
        }

        if (!NativeMethods.UnhookWindowsHookEx(_hook))
        {
            AppLog.Warning("hotkey", "hook-remove-failed", new Dictionary<string, string>
            {
                ["error"] = Marshal.GetLastWin32Error().ToString(CultureInfo.InvariantCulture)
            });
        }

        _hook = nint.Zero;
    }

    private nint HandleKeyboardEvent(int code, nint message, nint data)
    {
        if (code >= 0 && TryReadKey(message, data, out ModifierKey key, out bool isPressed))
        {
            ModifierHotKeySide? side = _state.Update(key, isPressed);
            if (side is not null)
            {
                AppLog.Info("hotkey", "trigger", new Dictionary<string, string>
                {
                    ["side"] = side == ModifierHotKeySide.Left ? "left" : "right"
                });
                try
                {
                    _onPressed(side.Value);
                }
                catch (Exception exception)
                {
                    AppLog.Error("hotkey", "callback-failed", new Dictionary<string, string>
                    {
                        ["error"] = exception.Message
                    });
                }
            }
        }

        return NativeMethods.CallNextHookEx(_hook, code, message, data);
    }

    private static bool TryReadKey(nint message, nint data, out ModifierKey key, out bool isPressed)
    {
        int messageValue = unchecked((int)message);
        isPressed = messageValue is NativeMethods.WmKeyDown or NativeMethods.WmSysKeyDown;
        bool isKeyEvent = isPressed || messageValue is NativeMethods.WmKeyUp or NativeMethods.WmSysKeyUp;
        if (!isKeyEvent)
        {
            key = default;
            return false;
        }

        NativeMethods.KeyboardHookData hookData = Marshal.PtrToStructure<NativeMethods.KeyboardHookData>(data);
        (bool recognized, key) = hookData.VirtualKeyCode switch
        {
            VkLeftAlt => (true, ModifierKey.LeftAlt),
            VkRightAlt => (true, ModifierKey.RightAlt),
            VkLeftShift => (true, ModifierKey.LeftShift),
            VkRightShift => (true, ModifierKey.RightShift),
            VkLeftControl => (true, ModifierKey.LeftControl),
            VkRightControl => (true, ModifierKey.RightControl),
            VkLeftWindows => (true, ModifierKey.LeftWindows),
            VkRightWindows => (true, ModifierKey.RightWindows),
            _ => (false, default)
        };
        return recognized;
    }
}
