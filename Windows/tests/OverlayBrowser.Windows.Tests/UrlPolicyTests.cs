namespace OverlayBrowser.Windows.Tests;

public sealed class UrlPolicyTests
{
    [Fact]
    public void AddsHttpsWhenSchemeIsMissing()
    {
        bool parsed = UrlPolicy.TryNormalize("example.com", out Uri? uri);

        Assert.True(parsed);
        Assert.Equal("https://example.com/", uri?.AbsoluteUri);
    }

    [Fact]
    public void KeepsHttpForLocalTesting()
    {
        bool parsed = UrlPolicy.TryNormalize("http://localhost:8080/focus.html", out Uri? uri);

        Assert.True(parsed);
        Assert.Equal("http://localhost:8080/focus.html", uri?.AbsoluteUri);
    }

    [Theory]
    [InlineData("file:///C:/test.html")]
    [InlineData("javascript:alert(1)")]
    [InlineData("")]
    public void RejectsUnsupportedOrEmptyAddresses(string value)
    {
        Assert.False(UrlPolicy.TryNormalize(value, out _));
    }

    [Fact]
    public void DefaultsToChatGpt()
    {
        StartDestination destination = UrlPolicy.DestinationFrom([]);

        StartDestination.Url url = Assert.IsType<StartDestination.Url>(destination);
        Assert.Equal("https://chatgpt.com/", url.Value.AbsoluteUri);
    }

    [Fact]
    public void InvalidExplicitAddressUsesFallbackPage()
    {
        StartDestination destination = UrlPolicy.DestinationFrom(["--ignored", "file:///C:/test.html"]);

        Assert.IsType<StartDestination.FallbackPage>(destination);
    }
}
