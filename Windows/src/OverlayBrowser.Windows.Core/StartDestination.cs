namespace OverlayBrowser.Windows;

internal abstract record StartDestination
{
    private StartDestination()
    {
    }

    internal sealed record Url(Uri Value) : StartDestination;

    internal sealed record FallbackPage : StartDestination;
}
