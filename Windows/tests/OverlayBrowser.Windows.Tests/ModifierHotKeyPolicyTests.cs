namespace OverlayBrowser.Windows.Tests;

public sealed class ModifierHotKeyPolicyTests
{
    [Fact]
    public void RecognizesLeftAltShiftOnly()
    {
        Assert.Equal(
            ModifierHotKeySide.Left,
            ModifierHotKeyPolicy.ActiveSide(new HashSet<ModifierKey>
            {
                ModifierKey.LeftAlt,
                ModifierKey.LeftShift
            }));
    }

    [Fact]
    public void RecognizesRightAltShiftOnly()
    {
        Assert.Equal(
            ModifierHotKeySide.Right,
            ModifierHotKeyPolicy.ActiveSide(new HashSet<ModifierKey>
            {
                ModifierKey.RightAlt,
                ModifierKey.RightShift
            }));
    }

    [Fact]
    public void RejectsMixedSidesAndExtraModifiers()
    {
        Assert.Null(ModifierHotKeyPolicy.ActiveSide(new HashSet<ModifierKey>
        {
            ModifierKey.LeftAlt,
            ModifierKey.RightShift
        }));
        Assert.Null(ModifierHotKeyPolicy.ActiveSide(new HashSet<ModifierKey>
        {
            ModifierKey.LeftAlt,
            ModifierKey.LeftShift,
            ModifierKey.LeftControl
        }));
        Assert.Null(ModifierHotKeyPolicy.ActiveSide(new HashSet<ModifierKey>
        {
            ModifierKey.LeftAlt,
            ModifierKey.LeftShift,
            ModifierKey.RightAlt
        }));
    }

    [Fact]
    public void StateTriggersOnceUntilPairIsReleased()
    {
        var state = new ModifierHotKeyState();

        Assert.Null(state.Update(ModifierKey.LeftAlt, true));
        Assert.Equal(ModifierHotKeySide.Left, state.Update(ModifierKey.LeftShift, true));
        Assert.Null(state.Update(ModifierKey.LeftShift, true));
        Assert.Null(state.Update(ModifierKey.LeftShift, false));
        Assert.Equal(ModifierHotKeySide.Left, state.Update(ModifierKey.LeftShift, true));
    }

    [Fact]
    public void InvalidChordStaysConsumedUntilReleased()
    {
        var state = new ModifierHotKeyState();

        Assert.Null(state.Update(ModifierKey.LeftControl, true));
        Assert.Null(state.Update(ModifierKey.LeftAlt, true));
        Assert.Null(state.Update(ModifierKey.LeftShift, true));
        Assert.Null(state.Update(ModifierKey.LeftControl, false));
        Assert.Null(state.Update(ModifierKey.LeftShift, false));
        Assert.Equal(ModifierHotKeySide.Left, state.Update(ModifierKey.LeftShift, true));
    }
}
