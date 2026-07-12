namespace OverlayBrowser.Windows;

internal enum ModifierKey
{
    LeftAlt,
    RightAlt,
    LeftShift,
    RightShift,
    LeftControl,
    RightControl,
    LeftWindows,
    RightWindows
}

internal enum ModifierHotKeySide
{
    Left,
    Right
}

internal static class ModifierHotKeyPolicy
{
    internal static ModifierHotKeySide? ActiveSide(IReadOnlySet<ModifierKey> pressed)
    {
        if (pressed.Contains(ModifierKey.LeftControl)
            || pressed.Contains(ModifierKey.RightControl)
            || pressed.Contains(ModifierKey.LeftWindows)
            || pressed.Contains(ModifierKey.RightWindows))
        {
            return null;
        }

        bool leftPair = pressed.Contains(ModifierKey.LeftAlt) && pressed.Contains(ModifierKey.LeftShift);
        bool rightPair = pressed.Contains(ModifierKey.RightAlt) && pressed.Contains(ModifierKey.RightShift);
        bool leftSide = pressed.Contains(ModifierKey.LeftAlt) || pressed.Contains(ModifierKey.LeftShift);
        bool rightSide = pressed.Contains(ModifierKey.RightAlt) || pressed.Contains(ModifierKey.RightShift);

        return (leftPair, rightPair, leftSide, rightSide) switch
        {
            (true, false, true, false) => ModifierHotKeySide.Left,
            (false, true, false, true) => ModifierHotKeySide.Right,
            _ => null
        };
    }

    internal static bool HasCompletePair(IReadOnlySet<ModifierKey> pressed) =>
        (pressed.Contains(ModifierKey.LeftAlt) && pressed.Contains(ModifierKey.LeftShift))
        || (pressed.Contains(ModifierKey.RightAlt) && pressed.Contains(ModifierKey.RightShift));
}

internal sealed class ModifierHotKeyState
{
    private readonly HashSet<ModifierKey> _pressed = [];
    private bool _chordConsumed;

    internal ModifierHotKeySide? Update(ModifierKey key, bool isPressed)
    {
        if (isPressed)
        {
            _pressed.Add(key);
        }
        else
        {
            _pressed.Remove(key);
        }

        if (!ModifierHotKeyPolicy.HasCompletePair(_pressed))
        {
            _chordConsumed = false;
            return null;
        }

        if (_chordConsumed)
        {
            return null;
        }

        _chordConsumed = true;
        return ModifierHotKeyPolicy.ActiveSide(_pressed);
    }
}
