namespace OverlayBrowser.Windows.Tests;

public sealed class BrowserContractTests
{
    [Fact]
    public void AppOptionsRecognizeSelfTestWithoutChangingStartUrl()
    {
        AppOptions options = AppOptions.Parse(["--self-test"]);

        Assert.True(options.RunSelfTest);
        StartDestination.Url destination = Assert.IsType<StartDestination.Url>(options.Destination);
        Assert.Equal(UrlPolicy.DefaultUri, destination.Value);
    }

    [Fact]
    public void FixedCursorScriptUsesDocumentStartCompatibleCss()
    {
        Assert.Contains("cursor: default !important", BrowserScripts.FixedCursor, StringComparison.Ordinal);
        Assert.DoesNotContain("mousemove", BrowserScripts.FixedCursor, StringComparison.Ordinal);
    }

    [Fact]
    public void SilentMediaScriptMutesMediaWithoutPatchingAudioContext()
    {
        Assert.Contains("HTMLMediaElement", BrowserScripts.SilentMedia, StringComparison.Ordinal);
        Assert.Contains("node.muted = true", BrowserScripts.SilentMedia, StringComparison.Ordinal);
        Assert.Contains("node.volume = 0", BrowserScripts.SilentMedia, StringComparison.Ordinal);
        Assert.DoesNotContain("AudioContext", BrowserScripts.SilentMedia, StringComparison.Ordinal);
    }

    [Fact]
    public void EscapeBridgeUsesWebViewHostMessaging()
    {
        Assert.Contains("overlay-escape", BrowserScripts.EscapeBridge, StringComparison.Ordinal);
        Assert.Contains("chrome?.webview?.postMessage", BrowserScripts.EscapeBridge, StringComparison.Ordinal);
    }
}
